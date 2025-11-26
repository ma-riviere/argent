# Semantic Scholar MCP Server - Standalone HTTP Implementation using plumber2
#
# A standalone MCP-compatible HTTP server using plumber2 for the Semantic Scholar API.
# Implements the MCP Streamable HTTP transport (protocol version 2025-03-26).
#
# This is a STANDALONE implementation - it does NOT depend on any MCP package
# (like posit-dev/mcptools). It implements the MCP protocol directly.
#
# FEATURES:
# - Implements MCP Streamable HTTP transport (2025-03-26)
# - JSON responses (batch mode, no SSE streaming)
# - Session management via Mcp-Session-Id header
# - Compatible with MCP clients (Gemini CLI, Claude Code, etc.)
#
# To start the server, run:
#
#   plumber2::api(system.file("examples/semantic_scholar_mcp_server_plumber.R", package = "argent")) |>
#       plumber2::api_run(host = "127.0.0.1", port = 8080, block = TRUE, silent = FALSE, showcase = FALSE)
#
# Then configure your MCP client:
# {
#   "mcpServers": {
#     "semantic-scholar": {
#       "type": "http",
#       "httpUrl": "http://127.0.0.1:8080/mcp"
#     }
#   }
# }

# ==============================================================================
# SETUP
# ==============================================================================

suppressPackageStartupMessages({
    library(plumber2)
    library(httr2)
    library(jsonlite)
})

options(httr2_progress = FALSE)

# Safe header getter - handles NULL, NA, and empty strings
safe_get_header <- function(request, name) {
    val <- tryCatch(request$get_header(name), error = function(e) NULL)
    # Handle NULL & empty
    if (purrr::is_empty(val)) {
        return(NULL)
    }
    # If multiple values, collapse them
    if (length(val) > 1) {
        val <- paste(val, collapse = ", ")
    }
    # Handle NA
    if (is.na(val) || !nzchar(val)) {
        return(NULL)
    }
    val
}

# MCP Protocol version we implement
MCP_PROTOCOL_VERSION <- "2025-03-26"

# Server information
SERVER_INFO <- list(name = "semantic-scholar", version = "1.0.0")

# Session storage - each session tracks initialization state
SESSION_STORE <- new.env(parent = emptyenv())

# ==============================================================================
# SEMANTIC SCHOLAR API FUNCTIONS
# ==============================================================================

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
        return(list(
            .error = TRUE,
            code = 429,
            message = "Rate limit exceeded",
            details = "Too many requests to Semantic Scholar API"
        ))
    }

    if (status == 404) {
        return(NULL)
    }

    if (status != 200) {
        return(list(
            .error = TRUE,
            code = status,
            message = paste0("Semantic Scholar API request failed with status ", status),
            details = paste0("Unexpected HTTP status code from endpoint: ", endpoint)
        ))
    }

    httr2::resp_body_json(resp)
}

default_fields <- "title,authors,year,abstract,citationCount,url,venue,publicationDate"

