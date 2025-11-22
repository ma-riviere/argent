#' MCP Client Implementation
#'
#' @description
#' R6 classes for connecting to and interacting with MCP servers.
#' Supports both stdio (local process) and HTTP transports.
#'
#' @keywords internal
McpClient <- R6::R6Class(
    "McpClient",
    public = list(
        #' @field name Client name
        name = NULL,
        
        #' @description
        #' Initialize client
        initialize = function() {
            self$name <- "argent-client"
        },
        
        #' @description
        #' List tools available on the server
        list_tools = function() {
            res <- self$send_request(list(method = "tools/list"))
            return(res$tools %||% list())
        },
        
        #' @description
        #' Call a tool on the server
        #' @param tool_name Name of the tool
        #' @param args List of arguments
        call_tool = function(tool_name, args) {
            req <- list(
                method = "tools/call",
                params = list(
                    name = tool_name,
                    arguments = args
                )
            )

            res <- self$send_request(req)

            # Check if response is an error
            if (!is.null(res$isError) && res$isError) {
                return(res)
            }

            # Extract content from MCP response structure
            # MCP supports multiple content types: text, resource, image
            # GitHub's get_file_contents returns: [{ type: "text", text: "status" },
            #   { type: "resource", resource: { text: "file contents" } }]
            # Strategy: prioritize resource/image content over text status messages
            if (!is.null(res$content) && is.list(res$content)) {
                # Separate content by type
                resource_content <- list()
                text_content <- list()

                for (item in res$content) {
                    if (item$type == "resource") {
                        resource_content <- c(
                            resource_content,
                            list(item$resource$text %||% item$resource$blob %||% "")
                        )
                    } else if (item$type == "image") {
                        resource_content <- c(
                            resource_content,
                            list(jsonlite::toJSON(list(
                                type = "image",
                                data = item$data,
                                mimeType = item$mimeType
                            ), auto_unbox = TRUE))
                        )
                    } else if (item$type == "text") {
                        text_content <- c(text_content, list(item$text %||% ""))
                    }
                }

                # Prioritize resource/image content, only use text if no resources
                if (length(resource_content) > 0) {
                    paste(unlist(resource_content), collapse = "\n")
                } else if (length(text_content) > 0) {
                    paste(unlist(text_content), collapse = "\n")
                } else {
                    ""
                }
            } else {
                res
            }
        },

        #' @description
        #' List resources available on the server
        list_resources = function() {
            res <- self$send_request(list(method = "resources/list"))
            return(res$resources %||% list())
        },

        #' @description
        #' Read a resource from the server
        #' @param uri URI of the resource to read
        read_resource = function(uri) {
            res <- self$send_request(list(method = "resources/read", params = list(uri = uri)))

            # Check if response is an error
            if (!is.null(res$isError) && res$isError) {
                return(res)
            }

            return(res$contents %||% list())
        },

        #' @description
        #' List prompts available on the server
        list_prompts = function() {
            res <- self$send_request(list(method = "prompts/list"))
            return(res$prompts %||% list())
        },

        #' @description
        #' Get a prompt from the server
        #' @param name Name of the prompt
        #' @param arguments List of arguments for the prompt
        get_prompt = function(name, arguments = NULL) {
            req <- list(
                method = "prompts/get",
                params = list(
                    name = name,
                    arguments = arguments
                )
            )

            res <- self$send_request(req)
            return(res)
        },
        
        #' @description
        #' Send a JSON-RPC request
        #' @param req List containing method and params
        send_request = function(req) {
            cli::cli_abort("Abstract method called")
        }
    )
)

