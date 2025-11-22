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
        },

        #' @description
        #' Add a tool to the server
        #' @param tool_def List definition of the tool (name, description, args_schema)
        #' @param handler Function to execute when the tool is called. Should have named
        #'   parameters matching the tool's arguments, with defaults for optional parameters.
        #'   Returns a result (character, list, or other).
        add_tool = function(tool_def, handler) {
            if (!is.function(handler)) {
                cli::cli_abort("{.arg handler} must be a function")
            }

            # Store tool definition and handler
            tool_name <- tool_def$name
            self$tools[[tool_name]] <- list(
                definition = tool_def,
                handler = handler
            )
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
            self$resources[[resource_uri]] <- list(
                definition = resource_def,
                handler = handler
            )
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
            self$prompts[[prompt_name]] <- list(
                definition = prompt_def,
                handler = handler
            )
            invisible(self)
        },

        #' @description
        #' Serve the MCP protocol over stdio
        #' This method blocks and listens for JSON-RPC requests on stdin.
        serve_stdio = function() {
            # Open stdin as a file connection to ensure it stays open
            con <- file("stdin", "open" = "r")
            on.exit(close(con))
            
            # Main loop
            while (TRUE) {
                line <- readLines(con, n = 1, warn = FALSE)
                if (length(line) == 0) break
                if (nchar(line) == 0) next
                
                self$handle_request(line)
            }
        },

        #' @description
        #' Handle a single JSON-RPC request line
        #' @param line JSON string
        handle_request = function(line) {
            # Parse request
            req <- purrr::possibly(jsonlite::fromJSON, otherwise = NULL)(line)
            
            if (is.null(req) || is.null(req$jsonrpc)) {
                return(invisible(NULL))
            }
            
            # Handle request based on method
            response <- tryCatch({
                if (!is.null(req$error)) stop("Request has error")
                
                method <- req$method
                id <- req$id
                
                if (method == "initialize") {
                    list(
                        protocolVersion = "2024-11-05",
                        serverInfo = list(
                            name = self$name,
                            version = self$version
                        ),
                        capabilities = list(
                            tools = list(listChanged = FALSE),
                            resources = list(subscribe = FALSE, listChanged = FALSE),
                            prompts = list(listChanged = FALSE)
                        )
                    )
                } else if (method == "notifications/initialized") {
                    # No response needed for notification
                    NULL
                } else if (method == "tools/list") {
                    # Convert stored tool definitions to MCP format
                    mcp_tools <- lapply(self$tools, function(t) {
                        def <- t$definition
                        list(
                            name = def$name,
                            description = def$description,
                            inputSchema = def$args_schema
                        )
                    })

                    list(tools = unname(mcp_tools))

                } else if (method == "tools/call") {
                    params <- req$params
                    tool_name <- params$name
                    args <- params$arguments

                    if (is.null(self$tools[[tool_name]])) {
                        cli::cli_abort("Tool not found: {tool_name}")
                    }

                    handler <- self$tools[[tool_name]]$handler
                    result <- rlang::exec(handler, !!!args)

                    # Format result as MCP expects
                    content_text <- if (is.character(result) && length(result) == 1) {
                        result
                    } else {
                        jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE)
                    }

                    list(
                        content = list(list(type = "text", text = content_text)),
                        isError = FALSE
                    )
                } else if (method == "resources/list") {
                    # Convert stored resource definitions to MCP format
                    mcp_resources <- lapply(self$resources, function(r) {
                        def <- r$definition
                        list(
                            uri = def$uri,
                            name = def$name,
                            description = def$description,
                            mimeType = def$mimeType
                        )
                    })

                    list(resources = unname(mcp_resources))

                } else if (method == "resources/read") {
                    params <- req$params
                    uri <- params$uri

                    if (is.null(self$resources[[uri]])) {
                        cli::cli_abort("Resource not found: {uri}")
                    }

                    handler <- self$resources[[uri]]$handler
                    result <- handler(uri)

                    # Format result as MCP expects
                    # Result should be a list with either 'text' or 'blob' field
                    content_item <- if (is.character(result) && length(result) == 1) {
                        list(
                            uri = uri,
                            mimeType = self$resources[[uri]]$definition$mimeType %||% "text/plain",
                            text = result
                        )
                    } else if (is.list(result) && !is.null(result$text)) {
                        list(
                            uri = uri,
                            mimeType = result$mimeType %||% self$resources[[uri]]$definition$mimeType %||% "text/plain",
                            text = result$text
                        )
                    } else if (is.list(result) && !is.null(result$blob)) {
                        list(
                            uri = uri,
                            mimeType = result$mimeType %||% self$resources[[uri]]$definition$mimeType %||% "application/octet-stream",
                            blob = result$blob
                        )
                    } else {
                        list(
                            uri = uri,
                            mimeType = "text/plain",
                            text = jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE)
                        )
                    }

                    list(contents = list(content_item))

                } else if (method == "prompts/list") {
                    # Convert stored prompt definitions to MCP format
                    mcp_prompts <- lapply(self$prompts, function(p) {
                        def <- p$definition
                        list(
                            name = def$name,
                            description = def$description,
                            arguments = def$arguments
                        )
                    })

                    list(prompts = unname(mcp_prompts))

                } else if (method == "prompts/get") {
                    params <- req$params
                    prompt_name <- params$name
                    args <- params$arguments

                    if (is.null(self$prompts[[prompt_name]])) {
                        cli::cli_abort("Prompt not found: {prompt_name}")
                    }

                    handler <- self$prompts[[prompt_name]]$handler
                    result <- rlang::exec(handler, !!!args)

                    # Result should be a list with 'description' (optional) and 'messages' fields
                    # messages should be a list of lists with 'role' and 'content' fields
                    if (is.null(result$messages)) {
                        cli::cli_abort("Prompt handler must return a list with a 'messages' field")
                    }

                    list(description = result$description, messages = result$messages)
                    
                } else {
                    cli::cli_abort("Method not found: {method}")
                }
            },
            error = function(e) {
                # Problem with the data being sent to the MCP server, 
                #  often due to undefined properties or incorrect JSON structure
                return(list(code = -32603, message = e$message))
            })
            
            # Send response if needed (requests with IDs expect responses)
            if (!is.null(req$id) && !is.null(response)) {
                resp_obj <- list(jsonrpc = "2.0", id = req$id)
                
                if (!is.null(response$code) && !is.null(response$message)) {
                    resp_obj$error <- response
                } else {
                    resp_obj$result <- response
                }

                cat(jsonlite::toJSON(resp_obj, auto_unbox = TRUE), "\n")
                flush(stdout())
            }
        }
    )
)
