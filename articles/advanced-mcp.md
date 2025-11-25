# Using MCP Servers with `argent`

## Introduction

The Model Context Protocol (MCP) enables LLMs to securely interact with
external tools and data sources. This vignette demonstrates how to
integrate MCP servers with argent to extend your AI agent’s
capabilities.

MCP (Model Context Protocol) is an open protocol that standardizes how
applications provide context to LLMs. MCP servers expose three main
primitives:

- **Tools**: Executable functions the LLM can call
- **Resources**: File-like structured data the LLM can access (not
  supported yet)
- **Prompts**: Predefined templates for interactions (not supported yet)

There are two main types of MCP servers: *HTTP* and *stdio*. HTTP
servers are typically used for cloud-based services like GitHub, while
stdio servers are typically used for local services like Docker or npx.
Both types of MCP servers can be used with `argent`.

## Setup

``` r
library(argent)
```

## Basic Usage

### Using an ‘HTTP’ MCP Server

Let’s look at the GitHub MCP server as an example. It is a HTTP server
that can be used to interact with the GitHub API.

``` r
github_mcp_client <- mcp_connect(
    name = "github",
    type = "http",
    url = "https://api.githubcopilot.com/mcp",
    headers = list(
        Authorization = paste("Bearer", Sys.getenv("GITHUB_PAT"))
    )
)
```

Then, we can get the tools we want from the GitHub MCP server:

``` r
github_mcp_tools <- mcp_tools(github_mcp_client, tools = c("get_file_contents", "search_code"))
```

Finally, we can call the `get_file_contents` tool manually to see if it
works:

``` r
execute_mcp_tool(
    tool_def = get_mcp_tool(github_mcp_tools, "get_file_contents"),
    arguments = list(
        owner = "tidyverse",
        repo = "ellmer",
        path = "/",
        ref = "main"
    )
)
```

### Using a ‘stdio’ MCP Server

