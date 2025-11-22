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
get_file_contents_mcp_tool <- get_mcp_tool(github_mcp_tools, "get_file_contents")

execute_mcp_tool(
    tool_def = get_file_contents_mcp_tool,
    arguments = list(
        owner = "ma-riviere",
        repo = "argent",
        path = "R/aaa-utils.R",
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
help_topics_tool <- get_mcp_tool(btw_mcp_tools, "btw_tool_docs_package_help_topics")

execute_mcp_tool(
    tool_def = help_topics_tool,
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

tools <- flat_list(github_mcp_tools, btw_mcp_tools, as_tool(web_search), as_tool(web_fetch))

google$chat(
    "Has 'posit-dev/mcptools' implemented the ability to use HTTP MCP servers with 'ellmer' ?",
    "Use the `get_file_contents` tool to list the contents of GitHub subdirectories, e.g. with path = '/' or 'dir/'.",
    "Use the `btw` tools to explore the help pages and vignettes of the local installation of the `mcptools` package.",
    model = "gemini-2.5-flash",
    tools = tools
)

print(google, show_tools = TRUE)
```

``` default
`posit-dev/mcptools` does not directly implement the ability to use HTTP MCP servers with `ellmer`. When `mcptools` acts as an MCP *client* via `ellmer`, it only supports the local (stdio) protocol. To connect to remote (HTTP) MCP servers, the `mcptools` documentation recommends using `mcp-remote`, an external tool (a local stdio MCP server) that converts remote HTTP servers to `mcptools`-compatible local ones. This allows `ellmer` (using the stdio protocol) to interact with remote HTTP MCP servers through `mcp-remote`.
```

`print(google, show_tools = TRUE)`

``` default
── [ <Google> turns: 10 | Current context: 62853 | Cumulated tokens: 196436 ] ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────


── user [1789 / 2107] ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Has 'posit-dev/mcptools' implemented the ability to use HTTP MCP servers with ellmer ? Use the `get_file_contents` tool to list the contents of GitHub subdirectories, e.g. with path = '/' or 'dir/'. Use the `btw` tools to explore the help pages and vignettes of the local installation of the `mcptools` package.

── System ──

You are a helpful AI assistant. Use your knowledge, the files you have access to, and the tools at your disposal to answer the user's query. You can use your tools multiple times, but use them sparingly. Make parallel tool calls if relevant to the user's query. Answer the user's query as soon as you have the information necessary to answer. Self-reflect and double-check your answer before responding. If you don't know the answer even after using your tools, say 'I don't know'. If you do not have all the information necessary to use a provided tool, use NA for required arguments. Today's date is 2025-11-19

── Tool Definitions ──

• get_file_contents(owner, path, ref, repo, sha): Get the contents of a file or directory from a GitHub repository
• search_code(order, page, perPage, query, sort): Fast and precise code search across ALL GitHub repositories using GitHub's native search engine. Best for finding exact symbols, functions, classes, or specific
  code patterns.
• btw_tool_docs_package_help_topics(package_name, _intent): Get available help topics for an R package.
• btw_tool_docs_help_page(package_name, topic, _intent): Get help page from package.
• btw_tool_docs_available_vignettes(package_name, _intent): List available vignettes for an R package. Vignettes are articles describing key concepts or features of an R package. Returns the listing as a JSON
  array of `vignette` and `title`. To read a vignette, use `btw_tool_docs_vignette(package_name, vignette)`.
• btw_tool_docs_vignette(package_name, vignette, _intent): Get a package vignette in plain text.
• btw_tool_session_check_package_installed(package_name, _intent): Check if a package is installed in the current session.
• btw_tool_session_package_info(packages, dependencies, _intent): Verify that a specific package is installed, or find out which packages are in use in the current session. As a last resort, this function can
  also list all installed packages.
• web_search(query): Search the web for information using Tavily API. Returns a JSON array of search results with titles, URLs, and content snippets. Use this when you need current information, facts, news, or
  any data not in your training data.
• web_fetch(url): Fetch and extract the main text content from a web page as clean markdown. Returns the page content with formatting preserved, stripped of navigation, ads, and boilerplate. Use this to read
  articles, documentation, blog posts, or any web page content.

── assistant [2107 / 2107] ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

── Tool Calls ──

• get_file_contents(repo = "mcptools", owner = "posit-dev", path = "/")

── tool [8379 / 10686] ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

• Result from get_file_contents:

name: get_file_contents
arguments:
  repo: mcptools
  owner: posit-dev
  path: /
result:
  content:
  - type: text
    text: '[{"type":"file","size":210,"name":".Rbuildignore","path":".Rbuildignore","sha":"8fe0bfc60f1d4655aff00d34de75b22f1e6bb7c3","url":"https://api.github.com/repos/posit-dev/mcptools/contents/.Rbuildignore?ref=4f91a58684555e66fd46414f2dc63c46c3802d89","git_url":"https://api.github.com/repos/posit-dev/mcptools/git/blobs/8fe0bfc60f1d4655aff00d34de75b22f1e6bb7c3","html_url":"https://github.com/posit-dev/mcptools/blob/4f91a58684555e66fd46414f2dc63c46c3802d89/.Rbuildignore","download_url":"https://raw.githubusercontent.com/posit-dev/mcptools/4f91a58684555e66fd46414f2dc63c46c3802d89/.Rbuildignore"},{"type":"dir","size":0,"name":".github","path":".github","sha":"c1a387a5ec7f8bf8c6626c7d04d8d00551252def","url":"https://api.github.com/repos/posit-dev/mcptools/contents/.github?ref=4f91a58684555e66fd46414f2dc63c46c3802d89","git_url":"https://api.github.com/repos/posit-dev/mcpto...

── assistant [8579 / 10686] ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

── Tool Calls ──

• search_code(query = "ellmer repo:posit-dev/mcptools")
• search_code(query = "http mcp server repo:posit-dev/mcptools")

── tool [60874 / 72190] ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

• Result from search_code:

name: search_code
arguments:
  query: ellmer repo:posit-dev/mcptools
result:
  content:
  - type: text
    text: '{"total_count":17,"incomplete_results":false,"items":[{"name":"example-ellmer-tools.R","path":"inst/example-ellmer-tools.R","sha":"bfde4b0d734301e24a4908ec1054a5e0c7997b4c","html_url":"https://github.com/posit-dev/mcptools/blob/4f91a58684555e66fd46414f2dc63c46c3802d89/inst/example-ellmer-tools.R","repository":{"id":955571244,"node_id":"R_kgDOOPTcLA","owner":{"login":"posit-dev","id":107264312,"node_id":"O_kgDOBmS5OA","avatar_url":"https://avatars.githubusercontent.com/u/107264312?v=4","html_url":"https://github.com/posit-dev","gravatar_id":"","type":"Organization","site_admin":false,"url":"https://api.github.com/users/posit-dev","events_url":"https://api.github.com/users/posit-dev/events{/privacy}","following_url":"https://api.github.com/users/posit-dev/following{/other_user}","followers_url":"https://api.github.com/users/posit-dev/followers","gists_url":"https://api.githu...

• Result from search_code:

name: search_code
arguments:
  query: http mcp server repo:posit-dev/mcptools
result:
  content:
  - type: text
    text: '{"total_count":16,"incomplete_results":false,"items":[{"name":"server.R","path":"R/server.R","sha":"c554b70c68889735629019c4b8d14d9a83f05a4b","html_url":"https://github.com/posit-dev/mcptools/blob/4f91a58684555e66fd46414f2dc63c46c3802d89/R/server.R","repository":{"id":955571244,"node_id":"R_kgDOOPTcLA","owner":{"login":"posit-dev","id":107264312,"node_id":"O_kgDOBmS5OA","avatar_url":"https://avatars.githubusercontent.com/u/107264312?v=4","html_url":"https://github.com/posit-dev","gravatar_id":"","type":"Organization","site_admin":false,"url":"https://api.github.com/users/posit-dev","events_url":"https://api.github.com/users/posit-dev/events{/privacy}","following_url":"https://api.github.com/users/posit-dev/following{/other_user}","followers_url":"https://api.github.com/users/posit-dev/followers","gists_url":"https://api.github.com/users/posit-dev/gists{/gist_id}",...

── assistant [61504 / 72190] ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

── Tool Calls ──

• btw_tool_docs_package_help_topics(package_name = "mcptools", _intent = "Check for relevant help topics in mcptools documentation regarding ellmer and HTTP MCP servers")

── tool [61172 / 133583] ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

• Result from btw_tool_docs_package_help_topics:

name: btw_tool_docs_package_help_topics
arguments:
  package_name: mcptools
  _intent: Check for relevant help topics in mcptools documentation regarding ellmer
    and HTTP MCP servers
result:
  content:
  - type: text
    text: |-
      [
        {"topic_id":"client","title":"R as a client: Define ellmer tools from MCP servers","aliases":["client","mcp_tools","mcp_client"]},
        {"topic_id":"mcptools-package","title":"mcptools: Model Context Protocol Servers and Clients","aliases":["mcptools","mcptools-package"]},
        {"topic_id":"server","title":"R as a server: Configure R-based tools with LLM-enabled apps","aliases":["server","mcp_server","mcp_session","server"]}
      ]
  isError: no


── assistant [61393 / 133583] ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

── Tool Calls ──

• btw_tool_docs_help_page(package_name = "mcptools", topic = "client", _intent = "Get details on how ellmer tools are defined from MCP servers")

── tool [62486 / 196436] ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

• Result from btw_tool_docs_help_page:

name: btw_tool_docs_help_page
arguments:
  package_name: mcptools
  topic: client
  _intent: Get details on how ellmer tools are defined from MCP servers
result:
  content:
  - type: text
    text: |-
      ## `help(package = "mcptools", "client")`

      ### R as a client: Define ellmer tools from MCP servers

      #### Description

      These functions implement R as an MCP *client*, so that ellmer chats can
      register functionality from third-party MCP servers such as those listed
      here: <https://github.com/modelcontextprotocol/servers>.

      `mcp_tools()` fetches tools from MCP servers configured in the mcptools
      server config file and converts them to a list of tools compatible with
      the `⁠$set_tools()⁠` method of ellmer::Chat objects.

      #### Arguments

      |  |  |
      |----|----|
      | `config` | A single string indicating the path to the mcptools MCP servers configuration f...

── assistant [62853 / 196436] ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

`posit-dev/mcptools` does not directly implement the ability to use HTTP MCP servers with `ellmer`. When `mcptools` acts as an MCP *client* via `ellmer`, it only supports the local (stdio) protocol. To connect to remote (HTTP) MCP servers, the `mcptools` documentation recommends using `mcp-remote`, an external tool (a local stdio MCP server) that converts remote HTTP servers to `mcptools`-compatible local ones. This allows `ellmer` (using the stdio protocol) to interact with remote HTTP MCP servers through `mcp-remote`.
```

## Advanced Usage

### Creating a Custom MCP Server

Let’s create our own stdio MCP server for interacting with Zotero’s
local API. This server will be usable both from argent and from other
MCP clients, like Claude Code.

#### Prerequisites

- Zotero 7+ must be running
- Enable “Allow other applications on this computer to communicate with
  Zotero” in Preferences \> Advanced

#### Server Implementation

Zotero MCP Server Implementation (long)

``` r
# Zotero MCP Server
#
# A stdio MCP server for interacting with Zotero's local API.
# This server can be used with argent or other MCP clients like Claude Code.

# ------🔺 SETUP ---------------------------------------------------------------

# Check and install required packages
required_packages <- c("httr2", "cli", "jsonlite", "argent")
missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]

if (length(missing_packages) > 0) {
    message("Installing missing packages: ", paste(missing_packages, collapse = ", "))
    install.packages(missing_packages, repos = "https://cloud.r-project.org", quiet = TRUE)
}

suppressPackageStartupMessages({
    library(httr2)
    library(cli)
    library(jsonlite)
    library(argent)
})

# Disable httr2 progress bars to avoid stderr noise
options(httr2_progress = FALSE)

# ------🔺 TOOLS ---------------------------------------------------------------

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
            cli::cli_abort(c(
                "Zotero local API request failed (501 Not Implemented)",
                "x" = "API version mismatch or local API not enabled",
                "i" = "Check Preferences > Advanced > 'Allow other applications on this computer to communicate with Zotero'"
            ))
        }
        cli::cli_abort("Zotero API request failed with status {status}")
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

    if (length(items) == 0) {
        return("No items found matching the search criteria.")
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

    return(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE))
}

