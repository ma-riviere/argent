# MCP: Creating MCP Servers

## Introduction

This vignette demonstrates how to create your own MCP servers using
`argent`. MCP servers allow you to expose tools, resources, and prompts
that can be used by any MCP client, including argent, Claude Code,
Claude Desktop, and other LLM applications.

## Building a STDIO MCP Server

Let’s create our own stdio MCP server for interacting with Zotero’s
local API. This server will be usable both from argent and from other
MCP clients, like Claude Code.

### Prerequisites

- Zotero 7+ must be running
- Enable “Allow other applications on this computer to communicate with
  Zotero” in Preferences \> Advanced

### Server Implementation

Zotero MCP Server Implementation

``` r
# Zotero MCP Server Tools
#
# Tool definitions for interacting with Zotero's local API.
# Use with: argent::mcp_serve_stdio(file = "zotero_mcp_server.R", name = "zotero")
```

``` {r🔺
# Base request function to Zotero local API (not an MCP tool)
zotero_request <- function(endpoint, query = list(), user_id = "0", valid_statuses = 200) {
    base_url <- "http://localhost:23119/api"
    url <- paste0(base_url, "/users/", user_id, endpoint)

    resp <- httr2::request(url) |>
        httr2::req_headers("Zotero-API-Version" = "3") |>
        httr2::req_url_query(!!!query) |>
        httr2::req_error(is_error = \(resp) FALSE) |>
        httr2::req_perform()

    status <- httr2::resp_status(resp)

    if (!status %in% valid_statuses) {
        if (status == 501) {
            return(argent:::mcp_error(
                message = "Zotero local API is not accessible",
                type = "api_error",
                details = "HTTP 501 - API version mismatch or local API not enabled",
                suggestion = paste(
                    "Enable local API in Zotero:",
                    "Preferences > Advanced > 'Allow other applications on this computer to communicate with Zotero'"
                )
            ))
        }
        return(argent:::mcp_error(
            message = paste0("Zotero API request failed with status ", status),
            type = "api_error",
            details = paste0("Unexpected HTTP status code from endpoint: ", endpoint)
        ))
    }

    if (status == 404) {
        return(NULL)
    }

    httr2::resp_body_json(resp)
}
```