search_papers <- function(query, limit = 10L, fields = NULL) {
    if (is.null(query) || nchar(query) == 0) {
        return(list(
            .error = TRUE,
            code = -32602,
            message = "Query parameter is required",
            details = "The 'query' parameter cannot be empty"
        ))
    }

    fields_param <- fields %||% default_fields

    params <- list(query = query, limit = as.integer(min(limit, 100)), fields = fields_param)

    result <- semantic_scholar_request("/paper/search", query = params)

    if (isTRUE(result$.error)) {
        return(result)
    }

    if (is.null(result) || length(result$data) == 0) {
        return(list())
    }

    papers <- lapply(result$data, function(paper) {
        authors <- "No authors"
        if (length(paper$authors) > 0) {
            authors <- paste(vapply(paper$authors, function(a) a$name %||% "", character(1)), collapse = "; ")
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

    return(papers)
}

get_paper <- function(paper_id, fields = NULL) {
    if (is.null(paper_id) || nchar(paper_id) == 0) {
        return(list(
            .error = TRUE,
            code = -32602,
            message = "Paper ID is required",
            details = "The 'paper_id' parameter cannot be empty"
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
        return(list(
            .error = TRUE,
            code = -32600,
            message = "Paper not found",
            details = paste0("No paper with ID '", paper_id, "' exists")
        ))
    }

    authors <- "No authors"
    if (length(result$authors) > 0) {
        authors <- paste(vapply(result$authors, function(a) a$name %||% "", character(1)), collapse = "; ")
    }

    list(
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
}

get_paper_citations <- function(paper_id, limit = 10, fields = NULL) {
    if (is.null(paper_id) || nchar(paper_id) == 0) {
        return(list(
            .error = TRUE,
            code = -32602,
            message = "Paper ID is required",
            details = "The 'paper_id' parameter cannot be empty"
        ))
    }

    fields_param <- fields %||% default_fields

    endpoint <- paste0("/paper/", paper_id, "/citations")
    params <- list(limit = as.integer(min(limit, 1000)), fields = fields_param)

    result <- semantic_scholar_request(endpoint, query = params)

    if (isTRUE(result$.error)) {
        return(result)
    }

    if (is.null(result) || length(result$data) == 0) {
        return(list())
    }

    citations <- lapply(result$data, function(citation) {
        paper <- citation$citingPaper

        authors <- "No authors"
        if (length(paper$authors) > 0) {
            authors <- paste(vapply(paper$authors, function(a) a$name %||% "", character(1)), collapse = "; ")
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

    return(citations)
}

get_paper_references <- function(paper_id, limit = 10, fields = NULL) {
    if (is.null(paper_id) || nchar(paper_id) == 0) {
        return(list(
            .error = TRUE,
            code = -32602,
            message = "Paper ID is required",
            details = "The 'paper_id' parameter cannot be empty"
        ))
    }

    fields_param <- fields %||% default_fields

    endpoint <- paste0("/paper/", paper_id, "/references")
    params <- list(limit = as.integer(min(limit, 1000)), fields = fields_param)

    result <- semantic_scholar_request(endpoint, query = params)

    if (isTRUE(result$.error)) {
        return(result)
    }

    if (is.null(result) || length(result$data) == 0) {
        return(list())
    }

    references <- lapply(result$data, function(reference) {
        paper <- reference$citedPaper

        authors <- "No authors"
        if (length(paper$authors) > 0) {
            authors <- paste(vapply(paper$authors, function(a) a$name %||% "", character(1)), collapse = "; ")
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

    return(references)
}

# ==============================================================================
# JSON-RPC 2.0 HELPERS
# ==============================================================================

jsonrpc_success <- function(id, result) {
    list(jsonrpc = "2.0", id = id, result = result)
}

jsonrpc_error <- function(id, code, message, data = NULL) {
    error_obj <- list(code = code, message = message)
    if (!is.null(data)) {
        error_obj$data <- data
    }

    list(jsonrpc = "2.0", id = id, error = error_obj)
}

mcp_tool_result <- function(content, is_error = FALSE) {
    if (is.character(content)) {
        text_content <- as.character(content)[[1]]
    } else if (is.list(content)) {
        text_content <- as.character(jsonlite::toJSON(content, auto_unbox = TRUE, pretty = TRUE))
    } else {
        text_content <- as.character(content)[[1]]
    }

    list(content = list(list(type = "text", text = text_content)), isError = is_error)
}

# ==============================================================================
# MCP TOOL DEFINITIONS
# ==============================================================================

MCP_TOOLS <- list(
    list(
        name = "search_papers",
        description = paste(
            "Search for academic papers by keywords, authors, or topics using the Semantic Scholar API.",
            "Returns a list of papers with metadata including title, authors, year, abstract, citation count, and URL.",
            "IMPORTANT: Use broad search terms for better results. Search is case-insensitive.",
            "Returns up to 100 results per query."
        ),
        inputSchema = list(
            type = "object",
            properties = list(
                query = list(
                    type = "string",
                    description = "Search query (keywords, author names, paper titles, etc.)"
                ),
                limit = list(
                    type = "integer",
                    description = "Maximum number of results to return (default: 10, max: 100)",
                    default = 10L
                ),
                fields = list(type = "string", description = "Comma-separated list of fields to return")
            ),
            required = list("query")
        )
    ),
    list(
        name = "get_paper",
        description = paste(
            "Get detailed metadata for a specific paper by its Semantic Scholar ID or DOI.",
            "Returns comprehensive information including title, authors, abstract, year, citation count, and more."
        ),
        inputSchema = list(
            type = "object",
            properties = list(
                paper_id = list(type = "string", description = "Paper ID (Semantic Scholar ID or DOI)"),
                fields = list(type = "string", description = "Comma-separated list of fields to return")
            ),
            required = list("paper_id")
        )
    ),
    list(
        name = "get_paper_citations",
        description = paste(
            "Get papers that cite a given paper.",
            "Returns a list of citing papers with their metadata."
        ),
        inputSchema = list(
            type = "object",
            properties = list(
                paper_id = list(type = "string", description = "Paper ID (Semantic Scholar ID or DOI)"),
                limit = list(
                    type = "integer",
                    description = "Maximum number of citations to return (default: 10, max: 1000)",
                    default = 10L
                ),
                fields = list(type = "string", description = "Comma-separated list of fields to return")
            ),
            required = list("paper_id")
        )
    ),
    list(
        name = "get_paper_references",
        description = paste(
            "Get papers referenced by a given paper (its bibliography).",
            "Returns a list of referenced papers with their metadata."
        ),
        inputSchema = list(
            type = "object",
            properties = list(
                paper_id = list(type = "string", description = "Paper ID (Semantic Scholar ID or DOI)"),
                limit = list(
                    type = "integer",
                    description = "Maximum number of references to return (default: 10, max: 1000)",
                    default = 10L
                ),
                fields = list(type = "string", description = "Comma-separated list of fields to return")
            ),
            required = list("paper_id")
        )
    )
)

MCP_RESOURCES <- list()
MCP_PROMPTS <- list()

# ==============================================================================
# MCP METHOD HANDLERS
# ==============================================================================

handle_initialize <- function(params) {
    list(
        protocolVersion = MCP_PROTOCOL_VERSION,
        capabilities = list(
            tools = list(listChanged = FALSE),
            resources = list(subscribe = FALSE, listChanged = FALSE),
            prompts = list(listChanged = FALSE)
        ),
        serverInfo = SERVER_INFO
    )
}

handle_tools_list <- function() {
    list(tools = MCP_TOOLS)
}

handle_tools_call <- function(params) {
    tool_name <- params$name
    tool_args <- params$arguments
    if (is.null(tool_args)) {
        tool_args <- list()
    }

    if (is.null(tool_name) || !is.character(tool_name) || nchar(tool_name) == 0) {
        return(list(.jsonrpc_error = TRUE, code = -32602, message = "Missing tool name"))
    }

    available_tools <- vapply(MCP_TOOLS, function(t) t$name, character(1))
    if (!tool_name %in% available_tools) {
        return(list(
            .jsonrpc_error = TRUE,
            code = -32601,
            message = "Method not found",
            data = paste0("Unknown tool: ", tool_name)
        ))
    }

    tool_fn <- tryCatch(get(tool_name), error = function(e) NULL)
    if (is.null(tool_fn) || !is.function(tool_fn)) {
        return(list(
            .jsonrpc_error = TRUE,
            code = -32601,
            message = "Method not found",
            data = paste0("Tool function not found: ", tool_name)
        ))
    }

    tool_result <- tryCatch(do.call(tool_fn, tool_args), error = function(e) {
        list(.error = TRUE, message = "Tool execution failed", details = conditionMessage(e))
    })

    if (isTRUE(tool_result$.error)) {
        error_msg <- tool_result$message %||% "Unknown error"
        if (!is.null(tool_result$details)) {
            error_msg <- paste0(error_msg, ": ", tool_result$details)
        }
        mcp_tool_result(error_msg, is_error = TRUE)
    } else {
        result_json <- jsonlite::toJSON(tool_result, auto_unbox = TRUE, pretty = TRUE)
        mcp_tool_result(result_json, is_error = FALSE)
    }
}

handle_resources_list <- function() {
    list(resources = MCP_RESOURCES)
}

handle_resources_templates_list <- function() {
    list(resourceTemplates = list())
}

handle_resources_read <- function(params) {
    uri <- params$uri
    if (is.null(uri)) {
        return(list(.jsonrpc_error = TRUE, code = -32602, message = "Missing uri parameter"))
    }

    resource <- NULL
    for (r in MCP_RESOURCES) {
        if (r$uri == uri) {
            resource <- r
            break
        }
    }

    if (is.null(resource)) {
        return(list(.jsonrpc_error = TRUE, code = -32002, message = "Resource not found", data = list(uri = uri)))
    }

    list(contents = list(resource))
}

handle_prompts_list <- function() {
    list(prompts = MCP_PROMPTS)
}

handle_prompts_get <- function(params) {
    name <- params$name
    if (is.null(name)) {
        return(list(.jsonrpc_error = TRUE, code = -32602, message = "Missing name parameter"))
    }

    prompt <- NULL
    for (p in MCP_PROMPTS) {
        if (p$name == name) {
            prompt <- p
            break
        }
    }

    if (is.null(prompt)) {
        return(list(
            .jsonrpc_error = TRUE,
            code = -32602,
            message = "Prompt not found",
            data = paste0("Unknown prompt: ", name)
        ))
    }

    list(description = prompt$description, messages = list())
}

# ==============================================================================
# MCP REQUEST PROCESSING
# ==============================================================================

validate_jsonrpc <- function(body) {
    if (is.null(body) || length(body) == 0) {
        return(list(code = -32700, message = "Empty or null request body"))
    }
    if (!is.list(body)) {
        return(list(code = -32700, message = "Request body must be a JSON object"))
    }
    jsonrpc <- body$jsonrpc
    if (is.null(jsonrpc) || jsonrpc != "2.0") {
        return(list(code = -32600, message = "Invalid JSON-RPC version"))
    }
    method <- body$method
    if (is.null(method) || !is.character(method) || nchar(method) == 0) {
        return(list(code = -32600, message = "Missing method in request"))
    }
    NULL
}

log_mcp_request <- function(method, session_id = NULL, error = NULL) {
    timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    session_str <- if (!is.null(session_id)) paste0(" [", session_id, "]") else ""
    error_str <- if (!is.null(error)) paste0(" ERROR: ", error) else ""
    cat(sprintf("[%s]%s MCP: %s%s", timestamp, session_str, method, error_str))
}

process_mcp_request <- function(body, session_id) {
    method <- body$method %||% "unknown"
    id <- body$id
    params <- body$params
    if (is.null(params)) {
        params <- list()
    }

    log_mcp_request(method, session_id)

    result <- tryCatch(
        {
            switch(
                method,
                "initialize" = handle_initialize(params),
                "notifications/initialized" = NULL,
                "ping" = list(),
                "tools/list" = handle_tools_list(),
                "tools/call" = handle_tools_call(params),
                "resources/list" = handle_resources_list(),
                "resources/read" = handle_resources_read(params),
                "resources/templates/list" = handle_resources_templates_list(),
                "prompts/list" = handle_prompts_list(),
                "prompts/get" = handle_prompts_get(params),
                # Default case
                {
                    list(
                        .jsonrpc_error = TRUE,
                        code = -32601,
                        message = "Method not found",
                        data = paste0("Unknown method: ", method)
                    )
                }
            )
        },
        error = function(e) {
            log_mcp_request(method, session_id, error = conditionMessage(e))
            list(.jsonrpc_error = TRUE, code = -32603, message = "Internal error", data = conditionMessage(e))
        }
    )

    list(result = result, method = method, id = id, is_notification = is.null(id))
}

# ==============================================================================
# PLUMBER2 HANDLERS (ANNOTATION-BASED)
# ==============================================================================

#* MCP Streamable HTTP endpoint - POST handler
#*
#* Handles all MCP JSON-RPC requests.
#*
#* @post /mcp
#* @parser json
#* @serializer unboxedJSON
function(request, response, body) {
    tryCatch(
        {
            cat("\n[MCP] POST /mcp request received")
            cat(sprintf("[MCP] Body: %s", jsonlite::toJSON(body, auto_unbox = TRUE)))

            # Check Content-Type
            content_type <- safe_get_header(request, "Content-Type")
            cat(sprintf("[MCP] Content-Type: %s", content_type %||% "(none)"))

            if (is.null(content_type) || !grepl("application/json", content_type, ignore.case = TRUE)) {
                response$status <- 400L
                return(jsonrpc_error(NULL, -32700, "Content-Type must be application/json"))
            }

            # Check Accept header (optional)
            accept <- safe_get_header(request, "Accept")
            if (
                !is.null(accept) &&
                    !grepl("application/json", accept, ignore.case = TRUE) &&
                    !grepl("text/event-stream", accept, ignore.case = TRUE) &&
                    !grepl("\\*/\\*", accept)
            ) {
                response$status <- 406L
                return(jsonrpc_error(NULL, -32600, "Accept header must include application/json"))
            }

            # Validate JSON-RPC structure
            validation_error <- validate_jsonrpc(body)
            if (!is.null(validation_error)) {
                response$status <- 400L
                return(jsonrpc_error(body$id, validation_error$code, validation_error$message))
            }

            method <- body$method
            id <- body$id
            cat(sprintf("[MCP] Method: %s, ID: %s", method, id %||% "(notification)"))

            # Get session ID from header
            session_id <- safe_get_header(request, "Mcp-Session-Id")

            # Handle initialize specially - creates new session
            if (method == "initialize") {
                new_session_id <- paste0("session-", format(Sys.time(), "%Y%m%d%H%M%S"), "-", sample.int(100000, 1))

                SESSION_STORE[[new_session_id]] <- list(created = Sys.time(), initialized = TRUE)

                processed <- process_mcp_request(body, new_session_id)

                response$set_header("Mcp-Session-Id", new_session_id)
                response$status <- 200L

                cat(sprintf("[MCP] Initialize complete, session: %s", new_session_id))

                return(jsonrpc_success(id, processed$result))
            }

            # For non-initialize methods, validate session if provided
            if (!is.null(session_id) && !exists(session_id, envir = SESSION_STORE)) {
                response$status <- 404L
                return(jsonrpc_error(id, -32001, "Session not found", paste0("Invalid session ID: ", session_id)))
            }

            # Process the request
            processed <- process_mcp_request(body, session_id)

            # Handle notifications (no id) - return 202 Accepted
            if (processed$is_notification || is.null(processed$result)) {
                response$status <- 202L
                return(list())
            }

            # Handle errors
            if (isTRUE(processed$result$.jsonrpc_error)) {
                response$status <- 200L
                return(jsonrpc_error(id, processed$result$code, processed$result$message, processed$result$data))
            }

            # Success response
            response$status <- 200L
            result <- jsonrpc_success(id, processed$result)
            cat(sprintf("[MCP] Success response for method: %s", method))
            return(result)
        },
        error = function(e) {
            cat(sprintf("[MCP] ERROR: %s", conditionMessage(e)))
            cat(sprintf("[MCP] Traceback: %s", paste(capture.output(traceback()), collapse = "\n")))
            response$status <- 500L
            return(jsonrpc_error(NULL, -32603, "Internal server error", conditionMessage(e)))
        }
    )
}

#* MCP Streamable HTTP endpoint - GET handler
#*
#* Per MCP spec: return 405 Method Not Allowed if server doesn't support SSE.
#*
#* @get /mcp
#* @serializer unboxedJSON
function(request, response) {
    cat("\n[MCP] GET /mcp request received - returning 405 (SSE not supported)")

    response$status <- 405L
    response$set_header("Allow", "POST")

    list(
        error = "Method Not Allowed",
        message = "This server does not support Server-Sent Events (SSE). Use POST for JSON-RPC requests."
    )
}

#* MCP Streamable HTTP endpoint - DELETE handler
#*
#* Terminates an MCP session.
#*
#* @delete /mcp
#* @serializer unboxedJSON
function(request, response) {
    cat("\n[MCP] DELETE /mcp request received\n")

    session_id <- safe_get_header(request, "Mcp-Session-Id")

    if (is.null(session_id)) {
        response$status <- 400L
        return(list(error = "Bad Request", message = "Missing Mcp-Session-Id header"))
    }

    if (!exists(session_id, envir = SESSION_STORE)) {
        response$status <- 404L
        return(list(error = "Not Found", message = "Session not found"))
    }

    rm(list = session_id, envir = SESSION_STORE)
    cat(sprintf("\n[MCP] Session terminated: %s\n", session_id))

    response$status <- 204L
    list()
}

#* Health check endpoint
#*
#* @get /health
#* @serializer unboxedJSON
function(request, response) {
    list(
        status = "ok",
        server = SERVER_INFO$name,
        version = SERVER_INFO$version,
        protocol_version = MCP_PROTOCOL_VERSION
    )
}

#* Root endpoint - server info
#*
#* @get /
#* @serializer unboxedJSON
function(request, response) {
    list(
        message = "Semantic Scholar MCP Server",
        mcp_endpoint = "/mcp",
        health_endpoint = "/health",
        server = SERVER_INFO$name,
        version = SERVER_INFO$version,
        protocol_version = MCP_PROTOCOL_VERSION
    )
}
