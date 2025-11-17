#' MCP (Model Context Protocol) Integration
#'
#' @description
#' Functions for integrating MCP servers with argent. MCP servers provide tools,
#' resources, and prompts that LLMs can use during conversations.
#'
#' ## MCP Server Connection
#'
#' `mcp_server()` creates a connection to an MCP server using programmatic
#' configuration. For stdio servers, the server is spawned as a subprocess and
#' communicates via JSON-RPC over stdin/stdout. For HTTP servers, communication
#' happens via HTTP requests to the specified endpoint.
#'
#' ## Tool Discovery
#'
#' `mcp_tools()` retrieves tool definitions from an MCP server and converts them
#' to argent's tool format. Tools can then be passed to `chat()` alongside
#' client-defined and provider server tools.
#'
#' ## Resources and Prompts
#'
#' `mcp_resources()` retrieves file-like structured data that LLMs can access.
#' `mcp_prompts()` retrieves predefined templates for interactions.
#' 
#' @name mcp_integration
#'
#' @param name Character. Name identifier for the MCP server
#' @param type Character. Server type: "stdio" for command-line or "http" for HTTP endpoint (default: "stdio")
#' @param command Character. Command to execute (for stdio servers, e.g., "docker", "npx")
#' @param args Character vector. Arguments to pass to the command (for stdio servers)
#' @param env Named list. Environment variables for the server process (for stdio servers)
#' @param url Character. HTTP endpoint URL (for http servers, e.g., "https://api.githubcopilot.com/mcp")
#' @param headers Named list. HTTP headers (for http servers, e.g., list(Authorization = "Bearer token"))
#' @param server An MCP server object created by `mcp_server()`
#' @param tools Character vector. Specific tool names to retrieve. If NULL, retrieves all tools
#' @param resources Character vector. Specific resource URIs to retrieve. If NULL, retrieves all
#' @param prompts Character vector. Specific prompt names to retrieve. If NULL, retrieves all
#'
#' @return
#' - `mcp_server()`: An MCP server connection object (list with class "mcp_server")
#' - `mcp_tools()`: List of tool definitions in argent format
#' - `mcp_resources()`: List of resource definitions
#' - `mcp_prompts()`: List of prompt definitions
#'
#' @examples
#' \dontrun{
#' # HTTP server configuration (GitHub Copilot MCP)
#' github <- mcp_server(
#'   name = "github",
#'   type = "http",
#'   url = "https://api.githubcopilot.com/mcp",
#'   headers = list(
#'     Authorization = paste("Bearer", Sys.getenv("GITHUB_PAT"))
#'   )
#' )
#'
#' # Stdio server configuration (Docker)
#' filesystem <- mcp_server(
#'   name = "filesystem",
#'   type = "stdio",
#'   command = "docker",
#'   args = c("run", "-i", "--rm", "mcp/filesystem"),
#'   env = list()
#' )
#'
#' # Get all tools from server
#' github_tools <- mcp_tools(github)
#'
#' # Get specific tools only
#' issue_tools <- mcp_tools(github, tools = c("search_issues", "create_issue"))
#'
#' # Use in chat with other tools
#' google <- Google$new()
#' google$chat(
#'   "Create an issue for the bug I found",
#'   tools = list(
#'     github_tools,
#'     as_tool(my_custom_function)
#'   )
#' )
#'
#' # Get resources
#' github_resources <- mcp_resources(github)
#' }
#'
NULL

#' @export
#' @rdname mcp_integration
mcp_server <- function(
    name,
    type = "stdio",
    command = NULL,
    args = NULL,
    env = NULL,
    url = NULL,
    headers = NULL
) {
    if (!is.character(name) || length(name) != 1 || nchar(name) == 0) {
        cli::cli_abort("{.arg name} must be a non-empty string")
    }

    if (!type %in% c("stdio", "http")) {
        cli::cli_abort("{.arg type} must be either 'stdio' or 'http'")
    }

    # Create server configuration based on type
    server_config <- list3(name = name, type = type)

    if (type == "http") {
        # HTTP server validation
        if (is.null(url) || !is.character(url) || length(url) != 1) {
            cli::cli_abort("For HTTP servers, {.arg url} is required and must be a string")
        }

        server_config$url <- url

        if (!is.null(headers)) {
            if (!is.list(headers)) {
                cli::cli_abort("{.arg headers} must be a named list")
            }
            server_config$headers <- headers
        }

    } else {
        # Stdio server validation
        if (is.null(command) || !is.character(command) || length(command) != 1) {
            cli::cli_abort("For stdio servers, {.arg command} is required and must be a string")
        }

        server_config$command <- command

        if (!is.null(args)) {
            if (!is.character(args)) {
                cli::cli_abort("{.arg args} must be a character vector")
            }
            server_config$args <- args
        }

        if (!is.null(env)) {
            if (!is.list(env)) {
                cli::cli_abort("{.arg env} must be a named list")
            }
            server_config$env <- env
        }
    }

    return(server_config)
}