``` {r🔺
zotero_search_items <- function(query = NULL, qmode = "titleCreatorYear", tag = NULL, item_type = NULL, limit = 25L) {
    #' @mcp tool
    #' @group papers
    #' @description Search for items in your Zotero library using phrase-based
    #'   matching. Returns a list of items with their metadata (title, authors,
    #'   year, type). IMPORTANT SEARCH TIPS: The 'query' parameter performs
    #'   phrase matching in titles and creator fields. Use broad, generic terms
    #'   first (e.g., 'climate' before 'climate change mitigation'). Try synonyms
    #'   if initial search yields no results. Break complex searches into multiple
    #'   queries with different keywords. Use 'qmode=everything' to include
    #'   full-text content in search. Search is case-insensitive but matches must
    #'   be complete phrases.
    #' @param query:string Quick search query for phrase matching in titles and
    #'   creator fields. Searches are case-insensitive phrase matches. Start with
    #'   generic terms and narrow down or try synonyms if no results.
    #' @param qmode:string Search mode: 'titleCreatorYear' (default, searches
    #'   title/creator/year) or 'everything' (includes full-text content from
    #'   indexed PDFs). Use 'everything' only when searching PDF content is needed.
    #' @param tag:string Filter by exact tag name (case-sensitive). Supports
    #'   Boolean syntax: 'tag1' (single), 'tag1 tag2' (tag with spaces),
    #'   'tag=tag1&tag=tag2' (AND), 'tag1 || tag2' (OR), '-tag1' (NOT).
    #' @param item_type:string Filter by item type. Common types: 'book',
    #'   'journalArticle', 'conferencePaper', 'thesis', 'report', 'webpage',
    #'   'document', 'attachment'. Supports Boolean: 'book || journalArticle' (OR),
    #'   '-attachment' (NOT).
    #' @param limit:integer Maximum number of items to return (1-100, default 25)

    params <- list(q = query, qmode = qmode, tag = tag, itemType = item_type, limit = as.integer(limit))
    params <- purrr::compact(params)

    items <- zotero_request("/items", query = params)

    if (isTRUE(items$.error)) {
        return(items)
    }

    if (purrr::is_empty(items)) {
        return(jsonlite::toJSON(list(), auto_unbox = TRUE))
    }

    result <- lapply(items, function(item) {
        data <- item$data

        creators <- "No authors"
        if (!purrr::is_empty(data$creators)) {
            names_list <- sapply(data$creators, \(c) paste(c$firstName %||% "", c$lastName %||% ""))
            creators <- paste(names_list, collapse = "; ")
        }

        list(
            key = data$key,
            title = data$title %||% "Untitled",
            creators = creators,
            year = data$date %||% "No date",
            type = data$itemType
        )
    })

    jsonlite::toJSON(result, auto_unbox = TRUE)
}

zotero_get_item <- function(item_key) {
    #' @mcp tool
    #' @group papers
    #' @description Get detailed metadata for a specific Zotero item by its key.
    #'   Returns comprehensive information including title, creators, abstract,
    #'   date, type, tags, and URL. Use this after zotero_search_items to get full
    #'   details for specific items.
    #' @param item_key:string* The unique item key returned from search results.
    #'   Example: 'X42A7DEE' (alphanumeric, case-sensitive).

    item <- zotero_request(paste0("/items/", item_key))

    if (isTRUE(item$.error)) {
        return(item)
    }

    if (is.null(item)) {
        return(argent:::mcp_error(
            message = "Item not found",
            type = "not_found",
            details = paste0("No item with key '", item_key, "' exists in the library"),
            suggestion = "Verify the item key using zotero_search_items first"
        ))
    }

    data <- item$data

    tags <- character(0)
    if (!purrr::is_empty(data$tags)) {
        tags <- purrr::map_chr(data$tags, \(t) t$tag)
    }

    result <- list(
        key = data$key,
        title = data$title %||% "Untitled",
        creators = data$creators,
        abstract = data$abstractNote %||% "No abstract",
        date = data$date %||% "No date",
        itemType = data$itemType,
        tags = tags,
        url = data$url
    )

    jsonlite::toJSON(result, auto_unbox = TRUE)
}

zotero_get_collections <- function() {
    #' @mcp tool
    #' @group collections
    #' @description List all collections (folders) in your Zotero library.
    #'   Collections organize items hierarchically. Returns collection keys, names,
    #'   and parent-child relationships. Use collection keys with other endpoints
    #'   to filter items by collection.

    collections <- zotero_request("/collections")

    if (isTRUE(collections$.error)) {
        return(collections)
    }

    if (purrr::is_empty(collections)) {
        return(jsonlite::toJSON(list(), auto_unbox = TRUE))
    }

    result <- lapply(collections, function(col) {
        data <- col$data
        list(key = data$key, name = data$name, parentCollection = data$parentCollection %||% NA)
    })

    jsonlite::toJSON(result, auto_unbox = TRUE)
}

zotero_get_fulltext <- function(item_key) {
    #' @mcp tool
    #' @group papers
    #' @description Extract full-text content from a Zotero item's attached PDF.
    #'   Automatically finds PDF attachments if given a parent item key.
    #'   REQUIREMENTS: Item must have an attached PDF file (stored or linked); PDF
    #'   must be indexed by Zotero (automatic when idle, or manual reindex); PDF
    #'   must have searchable text (not image-only scans). NOTES: Accepts both
    #'   parent item keys (will find first PDF) or direct attachment keys. Returns
    #'   helpful error messages if PDF is not indexed or not found. Warns if only
    #'   partial content indexed (due to page/character limits). Use this to access
    #'   the actual text content of papers for detailed analysis.
    #' @param item_key:string* The item key - can be either: (1) Parent item key
    #'   from search results (will auto-find PDF attachment), or (2) Direct
    #'   attachment key for a specific PDF. Obtain from zotero_search_items or
    #'   zotero_get_item results.

    tryCatch(
        {
            item <- zotero_request(paste0("/items/", item_key))

            if (isTRUE(item$.error)) {
                return(item)
            }

            if (is.null(item)) {
                return(argent:::mcp_error(
                    message = "Item not found",
                    type = "not_found",
                    details = paste0("No item with key '", item_key, "' exists in the library"),
                    suggestion = "Verify the item key using zotero_search_items first"
                ))
            }

            attachment_key <- item_key
            link_mode <- NULL
            if (item$data$itemType != "attachment") {
                children <- zotero_request(paste0("/items/", item_key, "/children"))

                if (isTRUE(children$.error)) {
                    return(children)
                }

                if (is.null(children)) {
                    children <- list()
                }

                pdf_attachments <- purrr::keep(children, function(child) {
                    child$data$itemType == "attachment" &&
                        grepl("pdf", child$data$contentType %||% "", ignore.case = TRUE)
                })

                if (purrr::is_empty(pdf_attachments)) {
                    return(argent:::mcp_error(
                        message = "No PDF attachments found for this item",
                        type = "not_found",
                        details = paste0("Item '", item_key, "' has no PDF attachments"),
                        suggestion = "Verify the item has PDF files attached in Zotero"
                    ))
                }

                attachment_key <- pdf_attachments[[1]]$data$key
                link_mode <- pdf_attachments[[1]]$data$linkMode
            } else {
                link_mode <- item$data$linkMode
            }

            fulltext <- zotero_request(paste0("/items/", attachment_key, "/fulltext"), valid_statuses = c(200, 404))

            if (isTRUE(fulltext$.error)) {
                return(fulltext)
            }

            if (is.null(fulltext)) {
                details <- "PDF exists but fulltext index is not yet available"
                if (!is.null(link_mode) && link_mode == "linked_file") {
                    details <- paste0(details, ". Note: This is a linked file.")
                }

                return(argent:::mcp_error(
                    message = "Fulltext has not been indexed yet",
                    type = "not_ready",
                    details = details,
                    suggestion = "Wait for automatic indexing or manually reindex in Zotero"
                ))
            }

            if (is.null(fulltext$content) || fulltext$content == "") {
                return(argent:::mcp_error(
                    message = "Fulltext cache is empty",
                    type = "unsupported",
                    details = "The PDF may be image-based without searchable text layer",
                    suggestion = "Use OCR software to add a text layer"
                ))
            }

            fulltext$content
        },
        error = function(e) {
            argent:::mcp_error(
                message = "Fulltext extraction failed",
                type = "error",
                details = conditionMessage(e),
                suggestion = "Verify the item key exists using zotero_search_items first"
            )
        }
    )
}

zotero_list_fulltext_items <- function(since = 0L) {
    #' @mcp tool
    #' @group overview
    #' @description List all items in the library that have indexed fulltext
    #'   content. Returns item keys and their fulltext version numbers. Useful for
    #'   discovering which items have searchable PDF content before retrieving it.
    #'   Combine with zotero_get_fulltext to access the actual content.
    #' @param since:integer Library version to filter from (default: 0 for all items)

    result <- zotero_request("/fulltext", query = list(since = as.integer(since)))

    if (isTRUE(result$.error)) {
        return(result)
    }

    if (purrr::is_empty(result)) {
        return(jsonlite::toJSON(list(), auto_unbox = TRUE))
    }

    items <- purrr::imap(result, \(version, key) list(key = key, version = version))

    jsonlite::toJSON(items, auto_unbox = TRUE)
}

zotero_get_collection_items <- function(collection_key, limit = 100L) {
    #' @mcp tool
    #' @group collections
    #' @description Get all items within a specific collection (folder). Returns
    #'   metadata for items including title, authors, year, and type. Use
    #'   zotero_get_collections to get collection keys first.
    #' @param collection_key:string* The collection key obtained from zotero_get_collections
    #' @param limit:integer Maximum number of items to return (1-100, default: 100)

    endpoint <- paste0("/collections/", collection_key, "/items")
    params <- list(limit = as.integer(limit))

    items <- zotero_request(endpoint, query = params)

    if (isTRUE(items$.error)) {
        return(items)
    }

    if (purrr::is_empty(items)) {
        return(jsonlite::toJSON(list(), auto_unbox = TRUE))
    }

    result <- lapply(items, function(item) {
        data <- item$data

        creators <- "No authors"
        if (!purrr::is_empty(data$creators)) {
            names_list <- sapply(data$creators, \(c) paste(c$firstName %||% "", c$lastName %||% ""))
            creators <- paste(names_list, collapse = "; ")
        }

        list(
            key = data$key,
            title = data$title %||% "Untitled",
            creators = creators,
            year = data$date %||% "No date",
            type = data$itemType
        )
    })

    jsonlite::toJSON(result, auto_unbox = TRUE)
}

zotero_get_top_items <- function(limit = 100L) {
    #' @mcp tool
    #' @group overview
    #' @description Get only top-level items in the library. Excludes child items
    #'   like attachments and notes. Returns metadata including title, authors,
    #'   year, and type. Useful for getting a clean list of main references without
    #'   clutter.
    #' @param limit:integer Maximum number of items to return (1-100, default: 100)

    params <- list(limit = as.integer(limit))
    items <- zotero_request("/items/top", query = params)

    if (isTRUE(items$.error)) {
        return(items)
    }

    if (purrr::is_empty(items)) {
        return(jsonlite::toJSON(list(), auto_unbox = TRUE))
    }

    result <- lapply(items, function(item) {
        data <- item$data

        creators <- "No authors"
        if (!purrr::is_empty(data$creators)) {
            names_list <- sapply(data$creators, \(c) paste(c$firstName %||% "", c$lastName %||% ""))
            creators <- paste(names_list, collapse = "; ")
        }

        list(
            key = data$key,
            title = data$title %||% "Untitled",
            creators = creators,
            year = data$date %||% "No date",
            type = data$itemType
        )
    })

    jsonlite::toJSON(result, auto_unbox = TRUE)
}

zotero_get_item_types <- function() {
    #' @mcp tool
    #' @group overview
    #' @description Get a list of all valid item types supported by Zotero. Item
    #'   types include: book, journalArticle, conferencePaper, thesis, etc. Useful
    #'   for understanding what types can be used with the item_type filter in
    #'   zotero_search_items and other endpoints.

    item_types <- zotero_request("/itemTypes")

    if (isTRUE(item_types$.error)) {
        return(item_types)
    }

    jsonlite::toJSON(item_types %||% list(), auto_unbox = TRUE)
}
```

``` {r🔺
# Resources provide read-only data that can be attached to context.
# Unlike tools (model-controlled), resources are application/user-controlled.
#
# NOTE: Per MCP spec, resource handlers MUST accept a 'uri' parameter, even if
# not used. The server calls handler(uri) when processing resources/read requests.

zotero_library_stats <- function(uri) {
    #' @mcp resource
    #' @group overview
    #' @description Overview statistics of your Zotero library including total
    #'   item counts, number of collections, and breakdown by item type. Useful
    #'   for understanding the scope and composition of your reference library.
    #' @uri zotero://library/stats
    #' @mimeType application/json

    # Get all top-level items for counting
    items <- zotero_request("/items/top", query = list(limit = 100))
    collections <- zotero_request("/collections")

    if (isTRUE(items$.error)) {
        return(jsonlite::toJSON(list(error = items$.error), auto_unbox = TRUE))
    }

    # Count by item type
    type_counts <- list()
    if (!purrr::is_empty(items)) {
        types <- sapply(items, \(item) item$data$itemType %||% "unknown")
        type_table <- table(types)
        type_counts <- as.list(type_table)
    }

    stats <- list(
        total_items = length(items),
        total_collections = length(collections),
        items_by_type = type_counts,
        note = if (length(items) >= 100) "Item count may be incomplete (limited to first 100)" else NULL
    )

    jsonlite::toJSON(stats, auto_unbox = TRUE)
}
```

