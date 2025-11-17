# OpenAI - Assistants API

> **Deprecation Warning**
>
> The Assistants API is deprecated and will shut down on August 26,
> 2026.
>
> **Use the [Responses
> API](https://ma-riviere.github.io/argent/articles/responses-api.md)
> instead** for all new development. The Responses API provides all the
> same features with a better interface and additional capabilities.
>
> Additionally, the Assistants API does not work with GPT-5 models.

## Introduction

The Assistants API manages conversation state server-side through
threads and provides server-side tools like file_search and
code_interpreter.

## Key Differences with OpenAI’s other APIs

- **Server-side state**: Conversation history stored in threads on
  OpenAI servers
- **Thread-based management**: Conversations persist in threads
- **No GPT-5 support**: Limited to GPT-4 and earlier models
- **No reasoning**: Does not support `reasoning_effort`

## Setup

``` r
openai_assistant <- OpenAI_Assistant$new(api_key = Sys.getenv("OPENAI_API_KEY"))
```

> **Note**
>
> This does not create an assistant, it only creates an instance of the
> `OpenAI_Assistant` class. For OpenAI Assistants, you need to
> specifically create an assistant with `create_assistant()`.

``` r
openai_assistant$create_assistant(name = "My Assistant", model = "gpt-4o-mini")
```

The assistant configuration (model, temperature, tools, system) is set
during creation and applies to all subsequent `chat()` calls.

> **Note**
>
> We can check the assistant configuration with `get_assistant()`:
>
> ``` r
> openai_assistant$get_assistant()
> ```
>
> We can also load an existing assistant with `load_assistant()`:
>
> ``` r
> # Find assistant by name
> assistant_id <- openai_assistant$find_assistants(name = "My Assistant") |>
>     purrr::pluck("id", 1)
>
> # Load in a new client instance
> existing_assistant <- OpenAI_Assistant$new()$load_assistant(id = assistant_id)
> ```

**Available Models**

> **Note**
>
> The Assistants API does not support GPT-5 models. Use GPT-4 or
> earlier.

``` r
openai_assistant$list_models() |>
    dplyr::filter(stringr::str_detect(id, "-4o-|-4.1-"))
```

## Basic Chat

The Assistants API manages conversation state through threads:

- **First message**: Creates a new thread automatically
- **Subsequent messages**: Continue in the same thread by default
- **New thread**: Set `in_new_thread = TRUE` to create a fresh
  conversation
- **Persistence**: Threads persist on OpenAI’s servers until explicitly
  deleted

``` r
openai_assistant$chat("What's the R programming language? Answer in three sentences.")
#> ✔ [OpenAI Assistant] Thread created: thread_r4WVfgfBmPZ66WUpy4diT2gE
```

Continue in the same thread:

``` r
openai_assistant$chat("Tell me more about its history")
```

Start a new thread:

``` r
openai_assistant$chat("What were we just talking about?", in_new_thread = TRUE)
#> ✔ [OpenAI Assistant] Thread created: thread_eVLlsNW3xGR2a0cUQSaoMX4G
```

> **Note**
>
> Unlike the Responses API which uses `previous_response_id`, the
> Assistants API maintains state through persistent threads. Threads
> continue automatically unless you explicitly create a new one,
> e.g. with `in_new_thread = TRUE`.

Access the latest thread messages with `get_thread_msgs()` (to see the
current ‘chat history’):

``` r
openai_assistant$get_chat_history()
```

Or, simply print the `openai_assistant` object to see the current chat
history:

``` r
print(openai_assistant, show_tools = TRUE)
```

## Tool Calling + Structured Output

First, define web-related tools bundled in a `web_tools` list:

Web Tools Implementation

**Search:**

``` r
web_search <- function(query) {
    #' @description Search the web for information using Tavily API. Returns a JSON array of search results with titles, URLs, and content snippets. Use this when you need current information, facts, news, or any data not in your training data.
    #' @param query:string* The search query string. Be specific and use keywords that will yield the most relevant results.
    
    return(web_search_tavily(query))
}

web_search_tavily <- function(query) {
    res <- httr2::request("https://api.tavily.com/search") |> 
        httr2::req_body_json(list(
            query = query,
            search_depth = "basic",
            include_answer = FALSE,
            max_results = 10,
            api_key = Sys.getenv("TAVILY_API_KEY")
        )) |> 
        httr2::req_error(is_error = \(resp) FALSE) |> 
        httr2::req_throttle(rate = 20/60, realm = "tavily") |> 
        httr2::req_perform() |> 
        httr2::resp_body_json() |> 
        purrr::discard_at(c("response_time", "follow_up_questions", "images"))

    results <- purrr::map(res$results, \(x) purrr::discard_at(x, "raw_content"))

    return(jsonlite::toJSON(results, pretty = FALSE, auto_unbox = TRUE))
}
```

**Fetch:**

``` r
web_fetch <- function(url) {
    #' @description Fetch and extract the main text content from a web page as clean markdown. Returns the page content with formatting preserved, stripped of navigation, ads, and boilerplate. Use this to read articles, documentation, blog posts, or any web page content.
    #' @param url:string* The complete URL of the web page to fetch (e.g., "https://example.com/article"). Must be a valid HTTP/HTTPS URL.
    
    res <- web_fetch_trafilatura(url)

    could_not_fetch <- c(
        "Impossible to fetch the contents of this web page",
        "Please reload this page",
        "There was an error while loading",
        "404"
    )
    if (is.null(res) || is.na(res) || nchar(res) == 0 ||
        any(stringr::str_detect(res, stringr::fixed(could_not_fetch, ignore_case = TRUE)))) {
        res <- web_fetch_rvest(url)
    }
    return(res)
}

web_fetch_trafilatura <- function(url) {
    # pip install trafilatura
    tryCatch({
        res <- paste0("trafilatura -u ", url, " --markdown --no-comments --links ") |> 
            system(intern = TRUE) |> 
            purrr::keep(nzchar) |>
            paste0(collapse = "\n")
        
        return(res)
    },
    error = function(e) {
        return("Impossible to fetch the contents of this web page. It might not allow scraping")
    })
}

web_fetch_rvest <- function(url) {
    tags_to_ignore <- c(
        "a", "script", "code", "img", "svg", "footer", "g", "path", "polygon", "label", "button", "form", "input", "select", 
        "style", "link", "meta", "noscript", "iframe", "embed", "object", "param", "video", "audio", "track", "source", 
        "canvas", "map", "area", "math", "col", "colgroup", "dl", "dt", "dd", "hr", "pre", "address", "figure", "figcaption",
        "dfn", "em", "kbd", "samp", "var", "del", "ins", "mark", "circle"
    )

    remove_tags <- function(xml, tags) {
        purrr::walk(tags, \(tag) purrr::walk(xml2::xml_find_all(xml, paste0(".//", tag)), \(node) xml2::xml_remove(node)))
        return(xml)
    }

    cleaned_contents <- tryCatch(
        rvest::read_html(url)
        |> rvest::html_element("body")
        |> remove_tags(tags_to_ignore)
        |> rvest::html_children()
        |> rvest::html_text2()
        |> purrr::discard(\(x) x == "")
        |> paste0(collapse = "\n\n"),
        error = \(e) return("")
    )
    return(cleaned_contents)
}
```

Then, define a JSON schema for structured output using
[`schema()`](https://ma-riviere.github.io/argent/reference/tool_definitions.md):

``` r
package_info_schema <- schema(
    name = "package_info",
    description = "Information about an R package release",
    release_version = "string* The release version of the package",
    release_date = "string* The release date of the `release_version`"
)
```

Create an assistant with client-side tools:

``` r
openai_assistant <- OpenAI_Assistant$new()$create_assistant(
    name = "My Assistant",
    model = "gpt-4.1",
    tools = list(as_tool(web_search), as_tool(web_fetch))
)
```

Ask a question with structured output:

``` r
openai_assistant$chat(
    "When was the first release of the R 'ellmer' package on GitHub?",
    output_schema = package_info_schema
)
6#> ✔ [OpenAI Assistant] Thread created: thread_leVxekjFQnO8vUES62HBJuLc
```

``` default
$release_version
[1] "0.1.0"

$release_date
[1] "2024-03-20"
```

*Hum. Not quite right …*

> **Warning**
>
> When an assistant uses server-side tools (like `file_search` or
> `code_interpreter`) and you provide an `output_schema`, the API forces
> a second call with the schema (and no tools) once the assistant is
> done using its tools, to bypass the fact that you can’t use
> server-side tools with structured outputs. This happens automatically.

## Server-side Tools

Server-side tools are tools you can call without having to define them
yourself. They will be run on the provider’s server.

OpenAI Assistants API supports two server-side tools:

- **file_search** - Search through uploaded files using vector stores
  (i.e. server-side RAG)
- **code_interpreter** - Execute Python code in sandboxed containers

### Server-side: Code Interpreter

The Assistants API provides `code_interpreter` for executing Python
code. Unlike the Responses API which uses containers, the Assistants API
attaches files directly to the tool.

**Example: Analyzing the Penguins Dataset**

``` r
penguins_url <- "https://raw.githubusercontent.com/allisonhorst/palmerpenguins/refs/heads/main/inst/extdata/penguins.csv"
penguins_file_metadata <- openai_assistant$upload_file(penguins_url, purpose = "assistants")

data_analyst <- OpenAI_Assistant$new()$create_assistant(
    name = "Data Analyst",
    model = "gpt-4.1",
    tools = list(list(type = "code_interpreter", file_ids = list(penguins_file_metadata$id)))
)

data_analyst$chat(
    "Create a summary table showing average body_mass grouped by species, sex, and year. Save as CSV."
)
```

Download generated files:

``` r
downloaded_paths <- data_analyst$download_generated_files(dest_path = "data")
```

``` r
read.csv(downloaded_paths[1], na.strings = c("", "NA"))
```

``` default
     species    sex year body_mass_g
1     Adelie female 2007    3389.773
2     Adelie female 2008    3386.000
3     Adelie female 2009    3334.615
4     Adelie   male 2007    4038.636
5     Adelie   male 2008    4098.000
6     Adelie   male 2009    3995.192
7  Chinstrap female 2007    3569.231
8  Chinstrap female 2008    3472.222
9  Chinstrap female 2009    3522.917
10 Chinstrap   male 2007    3819.231
11 Chinstrap   male 2008    4127.778
12 Chinstrap   male 2009    3927.083
13    Gentoo female 2007    4618.750
14    Gentoo female 2008    4627.273
15    Gentoo female 2009    4786.250
16    Gentoo   male 2007    5552.941
17    Gentoo   male 2008    5410.870
18    Gentoo   male 2009    5510.714
```

Continue asking questions in the same thread:

``` r
penguin_output_schema <- schema(
    name = "penguin_output",
    description = "Schema for the penguin output",
    average_body_mass = "number* The average body_mass",
    species = "string* The species",
    sex = "string* The sex",
    year = "integer* The year"
)

data_analyst$chat(
    "What's the average body_mass for the Adelie females in 2009? Use the code_interpreter tool to compute the answer.",
    output_schema = penguin_output_schema
)
```

``` default
$average_body_mass
[1] 3317.073

$species
[1] "Adelie"

$sex
[1] "male"

$year
[1] 2007
```

*Incorrect year, incorrect sex, and even accounting for that, the value
is incorrect …*

> **Note**
>
> The Responses API uses containers for code execution with dedicated
> management methods (`list_containers()`, `delete_container()`). The
> Assistants API attaches files directly and maintains context
> automatically within threads.

## Multimodal Inputs

OpenAI Assistants API supports sending:

- Images: URLs (as-is, or base64), files (base64)
- PDFs: URLs (as-is, base64, or text content), files (base64, or text
  content)
- Remote files (through
  [`as_file_content()`](https://ma-riviere.github.io/argent/reference/content_converters.md))
- Plain text & code files
- Text-based data files (csv, tsv, json, ..)
- R objects

### Image Comprehension

Downloading an example image

``` r
bsg04_cast_image_url <- "https://upload.wikimedia.org/wikipedia/en/1/1a/Battlestar_Galactica_%282004%29_cast.jpg"
bsg04_cast_image_path <- download_temp_file(bsg04_cast_image_url)
```

**Sending a local image:**

When we provide a local image path, the image will be automatically
uploaded to the server and the file_id will be passed to the model.

``` r
openai_assistant$chat(
    "Who are the characters in this image, and what show is it from?",
    bsg04_cast_image_path,
    in_new_thread = TRUE
)
```

``` default
The characters in the image are from the television series **Battlestar Galactica**, which aired from 2004 to 2009. Here are the main characters shown:

1. **William Adama** (played by Edward James Olmos) - Commanding Officer of the Galactica.
2. **Laura Roslin** (played by Mary McDonnell) - President of the Twelve Colonies and a key leader.
3. **Lee "Apollo" Adama** (played by Jamie Bamber) - A captain in the Colonial Fleet and son of Bill Adama.
4. **Kara "Starbuck" Thrace** (played by Katee Sackhoff) - A talented pilot known for her rebellious nature.
5. **Gaius Baltar** (played by James Callis) - A scientist with a complex role in the series’ storyline.
6. **Number Six** (played by Tricia Helfer) - A Cylon who plays a significant role in the narrative.
7. **Baltar's Number Six** (also played by Tricia Helfer) - A manifestation that interacts with Gaius Baltar.

These characters are central to the themes of survival, morality, and human identity explored in the series.
```

> **Warning**
>
> Behind the scenes, this is uploading the image to the server
> (i.e. using `$upload_file()`) and then passing the file_id to the
> model. Don’t forget to delete the file after use with
> `$delete_file()`.

*So say we all!*

**Sending an image URL:**

OpenAI supports sending image URLs as-is:

``` r
openai_assistant$chat(
    "Who are the characters in this image, and what show is it from?",
    bsg04_cast_image_url,
    in_new_thread = TRUE
)
```

> **Note**
>
> OpenAI supports an optional `detail` parameter (low/high/auto) to
> control the image processing detail level when the image is sent as a
> URL. The default value is `"auto"`.
>
> To specify this parameter, pass the image URL to
> `as_image_content(url, .provider_options = list(detail = "low"))`.
>
> You could also use
> [`as_image_content()`](https://ma-riviere.github.io/argent/reference/content_converters.md)
> to resize the image before sending it with the `.resize` argument.
>
> OpenAI Assistants API also supports sending a file_id (i.e. the image
> `as_file_content(file_id)` after uploading it with
> `openai_assistant$upload_file()`).

### PDF Comprehension

Downloading an example PDF (my CV)

``` r
my_cv_url <- "https://ma-riviere.com/res/cv.pdf"
my_cv_pdf_path <- download_temp_file(my_cv_url)
```

For PDFs, we need to give the assistant the `file_search` tool to be
able to search through the PDF’s contents, so let’s create an assistant
with that tool:

``` r
pdf_assistant <- OpenAI_Assistant$new()$create_assistant(
    name = "PDF Assistant",
    model = "gpt-4o-mini",
    tools = list("file_search")
)
```

> **Warning**
>
> Behind the scenes, this is uploading the PDF to the server (i.e. using
> `$upload_file()`) and then passing the file_id to the model. Don’t
> forget to delete the file after use with `$delete_file()`.

**Sending a local PDF:**

``` r
pdf_assistant$chat(
    "What's my favorite programming language?",
    my_cv_pdf_path
)
```

``` default
Your favorite programming language appears to be **R**, as indicated by your extensive experience and focus on R and Shiny in your work and projects【4:0†source】.
```

*Damn right!*

**Sending PDF URLs:**

For OpenAI Assistants, by default, PDF URLs (or files) are uploaded to
the server and the file_id is passed to the model.

However, we can use the
[`as_text_content()`](https://ma-riviere.github.io/argent/reference/content_converters.md)
helper to have
[`pdftools::pdf_convert()`](https://docs.ropensci.org/pdftools//reference/pdf_render_page.html)
parse the PDFs and pass their text contents to the model instead.

``` r
r6_pdf_url <- "https://cran.r-project.org/web/packages/R6/R6.pdf"
s7_pdf_url <- "https://cran.r-project.org/web/packages/S7/S7.pdf"

multimodal_prompt <- list(
    "Give a 3 sentences summary of the advantages of S7 over R6",
    as_text_content(r6_pdf_url),
    as_text_content(s7_pdf_url),
    "And give me the current versions of both packages"
)

openai_assistant$chat(!!!multimodal_prompt, in_new_thread = TRUE)
```

``` default
**Summary of the Advantages of S7 over R6:**

S7 is designed to be a more robust object-oriented programming system than R6, offering formal class and method specifications along with a limited form of multiple dispatch, which enhances its flexibility. It also integrates both S3 and S4 systems seamlessly, allowing for extensibility with the addition of a clear inheritance model and property validation, thereby promoting cleaner and more maintainable code. Furthermore, S7 facilitates better interoperability with base R types and modern R programming practices, making it more suitable for complex applications  .

**Current Versions of Both Packages:**
- **R6:** Version 2.6.1
- **S7:** Version 0.2.0
```

### Passing R Objects

You can pass any R object to `chat()` as is:

``` r
lm_obj <- lm(body_mass ~ species + sex, data = datasets::penguins)

openai_assistant$chat(
    "What can we deduct from this regression model?",
    lm_obj,
    in_new_thread = TRUE
)
```

> **Note**
>
> Any R object passed to `chat()` will be automatically converted to
> JSON (or text if JSON conversion fails), with some added information
> like the name of the object and its classes.

### Sending files

We can also send files directly to the model.

For this, we also need to give the assistant the `file_search` tool to
be able to search through the files’ contents, so let’s create an
assistant with that tool:

``` r
file_assistant <- OpenAI_Assistant$new()$create_assistant(
    name = "File Assistant",
    model = "gpt-4o-mini",
    tools = list("file_search")
)
```

**Uploading Files**

``` r
file_metadata <- file_assistant$upload_file(my_cv_url, purpose = "assistants")
```

**Listing Files**

``` r
file_assistant$list_files()
```

``` default
# A tibble: 1 × 9
   object id                          purpose    filename                bytes created_at          expires_at status    status_details
   <chr>  <chr>                       <chr>      <chr>                   <int> <dttm>              <lgl>      <chr>     <lgl>         
 1 file   file-B1MRQat6f1sRArT3KhFkGu assistants file1e612f9544482.pdf  431965 2025-11-14 09:03:52 NA         processed NA  
```

**Using Uploaded Files**

Use
[`as_file_content()`](https://ma-riviere.github.io/argent/reference/content_converters.md)
to reference uploaded files:

``` r
file_assistant$chat(
    "What are my two favorite frameworks/tools ?",
    as_file_content(file_metadata$id)
)
```

``` default
Your two favorite frameworks/tools are **Shiny** and **Quarto**【4:0†source】.
```

> **Note**
>
> For Assistants, this does the same thing as simply giving the local
> file path in the inputs of `$chat()`, like in the “PDF Comprehension”
> section.

**Downloading Files**

> **Note**
>
> Files with purpose ‘assistants’ cannot be downloaded.

**Deleting Files**

``` r
file_assistant$delete_file(file_metadata$id)
#> ✔ [OpenAI] File deleted: file-B1MRQat6f1sRArT3KhFkGu
```

## Server-Side RAG

Instead of just passing single files to the Assistant, we can also add
them to a vector store (where the files are chunked and indexed) and use
the `file_search` tool to search through the store and retrieve the
relevant chunks, effectively turning it into a server-side RAG
application. This is useful when your files are too large to pass
directly to the model.

### Vector Store Management

First, a quick overview of available methods to manage vector stores:

**Creating a Vector Store**

``` r
store <- file_assistant$create_store(
    name = "my_docs",
    file_ids = list("file-123", "file-456")
)
```

**Listing Vector Stores**

``` r
openai_assistant$list_stores()
```

**Adding Files to a Vector Store**

``` r
openai_assistant$add_file_to_store(store$id, "file-789")
```

**Listing Files in a Vector Store**

``` r
openai_assistant$list_files_in_store(store$id)
```

**Deleting a Vector Store**

``` r
openai_assistant$delete_store(store$id)
```

> **Note**
>
> Files and vector stores are shared across all OpenAI APIs (Chat
> Completions, Responses, and Assistants). A file uploaded via one API
> can be used in another.

### Basic Server-Side RAG Example

First, let’s upload the files we want to search through and create a
vector store with them:

``` r
r6_file_metadata <- openai_assistant$upload_file(r6_pdf_url, purpose = "assistants")
s7_file_metadata <- openai_assistant$upload_file(s7_pdf_url, purpose = "assistants")

r_oop_store <- openai_assistant$create_store(
    name = "r_oop_store",
    file_ids = list(r6_file_metadata$id, s7_file_metadata$id)
)
```

Then, define an output schema for the response:

``` r
oop_output_schema <- schema(
    name = "oop_output",
    description = "Explanation of the R6 and S7 active bindings mechanism",
    short_answer = "string* The short answer to the question, in plain text. One sentence.",
    r6_code_example = "string* R6 active bindings code example. Formatted as code block (```{r} ... ```).",
    s7_code_example = "string* S7 active bindings 'equivalent' code example. Formatted as code block (```{r} ... ```)."
)
```

Create an assistant with `file_search` and use it with structured
output:

``` r
rag_assistant <- OpenAI_Assistant$new(rate_limit = 3 / 60)$create_assistant(
    name = "R OOP Expert",
    model = "gpt-4.1",
    tools = list(
        list(type = "file_search", store_ids = list(r_oop_store$id)),
        as_tool(web_search),
        as_tool(web_fetch)
    )
)
```

> **Note**
>
> Unlike the Responses API where you can specify the vector store
> per-call, the Assistants API attaches the vector store to the
> assistant during creation. The store is available for all chat calls
> across all threads.

``` r
res <- rag_assistant$chat(
    "What's the active bindings' R6 mechanism equivalent in S7?",
    "Important: use both the file_search and web_search & web_fetch tools to find the information.",
    output_schema = oop_output_schema,
    remove_citations = TRUE
)
```

> **Note**
>
> The Assistants API includes citation markers like 【35†source】 and
> \[3:0†source\] in responses when using `file_search`. Set
> `remove_citations = TRUE` in `chat()` to automatically remove these
> markers from the response text.

Response

``` r
purrr::walk(res, \(x) cat(x, "\n\n", sep = ""))
```

R6 uses ‘active bindings’ to define properties that compute values
dynamically when accessed, whereas S7 uses active class methods to
achieve similar behavior.

``` r
library(R6)
Person <- R6Class("Person",
  private = list(age = 30),
  active = list(
    age = function(value) {
      if (missing(value)) private$age      # Getter
      else private$age <- value            # Setter
    }
  )
)

p <- Person$new()
p$age           # get age
p$age <- 35     # set age
p$age           # get new age
```

``` r
library(S7)
Person <- new_class("Person",
  properties = list(age = class_double),
  methods = list(
    age = function(self) {
      self@age     # Getter equivalent
    },
    set_age = function(self, value) {
      self@age <- value   # Setter equivalent
    }
  )
)

p <- Person(age = 30)
p$age()          # get age
p$set_age(35)    # set age
p$age()          # get new age
```

View citations and supplementary information:

``` r
cat(yaml::as.yaml(rag_assistant$get_supplementary()), "\n")
```

``` yaml
citations:
- type: file_citation
  text: 【6:18†file216bb87f788d7f.pdf】
  start_index: 1264
  end_index: 1293
  file_citation:
    file_id: file-N3CEQUR9ttxiRpo2qm3nqS
- type: file_citation
  text: 【6:13†file216bb87f788d7f.pdf】
  start_index: 1293
  end_index: 1322
  file_citation:
    file_id: file-N3CEQUR9ttxiRpo2qm3nqS
- type: file_citation
  text: 【6:0†file216bb87f788d7f.pdf】
  start_index: 1497
  end_index: 1525
  file_citation:
    file_id: file-N3CEQUR9ttxiRpo2qm3nqS
```

**Cleaning up**

``` r
rag_assistant$delete_store(r_oop_store$id)
rag_assistant$delete_file(r6_file_metadata$id)
rag_assistant$delete_file(s7_file_metadata$id)
rag_assistant$delete_assistant()
```

> **Tip**
>
> We could have deleted everything (assistant, stores used by the
> assistant, and files used by the stores) with :
>
> ``` r
> rag_assistant$delete_assistant_and_contents()
> ```
