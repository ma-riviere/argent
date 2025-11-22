#' MCP (Model Context Protocol) Integration
#'
#' @description
#' Functions for integrating MCP servers with argent. MCP servers provide tools,
#' resources, and prompts that LLMs can use during conversations.
#'
#' ## MCP Server Connection
#'
#' `mcp_connect()` creates a client connection to an MCP server.
#' - For **stdio** servers (command-line tools), it spawns a subprocess.
#' - For **HTTP** servers (remote APIs), it configures the endpoint.
#'
#' ## Capability Discovery
#'
#' - `mcp_tools()` retrieves tool definitions from a connected MCP client and
#'   converts them to argent's tool format.
#' - `mcp_resources()` retrieves resource definitions from a connected MCP client.
#'   Resources expose data/content via URIs (files, datasets, documentation, etc.).
#' - `mcp_prompts()` retrieves prompt definitions from a connected MCP client.
#'   Prompts are pre-defined message templates with optional arguments.
#'
#' @name mcp_integration
#'
#' @param name Character. Name identifier for the MCP server
#' @param type Character. Server type: "stdio" for command-line or "http" for HTTP endpoint (default: "stdio")
#' @param command Character. Command to execute (for stdio servers, e.g., "docker", "npx")
#' @param args Character vector. Arguments to pass to the command (for stdio servers)
#' @param env Named list. Environment variables for the server process (for stdio servers)
#' @param url Character. HTTP endpoint URL (for http servers)
#' @param headers Named list. HTTP headers (for http servers)
#' @param client An MCP client object returned by `mcp_connect()`
#' @param tools Character vector. Specific tool names to retrieve. If NULL, retrieves all tools
#' @param resources Character vector. Specific resource URIs to retrieve. If NULL, retrieves all
#' @param prompts Character vector. Specific prompt names to retrieve. If NULL, retrieves all
#'
#' @return
#' - `mcp_connect()`: An `McpClient` object (R6)
#' - `mcp_tools()`: List of tool definitions in argent format
#' - `mcp_resources()`: List of resource definitions in argent format
#' - `mcp_prompts()`: List of prompt definitions in argent format
#'
#' @export
#' @rdname mcp_integration
mcp_connect <- function(
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

    if (type == "http") {
        if (is.null(url) || !is.character(url) || length(url) != 1) {
            cli::cli_abort("For HTTP servers, {.arg url} is required")
        }
        if (!is.null(headers) && !is.list(headers)) {
            cli::cli_abort("{.arg headers} must be a named list")
        }
        
        client <- McpClientHttp$new(url = url, headers = headers)
        client$name <- name
        return(client)
        
    } else {
        if (is.null(command) || !is.character(command) || length(command) != 1) {
            cli::cli_abort("For stdio servers, {.arg command} is required")
        }
        if (!is.null(args) && !is.character(args)) {
            cli::cli_abort("{.arg args} must be a character vector")
        }
        if (!is.null(env) && !is.list(env)) {
            cli::cli_abort("{.arg env} must be a named list")
        }
        
        client <- McpClientStdio$new(command = command, args = args, env = env)
        client$name <- name
        return(client)
    }
}

#' @export
#' @rdname mcp_integration
mcp_tools <- function(client, tools = NULL) {
    if (!inherits(client, "McpClient")) {
        cli::cli_abort("{.arg client} must be an McpClient object returned by {.fun mcp_connect}")
    }

    # Fetch tools from client
    server_tools <- tryCatch(
        client$list_tools(),
        error = function(e) {
            cli::cli_abort(c(
                "Failed to retrieve tools from MCP server {.val {client$name}}",
                "i" = "Error: {e$message}"
            ))
        }
    )

    # Filter specific tools if requested
    if (!is.null(tools)) {
        if (!is.character(tools)) {
            cli::cli_abort("{.arg tools} must be a character vector")
        }
        server_tools <- purrr::keep(server_tools, \(tool) tool$name %in% tools)
    }

    # Convert to argent format
    argent_tools <- purrr::map(server_tools, \(tool) {
        argent_tool <- list(
            name = tool$name,
            description = tool$description %||% ""
        )

        # Map inputSchema to args_schema
        if (!is.null(tool$inputSchema)) {
            argent_tool$args_schema <- tool$inputSchema
        } else {
            argent_tool$args_schema <- list(type = "object", properties = named_list())
        }

        # Add metadata
        argent_tool[[".mcp"]] <- list(
            type = "tool",
            client = client,
            server_name = client$name
        )
        return(argent_tool)
    })
    return(argent_tools)
}

