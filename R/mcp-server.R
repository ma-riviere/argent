#' Create a structured error response for MCP tools
#'
#' @description
#' Returns a structured error object that MCP servers can format appropriately
#' for LLM agents. This provides actionable feedback instead of generic errors.
#'
#' @param message Character. Primary error message
#' @param type Character. Error category: "not_found", "validation", "api_error",
#'   "not_ready", or "unsupported"
#' @param details Character. Additional context about the error
#' @param suggestion Character. Actionable suggestion for fixing the error
#'
#' @return A list with class "mcp_error" containing structured error information
#' @keywords internal
mcp_error <- function(message, type = "error", details = NULL, suggestion = NULL) {
    structure(
        list(.error = TRUE, type = type, message = message, details = details, suggestion = suggestion),
        class = "mcp_error"
    )
}

#' Create a structured success response for MCP tools
#'
#' @description
#' Returns a structured success object that can include warnings or additional
#' context for LLM agents.
#'
#' @param data The result data (character, list, or other R object)
#' @param warning Character. Optional warning message to include with success
#'
#' @return A list with class "mcp_success" containing the data and optional warning
#' @keywords internal
mcp_success <- function(data, warning = NULL) {
    structure(list(.success = TRUE, data = data, warning = warning), class = "mcp_success")
}