# -----🔺 TOOLS ----------------------------------------------------------------

#' @export
#' @rdname mcp_integration
mcp_tools <- function(server, tools = NULL) {
    server_name <- server$name
    server_config <- server
    session_id <- NULL

    # Fetch tools based on server type
    if (server$type == "http") {
        # HTTP servers: use direct HTTP implementation
        result <- fetch_mcp_tools_http(server)
        all_tools <- result$tools
        session_id <- result$session_id
    } else {
        config <- create_temp_mcp_config(server)
        all_tools <- tryCatch(            
            mcptools::mcp_tools(config = config),
            error = function(e) {
                cli::cli_abort(c(
                    "Failed to retrieve tools from MCP server {.val {server_name}}",
                    "i" = "Error: {e$message}"
                ))
            }
        )
    }

    # For stdio servers using mcptools with a single-server config,
    # all tools already belong to our server - no filtering needed
    # For HTTP servers, all_tools already contains only our server's tools
    server_tools <- all_tools

    # Filter to specific tools if requested
    if (!is.null(tools)) {
        if (!is.character(tools)) {
            cli::cli_abort("{.arg tools} must be a character vector")
        }
        server_tools <- purrr::keep(server_tools, \(tool) {
            tool_name <- if (inherits(tool, "ellmer::ToolDef")) tool@name else tool$name
            tool_name %in% tools
        })
    }

    argent_tools <- purrr::map(server_tools, \(tool) mcptools_to_argent(tool, server_name, server_config, session_id))
    return(argent_tools)
}

#' Execute an MCP tool
#'
#' @param tool_def List. The tool definition with .mcp metadata
#' @param arguments List. The arguments to pass to the tool
#'
#' @return The result of the tool execution
#'
#' @examples
#' \dontrun{
#' # Assuming you have a tool_def from mcp_tools()
#' execute_mcp_tool(
#'   tool_def = github_tools[[1]],
#'   arguments = list(owner = "ma-riviere", repo = "argent", path = "R/aaa-utils.R", ref = "main")
#' )
#' }
#'
#' @export
execute_mcp_tool <- function(tool_def, arguments) {
    tool_name <- tool_def$name
    if (purrr::is_empty(tool_name)) {
        cli::cli_abort("Tool definition has no name")
    }

    mcp_metadata <- tool_def[[".mcp"]]
    if (purrr::is_empty(mcp_metadata)) {
        cli::cli_abort("Tool {.val {tool_name}} is not an MCP tool")
    }

    server_config <- mcp_metadata$config
    if (purrr::is_empty(server_config)) {
        cli::cli_abort("No server configuration found for tool {.val {tool_name}}")
    }

    # HTTP MCP server
    if (server_config$type == "http") {
        tool_request <- list(
            jsonrpc = "2.0",
            id = as.integer(runif(1, 1, 1000000)),
            method = "tools/call",
            params = list(
                name = tool_name,
                arguments = arguments
            )
        )

        req <- httr2::request(server_config$url) |>
            httr2::req_body_json(tool_request)

        # Add session ID if available
        session_id <- mcp_metadata$session_id
        if (!is.null(session_id)) {
            req <- httr2::req_headers(req, `mcp-session-id` = session_id)
        }

        # Add other headers
        if (!is.null(server_config$headers)) {
            for (header_name in names(server_config$headers)) {
                req <- httr2::req_headers(req, !!!stats::setNames(
                    list(server_config$headers[[header_name]]),
                    header_name
                ))
            }
        }

        resp <- tryCatch(
            httr2::req_perform(req),
            error = function(e) {
                cli::cli_abort(c(
                    "Failed to execute MCP tool {.val {tool_name}}",
                    "i" = "Error: {e$message}"
                ))
            }
        )

        result_data <- httr2::resp_body_json(resp)

        if (!is.null(result_data$error)) {
            cli::cli_abort(c(
                "MCP tool execution failed",
                "i" = "Tool: {.val {tool_name}}",
                "i" = "Error: {result_data$error$message}"
            ))
        }

        return(result_data$result)

    } else if (server_config$type == "stdio") {
        server_name <- server_config$name %||% mcp_metadata$server
        if (is.null(server_name)) {
            cli::cli_abort("Could not determine MCP server name for tool {.val {tool_name}}")
        }

        ensure_stdio_mcp_server(server_config, server_name)

        call_args <- arguments %||% list()
        tool_response <- tryCatch(
            rlang::exec(
                .fn = mcptools:::call_tool,
                !!!call_args,
                server = server_name,
                tool = tool_name
            ),
            error = function(e) {
                cli::cli_abort(c(
                    "Failed to execute MCP tool {.val {tool_name}}",
                    "i" = "Server: {.val {server_name}}",
                    "i" = "Error: {e$message}"
                ))
            }
        )

        if (is.null(tool_response)) {
            cli::cli_abort(c(
                "No response received from MCP server {.val {server_name}}",
                "i" = "Tool: {.val {tool_name}}"
            ))
        }

        if (!is.null(tool_response$error)) {
            cli::cli_abort(c(
                "MCP tool execution failed",
                "i" = "Tool: {.val {tool_name}}",
                "i" = "Error: {tool_response$error$message}"
            ))
        }

        return(tool_response$result)

    } else {
        cli::cli_abort("Unsupported MCP server type {.val {server_config$type}}")
    }
}