``` {r🔺
# Prompts provide user-triggered message templates for specific workflows.
# Unlike tools (model-controlled), prompts are explicitly invoked by users.

summarize_paper <- function(item_key) {
    #' @mcp prompt
    #' @group papers
    #' @description Generate a structured summary of a research paper from your
    #'   Zotero library. Fetches the paper's metadata and full text, then creates
    #'   a prompt asking for: main research question, methodology, key findings,
    #'   limitations, and implications. Best used with papers that have indexed
    #'   PDF content.
    #' @param item_key:string* The Zotero item key of the paper to summarize.
    #'   Obtain from zotero_search_items results.

    # Fetch item metadata
    item <- zotero_request(paste0("/items/", item_key))

    if (is.null(item) || isTRUE(item$.error)) {
        return(list(
            description = "Error: Could not fetch paper",
            messages = list(list(
                role = "user",
                content = list(
                    type = "text",
                    text = paste0(
                        "I tried to summarize a paper with key '",
                        item_key,
                        "' but it could not be found in Zotero."
                    )
                )
            ))
        ))
    }

    data <- item$data

    # Format creators
    authors <- "Unknown authors"
    if (!purrr::is_empty(data$creators)) {
        author_names <- sapply(data$creators, \(c) {
            paste(c$firstName %||% "", c$lastName %||% "")
        })
        authors <- paste(author_names, collapse = ", ")
    }

    # Try to get fulltext (best effort)
    fulltext_content <- NULL
    tryCatch(
        {
            fulltext_result <- zotero_get_fulltext(item_key)
            if (is.character(fulltext_result) && nchar(fulltext_result) > 0) {
                # Truncate if too long (keep first ~8000 chars for context limits)
                if (nchar(fulltext_result) > 8000) {
                    fulltext_content <- paste0(
                        substr(fulltext_result, 1, 8000),
                        "\n\n[... content truncated for length ...]"
                    )
                } else {
                    fulltext_content <- fulltext_result
                }
            }
        },
        error = function(e) NULL
    )

    # Build the prompt message
    prompt_text <- paste0(
        "Please provide a structured summary of this research paper:\n\n",
        "## Paper Metadata\n",
        "**Title:** ",
        data$title %||% "Untitled",
        "\n",
        "**Authors:** ",
        authors,
        "\n",
        "**Year:** ",
        data$date %||% "Unknown",
        "\n",
        "**Type:** ",
        data$itemType %||% "Unknown",
        "\n"
    )

    if (!is.null(data$abstractNote) && nchar(data$abstractNote) > 0) {
        prompt_text <- paste0(prompt_text, "**Abstract:** ", data$abstractNote, "\n")
    }

    if (!is.null(fulltext_content)) {
        prompt_text <- paste0(prompt_text, "\n## Full Text Content\n", fulltext_content, "\n")
    } else {
        prompt_text <- paste0(prompt_text, "\n*Note: Full text not available. Summary based on metadata only.*\n")
    }

    prompt_text <- paste0(
        prompt_text,
        "\n## Requested Summary Structure\n",
        "Please analyze this paper and provide:\n",
        "1. **Main Research Question**: What problem or question does this paper address?\n",
        "2. **Methodology**: What approach or methods were used?\n",
        "3. **Key Findings**: What are the main results or conclusions?\n",
        "4. **Limitations**: What limitations does the paper acknowledge or what gaps remain?\n",
        "5. **Implications**: Why does this research matter? What are the practical applications?\n"
    )

    list(
        description = paste0("Summarize: ", data$title %||% "Untitled"),
        messages = list(list(role = "user", content = list(type = "text", text = prompt_text)))
    )
}
```

> **Note**
>
> This implementation uses `argent`‘s annotation parsing & MCP
> machinery, which allows us to implement a fully-featured MCP server by
> simply defining the tools we want to expose as annotated functions.
> All the ’boilerplate’ code for setting up the MCP server is handled by
> `argent`.
>
> The Zotero MCP server code is available in the package at
> `inst/examples/zotero_mcp_server.R`.

### Using the MCP Server

``` r
zotero_client <- mcp_connect(
    name = "zotero",
    type = "stdio",
    command = "Rscript",
    args = c("-e", "argent::mcp_serve_stdio(system.file('examples/zotero_mcp_server.R', package = 'argent'))")
)

zotero_tools <- mcp_tools(zotero_client)
zotero_resources <- mcp_resources(zotero_client)
zotero_prompts <- mcp_prompts(zotero_client)
```

> **Tip**
>
> We could have served the MCP server with the `groups = c('papers')`
> argument, so that only the tools/resources/prompts with the
> `@group papers` annotation are available.

We could test if the MCP server is working by querying it ‘manually’:

Testing the Zotero MCP Server manually

``` r
# Getting details on all my collections
my_collections <- execute_mcp_tool(get_mcp_tool(zotero_tools, "zotero_get_collections"))

# Getting the key of the Neuroscience collection
neuroscience_collection_key <- jsonlite::fromJSON(my_collections) |>
    dplyr::filter(stringr::str_detect(name, "Neuroscience")) |>
    dplyr::pull(key)

# Getting details on all the items/papers in the Neuroscience collection
neuroscience_items <- execute_mcp_tool(
    get_mcp_tool(zotero_tools, "zotero_get_collection_items"),
    arguments = list(collection_key = neuroscience_collection_key)
)

# Getting a specific paper's key with a keyword from its title
neuroscience_paper_key <- jsonlite::fromJSON(neuroscience_items) |>
    dplyr::filter(stringr::str_detect(title, "cross-modal plasticity")) |>
    dplyr::pull(key)

# Getting the details on the paper
neuroscience_paper_details <- execute_mcp_tool(
    get_mcp_tool(zotero_tools, "zotero_get_item"),
    arguments = list(item_key = neuroscience_paper_key)
)

# Getting the fulltext of the paper (as a string)
neuroscience_paper_fulltext <- execute_mcp_tool(
    get_mcp_tool(zotero_tools, "zotero_get_fulltext"),
    arguments = list(item_key = neuroscience_paper_key)
)

cat(neuroscience_paper_fulltext)
```

Now, let’s give the tools to an LLM Agent instead:

``` r
gemini <- Google$new()

gemini$chat(
    "Can you summarize O'Regan's view on sensory substitution and on how the brain differentiates sensory inputs ?",
    "Find at least 2 papers in my library",
    model = "gemini-2.5-flash",
    tools = zotero_tools
)
```

> **Tip**
>
> We can use our new Zotero MCP server with other MCP clients (like
> Claude Code, Claude Desktop, Gemini CLI, etc):
>
> ``` json
> {
>   "mcpServers": {
>     "zotero": {
>       "type": "stdio",
>       "command": "Rscript",
>       "args": [
>         "-e",
>         "argent::mcp_serve_stdio(system.file('examples/zotero_mcp_server.R', package = 'argent'))"
>       ]
>     }
>   }
> }
> ```

## Building an HTTP MCP Server

Let’s create an HTTP MCP server for searching academic papers using the
Semantic Scholar API. Unlike stdio servers that communicate via standard
input/output, HTTP servers expose a REST endpoint that can be accessed
over the network.

> **Note**
>
> `argent` provides convenience functions to create HTTP MCP servers,
> but you can also create your own with `plumber2` or other HTTP server
> frameworks, independently from `argent`.

### Prerequisites

- A Semantic Scholar API key (not required, but the rate limits are low
  without one)

### Server Implementation

Semantic Scholar MCP Server Implementation