zotero_get_item <- function(item_key) {
    item <- zotero_request(paste0("/items/", item_key))
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

    jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE)
}

zotero_get_collections <- function() {
    collections <- zotero_request("/collections")

    if (purrr::is_empty(collections)) {
        return("No collections found.")
    }

    result <- lapply(collections, function(col) {
        data <- col$data
        list(
            key = data$key,
            name = data$name,
            parentCollection = data$parentCollection %||% NA
        )
    })

    jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE)
}

zotero_get_fulltext <- function(item_key) {
    tryCatch({
        item <- zotero_request(paste0("/items/", item_key))

        attachment_key <- item_key
        link_mode <- NULL
        if (item$data$itemType != "attachment") {
            children <- zotero_request(paste0("/items/", item_key, "/children"))

            pdf_attachments <- purrr::keep(
                children,
                function(child) {
                    child$data$itemType == "attachment" &&
                        grepl("pdf", child$data$contentType %||% "", ignore.case = TRUE)
                }
            )

            if (purrr::is_empty(pdf_attachments)) {
                return("No PDF attachments found for this item.")
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

        if (is.null(fulltext)) {
            linked_msg <- if (!is.null(link_mode) && link_mode == "linked_file") {
                paste0(
                    "\n",
                    "Note: This is a linked file. Zotero stores fulltext cache in a separate ",
                    "storage directory, not alongside the original PDF."
                )
            } else {
                ""
            }

            return(paste0(
                "PDF attachment exists but fulltext has not been indexed yet.\n",
                "\n",
                "Indexing happens automatically:\n",
                "- After 30+ seconds of computer idle time (background processor)\n",
                "- Or manually: Right-click attachment in Zotero > Reindex Item\n",
                "\n",
                "Once indexed, fulltext will be cached and available via this endpoint.",
                linked_msg
            ))
        }

        if (is.null(fulltext$content) || fulltext$content == "") {
            return("Full-text cache exists but is empty. The PDF may be image-based without searchable text.")
        }

        return(fulltext$content)
    },
    error = function(e) {
        return(paste(
            "Full-text extraction failed with error:",
            conditionMessage(e),
            "\nPossible reasons:",
            "- Item key not found",
            "- PDF is image-based without searchable text",
            "- File is corrupted or inaccessible",
            sep = "\n"
        ))
    })
}

zotero_list_fulltext_items <- function(since = 0) {
    result <- zotero_request("/fulltext", query = list(since = as.integer(since)))

    if (purrr::is_empty(result)) {
        return("No items with fulltext found.")
    }

    items <- lapply(names(result), function(key) {
        list(key = key, version = result[[key]])
    })

    return(jsonlite::toJSON(items, auto_unbox = TRUE, pretty = TRUE))
}

zotero_get_collection_items <- function(collection_key, limit = 100) {
    endpoint <- paste0("/collections/", collection_key, "/items")
    params <- list(limit = as.integer(limit))

    items <- zotero_request(endpoint, query = params)

    if (purrr::is_empty(items)) {
        return("No items found in this collection.")
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

    return(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE))
}

zotero_get_top_items <- function(limit = 100) {
    params <- list(limit = as.integer(limit))
    items <- zotero_request("/items/top", query = params)

    if (purrr::is_empty(items)) {
        return("No top-level items found.")
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

    return(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE))
}

zotero_list_searches <- function() {
    searches <- zotero_request("/searches")

    if (purrr::is_empty(searches)) {
        return("No saved searches found.")
    }

    result <- lapply(searches, function(search) {
        data <- search$data
        list(
            key = data$key,
            name = data$name,
            conditions = data$conditions
        )
    })

    return(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE))
}

zotero_execute_search <- function(search_key, limit = 100) {
    endpoint <- paste0("/searches/", search_key, "/items")
    params <- list(limit = as.integer(limit))

    items <- zotero_request(endpoint, query = params)

    if (purrr::is_empty(items)) {
        return("No items found matching this saved search.")
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

    return(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE))
}

zotero_get_item_types <- function() {
    item_types <- zotero_request("/itemTypes")

    if (purrr::is_empty(item_types)) {
        return("No item types found.")
    }

    return(jsonlite::toJSON(item_types, auto_unbox = TRUE, pretty = TRUE))
}

zotero_get_trashed_items <- function(limit = 100) {
    params <- list(limit = as.integer(limit))
    items <- zotero_request("/items/trash", query = params)

    if (purrr::is_empty(items)) {
        return("No items in trash.")
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
            type = data$itemType,
            deleted = data$deleted %||% FALSE
        ))
    })

    return(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE))
}