#' Ensure stdio MCP server is running
#' @keywords internal
#' @noRd
ensure_stdio_mcp_server <- function(server_config, server_name) {
    active_server <- tryCatch(
        mcptools:::the$mcp_servers[[server_name]],
        error = function(...) NULL
    )

    if (!is.null(active_server)) {
        return(invisible(NULL))
    }

    temp_config <- create_temp_mcp_config(server_config)
    on.exit({
        if (fs::file_exists(temp_config)) {
            fs::file_delete(temp_config)
        }
    }, add = TRUE)

    tryCatch(
        mcptools::mcp_tools(config = temp_config),
        error = function(e) {
            cli::cli_abort(c(
                "Failed to start MCP server {.val {server_name}}",
                "i" = "Error: {e$message}"
            ))
        }
    )

    invisible(NULL)
}

# -----🔺 RESOURCES ------------------------------------------------------------

#' @export
#' @rdname mcp_integration
mcp_resources <- function(server, resources = NULL) {
    cli::cli_abort(c(
        "MCP resources not yet implemented",
        "i" = "This feature will be added in a future version"
    ))
}

# -----🔺 PROMPTS --------------------------------------------------------------

#' @export
#' @rdname mcp_integration
mcp_prompts <- function(server, prompts = NULL) {
    cli::cli_abort(c(
        "MCP prompts not yet implemented",
        "i" = "This feature will be added in a future version"
    ))
}

# -----🔺 INTERNAL -------------------------------------------------------------

#' @keywords internal
#' @noRd
is_mcp_tool <- function(obj) {
    if (!is.list(obj)) {
        return(FALSE)
    }

    return(!is.null(obj[[".mcp"]]))
}

#' @keywords internal
#' @noRd
is_mcp_resource <- function(obj) {
    if (!is.list(obj)) {
        return(FALSE)
    }

    !is.null(obj[[".mcp"]]) && isTRUE(obj[[".mcp"]]$type == "resource")
}

#' @keywords internal
#' @noRd
is_mcp_prompt <- function(obj) {
    if (!is.list(obj)) {
        return(FALSE)
    }

    !is.null(obj[[".mcp"]]) && isTRUE(obj[[".mcp"]]$type == "prompt")
}

