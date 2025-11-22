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
