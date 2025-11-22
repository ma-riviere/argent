# Use-case: RAG with `argent` and `ragnar`

Retrieval-Augmented Generation (RAG) enhances LLM responses by
retrieving relevant context from a knowledge base before generating
answers. The [ragnar](https://ragnar.tidyverse.org/) package provides
efficient tools for building and querying knowledge stores, which can be
integrated with argent to create AI agents that answer questions
grounded in your documentation.

This article demonstrates how to build a RAG system using ragnar’s
hybrid search (combining semantic and keyword-based retrieval) with
`argent`.

For more details, see the [ragnar
documentation](https://ragnar.tidyverse.org/).

## Setup

``` r
library(argent)
library(ragnar)
library(cachem)
library(stringr)
```

## Basic RAG System

### Building a Knowledge Store

First, create a knowledge store from your documentation. We’ll use the
Quarto documentation as an example, to stay similar to the ragnar
documentation.

#### Collecting Documents

Here, let’s collect (part of) the Quarto documentation from the Quarto
website.

``` r
quarto_docs_url_filter <- function(urls) {
    str_subset(urls, "https://quarto.org/docs/") |> 
        str_subset(regex("\\.html$", ignore_case = FALSE))
}

paths <- ragnar::ragnar_find_links(
    "https://quarto.org/", 
    depth = 1, 
    url_filter = quarto_docs_url_filter
)
```

#### Create Store with Embeddings

``` r
gemini_embedding_fn <- \(text) ragnar::embed_google_gemini(text, model = "text-embedding-004")

store <- ragnar::ragnar_store_create(
    "data/quarto-docs.duckdb",
    embed = gemini_embedding_fn
)
```

> **Note**
>
> We could have made our own embedding function with our `LocalLLM`
> class and a local embedding model:
>
> ``` r
> local_embedding_fn <- function(text) {
>     argent::LocalLLM$new(
>         base_url = "http://127.0.0.1:5000",
>         default_model = "Qwen3-Embedding-8B-Q8_0.gguf"
>     )$embeddings(text)
> }
>
> store <- ragnar::ragnar_store_create(
>     "data/quarto-docs.duckdb",
>     embed = local_embedding_fn
> )
> ```
>
> Google, OpenAI (all 3 classes), OpenRouter, and local LLM all support
> embeddings.

#### Process and Index Documents

``` r
insert_chunk_into_store <- function(path) {
    ragnar::read_as_markdown(path) |>
        ragnar::markdown_chunk() |>
        ragnar::ragnar_store_insert(store, chunks = _)
}

purrr::walk(paths, insert_chunk_into_store, .progress = TRUE)

ragnar::ragnar_store_build_index(store)
```

### Creating a Stateful Retrieval Tool

To enable progressive exploration of the knowledge base (avoiding
duplicate chunks across multiple queries), we need to track which chunks
have already been retrieved. Since argent’s tools are stateless, we use
[`cachem::cache_mem()`](https://cachem.r-lib.org/reference/cache_mem.html)
to maintain state across tool calls.

``` r
retrieve_state <- cachem::cache_mem()

retrieve_docs <- function(query) {
    #' @description Retrieve relevant documentation chunks from Quarto docs
    #' @param query:string* Search query describing what information is needed

    # Get previously retrieved chunk IDs
    retrieved_ids <- retrieve_state$get("retrieved_chunks") %||% character(0)

    # Perform hybrid search using DuckDB (vector + keyword matching)
    chunks <- ragnar::ragnar_retrieve(
        store,
        query,
        n = 5,
        exclude_chunk_ids = retrieved_ids
    )

    # Update state with newly retrieved chunk IDs
    retrieve_state$set("retrieved_chunks", c(retrieved_ids, purrr::flatten_int(chunks$chunk_id)))

    results <- dplyr::select(chunks, text, origin, context)
    return(jsonlite::toJSON(results, auto_unbox = TRUE))
}
```

### Using the RAG System

Now you can use the retrieval tool in conversations. The LLM will
automatically retrieve relevant documentation when needed.

``` r
gemini <- Google$new()

gemini$chat(
    "How do I create tables in Quarto?",
    tools = list(as_tool(retrieve_docs))
)
```

Answer

You can create tables in Quarto using Markdown pipe tables. Here’s an
example:

``` markdown
| fruit  | price  |
|--------|--------|
| apple  | 2.05   |
| pear   | 1.37   |
| orange | 3.09   |

: Fruit prices {.striped .hover}
```

This will render a table with three columns: “fruit” and “price”, with
row stripes and highlighting on hover due to the `{.striped .hover}`
attribute after the caption.

You can also control the relative column widths using dashes in the line
separating the header from the body. For example, `---|-` would make the
first column 3/4 and the second column 1/4 of the full text width.

Keep in mind that pipe table cells cannot contain block elements like
paragraphs and lists, and cannot span multiple lines

The LLM will:

1.  Recognize it needs documentation about Quarto tables
2.  Call `retrieve_docs("tables in Quarto")` automatically
3.  Receive relevant documentation chunks
4.  Generate an answer based on the retrieved context