#' @keywords internal
#' @noRd
get_mcp_server <- function(obj) {
    if (!is.list(obj) || is.null(obj[[".mcp"]])) {
        return(NULL)
    }

    obj[[".mcp"]]$server
}

#' Convert MCP tool to argent format
#' @keywords internal
#' @noRd
mcptools_to_argent <- function(mcp_tool, server_name, server_config, session_id = NULL) {
    # Detect if this is an ellmer S7 ToolDef object (stdio) or plain list (HTTP)
    is_s7_tooldef <- inherits(mcp_tool, "ellmer::ToolDef")

    if (is_s7_tooldef) {
        # Use helper for S7 ToolDef conversion
        argent_tool <- ellmer_to_argent(mcp_tool)
    } else {
        # Plain list from HTTP servers
        # MCP tools from HTTP have structure:
        # list(
        #   name = "tool_name",
        #   description = "...",
        #   inputSchema = list(type = "object", properties = ..., required = ...)
        # )
        argent_tool <- list(
            name = mcp_tool$name,
            description = mcp_tool$description %||% ""
        )

        # Convert inputSchema to args_schema
        if (!is.null(mcp_tool$inputSchema)) {
            argent_tool$args_schema <- mcp_tool$inputSchema
        } else if (!is.null(mcp_tool$parameters)) {
            # Some implementations might use 'parameters' instead
            argent_tool$args_schema <- mcp_tool$parameters
        }
    }

    # Add MCP metadata
    argent_tool[[".mcp"]] <- list(
        type = "tool",
        server = server_name,
        config = server_config,
        session_id = session_id
    )

    return(argent_tool)
}

#' Convert ellmer ToolDef to argent tool format
#'
#' Converts an ellmer S7 ToolDef object (from stdio MCP servers) to argent's
#' internal tool representation with JSON Schema args_schema.
#'
#' @param ellmer_tool An ellmer::ToolDef S7 object
#' @return List with name, description, and args_schema fields
#' @keywords internal
#' @noRd
ellmer_to_argent <- function(ellmer_tool) {
    # Extract basic fields
    tool_def <- list(
        name = ellmer_tool@name,
        description = ellmer_tool@description
    )

    # Convert arguments (TypeObject) to JSON Schema args_schema
    if (length(ellmer_tool@arguments@properties) > 0) {
        properties <- list()
        required <- character()

        for (param_name in names(ellmer_tool@arguments@properties)) {
            param_type <- ellmer_tool@arguments@properties[[param_name]]

            # Convert ellmer Type to JSON Schema
            properties[[param_name]] <- ellmer_type_to_json_schema(param_type)

            # Check if required
            if (isTRUE(param_type@required)) {
                required <- c(required, param_name)
            }
        }

        tool_def$args_schema <- list(
            type = "object",
            properties = properties,
            required = if (length(required) > 0) as.list(required) else list()
        )
    }

    return(tool_def)
}

#' Convert ellmer Type object to JSON Schema
#'
#' Recursively converts ellmer S7 Type objects (TypeString, TypeNumber, etc.)
#' to JSON Schema format for tool argument specifications.
#'
#' @param type_obj An ellmer Type S7 object
#' @return List representing JSON Schema for the type
#' @keywords internal
#' @noRd
ellmer_type_to_json_schema <- function(type_obj) {
    schema <- list()

    # Map ellmer type class to JSON Schema type
    type_class <- class(type_obj)[1]
    schema$type <- switch(
        type_class,
        "TypeString" = "string",
        "TypeNumber" = "number",
        "TypeInteger" = "integer",
        "TypeBoolean" = "boolean",
        "TypeArray" = "array",
        "TypeObject" = "object",
        "string"
    )

    # Add description if present
    if (!is.null(type_obj@description) && nchar(type_obj@description) > 0) {
        schema$description <- type_obj@description
    }

    # Handle array items
    if (type_class == "TypeArray" && !is.null(type_obj@items)) {
        schema$items <- ellmer_type_to_json_schema(type_obj@items)
    }

    # Handle object properties
    if (type_class == "TypeObject" && length(type_obj@properties) > 0) {
        props <- list()
        req <- character()

        for (pname in names(type_obj@properties)) {
            ptype <- type_obj@properties[[pname]]
            props[[pname]] <- ellmer_type_to_json_schema(ptype)
            if (isTRUE(ptype@required)) {
                req <- c(req, pname)
            }
        }

        schema$properties <- props
        if (length(req) > 0) {
            schema$required <- as.list(req)
        }
    }

    return(schema)
}