#' @title Standard IO MCP Client
#' @description
#' A client for interacting with local MCP servers via stdio.
#' @keywords internal
McpClientStdio <- R6::R6Class(
    "McpClientStdio",
    inherit = McpClient,
    public = list(
        #' @field process processx process object
        process = NULL,
        
        #' @description
        #' Initialize stdio client
        #' @param command Command to run
        #' @param args Arguments for the command
        #' @param env Environment variables
        initialize = function(command, args = character(), env = NULL) {
            super$initialize()
            
            self$process <- processx::process$new(
                command = command,
                args = args,
                env = env,
                stdin = "|",
                stdout = "|",
                stderr = "|" # Capture stderr to avoid polluting console
            )
            
            # Perform handshake
            self$initialize_connection()
        },
        
        #' @description
        #' Initialize MCP connection
        initialize_connection = function() {
            req <- list(
                method = "initialize",
                params = list(
                    protocolVersion = "2024-11-05",
                    capabilities = list(
                        tools = list(listChanged = FALSE),
                        resources = list(subscribe = FALSE, listChanged = FALSE),
                        prompts = list(listChanged = FALSE)
                    ),
                    clientInfo = list(name = "argent", version = "1.0")
                )
            )
            self$send_request(req)
            
            # Send initialized notification
            notif <- list(method = "notifications/initialized", params = named_list())
            self$send_notification(notif)
        },
        
        #' @description
        #' Send request to stdio process
        #' @param req Request list
        send_request = function(req) {
            # Add JSON-RPC 2.0 fields
            req$jsonrpc <- "2.0"
            req$id <- as.integer(runif(1, 1, 1000000))

            # Remove NULL values to ensure proper JSON-RPC structure
            req <- purrr::discard(req, is.null)

            json <- jsonlite::toJSON(req, auto_unbox = TRUE)
            self$process$write_input(paste0(json, "\n"))
            
            # Read response (blocking simple implementation)
            # TODO: Improve robustness with timeouts/loops
            while (TRUE) {
                Sys.sleep(0.1)
                if (!self$process$is_alive()) {
                    cli::cli_abort("MCP server process died")
                }
                
                out <- self$process$read_output_lines()
                if (length(out) > 0) {
                    # Parse the first valid JSON line
                    for (line in out) {
                        # Basic check for JSON
                        if (startsWith(line, "{")) {
                            res <- jsonlite::fromJSON(line, simplifyVector = FALSE)
                            if (!is.null(res$id) && res$id == req$id) {
                                if (!is.null(res$error)) {
                                    return(list(isError = TRUE, error = res$error))
                                }
                                return(res$result)
                            }
                        }
                    }
                }
                
                # Check stderr for debugging
                err <- self$process$read_error_lines()
                if (length(err) > 0) {
                    # Could log debug info here
                }
            }
        },
        
        #' @description
        #' Send notification (no ID, no response expected)
        #' @param req Request list
        send_notification = function(req) {
            req$jsonrpc <- "2.0"
            json <- jsonlite::toJSON(req, auto_unbox = TRUE)
            self$process$write_input(paste0(json, "\n"))
        }
    )
)

#' @title HTTP MCP Client
#' @description
#' A client for interacting with remote MCP servers via HTTP.
#' @keywords internal
McpClientHttp <- R6::R6Class(
    "McpClientHttp",
    inherit = McpClient,
    public = list(
        #' @field url Server URL
        url = NULL,
        #' @field headers HTTP headers
        headers = NULL,
        #' @field session_id Session ID from server
        session_id = NULL,
        
        #' @description
        #' Initialize HTTP client
        #' @param url Server URL
        #' @param headers Named list of headers
        initialize = function(url, headers = NULL) {
            super$initialize()
            self$url <- url
            self$headers <- headers
            self$initialize_connection()
        },
        
        #' @description
        #' Initialize connection
        initialize_connection = function() {
            req <- list(
                method = "initialize",
                params = list(
                    protocolVersion = "2024-11-05",
                    capabilities = list(
                        tools = list(listChanged = FALSE),
                        resources = list(subscribe = FALSE, listChanged = FALSE),
                        prompts = list(listChanged = FALSE)
                    ),
                    clientInfo = list(name = "argent", version = "1.0")
                )
            )
            self$send_request(req, is_init = TRUE)
        },
        
        #' @description
        #' Send request via HTTP
        #' @param req Request list
        #' @param is_init Boolean, if TRUE, captures session ID
        send_request = function(req, is_init = FALSE) {
            req$jsonrpc <- "2.0"
            req$id <- as.integer(runif(1, 1, 1000000))

            # Remove NULL values to ensure proper JSON-RPC structure
            req <- purrr::discard(req, is.null)

            http_req <- httr2::request(self$url) |>
                httr2::req_body_json(req)
            
            if (!is.null(self$headers)) {
                http_req <- httr2::req_headers(http_req, !!!self$headers)
            }
            
            if (!is.null(self$session_id)) {
                http_req <- httr2::req_headers(http_req, `mcp-session-id` = self$session_id)
            }
            
            resp <- httr2::req_perform(http_req)
            
            if (is_init) {
                self$session_id <- httr2::resp_header(resp, "mcp-session-id")
            }
            
            body <- httr2::resp_body_json(resp)

            if (!is.null(body$error)) {
                return(list(isError = TRUE, error = body$error))
            }

            return(body$result)
        }
    )
)