#' Execute an MCP tool
#'
#' @param tool_def List. The tool definition with .mcp metadata
#' @param arguments List. The arguments to pass to the tool
#'
#' @return The result of the tool execution
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

    client <- mcp_metadata$client
    if (is.null(client) || !inherits(client, "McpClient")) {
        cli::cli_abort("No active MCP client found for tool {.val {tool_name}}")
    }

    result <- tryCatch(
        client$call_tool(tool_name, arguments),
        error = function(e) {
            # Return R-level errors (connection issues, etc.) as error results
            return(list(
                isError = TRUE,
                error = list(
                    code = "R_ERROR",
                    message = e$message
                )
            ))
        }
    )

    # MCP errors are already in the correct format (isError = TRUE, error = ...)
    # Return them as-is so LLMs can see and respond to the error message
    return(result)
}

#' Get an MCP tool from a list of tool definitions (convenience function)
#'
#' @param tool_defs List. A list of tool definitions
#' @param tool_name Character. The name of the tool to get
#'
#' @return The tool definition
#' @export
get_mcp_tool <- function(tool_defs, tool_name) {
    if (!is.list(tool_defs)) {
        cli::cli_abort("{.arg tool_defs} must be a list")
    }

    if (!is.character(tool_name) || length(tool_name) != 1 || nchar(tool_name) == 0) {
        cli::cli_abort("{.arg tool_name} must be a non-empty string")
    }

    matching_tools <- purrr::keep(tool_defs, \(tool) tool$name == tool_name)
    if (purrr::is_empty(matching_tools)) {
        cli::cli_abort("Tool {.val {tool_name}} not found in the provided tool definitions")
    }

    return(matching_tools[[1]])
}

#' Read an MCP resource
#'
#' @param resource_def List. The resource definition with .mcp metadata
#'
#' @return The content of the resource
#' @export
read_mcp_resource <- function(resource_def) {
    resource_uri <- resource_def$uri
    if (purrr::is_empty(resource_uri)) {
        cli::cli_abort("Resource definition has no URI")
    }

    mcp_metadata <- resource_def[[".mcp"]]
    if (purrr::is_empty(mcp_metadata)) {
        cli::cli_abort("Resource {.val {resource_uri}} is not an MCP resource")
    }

    client <- mcp_metadata$client
    if (is.null(client) || !inherits(client, "McpClient")) {
        cli::cli_abort("No active MCP client found for resource {.val {resource_uri}}")
    }

    result <- tryCatch(
        client$read_resource(resource_uri),
        error = function(e) {
            # Return R-level errors as error results
            return(list(
                isError = TRUE,
                error = list(
                    code = "R_ERROR",
                    message = e$message
                )
            ))
        }
    )

    # MCP errors are already in the correct format
    # Return them as-is so LLMs can see and respond to the error message
    return(result)
}