#' MCP Server Implementation
#'
#' @description
#' An R6 class to create and run Model Context Protocol (MCP) servers.
#' Use this to expose R functions as tools to LLMs via the MCP protocol.
#'
#' @keywords internal
McpServer <- R6::R6Class(
    "McpServer",
    public = list(
        #' @field name Server name
        name = NULL,
        #' @field version Server version
        version = NULL,
        #' @field tools List of registered tools
        tools = NULL,
        #' @field resources List of registered resources
        resources = NULL,
        #' @field prompts List of registered prompts
        prompts = NULL,

        #' @description
        #' Initialize a new MCP server
        #' @param name Character string. Server name.
        #' @param version Character string. Server version.
        initialize = function(name, version) {
            self$name <- name
            self$version <- version
            self$tools <- list()
            self$resources <- list()
            self$prompts <- list()
            private$session_store <- new.env(parent = emptyenv())
        },

        #' @description
        #' Add a tool to the server
        #' @param tool_def List definition of the tool (name, description, args_schema)
        #' @param handler Function to execute when the tool is called. Should have named
        #'   parameters matching the tool's arguments, with defaults for optional parameters.
        #'   Returns a result (character, list, or other). If NULL (default), uses the
        #'   `.fn` field from `tool_def` if available.
        add_tool = function(tool_def, handler = NULL) {
            # Use .fn from tool_def if handler not provided
            if (is.null(handler)) {
                if (!is.null(tool_def$.fn)) {
                    handler <- tool_def$.fn
                } else {
                    cli::cli_abort(
                        "{.arg handler} must be provided or {.arg tool_def} must contain a {.field .fn} field"
                    )
                }
            }

            if (!is.function(handler)) {
                cli::cli_abort("{.arg handler} must be a function")
            }

            # Store tool definition and handler
            tool_name <- tool_def$name
            self$tools[[tool_name]] <- list(definition = tool_def, handler = handler)
            invisible(self)
        },

        #' @description
        #' Add a resource to the server
        #' @param resource_def List definition of the resource (uri, name, description, mimeType)
        #' @param handler Function to execute when the resource is read. Should take a uri and return content (text or blob).
        add_resource = function(resource_def, handler) {
            if (!is.function(handler)) {
                cli::cli_abort("{.arg handler} must be a function")
            }

            # Store resource definition and handler
            resource_uri <- resource_def$uri
            self$resources[[resource_uri]] <- list(definition = resource_def, handler = handler)
            invisible(self)
        },

        #' @description
        #' Add a prompt to the server
        #' @param prompt_def List definition of the prompt (name, description, arguments)
        #' @param handler Function to execute when the prompt is requested. Should have named
        #'   parameters matching the prompt's arguments, with defaults for optional parameters.
        #'   Returns a list with 'messages' field (and optional 'description' field).
        add_prompt = function(prompt_def, handler) {
            if (!is.function(handler)) {
                cli::cli_abort("{.arg handler} must be a function")
            }

            # Store prompt definition and handler
            prompt_name <- prompt_def$name
            self$prompts[[prompt_name]] <- list(definition = prompt_def, handler = handler)
            invisible(self)
        },

        #' @description
        #' Serve the MCP protocol over stdio
        #' This method blocks and listens for JSON-RPC requests on stdin.
        serve_stdio = function() {
            # Open stdin as a file connection to ensure it stays open
            con <- file("stdin", "open" = "r")
            on.exit(close(con))

            # Main loop - wrapped in tryCatch to allow Ctrl+C interruption
            tryCatch(
                {
                    while (TRUE) {
                        line <- readLines(con, n = 1, warn = FALSE)
                        if (length(line) == 0) {
                            break
                        }
                        if (nchar(line) == 0) {
                            next
                        }

                        private$process_and_respond_stdio(line)
                    }
                },
                interrupt = function(e) {
                    message("\nServer interrupted by user")
                }
            )
        },

        #' @description
        #' Serve the MCP protocol over HTTP
        #' This method starts an HTTP server and blocks, listening for JSON-RPC requests on POST /.
        #' @param host Character. Host to bind to (default: "127.0.0.1")
        #' @param port Integer. Port to listen on (default: 8080)
        #' @param block Logical. Whether to block the console (default: TRUE)
        #' @param silent Logical. Whether to suppress startup messages (default: FALSE)
        serve_http = function(host = "127.0.0.1", port = 8080, block = TRUE, silent = FALSE) {
            # Main request handler
            app <- list(call = function(req) {
                if (req$REQUEST_METHOD == "POST") {
                    private$handle_http_post(req)
                } else if (req$REQUEST_METHOD == "OPTIONS") {
                    private$handle_http_options(req)
                } else if (req$REQUEST_METHOD == "GET") {
                    private$handle_http_get(req)
                } else if (req$REQUEST_METHOD == "DELETE") {
                    private$handle_http_delete(req)
                } else {
                    list(
                        status = 405L,
                        headers = private$add_mcp_headers(list("Content-Type" = "text/plain")),
                        body = "Method Not Allowed"
                    )
                }
            })

            # Show startup message
            if (!silent) {
                cli::cli_alert_success("Starting {.field {self$name}} MCP server on {.url http://{host}:{port}}")
            }

            # Start server
            server <- httpuv::startServer(host = host, port = port, app = app)

            if (block) {
                on.exit(httpuv::stopServer(server))
                httpuv::service(Inf)
            } else {
                invisible(server)
            }
        }
    ),
    private = list(
        # Session storage environment
        session_store = NULL,

        # Format a JSON-RPC response
        # @param id Request ID (NULL for notifications)
        # @param result Result object (for success responses)
        # @param error Error object (for error responses)
        # @return Formatted JSON-RPC response list (or NULL for notifications)
        format_jsonrpc_response = function(id, result = NULL, error = NULL) {
            if (!is.null(id)) {
                resp <- list(jsonrpc = "2.0", id = id)
                if (!is.null(error)) {
                    resp$error <- if (is.list(error) && !is.null(error$code)) {
                        error
                    } else {
                        list(code = -32603, message = as.character(error))
                    }
                } else {
                    resp$result <- result
                }
                return(resp)
            }
            return(NULL)
        },

        # Add MCP protocol headers to HTTP response
        # @param headers_list Existing headers list
        # @return Headers list with MCP-Protocol-Version added
        add_mcp_headers = function(headers_list) {
            headers_list[["MCP-Protocol-Version"]] <- "2025-06-18"
            headers_list
        },

        # Process stdio request and send response
        # @param line JSON string from stdin
        process_and_respond_stdio = function(line) {
            req <- purrr::possibly(jsonlite::fromJSON, otherwise = NULL)(line)

            if (is.null(req) || is.null(req$jsonrpc)) {
                return(invisible(NULL))
            }

            result <- tryCatch(private$process_jsonrpc_method(req$method, req$params), error = function(e) {
                list(.error = TRUE, message = e$message)
            })

            if (!is.null(req$id)) {
                resp <- if (isTRUE(result$.error)) {
                    private$format_jsonrpc_response(req$id, error = result)
                } else {
                    private$format_jsonrpc_response(req$id, result = result)
                }

                if (!is.null(resp)) {
                    cat(jsonlite::toJSON(resp, auto_unbox = TRUE), "\n")
                    flush(stdout())
                }
            }
        },

        # Handle HTTP POST request
        # @param req HTTP request object
        # @return HTTP response list
        handle_http_post = function(req) {
            if (!private$validate_origin(req)) {
                return(list(
                    status = 403L,
                    headers = private$add_mcp_headers(list("Content-Type" = "application/json")),
                    body = '{"error":"Forbidden origin"}'
                ))
            }

            body_text <- rawToChar(req$rook.input$read())
            json_req <- purrr::possibly(jsonlite::fromJSON)(body_text, simplifyVector = FALSE)

            if (is.null(json_req) || is.null(json_req$jsonrpc)) {
                return(list(
                    status = 400L,
                    headers = private$add_mcp_headers(list("Content-Type" = "application/json")),
                    body = jsonlite::toJSON(
                        list(jsonrpc = "2.0", error = list(code = -32600, message = "Invalid Request"), id = NULL),
                        auto_unbox = TRUE
                    )
                ))
            }

            method <- json_req$method
            session_id <- req$HTTP_MCP_SESSION_ID

            if (method == "initialize") {
                new_session_id <- uuid::UUIDgenerate()

                private$session_store[[new_session_id]] <- list(created = Sys.time(), initialized = TRUE)

                result <- tryCatch(private$process_jsonrpc_method(method, json_req$params), error = function(e) {
                    list(.error = TRUE, message = e$message)
                })

                resp <- if (isTRUE(result$.error)) {
                    private$format_jsonrpc_response(json_req$id, error = result)
                } else {
                    private$format_jsonrpc_response(json_req$id, result = result)
                }

                return(list(
                    status = 200L,
                    headers = private$add_mcp_headers(list(
                        "Content-Type" = "application/json",
                        "Access-Control-Allow-Origin" = "*",
                        "Mcp-Session-Id" = new_session_id
                    )),
                    body = jsonlite::toJSON(resp, auto_unbox = TRUE)
                ))
            }

            if (!is.null(session_id) && !exists(session_id, envir = private$session_store)) {
                return(list(
                    status = 404L,
                    headers = private$add_mcp_headers(list("Content-Type" = "application/json")),
                    body = jsonlite::toJSON(
                        list(
                            jsonrpc = "2.0",
                            error = list(
                                code = -32001,
                                message = "Session not found",
                                data = paste0("Invalid session ID: ", session_id)
                            ),
                            id = json_req$id
                        ),
                        auto_unbox = TRUE
                    )
                ))
            }

            result <- tryCatch(private$process_jsonrpc_method(method, json_req$params), error = function(e) {
                list(.error = TRUE, message = e$message)
            })

            resp <- if (isTRUE(result$.error)) {
                private$format_jsonrpc_response(json_req$id, error = result)
            } else {
                private$format_jsonrpc_response(json_req$id, result = result)
            }

            if (!is.null(resp)) {
                list(
                    status = 200L,
                    headers = private$add_mcp_headers(list(
                        "Content-Type" = "application/json",
                        "Access-Control-Allow-Origin" = "*"
                    )),
                    body = jsonlite::toJSON(resp, auto_unbox = TRUE)
                )
            } else {
                list(status = 202L, headers = private$add_mcp_headers(list()), body = "")
            }
        },

        # Handle HTTP OPTIONS request (CORS preflight)
        # @param req HTTP request object
        # @return HTTP response list
        handle_http_options = function(req) {
            list(
                status = 200L,
                headers = list(
                    "Access-Control-Allow-Origin" = "*",
                    "Access-Control-Allow-Methods" = "POST, DELETE, OPTIONS",
                    "Access-Control-Allow-Headers" = "Content-Type, Mcp-Session-Id"
                ),
                body = ""
            )
        },

        # Handle HTTP GET request
        # @param req HTTP request object
        # @return HTTP response list (405 - SSE not supported)
        handle_http_get = function(req) {
            list(
                status = 405L,
                headers = private$add_mcp_headers(list("Content-Type" = "application/json", "Allow" = "POST, DELETE")),
                body = jsonlite::toJSON(
                    list(
                        error = "Method Not Allowed",
                        message = "This server does not support Server-Sent Events (SSE). Use POST for requests."
                    ),
                    auto_unbox = TRUE
                )
            )
        },

        # Handle HTTP DELETE request (session termination)
        # @param req HTTP request object
        # @return HTTP response list
        handle_http_delete = function(req) {
            session_id <- req$HTTP_MCP_SESSION_ID

            if (is.null(session_id)) {
                return(list(
                    status = 400L,
                    headers = private$add_mcp_headers(list("Content-Type" = "application/json")),
                    body = jsonlite::toJSON(
                        list(error = "Bad Request", message = "Missing Mcp-Session-Id header"),
                        auto_unbox = TRUE
                    )
                ))
            }

            if (!exists(session_id, envir = private$session_store)) {
                return(list(
                    status = 404L,
                    headers = private$add_mcp_headers(list("Content-Type" = "application/json")),
                    body = jsonlite::toJSON(list(error = "Not Found", message = "Session not found"), auto_unbox = TRUE)
                ))
            }

            rm(list = session_id, envir = private$session_store)
            list(status = 204L, headers = private$add_mcp_headers(list()), body = "")
        },

        # Validate HTTP request origin. We only allow local requests for now.
        # @param req HTTP request object
        # @return Logical indicating if origin is allowed
        validate_origin = function(req) {
            origin <- req$HTTP_ORIGIN
            if (!is.null(origin)) {
                allowed <- c("http://localhost", "http://127.0.0.1", "https://localhost", "https://127.0.0.1")
                if (!any(startsWith(origin, allowed))) {
                    return(FALSE)
                }
            }
            return(TRUE)
        },

        # Process a JSON-RPC method call
        # @param method Character. The JSON-RPC method name
        # @param params List. The method parameters (NULL for methods without params)
        # @return The result object (or NULL for notifications)
        process_jsonrpc_method = function(method, params = NULL) {
            if (method == "initialize") {
                return(list(
                    protocolVersion = "2025-06-18",
                    serverInfo = list(name = self$name, version = self$version),
                    capabilities = list(
                        tools = list(listChanged = FALSE),
                        resources = list(subscribe = FALSE, listChanged = FALSE),
                        prompts = list(listChanged = FALSE)
                    )
                ))
            }

            if (method == "notifications/initialized") {
                return(NULL)
            }

            if (method == "tools/list") {
                mcp_tools <- lapply(self$tools, function(t) {
                    def <- t$definition
                    list(name = def$name, description = def$description, inputSchema = def$args_schema)
                })
                return(list(tools = unname(mcp_tools)))
            }

            if (method == "tools/call") {
                return(private$handle_tool_call(params$name, params$arguments))
            }

            if (method == "resources/list") {
                mcp_resources <- lapply(self$resources, function(r) {
                    def <- r$definition
                    list(uri = def$uri, name = def$name, description = def$description, mimeType = def$mimeType)
                })
                return(list(resources = unname(mcp_resources)))
            }

            if (method == "resources/read") {
                return(private$handle_resource_read(params$uri))
            }

            if (method == "prompts/list") {
                mcp_prompts <- lapply(self$prompts, function(p) {
                    def <- p$definition
                    list(name = def$name, description = def$description, arguments = def$arguments)
                })
                return(list(prompts = unname(mcp_prompts)))
            }

            if (method == "prompts/get") {
                return(private$handle_prompt_get(params$name, params$arguments))
            }

            cli::cli_abort("Method not found: {method}")
        },

        # Handle tools/call method
        # @param tool_name Character. Name of the tool to call
        # @param args List. Arguments to pass to the tool
        # @return MCP-formatted tool result
        handle_tool_call = function(tool_name, args) {
            if (is.null(self$tools[[tool_name]])) {
                cli::cli_abort("Tool not found: {tool_name}")
            }

            handler <- self$tools[[tool_name]]$handler

            # Execute tool with improved error handling
            result <- tryCatch(rlang::exec(handler, !!!args), error = function(e) {
                # Check if it's a missing argument error
                if (grepl("argument.*missing|missing.*argument", e$message, ignore.case = TRUE)) {
                    mcp_error(
                        message = paste0("Missing required parameter for tool '", tool_name, "'"),
                        type = "validation",
                        details = e$message,
                        suggestion = "Check the tool's required parameters and provide all necessary arguments"
                    )
                } else if (grepl("unused argument", e$message, ignore.case = TRUE)) {
                    mcp_error(
                        message = paste0("Invalid parameter for tool '", tool_name, "'"),
                        type = "validation",
                        details = e$message,
                        suggestion = "Check the tool's parameter names and remove any invalid arguments"
                    )
                } else {
                    mcp_error(
                        message = paste0("Tool '", tool_name, "' execution failed"),
                        type = "error",
                        details = e$message,
                        suggestion = "Check the tool implementation and input parameters"
                    )
                }
            })

            # Handle structured error responses
            if (inherits(result, "mcp_error")) {
                error_parts <- paste0("Error (", result$type, "): ", result$message)
                if (!is.null(result$details)) {
                    error_parts <- c(error_parts, paste0("Details: ", result$details))
                }
                if (!is.null(result$suggestion)) {
                    error_parts <- c(error_parts, paste0("Suggestion: ", result$suggestion))
                }
                content_text <- paste(error_parts, collapse = "\n")
                return(list(content = list(list(type = "text", text = content_text)), isError = TRUE))
            }

            # Handle structured success responses
            if (inherits(result, "mcp_success")) {
                if (is.character(result$data) && length(result$data) == 1) {
                    data_text <- result$data
                } else {
                    data_text <- jsonlite::toJSON(result$data, auto_unbox = TRUE, pretty = TRUE)
                }
                if (!is.null(result$warning)) {
                    content_text <- paste0("Warning: ", result$warning, "\n\n", data_text)
                } else {
                    content_text <- data_text
                }
                return(list(content = list(list(type = "text", text = content_text)), isError = FALSE))
            }

            # Handle regular results
            if (is.character(result) && length(result) == 1) {
                content_text <- result
            } else {
                content_text <- jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE)
            }
            return(list(content = list(list(type = "text", text = content_text)), isError = FALSE))
        },

        # Handle resources/read method
        # @param uri Character. URI of the resource to read
        # @return MCP-formatted resource content
        handle_resource_read = function(uri) {
            if (is.null(self$resources[[uri]])) {
                cli::cli_abort("Resource not found: {uri}")
            }

            handler <- self$resources[[uri]]$handler
            result <- handler(uri)

            # Format content based on result type
            content_item <- if (is.character(result) && length(result) == 1) {
                list(uri = uri, mimeType = self$resources[[uri]]$definition$mimeType %||% "text/plain", text = result)
            } else if (is.list(result) && !is.null(result$text)) {
                list(
                    uri = uri,
                    mimeType = result$mimeType %||% self$resources[[uri]]$definition$mimeType %||% "text/plain",
                    text = result$text
                )
            } else if (is.list(result) && !is.null(result$blob)) {
                list(
                    uri = uri,
                    mimeType = result$mimeType %||%
                        self$resources[[uri]]$definition$mimeType %||%
                        "application/octet-stream",
                    blob = result$blob
                )
            } else {
                list(
                    uri = uri,
                    mimeType = "text/plain",
                    text = jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE)
                )
            }

            return(list(contents = list(content_item)))
        },

        # Handle prompts/get method
        # @param prompt_name Character. Name of the prompt to get
        # @param args List. Arguments to pass to the prompt handler
        # @return MCP-formatted prompt result
        handle_prompt_get = function(prompt_name, args) {
            if (is.null(self$prompts[[prompt_name]])) {
                cli::cli_abort("Prompt not found: {prompt_name}")
            }

            handler <- self$prompts[[prompt_name]]$handler
            result <- rlang::exec(handler, !!!args)

            if (is.null(result$messages)) {
                cli::cli_abort("Prompt handler must return a list with a 'messages' field")
            }

            return(list(description = result$description, messages = result$messages))
        }
    )
)