``` r
# Semantic Scholar MCP Server Tools
#
# Tool definitions for searching academic papers using the Semantic Scholar API.
# Use with: argent::mcp_serve_http(file = "semantic_scholar_mcp_server.R", name = "semantic-scholar")
```

``` {r🔺
# Base request function for Semantic Scholar API (not an MCP tool)
semantic_scholar_request <- function(endpoint, query = list()) {
    base_url <- "https://api.semanticscholar.org/graph/v1"
    url <- paste0(base_url, endpoint)

    resp <- httr2::request(url) |>
        httr2::req_url_query(!!!query) |>
        httr2::req_error(is_error = \(resp) FALSE) |>
        httr2::req_throttle(rate = 20 / 60, realm = "semantic-scholar") |>
        httr2::req_perform()

    status <- httr2::resp_status(resp)

    if (status == 429) {
        return(argent:::mcp_error(
            message = "Rate limit exceeded",
            type = "api_error",
            details = "Too many requests to Semantic Scholar API",
            suggestion = "Wait a few seconds before retrying"
        ))
    }

    if (status == 404) {
        return(NULL)
    }

    if (status != 200) {
        return(argent:::mcp_error(
            message = paste0("Semantic Scholar API request failed with status ", status),
            type = "api_error",
            details = paste0("Unexpected HTTP status code from endpoint: ", endpoint)
        ))
    }

    httr2::resp_body_json(resp)
}

# Default fields to return for papers
default_fields <- "title,authors,year,abstract,citationCount,url,venue,publicationDate"
```

``` {r🔺
search_papers <- function(query, limit = 10L, fields = NULL) {
    #' @description Search for academic papers by keywords, authors, or topics
    #'   using the Semantic Scholar API. Returns papers with metadata including
    #'   title, authors, year, abstract, citation count, and URL. Use broad
    #'   search terms for better results. Returns up to 100 results per query.
    #' @mcp tool
    #' @param query:string* Search query (keywords, author names, paper titles)
    #' @param limit:integer Maximum results to return (default 10, max 100)
    #' @param fields:string Comma-separated fields to return

    if (is.null(query) || nchar(query) == 0) {
        return(argent:::mcp_error(
            message = "Query parameter is required",
            type = "validation",
            details = "The 'query' parameter cannot be empty",
            suggestion = "Provide keywords, author names, or paper titles to search for"
        ))
    }

    fields_param <- fields %||% default_fields

    params <- list(query = query, limit = as.integer(min(limit, 100)), fields = fields_param)

    result <- semantic_scholar_request("/paper/search", query = params)

    if (isTRUE(result$.error)) {
        return(result)
    }

    if (is.null(result) || purrr::is_empty(result$data)) {
        return(jsonlite::toJSON(list(), auto_unbox = TRUE))
    }

    papers <- lapply(result$data, function(paper) {
        authors <- "No authors"
        if (!purrr::is_empty(paper$authors)) {
            authors <- paste(purrr::map_chr(paper$authors, \(a) a$name), collapse = "; ")
        }

        list(
            paperId = paper$paperId,
            title = paper$title %||% "Untitled",
            authors = authors,
            year = paper$year %||% "Unknown year",
            abstract = paper$abstract %||% "No abstract available",
            citationCount = paper$citationCount %||% 0,
            url = paper$url,
            venue = paper$venue %||% "Unknown venue",
            publicationDate = paper$publicationDate %||% "Unknown date"
        )
    })

    jsonlite::toJSON(papers, auto_unbox = TRUE)
}

get_paper <- function(paper_id, fields = NULL) {
    #' @description Get detailed metadata for a specific paper by its Semantic
    #'   Scholar ID or DOI. Returns title, authors, abstract, year, citation
    #'   count, and more. Use after search_papers to get full details.
    #' @mcp tool
    #' @param paper_id:string* Paper ID (Semantic Scholar ID or DOI)
    #' @param fields:string Comma-separated fields to return

    if (is.null(paper_id) || nchar(paper_id) == 0) {
        return(argent:::mcp_error(
            message = "Paper ID is required",
            type = "validation",
            details = "The 'paper_id' parameter cannot be empty",
            suggestion = "Provide a Semantic Scholar paper ID or DOI"
        ))
    }

    fields_param <- fields %||% default_fields

    endpoint <- paste0("/paper/", paper_id)
    params <- list(fields = fields_param)

    result <- semantic_scholar_request(endpoint, query = params)

    if (isTRUE(result$.error)) {
        return(result)
    }

    if (is.null(result)) {
        return(argent:::mcp_error(
            message = "Paper not found",
            type = "not_found",
            details = paste0("No paper with ID '", paper_id, "' exists"),
            suggestion = "Verify the paper ID using search_papers first"
        ))
    }

    authors <- "No authors"
    if (!purrr::is_empty(result$authors)) {
        authors <- paste(purrr::map_chr(result$authors, \(a) a$name), collapse = "; ")
    }

    paper <- list(
        paperId = result$paperId,
        title = result$title %||% "Untitled",
        authors = authors,
        year = result$year %||% "Unknown year",
        abstract = result$abstract %||% "No abstract available",
        citationCount = result$citationCount %||% 0,
        url = result$url,
        venue = result$venue %||% "Unknown venue",
        publicationDate = result$publicationDate %||% "Unknown date"
    )

    jsonlite::toJSON(paper, auto_unbox = TRUE)
}

get_paper_citations <- function(paper_id, limit = 10L, fields = NULL) {
    #' @description Get papers that cite a given paper. Returns citing papers
    #'   with their metadata. Useful for finding related work and tracking
    #'   research impact.
    #' @mcp tool
    #' @param paper_id:string* Paper ID (Semantic Scholar ID or DOI)
    #' @param limit:integer Maximum citations to return (default 10, max 1000)
    #' @param fields:string Comma-separated fields to return

    if (is.null(paper_id) || nchar(paper_id) == 0) {
        return(argent:::mcp_error(
            message = "Paper ID is required",
            type = "validation",
            details = "The 'paper_id' parameter cannot be empty",
            suggestion = "Provide a Semantic Scholar paper ID or DOI"
        ))
    }

    fields_param <- fields %||% default_fields

    endpoint <- paste0("/paper/", paper_id, "/citations")
    params <- list(limit = as.integer(min(limit, 1000)), fields = fields_param)

    result <- semantic_scholar_request(endpoint, query = params)

    if (isTRUE(result$.error)) {
        return(result)
    }

    if (is.null(result) || purrr::is_empty(result$data)) {
        return(jsonlite::toJSON(list(), auto_unbox = TRUE))
    }

    citations <- lapply(result$data, function(citation) {
        paper <- citation$citingPaper

        authors <- "No authors"
        if (!purrr::is_empty(paper$authors)) {
            authors <- paste(purrr::map_chr(paper$authors, \(a) a$name), collapse = "; ")
        }

        list(
            paperId = paper$paperId,
            title = paper$title %||% "Untitled",
            authors = authors,
            year = paper$year %||% "Unknown year",
            abstract = paper$abstract %||% "No abstract available",
            citationCount = paper$citationCount %||% 0,
            url = paper$url,
            venue = paper$venue %||% "Unknown venue",
            publicationDate = paper$publicationDate %||% "Unknown date"
        )
    })

    jsonlite::toJSON(citations, auto_unbox = TRUE)
}

get_paper_references <- function(paper_id, limit = 10L, fields = NULL) {
    #' @description Get papers referenced by a given paper (its bibliography).
    #'   Returns referenced papers with metadata. Useful for finding foundational
    #'   work and related research.
    #' @mcp tool
    #' @param paper_id:string* Paper ID (Semantic Scholar ID or DOI)
    #' @param limit:integer Maximum references to return (default 10, max 1000)
    #' @param fields:string Comma-separated fields to return

    if (is.null(paper_id) || nchar(paper_id) == 0) {
        return(argent:::mcp_error(
            message = "Paper ID is required",
            type = "validation",
            details = "The 'paper_id' parameter cannot be empty",
            suggestion = "Provide a Semantic Scholar paper ID or DOI"
        ))
    }

    fields_param <- fields %||% default_fields

    endpoint <- paste0("/paper/", paper_id, "/references")
    params <- list(limit = as.integer(min(limit, 1000)), fields = fields_param)

    result <- semantic_scholar_request(endpoint, query = params)

    if (isTRUE(result$.error)) {
        return(result)
    }

    if (is.null(result) || purrr::is_empty(result$data)) {
        return(jsonlite::toJSON(list(), auto_unbox = TRUE))
    }

    references <- lapply(result$data, function(reference) {
        paper <- reference$citedPaper

        authors <- "No authors"
        if (!purrr::is_empty(paper$authors)) {
            authors <- paste(purrr::map_chr(paper$authors, \(a) a$name), collapse = "; ")
        }

        list(
            paperId = paper$paperId,
            title = paper$title %||% "Untitled",
            authors = authors,
            year = paper$year %||% "Unknown year",
            abstract = paper$abstract %||% "No abstract available",
            citationCount = paper$citationCount %||% 0,
            url = paper$url,
            venue = paper$venue %||% "Unknown venue",
            publicationDate = paper$publicationDate %||% "Unknown date"
        )
    })

    jsonlite::toJSON(references, auto_unbox = TRUE)
}
```