#' Get an MCP prompt
#'
#' @param prompt_def List. The prompt definition with .mcp metadata
#' @param arguments List. The arguments to pass to the prompt
#'
#' @return The prompt result with messages
#' @export
get_mcp_prompt <- function(prompt_def, arguments = NULL) {
    prompt_name <- prompt_def$name
    if (purrr::is_empty(prompt_name)) {
        cli::cli_abort("Prompt definition has no name")
    }

    mcp_metadata <- prompt_def[[".mcp"]]
    if (purrr::is_empty(mcp_metadata)) {
        cli::cli_abort("Prompt {.val {prompt_name}} is not an MCP prompt")
    }

    client <- mcp_metadata$client
    if (is.null(client) || !inherits(client, "McpClient")) {
        cli::cli_abort("No active MCP client found for prompt {.val {prompt_name}}")
    }

    result <- tryCatch(
        client$get_prompt(prompt_name, arguments),
        error = function(e) {
            # Return R-level errors as error results
            return(list(
                isError = TRUE,
                error = list(
                    code = "R_ERROR",
                    message = e$message
                )
            ))
        }
    )

    # MCP errors are already in the correct format
    # Return them as-is so LLMs can see and respond to the error message
    return(result)
}

#' @export
#' @rdname mcp_integration
mcp_resources <- function(client, resources = NULL) {
    if (!inherits(client, "McpClient")) {
        cli::cli_abort("{.arg client} must be an McpClient object returned by {.fun mcp_connect}")
    }

    # Fetch resources from client
    server_resources <- tryCatch(
        client$list_resources(),
        error = function(e) {
            if (grepl("Method not found|not implemented", e$message, ignore.case = TRUE)) {
                cli::cli_abort(c(
                    "MCP server {.val {client$name}} does not support resources",
                    "i" = "This server only advertises support for: tools"
                ))
            }
            cli::cli_abort(c(
                "Failed to retrieve resources from MCP server {.val {client$name}}",
                "i" = "Error: {e$message}"
            ))
        }
    )

    # Filter specific resources if requested
    if (!is.null(resources)) {
        if (!is.character(resources)) {
            cli::cli_abort("{.arg resources} must be a character vector")
        }
        server_resources <- purrr::keep(server_resources, \(resource) resource$uri %in% resources)
    }

    # Convert to argent format
    argent_resources <- purrr::map(server_resources, \(resource) {
        argent_resource <- list(
            uri = resource$uri,
            name = resource$name,
            description = resource$description %||% "",
            mimeType = resource$mimeType %||% "text/plain"
        )

        # Add metadata
        argent_resource[[".mcp"]] <- list(
            type = "resource",
            client = client,
            server_name = client$name
        )
        return(argent_resource)
    })
    return(argent_resources)
}

#' @export
#' @rdname mcp_integration
mcp_prompts <- function(client, prompts = NULL) {
    if (!inherits(client, "McpClient")) {
        cli::cli_abort("{.arg client} must be an McpClient object returned by {.fun mcp_connect}")
    }

    # Fetch prompts from client
    server_prompts <- tryCatch(
        client$list_prompts(),
        error = function(e) {
            if (grepl("Method not found|not implemented", e$message, ignore.case = TRUE)) {
                cli::cli_abort(c(
                    "MCP server {.val {client$name}} does not support prompts",
                    "i" = "This server only advertises support for: tools"
                ))
            }
            cli::cli_abort(c(
                "Failed to retrieve prompts from MCP server {.val {client$name}}",
                "i" = "Error: {e$message}"
            ))
        }
    )

    # Filter specific prompts if requested
    if (!is.null(prompts)) {
        if (!is.character(prompts)) {
            cli::cli_abort("{.arg prompts} must be a character vector")
        }
        server_prompts <- purrr::keep(server_prompts, \(prompt) prompt$name %in% prompts)
    }

    # Convert to argent format
    argent_prompts <- purrr::map(server_prompts, \(prompt) {
        argent_prompt <- list(
            name = prompt$name,
            description = prompt$description %||% "",
            arguments = prompt$arguments
        )

        # Add metadata
        argent_prompt[[".mcp"]] <- list(
            type = "prompt",
            client = client,
            server_name = client$name
        )
        return(argent_prompt)
    })
    return(argent_prompts)
}