# -----🔺 CONVENIENCE FUNCTIONS ------------------------------------------------

#' Create and serve MCP server from file over HTTP
#'
#' @description
#' Parses an R file with annotated functions and serves them as an MCP server
#' over HTTP. This is a convenience wrapper around creating an McpServer instance,
#' parsing the file, registering tools/resources/prompts, and starting the server.
#'
#' @param file Character. Path to R file with annotated functions. Functions should
#'   use `#' @mcp tool|resource|prompt` annotations. Tools use `#' @param` tags,
#'   resources use `#' @uri` and `#' @mimeType` tags, prompts use `#' @param` tags
#'   for arguments.
#' @param name Character. Server name. If NULL, auto-detected from filename.
#' @param version Character. Server version. If NULL, defaults to "1.0.0".
#' @param groups Character vector. Optional. If provided, only serve tools/resources/prompts
#'   in the specified groups. Use the `@group` annotation to assign functions to groups.
#' @param host Character. Host to bind to (default: "127.0.0.1")
#' @param port Integer. Port to listen on (default: 8080)
#' @param ... Additional arguments passed to `McpServer$serve_http()`
#'
#' @return NULL (server runs blocking by default)
#' @export
#'
#' @examples
#' \dontrun{
#' # Simple usage - auto-detects name from filename
#' mcp_serve_http("zotero_tools.R", port = 8080)
#'
#' # Serve only specific groups
#' mcp_serve_http("all_tools.R", groups = c("zotero", "web"), port = 8080)
#'
#' # Explicit name and version
#' mcp_serve_http("tools.R", name = "my-server", version = "2.0.0", port = 8080)
#'
#' # With custom settings
#' mcp_serve_http(
#'     "tools.R",
#'     name = "my-server",
#'     port = 8080,
#'     block = TRUE,
#'     silent = FALSE
#' )
#' }
mcp_serve_http <- function(file, name = NULL, version = NULL, groups = NULL, host = "127.0.0.1", port = 8080, ...) {
    # Auto-detect name from filename if not provided
    if (is.null(name)) {
        name <- tools::file_path_sans_ext(basename(file))
    }

    # Default version
    if (is.null(version)) {
        version <- "1.0.0"
    }

    # Parse file to extract tools/resources/prompts
    parsed <- parse_mcp_file(file, groups = groups)

    # Create server
    server <- McpServer$new(name = name, version = version)

    # Register tools
    for (tool in parsed$tools) {
        server$add_tool(tool)
    }

    # Register resources
    for (resource in parsed$resources) {
        server$add_resource(resource, handler = resource$.fn)
    }

    # Register prompts
    for (prompt in parsed$prompts) {
        server$add_prompt(prompt, handler = prompt$.fn)
    }

    # Serve
    server$serve_http(host = host, port = port, ...)
}