# MCP server function
zotero_mcp_server <- function() {
    server <- argent:::McpServer$new(
        name = "Zotero",
        version = "1.0.0"
    )

    # Define tool definitions using argent::tool()
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
        limit = "integer Maximum number of items to return (1-100, default: 25)"
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
        )
    )

    get_collections_tool <- argent::tool(
        name = "zotero_get_collections",
        description = paste(
            "List all collections (folders) in your Zotero library.",
            "Collections organize items hierarchically.",
            "Returns collection keys, names, and parent-child relationships.",
            "Use collection keys with other endpoints to filter items by collection."
        )
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
        )
    )

    list_fulltext_items_tool <- argent::tool(
        name = "zotero_list_fulltext_items",
        description = paste(
            "List all items in the library that have indexed fulltext content.",
            "Returns item keys and their fulltext version numbers.",
            "Useful for discovering which items have searchable PDF content before retrieving it.",
            "Combine with zotero_get_fulltext to access the actual content."
        ),
        since = "integer Library version to filter from (default: 0 for all items)"
    )

    get_collection_items_tool <- argent::tool(
        name = "zotero_get_collection_items",
        description = paste(
            "Get all items within a specific collection (folder).",
            "Returns metadata for items including title, authors, year, and type.",
            "Use zotero_get_collections to get collection keys first."
        ),
        collection_key = "string* The collection key obtained from zotero_get_collections",
        limit = "integer Maximum number of items to return (1-100, default: 100)"
    )

    get_top_items_tool <- argent::tool(
        name = "zotero_get_top_items",
        description = paste(
            "Get only top-level items in the library.",
            "Excludes child items like attachments and notes.",
            "Returns metadata including title, authors, year, and type.",
            "Useful for getting a clean list of main references without clutter."
        ),
        limit = "integer Maximum number of items to return (1-100, default: 100)"
    )

    list_searches_tool <- argent::tool(
        name = "zotero_list_searches",
        description = paste(
            "List all saved searches in the library.",
            "Saved searches are pre-configured queries that can be executed.",
            "Returns search keys, names, and their conditions.",
            "Use the search key with zotero_execute_search to run the search."
        )
    )

    execute_search_tool <- argent::tool(
        name = "zotero_execute_search",
        description = paste(
            "Execute a saved search and return matching items.",
            "Saved searches are pre-configured queries created in Zotero.",
            "Returns item metadata including title, authors, year, and type.",
            "Use zotero_list_searches to discover available saved searches."
        ),
        search_key = "string* The search key obtained from zotero_list_searches",
        limit = "integer Maximum number of items to return (1-100, default: 100)"
    )

    get_item_types_tool <- argent::tool(
        name = "zotero_get_item_types",
        description = paste(
            "Get a list of all valid item types supported by Zotero.",
            "Item types include: book, journalArticle, conferencePaper, thesis, etc.",
            "Useful for understanding what types can be used with the item_type filter",
            "in zotero_search_items and other endpoints."
        )
    )

    get_trashed_items_tool <- argent::tool(
        name = "zotero_get_trashed_items",
        description = paste(
            "Get items that are in the trash.",
            "Returns metadata including title, authors, year, type, and deletion status.",
            "Useful for recovering or reviewing deleted items."
        ),
        limit = "integer Maximum number of items to return (1-100, default: 100)"
    )

    # Add tools to server
    server$add_tool(tool_def = search_items_tool, handler = zotero_search_items)
    server$add_tool(tool_def = get_item_tool, handler = zotero_get_item)
    server$add_tool(tool_def = get_collections_tool, handler = zotero_get_collections)
    server$add_tool(tool_def = get_fulltext_tool, handler = zotero_get_fulltext)
    server$add_tool(tool_def = list_fulltext_items_tool, handler = zotero_list_fulltext_items)
    server$add_tool(tool_def = get_collection_items_tool, handler = zotero_get_collection_items)
    server$add_tool(tool_def = get_top_items_tool, handler = zotero_get_top_items)
    server$add_tool(tool_def = list_searches_tool, handler = zotero_list_searches)
    server$add_tool(tool_def = execute_search_tool, handler = zotero_execute_search)
    server$add_tool(tool_def = get_item_types_tool, handler = zotero_get_item_types)
    server$add_tool(tool_def = get_trashed_items_tool, handler = zotero_get_trashed_items)

    server$serve_stdio()
}

zotero_mcp_server()
```

> **Note**
>
> The complete Zotero MCP server code is available in the package at
> `inst/examples/zotero_mcp_server.R`.

### Using the Server

#### Use with argent

``` r
zotero_client <- mcp_connect(
    name = "zotero",
    type = "stdio",
    command = "Rscript",
    args = system.file("examples/zotero_mcp_server.R", package = "argent")
)

zotero_tools <- mcp_tools(zotero_client)
```

``` r
zotero_get_collections_tool <- get_mcp_tool(zotero_tools, "zotero_get_collections")

execute_mcp_tool(zotero_get_collections_tool, arguments = list())
```

``` r
openrouter <- OpenRouter$new()

openrouter$chat(
    "Can you summarize Noe's view on sensory substitution and how the brain differentiates sensory inputs ?",
    model = "google/gemini-2.5-flash-lite-preview-09-2025",
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