Let’s look at the BTW MCP server as an example (which requires the
[`btw`](https://github.com/posit-dev/btw) package to be installed). It
is a stdio server that can be used to interact with the `btw` package.

``` r
btw_mcp_client <- mcp_connect(
    name = "btw",
    type = "stdio",
    command = "Rscript",
    args = c(
        "-e",
        "btw::btw_mcp_server(tools = btw::btw_tools(c('docs', 'env', 'ide', 'search', 'session')))"
    )
)
```

Then, we can get the tools we want from the `btw` MCP server:

``` r
btw_mcp_tools <- mcp_tools(
    btw_mcp_client,
    tools = c(
        "btw_tool_session_check_package_installed",
        "btw_tool_docs_available_vignettes",
        "btw_tool_docs_package_help_topics",
        "btw_tool_docs_help_page",
        "btw_tool_docs_vignette",
        "btw_tool_session_package_info",
        "btw_tool_docs_package_help_topics"
    )
)
```

Finally, we can call the `help_topics` tool manually to see if it works:

``` r
execute_mcp_tool(
    tool_def = get_mcp_tool(btw_mcp_tools, "btw_tool_docs_package_help_topics"),
    arguments = list(
        package_name = "argent",
        `_intent` = "Vignettes explaining how to use MCP servers with argent"
    )
)
```

## Argent + MCP Servers

Let’s use the GitHub MCP server and the BTW MCP server to ask a complex
question about the `mcptools` and `ellmer` packages.

``` r
google <- Google$new()

google$chat(
    "Has 'posit-dev/mcptools' implemented the ability to use HTTP MCP servers with 'ellmer' ?",
    "Use the `get_file_contents` tool to list the contents of GitHub subdirectories, e.g. with path = '/' or 'dir/'.",
    "Use the `btw` tools to explore the help pages and vignettes of the local installation of the `mcptools` package.",
    model = "gemini-2.5-flash",
    tools = flat_list(github_mcp_tools, btw_mcp_tools)
)
```

``` default
`posit-dev/mcptools` does not directly implement the ability to use HTTP MCP servers with `ellmer`. When `mcptools` acts as an MCP *client* via `ellmer`, it only supports the local (stdio) protocol. 
To connect to remote (HTTP) MCP servers, the `mcptools` documentation recommends using `mcp-remote`, an external tool (a local stdio MCP server) that converts remote HTTP servers to `mcptools`-compatible local ones. This allows `ellmer` (using the stdio protocol) to interact with remote HTTP MCP servers through `mcp-remote`.
```

`print(google, show_tools = TRUE)`

``` default
── [ <Google> turns: 8 | Current context: 3786 | Cumulated tokens: 10034 ] ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────


── user [1611 / 2155] ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Has 'posit-dev/mcptools' implemented the ability to use HTTP MCP servers with 'ellmer' ? Use the `get_file_contents` tool to list the contents of GitHub subdirectories, e.g. with path = '/' or 'dir/'. Use the `btw` tools to explore the help pages and vignettes of the local installation of the `mcptools` package.

── System ──

You are a helpful AI assistant. Use your knowledge, the files you have access to, and the tools at your disposal to answer the user's query. You can use your tools multiple times, but use them sparingly. Make parallel tool calls if relevant to the user's query. Answer the user's query as soon as you have the information necessary to answer. Self-reflect and double-check your answer before responding. If you don't know the answer even after using your tools, say 'I don't know'. If you do not have all the information necessary to use a provided tool, use NA for required arguments. Today's date is 2025-11-24

── Tool Definitions ──

• get_file_contents(owner, path, ref, repo, sha): Get the contents of a file or directory from a GitHub repository
• search_code(order, page, perPage, query, sort): Fast and precise code search across ALL GitHub repositories using GitHub's native search engine. Best for finding exact symbols, functions,
  classes, or specific code patterns.
• btw_tool_docs_package_help_topics(package_name, _intent): Get available help topics for an R package.
• btw_tool_docs_help_page(package_name, topic, _intent): Get help page from package.
• btw_tool_docs_available_vignettes(package_name, _intent): List available vignettes for an R package. Vignettes are articles describing key concepts or features of an R package. Returns the
  listing as a JSON array of `vignette` and `title`. To read a vignette, use `btw_tool_docs_vignette(package_name, vignette)`.
• btw_tool_docs_vignette(package_name, vignette, _intent): Get a package vignette in plain text.
• btw_tool_session_check_package_installed(package_name, _intent): Check if a package is installed in the current session.
• btw_tool_session_package_info(packages, dependencies, _intent): Verify that a specific package is installed, or find out which packages are in use in the current session. As a last resort, this
  function can also list all installed packages.

── assistant [2155 / 2155] ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

── Tool Calls ──

• btw_tool_session_check_package_installed(package_name = "mcptools", _intent = "Check if mcptools is installed locally to access its documentation.")

── tool [1757 / 4021] ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

• Result from btw_tool_session_check_package_installed:

name: btw_tool_session_check_package_installed
arguments:
  package_name: mcptools
  _intent: Check if mcptools is installed locally to access its documentation.
result: Package `mcptools` version 0.2.0 is installed.


── assistant [1866 / 4021] ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

── Tool Calls ──

• btw_tool_docs_package_help_topics(_intent = "List all help topics for mcptools to find relevant documentation on HTTP MCP servers and ellmer.", package_name = "mcptools")

── tool [2040 / 6248] ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

• Result from btw_tool_docs_package_help_topics:

name: btw_tool_docs_package_help_topics
arguments:
  _intent: List all help topics for mcptools to find relevant documentation on HTTP
    MCP servers and ellmer.
  package_name: mcptools
result: |-
  [
    {"topic_id":"client","title":"R as a client: Define ellmer tools from MCP servers","aliases":["client","mcp_tools","mcp_client"]},
    {"topic_id":"mcptools-package","title":"mcptools: Model Context Protocol Servers and Clients","aliases":["mcptools","mcptools-package"]},
    {"topic_id":"server","title":"R as a server: Configure R-based tools with LLM-enabled apps","aliases":["server","mcp_server","mcp_session","server"]}
  ]


── assistant [2227 / 6248] ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

── Tool Calls ──

• btw_tool_docs_help_page(package_name = "mcptools", _intent = "Get the help page for the 'client' topic in mcptools to understand its functionality with ellmer and MCP servers.", topic = "client")

── tool [3359 / 10034] ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

• Result from btw_tool_docs_help_page:

name: btw_tool_docs_help_page
arguments:
  package_name: mcptools
  _intent: Get the help page for the 'client' topic in mcptools to understand its
    functionality with ellmer and MCP servers.
  topic: client
result: |-
  ## `help(package = "mcptools", "client")`

  ### R as a client: Define ellmer tools from MCP servers

  #### Description

  These functions implement R as an MCP *client*, so that ellmer chats can
  register functionality from third-party MCP servers such as those listed
  here: <https://github.com/modelcontextprotocol/servers>.

  `mcp_tools()` fetches tools from MCP servers configured in the mcptools
  server config file and converts them to a list of tools compatible with
  the `⁠$set_tools()⁠` method of ellmer::Chat objects.

  #### Usage

  mcp_tools(config = NULL)

  #### Arguments

  |  |  |
  |----|----|
  | `config` | A single string indicating the path to the mcptools MCP servers configuration file. If one is not supplied, mcptools will look...

── assistant [3786 / 10034] ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

No, `posit-dev/mcptools` itself does not directly implement the ability to use HTTP MCP servers with 'ellmer'. The `mcp_tools()` function within `mcptools`, which allows R to act as an MCP client via 'ellmer', only implements the local (stdio) protocol. However, `mcptools` recommends using `mcp-remote` (an external tool) as an intermediary. `mcp-remote` is a local (stdio) MCP server that can connect to remote (http) servers, converting them to an `mcptools`-compatible local protocol. This allows `mcptools` to indirectly utilize HTTP MCP servers through `mcp-remote`.
```

## Advanced Usage: making our own MCP servers

### Building a STDIO MCP Server

Let’s create our own stdio MCP server for interacting with Zotero’s
local API. This server will be usable both from argent and from other
MCP clients, like Claude Code.

#### Prerequisites

- Zotero 7+ must be running
- Enable “Allow other applications on this computer to communicate with
  Zotero” in Preferences \> Advanced

#### Server Implementation

Zotero MCP Server Implementation

``` r
# Zotero MCP Server
#
# A stdio MCP server for interacting with Zotero's local API.
# This server can be used with argent or other MCP clients like Claude Code.
```

``` {r🔺
# Setup for when the server is used as a standalone MCP server (e.g. from Claude Desktop)

# Since this file is part of the argent package, there should be no need to test is the package is installed or not.
# `argent` imports httr2, jsonlite & purrr, so we don't need to check if those are installed either.
suppressPackageStartupMessages(library(argent))

# Disable httr2 progress bars to avoid stderr noise
options(
    httr2_progress = FALSE,
    argent.debug = FALSE
)
```

``` {r🔺
# Defining the tools that the server will expose

# Base request function to Zotero local API
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

zotero_search_items <- function(query = NULL, qmode = "titleCreatorYear", tag = NULL, item_type = NULL, limit = 25) {
    params <- list(
        q = query,
        qmode = qmode,
        tag = tag,
        itemType = item_type,
        limit = as.integer(limit)
    )
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

        return(list(
            key = data$key,
            title = data$title %||% "Untitled",
            creators = creators,
            year = data$date %||% "No date",
            type = data$itemType
        ))
    })

    return(jsonlite::toJSON(result, auto_unbox = TRUE))
}

zotero_get_item <- function(item_key) {
    item <- zotero_request(paste0("/items/", item_key))

    if (isTRUE(item$.error)) {
        return(item)
    }

    # Handle NULL (404 not found)
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
    collections <- zotero_request("/collections")

    if (isTRUE(collections$.error)) {
        return(collections)
    }

    if (purrr::is_empty(collections)) {
        return(jsonlite::toJSON(list(), auto_unbox = TRUE))
    }

    result <- lapply(collections, function(col) {
        data <- col$data
        list(
            key = data$key,
            name = data$name,
            parentCollection = data$parentCollection %||% NA
        )
    })

    jsonlite::toJSON(result, auto_unbox = TRUE)
}

zotero_get_fulltext <- function(item_key) {
    tryCatch({
        item <- zotero_request(paste0("/items/", item_key))

        if (isTRUE(item$.error)) {
            return(item)
        }

        # Handle NULL (404 not found)
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

            pdf_attachments <- purrr::keep(
                children,
                function(child) {
                    child$data$itemType == "attachment" &&
                        grepl("pdf", child$data$contentType %||% "", ignore.case = TRUE)
                }
            )

            if (purrr::is_empty(pdf_attachments)) {
                return(argent:::mcp_error(
                    message = "No PDF attachments found for this item",
                    type = "not_found",
                    details = paste0("Item '", item_key, "' has no PDF attachments"),
                    suggestion = "Verify the item has PDF files attached in Zotero, or try a different item key"
                ))
            }

            attachment_key <- pdf_attachments[[1]]$data$key
            link_mode <- pdf_attachments[[1]]$data$linkMode
        } else {
            link_mode <- item$data$linkMode
        }

        fulltext <- zotero_request(
            paste0("/items/", attachment_key, "/fulltext"),
            valid_statuses = c(200, 404)
        )

        if (isTRUE(fulltext$.error)) {
            return(fulltext)
        }

        if (is.null(fulltext)) {
            details <- "PDF exists but fulltext index is not yet available"
            if (!is.null(link_mode) && link_mode == "linked_file") {
                details <- paste0(
                    details,
                    ". Note: This is a linked file. Zotero stores fulltext cache in a separate storage directory."
                )
            }

            return(argent:::mcp_error(
                message = "Fulltext has not been indexed yet",
                type = "not_ready",
                details = details,
                suggestion = paste(
                    "Wait for automatic indexing (after 30+ seconds of idle time)",
                    "or manually reindex: Right-click attachment in Zotero > Reindex Item"
                )
            ))
        }

        if (is.null(fulltext$content) || fulltext$content == "") {
            return(argent:::mcp_error(
                message = "Fulltext cache is empty",
                type = "unsupported",
                details = "The PDF may be image-based without searchable text layer",
                suggestion = "Use OCR software to add a text layer, or try a different PDF"
            ))
        }

        return(fulltext$content)
    },
    error = function(e) {
        return(argent:::mcp_error(
            message = "Fulltext extraction failed",
            type = "error",
            details = conditionMessage(e),
            suggestion = "Verify the item key exists using zotero_search_items or zotero_get_item first"
        ))
    })
}

zotero_list_fulltext_items <- function(since = 0) {
    result <- zotero_request("/fulltext", query = list(since = as.integer(since)))

    if (isTRUE(result$.error)) {
        return(result)
    }

    if (purrr::is_empty(result)) {
        return(jsonlite::toJSON(list(), auto_unbox = TRUE))
    }

    items <- purrr::imap(result, \(version, key) list(key = key, version = version))

    return(jsonlite::toJSON(items, auto_unbox = TRUE))
}

zotero_get_collection_items <- function(collection_key, limit = 100) {
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

        return(list(
            key = data$key,
            title = data$title %||% "Untitled",
            creators = creators,
            year = data$date %||% "No date",
            type = data$itemType
        ))
    })

    return(jsonlite::toJSON(result, auto_unbox = TRUE))
}

zotero_get_top_items <- function(limit = 100) {
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

        return(list(
            key = data$key,
            title = data$title %||% "Untitled",
            creators = creators,
            year = data$date %||% "No date",
            type = data$itemType
        ))
    })

    return(jsonlite::toJSON(result, auto_unbox = TRUE))
}

zotero_get_item_types <- function() {
    item_types <- zotero_request("/itemTypes")

    if (isTRUE(item_types$.error)) {
        return(item_types)
    }

    return(jsonlite::toJSON(item_types %||% list(), auto_unbox = TRUE))
}
```

``` {r🔺
zotero_mcp_server <- function() {
    server <- argent:::McpServer$new(
        name = "Zotero",
        version = "1.0.0"
    )

    # Define tool definitions using argent::tool() with fn parameter
    search_items_tool <- argent::tool(
        name = "zotero_search_items",
        description = paste(
            "Search for items in your Zotero library using phrase-based matching.",
            "Returns a list of items with their metadata (title, authors, year, type).",
            "IMPORTANT SEARCH TIPS:",
            "- The 'query' parameter performs phrase matching in titles and creator fields",
            "- Use broad, generic terms first (e.g., 'climate' before 'climate change mitigation')",
            "- Try synonyms if initial search yields no results",
            "- Break complex searches into multiple queries with different keywords",
            "- Use 'qmode=everything' to include full-text content in search",
            "- Search is case-insensitive but matches must be complete phrases"
        ),
        query = paste(
            "string Quick search query for phrase matching in titles and creator fields.",
            "Searches are case-insensitive phrase matches.",
            "Start with generic terms and narrow down or try synonyms if no results."
        ),
        qmode = paste(
            "string Search mode: 'titleCreatorYear' (default, searches title/creator/year)",
            "or 'everything' (includes full-text content from indexed PDFs).",
            "Use 'everything' only when searching PDF content is needed."
        ),
        tag = paste(
            "string Filter by exact tag name (case-sensitive).",
            "Supports Boolean syntax: 'tag1' (single), 'tag1 tag2' (tag with spaces),",
            "'tag=tag1&tag=tag2' (AND), 'tag1 || tag2' (OR), '-tag1' (NOT)."
        ),
        item_type = paste(
            "string Filter by item type.",
            "Common types: 'book', 'journalArticle', 'conferencePaper', 'thesis', 'report',",
            "'webpage', 'document', 'attachment'.",
            "Supports Boolean: 'book || journalArticle' (OR), '-attachment' (NOT)."
        ),
        limit = "integer Maximum number of items to return (1-100, default: 25)",
        fn = zotero_search_items
    )

    get_item_tool <- argent::tool(
        name = "zotero_get_item",
        description = paste(
            "Get detailed metadata for a specific Zotero item by its key.",
            "Returns comprehensive information including title, creators, abstract, date, type, tags, and URL.",
            "Use this after zotero_search_items to get full details for specific items."
        ),
        item_key = paste(
            "string* The unique item key returned from search results.",
            "Example: 'X42A7DEE' (alphanumeric, case-sensitive)."
        ),
        fn = zotero_get_item
    )

    get_collections_tool <- argent::tool(
        name = "zotero_get_collections",
        description = paste(
            "List all collections (folders) in your Zotero library.",
            "Collections organize items hierarchically.",
            "Returns collection keys, names, and parent-child relationships.",
            "Use collection keys with other endpoints to filter items by collection."
        ),
        fn = zotero_get_collections
    )

    get_fulltext_tool <- argent::tool(
        name = "zotero_get_fulltext",
        description = paste(
            "Extract full-text content from a Zotero item's attached PDF.",
            "Automatically finds PDF attachments if given a parent item key.",
            "REQUIREMENTS:",
            "- Item must have an attached PDF file (stored or linked)",
            "- PDF must be indexed by Zotero (automatic when idle, or manual reindex)",
            "- PDF must have searchable text (not image-only scans)",
            "NOTES:",
            "- Accepts both parent item keys (will find first PDF) or direct attachment keys",
            "- Returns helpful error messages if PDF is not indexed or not found",
            "- Warns if only partial content indexed (due to page/character limits)",
            "Use this to access the actual text content of papers for detailed analysis."
        ),
        item_key = paste(
            "string* The item key - can be either:",
            "(1) Parent item key from search results (will auto-find PDF attachment), or",
            "(2) Direct attachment key for a specific PDF.",
            "Obtain from zotero_search_items or zotero_get_item results."
        ),
        fn = zotero_get_fulltext
    )

    list_fulltext_items_tool <- argent::tool(
        name = "zotero_list_fulltext_items",
        description = paste(
            "List all items in the library that have indexed fulltext content.",
            "Returns item keys and their fulltext version numbers.",
            "Useful for discovering which items have searchable PDF content before retrieving it.",
            "Combine with zotero_get_fulltext to access the actual content."
        ),
        since = "integer Library version to filter from (default: 0 for all items)",
        fn = zotero_list_fulltext_items
    )

    get_collection_items_tool <- argent::tool(
        name = "zotero_get_collection_items",
        description = paste(
            "Get all items within a specific collection (folder).",
            "Returns metadata for items including title, authors, year, and type.",
            "Use zotero_get_collections to get collection keys first."
        ),
        collection_key = "string* The collection key obtained from zotero_get_collections",
        limit = "integer Maximum number of items to return (1-100, default: 100)",
        fn = zotero_get_collection_items
    )

    get_top_items_tool <- argent::tool(
        name = "zotero_get_top_items",
        description = paste(
            "Get only top-level items in the library.",
            "Excludes child items like attachments and notes.",
            "Returns metadata including title, authors, year, and type.",
            "Useful for getting a clean list of main references without clutter."
        ),
        limit = "integer Maximum number of items to return (1-100, default: 100)",
        fn = zotero_get_top_items
    )

    get_item_types_tool <- argent::tool(
        name = "zotero_get_item_types",
        description = paste(
            "Get a list of all valid item types supported by Zotero.",
            "Item types include: book, journalArticle, conferencePaper, thesis, etc.",
            "Useful for understanding what types can be used with the item_type filter",
            "in zotero_search_items and other endpoints."
        ),
        fn = zotero_get_item_types
    )

    # Add tools to server (handler extracted from .fn field)
    server$add_tool(search_items_tool)
    server$add_tool(get_item_tool)
    server$add_tool(get_collections_tool)
    server$add_tool(get_fulltext_tool)
    server$add_tool(list_fulltext_items_tool)
    server$add_tool(get_collection_items_tool)
    server$add_tool(get_top_items_tool)
    server$add_tool(get_item_types_tool)

    server$serve_stdio()
}

zotero_mcp_server()
```

> **Note**
>
> The Zotero MCP server code is available in the package at
> `inst/examples/zotero_mcp_server.R`.

#### Using the MCP Server

``` r
zotero_client <- mcp_connect(
    name = "zotero",
    type = "stdio",
    command = "Rscript",
    args = system.file("examples/zotero_mcp_server.R", package = "argent")
)

zotero_tools <- mcp_tools(zotero_client)
```

We could test if the MCP server is working by querying it ‘manually’:

Testing the Zotero MCP Server manually

``` r
# Getting details on all my collections
my_collections <- execute_mcp_tool(
    get_mcp_tool(zotero_tools, "zotero_get_collections")
)

# Getting the key of the Neuroscience collection
neuroscience_collection_key <- jsonlite::fromJSON(my_collections)  |> 
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
>         "--quiet",
>         "--vanilla",
>         "/path/to/argent/inst/examples/zotero_mcp_server.R"
>       ]
>     }
>   }
> }
> ```

### Building an HTTP MCP Server

Let’s create an HTTP MCP server for searching academic papers using the
Semantic Scholar API. Unlike stdio servers that communicate via standard
input/output, HTTP servers expose a REST endpoint that can be accessed
over the network.

> **Note**
>
> `argent` provides convenience functions to create HTTP MCP servers,
> but you can also create your own with `plumber2` or other HTTP server
> frameworks, independently from `argent`.

#### Prerequisites

- A Semantic Scholar API key (not required, but the rate limits are low
  without one)

#### Server Implementation

Semantic Scholar MCP Server Implementation

``` r
# Semantic Scholar MCP Server
#
# An HTTP MCP server for searching academic papers using the Semantic Scholar API.
# This server can be used with argent or other MCP clients.
```

``` {r🔺
suppressPackageStartupMessages(library(argent))

# Disable httr2 progress bars to avoid stderr noise
options(
    httr2_progress = FALSE,
    argent.debug = FALSE
)
```

``` {r🔺
# Defining the tools that the server will expose

# Base request function for Semantic Scholar API
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

semantic_scholar_search_papers <- function(query, limit = 10L, fields = NULL) {
    if (is.null(query) || nchar(query) == 0) {
        return(argent:::mcp_error(
            message = "Query parameter is required",
            type = "validation",
            details = "The 'query' parameter cannot be empty",
            suggestion = "Provide keywords, author names, or paper titles to search for"
        ))
    }

    # Use default fields if not specified
    fields_param <- fields %||% default_fields

    params <- list(
        query = query,
        limit = as.integer(min(limit, 100)),
        fields = fields_param
    )

    result <- semantic_scholar_request("/paper/search", query = params)

    if (isTRUE(result$.error)) {
        return(result)
    }

    if (is.null(result) || purrr::is_empty(result$data)) {
        return(jsonlite::toJSON(list(), auto_unbox = TRUE))
    }

    # Extract and format papers
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

semantic_scholar_get_paper <- function(paper_id, fields = NULL) {
    if (is.null(paper_id) || nchar(paper_id) == 0) {
        return(argent:::mcp_error(
            message = "Paper ID is required",
            type = "validation",
            details = "The 'paper_id' parameter cannot be empty",
            suggestion = "Provide a Semantic Scholar paper ID or DOI"
        ))
    }

    # Use default fields if not specified
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
            suggestion = "Verify the paper ID using search_papers first, or try a different ID/DOI"
        ))
    }

    # Format authors
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

semantic_scholar_get_paper_citations <- function(paper_id, limit = 10, fields = NULL) {
    if (is.null(paper_id) || nchar(paper_id) == 0) {
        return(argent:::mcp_error(
            message = "Paper ID is required",
            type = "validation",
            details = "The 'paper_id' parameter cannot be empty",
            suggestion = "Provide a Semantic Scholar paper ID or DOI"
        ))
    }

    # Use default fields if not specified
    fields_param <- fields %||% default_fields

    endpoint <- paste0("/paper/", paper_id, "/citations")
    params <- list(
        limit = as.integer(min(limit, 1000)),
        fields = fields_param
    )

    result <- semantic_scholar_request(endpoint, query = params)

    if (isTRUE(result$.error)) {
        return(result)
    }

    if (is.null(result) || purrr::is_empty(result$data)) {
        return(jsonlite::toJSON(list(), auto_unbox = TRUE))
    }

    # Extract citing papers
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

semantic_scholar_get_paper_references <- function(paper_id, limit = 10, fields = NULL) {
    if (is.null(paper_id) || nchar(paper_id) == 0) {
        return(argent:::mcp_error(
            message = "Paper ID is required",
            type = "validation",
            details = "The 'paper_id' parameter cannot be empty",
            suggestion = "Provide a Semantic Scholar paper ID or DOI"
        ))
    }

    # Use default fields if not specified
    fields_param <- fields %||% default_fields

    endpoint <- paste0("/paper/", paper_id, "/references")
    params <- list(
        limit = as.integer(min(limit, 1000)),
        fields = fields_param
    )

    result <- semantic_scholar_request(endpoint, query = params)

    if (isTRUE(result$.error)) {
        return(result)
    }

    if (is.null(result) || purrr::is_empty(result$data)) {
        return(jsonlite::toJSON(list(), auto_unbox = TRUE))
    }

    # Extract referenced papers
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

``` {r🔺
semantic_scholar_mcp_server <- function(port = 8080, host = "127.0.0.1") {
    server <- argent:::McpServer$new(
        name = "semantic-scholar",
        version = "1.0.0"
    )

    # Define tools
    search_papers_tool <- argent::tool(
        name = "search_papers",
        description = paste(
            "Search for academic papers by keywords, authors, or topics using the Semantic Scholar API.",
            "Returns a list of papers with metadata including title, authors, year, abstract, citation count, and URL.",
            "IMPORTANT:",
            "- Use broad search terms for better results",
            "- Search is case-insensitive",
            "- Returns up to 100 results per query"
        ),
        query = paste(
            "string* Search query (keywords, author names, paper titles, etc.).",
            "Examples: 'neural networks', 'attention mechanisms', 'Geoffrey Hinton'"
        ),
        limit = "integer Maximum number of results to return (default: 10, max: 100)",
        fields = paste(
            "string Comma-separated list of fields to return.",
            "Default: 'title,authors,year,abstract,citationCount,url,venue,publicationDate'.",
            "Other available fields: 'referenceCount', 'influentialCitationCount', 'fieldsOfStudy'"
        ),
        fn = semantic_scholar_search_papers
    )

    get_paper_tool <- argent::tool(
        name = "get_paper",
        description = paste(
            "Get detailed metadata for a specific paper by its Semantic Scholar ID or DOI.",
            "Returns comprehensive information including title, authors, abstract, year, citation count, and more.",
            "Use this after search_papers to get full details for specific papers."
        ),
        paper_id = paste(
            "string* Paper ID (Semantic Scholar ID or DOI).",
            "Examples: '649def34f8be52c8b66281af98ae884c09aef38b' (S2 ID), '10.1038/nature14539' (DOI)"
        ),
        fields = paste(
            "string Comma-separated list of fields to return.",
            "Default: 'title,authors,year,abstract,citationCount,url,venue,publicationDate'"
        ),
        fn = semantic_scholar_get_paper
    )

    get_paper_citations_tool <- argent::tool(
        name = "get_paper_citations",
        description = paste(
            "Get papers that cite a given paper.",
            "Returns a list of citing papers with their metadata.",
            "Useful for finding related work and tracking research impact."
        ),
        paper_id = "string* Paper ID (Semantic Scholar ID or DOI)",
        limit = "integer Maximum number of citations to return (default: 10, max: 1000)",
        fields = paste(
            "string Comma-separated list of fields to return for each citing paper.",
            "Default: 'title,authors,year,abstract,citationCount,url,venue,publicationDate'"
        ),
        fn = semantic_scholar_get_paper_citations
    )

    get_paper_references_tool <- argent::tool(
        name = "get_paper_references",
        description = paste(
            "Get papers referenced by a given paper (its bibliography).",
            "Returns a list of referenced papers with their metadata.",
            "Useful for finding foundational work and related research."
        ),
        paper_id = "string* Paper ID (Semantic Scholar ID or DOI)",
        limit = "integer Maximum number of references to return (default: 10, max: 1000)",
        fields = paste(
            "string Comma-separated list of fields to return for each referenced paper.",
            "Default: 'title,authors,year,abstract,citationCount,url,venue,publicationDate'"
        ),
        fn = semantic_scholar_get_paper_references
    )

    # Add tools to server
    server$add_tool(search_papers_tool)
    server$add_tool(get_paper_tool)
    server$add_tool(get_paper_citations_tool)
    server$add_tool(get_paper_references_tool)

    # Start HTTP server
    server$serve_http(host = host, port = port, block = TRUE)
}

# Run server with command line args or defaults
args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args) > 0) as.integer(args[1]) else 8080
semantic_scholar_mcp_server(port = port)
```

> **Note**
>
> The Semantic Scholar MCP server code is available at
> `inst/examples/semantic_scholar_mcp_server.R`.

#### Using the HTTP MCP Server

First, start the server in a separate R session or terminal:

``` r
source(system.file("examples/semantic_scholar_mcp_server.R", package = "argent"))
#> ✔ Starting semantic-scholar MCP server on <http://127.0.0.1:8080>
```

Then connect to it from your main session:

``` r
semantic_scholar_client <- mcp_connect(
    name = "semantic-scholar",
    type = "http",
    url = "http://127.0.0.1:8080"
)

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
papers_df <- jsonlite::fromJSON(papers) |> 
    dplyr::select(paperId, title, year, citationCount)

paper_id <- dplyr::slice_max(papers_df, order_by = citationCount)$paperId

# Getting the details of the first paper
execute_mcp_tool(
    get_mcp_tool(semantic_scholar_tools, "get_paper"),
    arguments = list(
        paper_id = paper_id,
        fields = "title,authors,year,abstract"
    )
)
```

Now use it with an LLM agent:

``` r
gemini <- Google$new()

gemini$chat(
    "Find recent papers (2020+) on Sensory Substitution and Cross-Modal Plasticity and summarize the key innovations",
    "When using the `search_papers` tool, use a limit of 2 by search, to not exceed the rate limit.",
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
> You can use this server with other MCP clients by configuring them to
> connect to `http://127.0.0.1:8080`.