We can start the server **in a separate R session or terminal** with:

``` r
mcp_serve_http(system.file("examples/semantic_scholar_mcp_server.R", package = "argent"), port = 8080)
#> ✔ Starting semantic_scholar_mcp_server MCP server on <http://127.0.0.1:8080>
```

> **Note**
>
> **Why start the server separately?** Unlike stdio servers (like Zotero
> above), which are spawned as child processes by
> [`mcp_connect()`](https://ma-riviere.github.io/argent/reference/mcp_integration.md)
> using the provided `command` and `args`, HTTP servers are independent
> network services.
> [`mcp_connect()`](https://ma-riviere.github.io/argent/reference/mcp_integration.md)
> with `type = "http"` simply connects to an already-running server at
> the specified URL—it cannot start the server for you.

> **Note**
>
> This implementation uses `argent`‘s annotation parsing & MCP
> machinery, which allows us to implement a fully-featured MCP server by
> simply defining the tools we want to expose as annotated functions.
> All the ’boilerplate’ code for setting up the MCP server is handled by
> `argent`.
>
> If we were to create the same MCP server manually using an HTTP server
> framework like `plumber2`, here is what it would look like:
>
> 'Manual' HTTP MCP Server Implementation
>
> ``` r
> # Semantic Scholar MCP Server - Standalone HTTP Implementation using plumber2
> #
> # A standalone MCP-compatible HTTP server using plumber2 for the Semantic Scholar API.
> # Implements the MCP Streamable HTTP transport (protocol version 2025-03-26).
> #
> # This is a STANDALONE implementation - it does NOT depend on any MCP package
> # (like posit-dev/mcptools). It implements the MCP protocol directly.
> #
> # FEATURES:
> # - Implements MCP Streamable HTTP transport (2025-03-26)
> # - JSON responses (batch mode, no SSE streaming)
> # - Session management via Mcp-Session-Id header
> # - Compatible with MCP clients (Gemini CLI, Claude Code, etc.)
> #
> # To start the server, run:
> #
> #   plumber2::api(system.file("examples/semantic_scholar_mcp_server_plumber.R", package = "argent")) |>
> #       plumber2::api_run(host = "127.0.0.1", port = 8080, block = TRUE, silent = FALSE, showcase = FALSE)
> #
> # Then configure your MCP client:
> # {
> #   "mcpServers": {
> #     "semantic-scholar": {
> #       "type": "http",
> #       "httpUrl": "http://127.0.0.1:8080/mcp"
> #     }
> #   }
> # }
> ```
>
> ``` r
> suppressPackageStartupMessages({
>     library(plumber2)
>     library(httr2)
>     library(jsonlite)
> })
>
> options(httr2_progress = FALSE)
>
> # Safe header getter - handles NULL, NA, and empty strings
> safe_get_header <- function(request, name) {
>     val <- tryCatch(request$get_header(name), error = function(e) NULL)
>     # Handle NULL & empty
>     if (purrr::is_empty(val)) {
>         return(NULL)
>     }
>     # If multiple values, collapse them
>     if (length(val) > 1) {
>         val <- paste(val, collapse = ", ")
>     }
>     # Handle NA
>     if (is.na(val) || !nzchar(val)) {
>         return(NULL)
>     }
>     val
> }
>
> # MCP Protocol version we implement
> MCP_PROTOCOL_VERSION <- "2025-03-26"
>
> # Server information
> SERVER_INFO <- list(name = "semantic-scholar", version = "1.0.0")
>
> # Session storage - each session tracks initialization state
> SESSION_STORE <- new.env(parent = emptyenv())
> ```
>
> ``` r
> semantic_scholar_request <- function(endpoint, query = list()) {
>     base_url <- "https://api.semanticscholar.org/graph/v1"
>     url <- paste0(base_url, endpoint)
>
>     resp <- httr2::request(url) |>
>         httr2::req_url_query(!!!query) |>
>         httr2::req_error(is_error = \(resp) FALSE) |>
>         httr2::req_throttle(rate = 20 / 60, realm = "semantic-scholar") |>
>         httr2::req_perform()
>
>     status <- httr2::resp_status(resp)
>
>     if (status == 429) {
>         return(list(
>             .error = TRUE,
>             code = 429,
>             message = "Rate limit exceeded",
>             details = "Too many requests to Semantic Scholar API"
>         ))
>     }
>
>     if (status == 404) {
>         return(NULL)
>     }
>
>     if (status != 200) {
>         return(list(
>             .error = TRUE,
>             code = status,
>             message = paste0("Semantic Scholar API request failed with status ", status),
>             details = paste0("Unexpected HTTP status code from endpoint: ", endpoint)
>         ))
>     }
>
>     httr2::resp_body_json(resp)
> }
>
> default_fields <- "title,authors,year,abstract,citationCount,url,venue,publicationDate"
>
> search_papers <- function(query, limit = 10L, fields = NULL) {
>     if (is.null(query) || nchar(query) == 0) {
>         return(list(
>             .error = TRUE,
>             code = -32602,
>             message = "Query parameter is required",
>             details = "The 'query' parameter cannot be empty"
>         ))
>     }
>
>     fields_param <- fields %||% default_fields
>
>     params <- list(query = query, limit = as.integer(min(limit, 100)), fields = fields_param)
>
>     result <- semantic_scholar_request("/paper/search", query = params)
>
>     if (isTRUE(result$.error)) {
>         return(result)
>     }
>
>     if (is.null(result) || length(result$data) == 0) {
>         return(list())
>     }
>
>     papers <- lapply(result$data, function(paper) {
>         authors <- "No authors"
>         if (length(paper$authors) > 0) {
>             authors <- paste(vapply(paper$authors, function(a) a$name %||% "", character(1)), collapse = "; ")
>         }
>
>         list(
>             paperId = paper$paperId,
>             title = paper$title %||% "Untitled",
>             authors = authors,
>             year = paper$year %||% "Unknown year",
>             abstract = paper$abstract %||% "No abstract available",
>             citationCount = paper$citationCount %||% 0,
>             url = paper$url,
>             venue = paper$venue %||% "Unknown venue",
>             publicationDate = paper$publicationDate %||% "Unknown date"
>         )
>     })
>
>     return(papers)
> }
>
> get_paper <- function(paper_id, fields = NULL) {
>     if (is.null(paper_id) || nchar(paper_id) == 0) {
>         return(list(
>             .error = TRUE,
>             code = -32602,
>             message = "Paper ID is required",
>             details = "The 'paper_id' parameter cannot be empty"
>         ))
>     }
>
>     fields_param <- fields %||% default_fields
>
>     endpoint <- paste0("/paper/", paper_id)
>     params <- list(fields = fields_param)
>
>     result <- semantic_scholar_request(endpoint, query = params)
>
>     if (isTRUE(result$.error)) {
>         return(result)
>     }
>
>     if (is.null(result)) {
>         return(list(
>             .error = TRUE,
>             code = -32600,
>             message = "Paper not found",
>             details = paste0("No paper with ID '", paper_id, "' exists")
>         ))
>     }
>
>     authors <- "No authors"
>     if (length(result$authors) > 0) {
>         authors <- paste(vapply(result$authors, function(a) a$name %||% "", character(1)), collapse = "; ")
>     }
>
>     list(
>         paperId = result$paperId,
>         title = result$title %||% "Untitled",
>         authors = authors,
>         year = result$year %||% "Unknown year",
>         abstract = result$abstract %||% "No abstract available",
>         citationCount = result$citationCount %||% 0,
>         url = result$url,
>         venue = result$venue %||% "Unknown venue",
>         publicationDate = result$publicationDate %||% "Unknown date"
>     )
> }
>
> get_paper_citations <- function(paper_id, limit = 10, fields = NULL) {
>     if (is.null(paper_id) || nchar(paper_id) == 0) {
>         return(list(
>             .error = TRUE,
>             code = -32602,
>             message = "Paper ID is required",
>             details = "The 'paper_id' parameter cannot be empty"
>         ))
>     }
>
>     fields_param <- fields %||% default_fields
>
>     endpoint <- paste0("/paper/", paper_id, "/citations")
>     params <- list(limit = as.integer(min(limit, 1000)), fields = fields_param)
>
>     result <- semantic_scholar_request(endpoint, query = params)
>
>     if (isTRUE(result$.error)) {
>         return(result)
>     }
>
>     if (is.null(result) || length(result$data) == 0) {
>         return(list())
>     }
>
>     citations <- lapply(result$data, function(citation) {
>         paper <- citation$citingPaper
>
>         authors <- "No authors"
>         if (length(paper$authors) > 0) {
>             authors <- paste(vapply(paper$authors, function(a) a$name %||% "", character(1)), collapse = "; ")
>         }
>
>         list(
>             paperId = paper$paperId,
>             title = paper$title %||% "Untitled",
>             authors = authors,
>             year = paper$year %||% "Unknown year",
>             abstract = paper$abstract %||% "No abstract available",
>             citationCount = paper$citationCount %||% 0,
>             url = paper$url,
>             venue = paper$venue %||% "Unknown venue",
>             publicationDate = paper$publicationDate %||% "Unknown date"
>         )
>     })
>
>     return(citations)
> }
>
> get_paper_references <- function(paper_id, limit = 10, fields = NULL) {
>     if (is.null(paper_id) || nchar(paper_id) == 0) {
>         return(list(
>             .error = TRUE,
>             code = -32602,
>             message = "Paper ID is required",
>             details = "The 'paper_id' parameter cannot be empty"
>         ))
>     }
>
>     fields_param <- fields %||% default_fields
>
>     endpoint <- paste0("/paper/", paper_id, "/references")
>     params <- list(limit = as.integer(min(limit, 1000)), fields = fields_param)
>
>     result <- semantic_scholar_request(endpoint, query = params)
>
>     if (isTRUE(result$.error)) {
>         return(result)
>     }
>
>     if (is.null(result) || length(result$data) == 0) {
>         return(list())
>     }
>
>     references <- lapply(result$data, function(reference) {
>         paper <- reference$citedPaper
>
>         authors <- "No authors"
>         if (length(paper$authors) > 0) {
>             authors <- paste(vapply(paper$authors, function(a) a$name %||% "", character(1)), collapse = "; ")
>         }
>
>         list(
>             paperId = paper$paperId,
>             title = paper$title %||% "Untitled",
>             authors = authors,
>             year = paper$year %||% "Unknown year",
>             abstract = paper$abstract %||% "No abstract available",
>             citationCount = paper$citationCount %||% 0,
>             url = paper$url,
>             venue = paper$venue %||% "Unknown venue",
>             publicationDate = paper$publicationDate %||% "Unknown date"
>         )
>     })
>
>     return(references)
> }
> ```
>
> ``` r
> jsonrpc_success <- function(id, result) {
>     list(jsonrpc = "2.0", id = id, result = result)
> }
>
> jsonrpc_error <- function(id, code, message, data = NULL) {
>     error_obj <- list(code = code, message = message)
>     if (!is.null(data)) {
>         error_obj$data <- data
>     }
>
>     list(jsonrpc = "2.0", id = id, error = error_obj)
> }
>
> mcp_tool_result <- function(content, is_error = FALSE) {
>     if (is.character(content)) {
>         text_content <- as.character(content)[[1]]
>     } else if (is.list(content)) {
>         text_content <- as.character(jsonlite::toJSON(content, auto_unbox = TRUE, pretty = TRUE))
>     } else {
>         text_content <- as.character(content)[[1]]
>     }
>
>     list(content = list(list(type = "text", text = text_content)), isError = is_error)
> }
> ```
>
> ``` r
> MCP_TOOLS <- list(
>     list(
>         name = "search_papers",
>         description = paste(
>             "Search for academic papers by keywords, authors, or topics using the Semantic Scholar API.",
>             "Returns a list of papers with metadata including title, authors, year, abstract, citation count, and URL.",
>             "IMPORTANT: Use broad search terms for better results. Search is case-insensitive.",
>             "Returns up to 100 results per query."
>         ),
>         inputSchema = list(
>             type = "object",
>             properties = list(
>                 query = list(
>                     type = "string",
>                     description = "Search query (keywords, author names, paper titles, etc.)"
>                 ),
>                 limit = list(
>                     type = "integer",
>                     description = "Maximum number of results to return (default: 10, max: 100)",
>                     default = 10L
>                 ),
>                 fields = list(type = "string", description = "Comma-separated list of fields to return")
>             ),
>             required = list("query")
>         )
>     ),
>     list(
>         name = "get_paper",
>         description = paste(
>             "Get detailed metadata for a specific paper by its Semantic Scholar ID or DOI.",
>             "Returns comprehensive information including title, authors, abstract, year, citation count, and more."
>         ),
>         inputSchema = list(
>             type = "object",
>             properties = list(
>                 paper_id = list(type = "string", description = "Paper ID (Semantic Scholar ID or DOI)"),
>                 fields = list(type = "string", description = "Comma-separated list of fields to return")
>             ),
>             required = list("paper_id")
>         )
>     ),
>     list(
>         name = "get_paper_citations",
>         description = paste(
>             "Get papers that cite a given paper.",
>             "Returns a list of citing papers with their metadata."
>         ),
>         inputSchema = list(
>             type = "object",
>             properties = list(
>                 paper_id = list(type = "string", description = "Paper ID (Semantic Scholar ID or DOI)"),
>                 limit = list(
>                     type = "integer",
>                     description = "Maximum number of citations to return (default: 10, max: 1000)",
>                     default = 10L
>                 ),
>                 fields = list(type = "string", description = "Comma-separated list of fields to return")
>             ),
>             required = list("paper_id")
>         )
>     ),
>     list(
>         name = "get_paper_references",
>         description = paste(
>             "Get papers referenced by a given paper (its bibliography).",
>             "Returns a list of referenced papers with their metadata."
>         ),
>         inputSchema = list(
>             type = "object",
>             properties = list(
>                 paper_id = list(type = "string", description = "Paper ID (Semantic Scholar ID or DOI)"),
>                 limit = list(
>                     type = "integer",
>                     description = "Maximum number of references to return (default: 10, max: 1000)",
>                     default = 10L
>                 ),
>                 fields = list(type = "string", description = "Comma-separated list of fields to return")
>             ),
>             required = list("paper_id")
>         )
>     )
> )
>
> MCP_RESOURCES <- list()
> MCP_PROMPTS <- list()
> ```
>
> ``` r
> handle_initialize <- function(params) {
>     list(
>         protocolVersion = MCP_PROTOCOL_VERSION,
>         capabilities = list(
>             tools = list(listChanged = FALSE),
>             resources = list(subscribe = FALSE, listChanged = FALSE),
>             prompts = list(listChanged = FALSE)
>         ),
>         serverInfo = SERVER_INFO
>     )
> }
>
> handle_tools_list <- function() {
>     list(tools = MCP_TOOLS)
> }
>
> handle_tools_call <- function(params) {
>     tool_name <- params$name
>     tool_args <- params$arguments
>     if (is.null(tool_args)) {
>         tool_args <- list()
>     }
>
>     if (is.null(tool_name) || !is.character(tool_name) || nchar(tool_name) == 0) {
>         return(list(.jsonrpc_error = TRUE, code = -32602, message = "Missing tool name"))
>     }
>
>     available_tools <- vapply(MCP_TOOLS, function(t) t$name, character(1))
>     if (!tool_name %in% available_tools) {
>         return(list(
>             .jsonrpc_error = TRUE,
>             code = -32601,
>             message = "Method not found",
>             data = paste0("Unknown tool: ", tool_name)
>         ))
>     }
>
>     tool_fn <- tryCatch(get(tool_name), error = function(e) NULL)
>     if (is.null(tool_fn) || !is.function(tool_fn)) {
>         return(list(
>             .jsonrpc_error = TRUE,
>             code = -32601,
>             message = "Method not found",
>             data = paste0("Tool function not found: ", tool_name)
>         ))
>     }
>
>     tool_result <- tryCatch(do.call(tool_fn, tool_args), error = function(e) {
>         list(.error = TRUE, message = "Tool execution failed", details = conditionMessage(e))
>     })
>
>     if (isTRUE(tool_result$.error)) {
>         error_msg <- tool_result$message %||% "Unknown error"
>         if (!is.null(tool_result$details)) {
>             error_msg <- paste0(error_msg, ": ", tool_result$details)
>         }
>         mcp_tool_result(error_msg, is_error = TRUE)
>     } else {
>         result_json <- jsonlite::toJSON(tool_result, auto_unbox = TRUE, pretty = TRUE)
>         mcp_tool_result(result_json, is_error = FALSE)
>     }
> }
>
> handle_resources_list <- function() {
>     list(resources = MCP_RESOURCES)
> }
>
> handle_resources_templates_list <- function() {
>     list(resourceTemplates = list())
> }
>
> handle_resources_read <- function(params) {
>     uri <- params$uri
>     if (is.null(uri)) {
>         return(list(.jsonrpc_error = TRUE, code = -32602, message = "Missing uri parameter"))
>     }
>
>     resource <- NULL
>     for (r in MCP_RESOURCES) {
>         if (r$uri == uri) {
>             resource <- r
>             break
>         }
>     }
>
>     if (is.null(resource)) {
>         return(list(.jsonrpc_error = TRUE, code = -32002, message = "Resource not found", data = list(uri = uri)))
>     }
>
>     list(contents = list(resource))
> }
>
> handle_prompts_list <- function() {
>     list(prompts = MCP_PROMPTS)
> }
>
> handle_prompts_get <- function(params) {
>     name <- params$name
>     if (is.null(name)) {
>         return(list(.jsonrpc_error = TRUE, code = -32602, message = "Missing name parameter"))
>     }
>
>     prompt <- NULL
>     for (p in MCP_PROMPTS) {
>         if (p$name == name) {
>             prompt <- p
>             break
>         }
>     }
>
>     if (is.null(prompt)) {
>         return(list(
>             .jsonrpc_error = TRUE,
>             code = -32602,
>             message = "Prompt not found",
>             data = paste0("Unknown prompt: ", name)
>         ))
>     }
>
>     list(description = prompt$description, messages = list())
> }
> ```
>
> ``` r
> validate_jsonrpc <- function(body) {
>     if (is.null(body) || length(body) == 0) {
>         return(list(code = -32700, message = "Empty or null request body"))
>     }
>     if (!is.list(body)) {
>         return(list(code = -32700, message = "Request body must be a JSON object"))
>     }
>     jsonrpc <- body$jsonrpc
>     if (is.null(jsonrpc) || jsonrpc != "2.0") {
>         return(list(code = -32600, message = "Invalid JSON-RPC version"))
>     }
>     method <- body$method
>     if (is.null(method) || !is.character(method) || nchar(method) == 0) {
>         return(list(code = -32600, message = "Missing method in request"))
>     }
>     NULL
> }
>
> log_mcp_request <- function(method, session_id = NULL, error = NULL) {
>     timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
>     session_str <- if (!is.null(session_id)) paste0(" [", session_id, "]") else ""
>     error_str <- if (!is.null(error)) paste0(" ERROR: ", error) else ""
>     cat(sprintf("[%s]%s MCP: %s%s", timestamp, session_str, method, error_str))
> }
>
> process_mcp_request <- function(body, session_id) {
>     method <- body$method %||% "unknown"
>     id <- body$id
>     params <- body$params
>     if (is.null(params)) {
>         params <- list()
>     }
>
>     log_mcp_request(method, session_id)
>
>     result <- tryCatch(
>         {
>             switch(
>                 method,
>                 "initialize" = handle_initialize(params),
>                 "notifications/initialized" = NULL,
>                 "ping" = list(),
>                 "tools/list" = handle_tools_list(),
>                 "tools/call" = handle_tools_call(params),
>                 "resources/list" = handle_resources_list(),
>                 "resources/read" = handle_resources_read(params),
>                 "resources/templates/list" = handle_resources_templates_list(),
>                 "prompts/list" = handle_prompts_list(),
>                 "prompts/get" = handle_prompts_get(params),
>                 # Default case
>                 {
>                     list(
>                         .jsonrpc_error = TRUE,
>                         code = -32601,
>                         message = "Method not found",
>                         data = paste0("Unknown method: ", method)
>                     )
>                 }
>             )
>         },
>         error = function(e) {
>             log_mcp_request(method, session_id, error = conditionMessage(e))
>             list(.jsonrpc_error = TRUE, code = -32603, message = "Internal error", data = conditionMessage(e))
>         }
>     )
>
>     list(result = result, method = method, id = id, is_notification = is.null(id))
> }
> ```
>
> ``` r
> #* MCP Streamable HTTP endpoint - POST handler
> #*
> #* Handles all MCP JSON-RPC requests.
> #*
> #* @post /mcp
> #* @parser json
> #* @serializer unboxedJSON
> function(request, response, body) {
>     tryCatch(
>         {
>             cat("\n[MCP] POST /mcp request received")
>             cat(sprintf("[MCP] Body: %s", jsonlite::toJSON(body, auto_unbox = TRUE)))
>
>             # Check Content-Type
>             content_type <- safe_get_header(request, "Content-Type")
>             cat(sprintf("[MCP] Content-Type: %s", content_type %||% "(none)"))
>
>             if (is.null(content_type) || !grepl("application/json", content_type, ignore.case = TRUE)) {
>                 response$status <- 400L
>                 return(jsonrpc_error(NULL, -32700, "Content-Type must be application/json"))
>             }
>
>             # Check Accept header (optional)
>             accept <- safe_get_header(request, "Accept")
>             if (
>                 !is.null(accept) &&
>                     !grepl("application/json", accept, ignore.case = TRUE) &&
>                     !grepl("text/event-stream", accept, ignore.case = TRUE) &&
>                     !grepl("\\*/\\*", accept)
>             ) {
>                 response$status <- 406L
>                 return(jsonrpc_error(NULL, -32600, "Accept header must include application/json"))
>             }
>
>             # Validate JSON-RPC structure
>             validation_error <- validate_jsonrpc(body)
>             if (!is.null(validation_error)) {
>                 response$status <- 400L
>                 return(jsonrpc_error(body$id, validation_error$code, validation_error$message))
>             }
>
>             method <- body$method
>             id <- body$id
>             cat(sprintf("[MCP] Method: %s, ID: %s", method, id %||% "(notification)"))
>
>             # Get session ID from header
>             session_id <- safe_get_header(request, "Mcp-Session-Id")
>
>             # Handle initialize specially - creates new session
>             if (method == "initialize") {
>                 new_session_id <- paste0("session-", format(Sys.time(), "%Y%m%d%H%M%S"), "-", sample.int(100000, 1))
>
>                 SESSION_STORE[[new_session_id]] <- list(created = Sys.time(), initialized = TRUE)
>
>                 processed <- process_mcp_request(body, new_session_id)
>
>                 response$set_header("Mcp-Session-Id", new_session_id)
>                 response$status <- 200L
>
>                 cat(sprintf("[MCP] Initialize complete, session: %s", new_session_id))
>
>                 return(jsonrpc_success(id, processed$result))
>             }
>
>             # For non-initialize methods, validate session if provided
>             if (!is.null(session_id) && !exists(session_id, envir = SESSION_STORE)) {
>                 response$status <- 404L
>                 return(jsonrpc_error(id, -32001, "Session not found", paste0("Invalid session ID: ", session_id)))
>             }
>
>             # Process the request
>             processed <- process_mcp_request(body, session_id)
>
>             # Handle notifications (no id) - return 202 Accepted
>             if (processed$is_notification || is.null(processed$result)) {
>                 response$status <- 202L
>                 return(list())
>             }
>
>             # Handle errors
>             if (isTRUE(processed$result$.jsonrpc_error)) {
>                 response$status <- 200L
>                 return(jsonrpc_error(id, processed$result$code, processed$result$message, processed$result$data))
>             }
>
>             # Success response
>             response$status <- 200L
>             result <- jsonrpc_success(id, processed$result)
>             cat(sprintf("[MCP] Success response for method: %s", method))
>             return(result)
>         },
>         error = function(e) {
>             cat(sprintf("[MCP] ERROR: %s", conditionMessage(e)))
>             cat(sprintf("[MCP] Traceback: %s", paste(capture.output(traceback()), collapse = "\n")))
>             response$status <- 500L
>             return(jsonrpc_error(NULL, -32603, "Internal server error", conditionMessage(e)))
>         }
>     )
> }
>
> #* MCP Streamable HTTP endpoint - GET handler
> #*
> #* Per MCP spec: return 405 Method Not Allowed if server doesn't support SSE.
> #*
> #* @get /mcp
> #* @serializer unboxedJSON
> function(request, response) {
>     cat("\n[MCP] GET /mcp request received - returning 405 (SSE not supported)")
>
>     response$status <- 405L
>     response$set_header("Allow", "POST")
>
>     list(
>         error = "Method Not Allowed",
>         message = "This server does not support Server-Sent Events (SSE). Use POST for JSON-RPC requests."
>     )
> }
>
> #* MCP Streamable HTTP endpoint - DELETE handler
> #*
> #* Terminates an MCP session.
> #*
> #* @delete /mcp
> #* @serializer unboxedJSON
> function(request, response) {
>     cat("\n[MCP] DELETE /mcp request received\n")
>
>     session_id <- safe_get_header(request, "Mcp-Session-Id")
>
>     if (is.null(session_id)) {
>         response$status <- 400L
>         return(list(error = "Bad Request", message = "Missing Mcp-Session-Id header"))
>     }
>
>     if (!exists(session_id, envir = SESSION_STORE)) {
>         response$status <- 404L
>         return(list(error = "Not Found", message = "Session not found"))
>     }
>
>     rm(list = session_id, envir = SESSION_STORE)
>     cat(sprintf("\n[MCP] Session terminated: %s\n", session_id))
>
>     response$status <- 204L
>     list()
> }
>
> #* Health check endpoint
> #*
> #* @get /health
> #* @serializer unboxedJSON
> function(request, response) {
>     list(
>         status = "ok",
>         server = SERVER_INFO$name,
>         version = SERVER_INFO$version,
>         protocol_version = MCP_PROTOCOL_VERSION
>     )
> }
>
> #* Root endpoint - server info
> #*
> #* @get /
> #* @serializer unboxedJSON
> function(request, response) {
>     list(
>         message = "Semantic Scholar MCP Server",
>         mcp_endpoint = "/mcp",
>         health_endpoint = "/health",
>         server = SERVER_INFO$name,
>         version = SERVER_INFO$version,
>         protocol_version = MCP_PROTOCOL_VERSION
>     )
> }
> ```
>
> Which we can run **in a separate R session or terminal** with:
>
> ``` r
> plumber2::api(system.file("examples/semantic_scholar_mcp_server_plumber.R", package = "argent")) |>
>     plumber2::api_run(host = "127.0.0.1", port = 8080, block = TRUE, silent = FALSE, showcase = FALSE)
> ```

Then, we can connect to it from our main session:

``` r
semantic_scholar_client <- mcp_connect(name = "semantic-scholar", type = "http", url = "http://127.0.0.1:8080/mcp")

semantic_scholar_tools <- mcp_tools(semantic_scholar_client)
```

Test the server manually:

``` r
papers <- execute_mcp_tool(
    get_mcp_tool(semantic_scholar_tools, "search_papers"),
    arguments = list(
        query = "Sensorimotor Contingencies",
        limit = 2L,
        fields = "title,authors,year,abstract,citationCount"
    )
)

# Parse results
papers_df <- jsonlite::fromJSON(papers) |> dplyr::select(paperId, title, year, citationCount)

paper_id <- dplyr::slice_max(papers_df, order_by = citationCount)$paperId

# Getting the details of the first paper
execute_mcp_tool(
    get_mcp_tool(semantic_scholar_tools, "get_paper"),
    arguments = list(paper_id = paper_id, fields = "title,authors,year,abstract")
)
```

Now use it with an LLM agent:

``` r
gemini <- Google$new()

gemini$chat(
    "Find recent papers (2020+) on Sensory Substitution and Cross-Modal Plasticity and summarize the key innovations",
    "When using the `search_papers` tool, use a limit of 2 by search, to not exceed the rate limit.",
    "If you exceed the rate limit, wait a few seconds before trying again.",
    "Use the `get_paper` tool to get the details of the papers like its abstract.",
    model = "gemini-2.5-flash",
    tools = semantic_scholar_tools,
    output_schema = schema(
        name = "research_papers_summary",
        description = "Information about research papers",
        papers = list(
            type = "[object]*",
            description = "Array of paper objects",
            paper_id = "string* The ID of the paper",
            title = "string* The title of the paper",
            year = "integer* The year of the paper",
            main_findings = "string* The main findings of the paper"
        )
    )
)
```

> **Tip**
>
> **HTTP vs stdio servers:**
>
> - **HTTP servers** can be accessed remotely, support multiple
>   concurrent clients, and can be deployed as web services
> - **stdio servers** are simpler, work locally only, and are typically
>   one client per server instance
> - Both types use the same MCP protocol and tool definitions

> **Tip**
>
> We can use our new Semantic Scholar MCP server (either the standalone
> `plumber2` implementation or the `argent` implementation) with other
> MCP clients with:
>
> ``` json
> {
>   "mcpServers": {
>     "semantic-scholar": {
>       "httpUrl": "http://127.0.0.1:8080/mcp"
>     }
>   }
> }
> ```