#' Create temporary MCP config from server object
#' @keywords internal
#' @noRd
create_temp_mcp_config <- function(server) {
    # Build server config based on type
    if (server$type == "http") {
        server_def <- list3(
            type = "http",
            url = server$url,
            headers = server$headers
        )
    } else if (server$type == "stdio") {
        # stdio type
        server_def <- list3(
            command = server$command,
            args = server$args,
            env = server$env
        )
    } else {
        cli::cli_abort("Unsupported server type: {.val {server$type}}")
    }

    config_data <- list(mcpServers = stats::setNames(list(server_def), server$name))

    temp_file <- tempfile(pattern = "mcp_config_", fileext = ".json")
    jsonlite::write_json(config_data, temp_file, pretty = TRUE, auto_unbox = TRUE)

    return(temp_file)
}

#' Fetch tools from HTTP MCP server
#' @keywords internal
#' @noRd
fetch_mcp_tools_http <- function(server) {
    # Initialize MCP session via JSON-RPC
    init_request <- list(
        jsonrpc = "2.0",
        id = 1L,
        method = "initialize",
        params = list(
            protocolVersion = "2024-11-05",
            capabilities = named_list(),
            clientInfo = list(
                name = "argent",
                version = as.character(packageVersion("argent"))
            )
        )
    )

    # Build HTTP request
    req <- httr2::request(server$url) |>
        httr2::req_body_json(init_request)

    # Add headers
    if (!is.null(server$headers)) {
        for (header_name in names(server$headers)) {
            req <- httr2::req_headers(req, !!!stats::setNames(
                list(server$headers[[header_name]]),
                header_name
            ))
        }
    }

    # Send initialize request
    init_resp <- tryCatch(
        httr2::req_perform(req),
        error = function(e) {
            cli::cli_abort(
                c(
                    "Failed to connect to MCP server {.val {server$name}}",
                    "i" = "URL: {server$url}",
                    "i" = "Error: {e$message}"
                )
            )
        }
    )

    # Extract session ID from response headers
    session_id <- httr2::resp_header(init_resp, "mcp-session-id")

    # Check for errors in response body
    init_data <- httr2::resp_body_json(init_resp)
    if (!is.null(init_data$error)) {
        cli::cli_abort(
            c(
                "MCP server returned error during initialization",
                "i" = "Code: {init_data$error$code}",
                "i" = "Message: {init_data$error$message}"
            )
        )
    }

    # List tools
    tools_request <- list(
        jsonrpc = "2.0",
        id = 2L,
        method = "tools/list",
        params = named_list()
    )

    req_tools <- httr2::request(server$url) |>
        httr2::req_body_json(tools_request)

    # Add session ID header
    if (!is.null(session_id)) {
        req_tools <- httr2::req_headers(req_tools, `mcp-session-id` = session_id)
    }

    # Add other headers
    if (!is.null(server$headers)) {
        for (header_name in names(server$headers)) {
            req_tools <- httr2::req_headers(req_tools, !!!stats::setNames(
                list(server$headers[[header_name]]),
                header_name
            ))
        }
    }

    tools_resp <- tryCatch(
        httr2::req_perform(req_tools),
        error = function(e) {
            cli::cli_abort(
                c(
                    "Failed to list tools from MCP server {.val {server$name}}",
                    "i" = "Error: {e$message}"
                )
            )
        }
    )

    # Parse response
    tools_data <- httr2::resp_body_json(tools_resp)

    if (!is.null(tools_data$error)) {
        cli::cli_abort(
            c(
                "MCP server returned error",
                "i" = "Code: {tools_data$error$code}",
                "i" = "Message: {tools_data$error$message}"
            )
        )
    }

    # Extract tools
    mcp_tools <- tools_data$result$tools

    if (is.null(mcp_tools) || length(mcp_tools) == 0) {
        cli::cli_warn("No tools found on MCP server {.val {server$name}}")
        return(list(tools = list(), session_id = session_id))
    }

    return(list(tools = mcp_tools, session_id = session_id))
}