#' Create and serve MCP server from file over stdio
#'
#' @description
#' Parses an R file with annotated functions and serves them as an MCP server
#' over stdio (standard input/output). This is a convenience wrapper around
#' creating an McpServer instance, parsing the file, registering
#' tools/resources/prompts, and starting the server.
#'
#' @param file Character. Path to R file with annotated functions. Functions should
#'   use `#' @mcp tool|resource|prompt` annotations. Tools use `#' @param` tags,
#'   resources use `#' @uri` and `#' @mimeType` tags, prompts use `#' @param` tags
#'   for arguments.
#' @param name Character. Server name. If NULL, auto-detected from filename.
#' @param version Character. Server version. If NULL, defaults to "1.0.0".
#' @param groups Character vector. Optional. If provided, only serve tools/resources/prompts
#'   in the specified groups. Use the `@group` annotation to assign functions to groups.
#'
#' @return NULL (server runs blocking)
#' @export
#'
#' @examples
#' \dontrun{
#' # Simple usage - auto-detects name from filename
#' mcp_serve_stdio("zotero_tools.R")
#'
#' # Serve only specific groups
#' mcp_serve_stdio("all_tools.R", groups = c("zotero", "web"))
#'
#' # Explicit name and version
#' mcp_serve_stdio("tools.R", name = "my-server", version = "2.0.0")
#'
#' # Typical usage in an MCP server script
#' if (!interactive()) {
#'     mcp_serve_stdio(
#'         rstudioapi::getActiveDocumentContext()$path,
#'         name = "my-server"
#'     )
#' }
#' }
mcp_serve_stdio <- function(file, name = NULL, version = NULL, groups = NULL) {
    # Auto-detect name from filename if not provided
    if (is.null(name)) {
        name <- tools::file_path_sans_ext(basename(file))
    }

    # Default version
    if (is.null(version)) {
        version <- "1.0.0"
    }

    # Parse file to extract tools/resources/prompts
    parsed <- parse_mcp_file(file, groups = groups)

    # Create server
    server <- McpServer$new(name = name, version = version)

    # Register tools
    for (tool in parsed$tools) {
        server$add_tool(tool)
    }

    # Register resources
    for (resource in parsed$resources) {
        server$add_resource(resource, handler = resource$.fn)
    }

    # Register prompts
    for (prompt in parsed$prompts) {
        server$add_prompt(prompt, handler = prompt$.fn)
    }

    # Serve
    server$serve_stdio()
}
