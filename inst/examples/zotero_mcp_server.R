# Zotero MCP Server Tools
#
# Tool definitions for interacting with Zotero's local API.
# Use with: argent::mcp_serve_stdio(file = "zotero_mcp_server.R", name = "zotero")

# ------🔺 HELPER FUNCTIONS ----------------------------------------------------

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

# ------🔺 MCP TOOLS -----------------------------------------------------------

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

# ------🔺 MCP RESOURCES ---------------------------------------------------------
# Resources provide read-only data that can be attached to context.
# Unlike tools (model-controlled), resources are application/user-controlled.

zotero_library_stats <- function() {
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

# ------🔺 MCP PROMPTS -----------------------------------------------------------
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
