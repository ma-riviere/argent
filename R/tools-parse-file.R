# File Parser for MCP Tools
#
# Parses entire R files to extract annotated tools, resources, and prompts
# using inline annotations (inside function body) - same style as as_tool()

#' Parse a file and extract all MCP definitions (tools/resources/prompts)
#'
#' @description
#' Parses an R file and extracts functions with MCP annotations. Functions must
#' use inline annotations (inside the function body with `#'` prefix) similar to
#' `as_tool()`.
#'
#' Supported annotations:
#' - `@description`: Function description (required)
#' - `@mcp tool|resource|prompt`: MCP type (defaults to "tool" if omitted)
#' - `@group`: Group name for organizing tools (defaults to "general")
#' - `@param name:type* description`: Parameter specification (for tools/prompts)
#' - `@uri`: Resource URI (for resources)
#' - `@mimeType`: Resource MIME type (for resources)
#'
#' @param file Character. Path to R file with annotated functions
#' @param groups Character vector. Optional. If provided, only return tools/resources/prompts
#'   in the specified groups. If NULL (default), return all.
#' @return List with `tools`, `resources`, `prompts` fields (each a list)
#' @keywords internal
#' @examples
#' \dontrun{
#' # Parse a file with annotated tools
#' parsed <- parse_mcp_file("inst/examples/zotero_tools.R")
#'
#' # Parse only specific groups
#' parsed <- parse_mcp_file("inst/examples/all_tools.R", groups = c("zotero", "web"))
#'
#' # Inspect results
#' length(parsed$tools)      # Number of tools found
#' length(parsed$resources)  # Number of resources found
#' length(parsed$prompts)    # Number of prompts found
#'
#' # Access a specific tool
#' tool <- parsed$tools[[1]]
#' tool$name
#' tool$description
#' tool$group
#' tool$args_schema
#' }
parse_mcp_file <- function(file, groups = NULL) {
    if (!file.exists(file)) {
        cli::cli_abort("File not found: {.file {file}}")
    }

    # Source the file into an environment to get function definitions
    env <- new.env(parent = .GlobalEnv)

    tryCatch(source(file, local = env, keep.source = TRUE), error = function(e) {
        cli::cli_abort(c(
            "Failed to source file {.file {file}}",
            "x" = "R error: {e$message}",
            "i" = "Check for syntax errors in the file",
            "i" = "Ensure all required packages are loaded"
        ))
    })

    result <- list(tools = list(), resources = list(), prompts = list())

    # Find all functions in the environment
    fn_names <- ls(env)
    fn_names <- fn_names[sapply(fn_names, function(n) is.function(env[[n]]))]

    for (fn_name in fn_names) {
        fn <- env[[fn_name]]
        parsed <- parse_mcp_function(fn, fn_name)

        if (!is.null(parsed)) {
            type <- parsed$type
            category <- paste0(type, "s")
            result[[category]] <- c(result[[category]], list(parsed$definition))
        }
    }

    # Filter by groups if specified
    if (!is.null(groups)) {
        result$tools <- purrr::keep(result$tools, \(t) t$group %in% groups)
        result$resources <- purrr::keep(result$resources, \(r) r$group %in% groups)
        result$prompts <- purrr::keep(result$prompts, \(p) p$group %in% groups)
    }

    return(result)
}

#' Parse a single function for MCP definitions
#'
#' @param fn Function object
#' @param fn_name Character. Function name
#' @return List with `type` and `definition`, or NULL if not an MCP function
#' @keywords internal
#' @noRd
parse_mcp_function <- function(fn, fn_name) {
    # Extract inline annotations from function body
    annotations <- extract_annotations(fn)

    if (length(annotations) == 0) {
        return(NULL) # No annotations - skip
    }

    # Group multi-line annotations
    annotations <- group_multiline_annotations(annotations)

    # Extract description
    description <- extract_description(annotations)
    if (is.null(description)) {
        return(NULL) # No description - skip
    }

    # Extract MCP type (default to "tool")
    mcp_type <- extract_mcp_type(annotations)

    # Dispatch to type-specific parser
    definition <- switch(
        mcp_type,
        tool = parse_tool_from_annotations(fn, fn_name, description, annotations),
        resource = parse_resource_from_annotations(fn, fn_name, description, annotations),
        prompt = parse_prompt_from_annotations(fn, fn_name, description, annotations)
    )

    return(list(type = mcp_type, definition = definition))
}

#' Extract @mcp type from annotations
#' @noRd
extract_mcp_type <- function(annotations) {
    mcp_lines <- grep("^@mcp\\s+", annotations, value = TRUE)

    if (length(mcp_lines) == 0) {
        return("tool") # Default
    }

    mcp_type <- trimws(gsub("^@mcp\\s+", "", mcp_lines[1]))

    if (!mcp_type %in% c("tool", "resource", "prompt")) {
        cli::cli_warn("Unknown @mcp type: {.val {mcp_type}} - defaulting to tool")
        return("tool")
    }

    return(mcp_type)
}

#' Extract @group from annotations
#' @noRd
extract_group <- function(annotations) {
    group_lines <- grep("^@group\\s+", annotations, value = TRUE)

    if (length(group_lines) == 0) {
        return("general") # Default group
    }

    group <- trimws(gsub("^@group\\s+", "", group_lines[1]))
    return(group)
}

#' Parse tool from inline annotations
#' @noRd
parse_tool_from_annotations <- function(fn, fn_name, description, annotations) {
    params <- extract_params(annotations)
    group <- extract_group(annotations)
    formals_list <- formals(fn)

    properties <- list()
    required <- character()

    for (param in params) {
        param_name <- param$name
        param_type <- param$type
        param_required <- param$required
        param_desc <- param$description

        # Use type parser
        parsed <- parse_type_spec(param_type, param_name)

        properties[[param_name]] <- parsed$schema
        if (!is.null(param_desc)) {
            properties[[param_name]]$description <- param_desc
        }

        has_default <- !identical(formals_list[[param_name]], quote(expr = ))
        is_required <- infer_required(param_name, param_required, has_default)

        if (is_required) {
            required <- c(required, param_name)
        }
    }

    return(list(
        name = fn_name,
        description = description,
        group = group,
        args_schema = list(
            type = "object",
            properties = if (length(properties) > 0) properties else named_list(),
            required = if (length(required) > 0) as.list(required) else list()
        ),
        .fn = fn
    ))
}

#' Parse resource from inline annotations
#' @noRd
parse_resource_from_annotations <- function(fn, fn_name, description, annotations) {
    group <- extract_group(annotations)

    # Extract @uri
    uri_lines <- grep("^@uri\\s+", annotations, value = TRUE)
    uri <- if (length(uri_lines) > 0) {
        trimws(gsub("^@uri\\s+", "", uri_lines[1]))
    } else {
        paste0("resource://", fn_name)
    }

    # Extract @mimeType
    mime_lines <- grep("^@mimeType\\s+", annotations, value = TRUE)
    mime_type <- if (length(mime_lines) > 0) {
        trimws(gsub("^@mimeType\\s+", "", mime_lines[1]))
    } else {
        "text/plain"
    }

    return(list(
        uri = uri,
        name = fn_name,
        description = description,
        group = group,
        mimeType = mime_type,
        .fn = fn
    ))
}

#' Parse prompt from inline annotations
#' @noRd
parse_prompt_from_annotations <- function(fn, fn_name, description, annotations) {
    params <- extract_params(annotations)
    group <- extract_group(annotations)
    formals_list <- formals(fn)

    arguments <- list()

    for (param in params) {
        param_name <- param$name
        has_default <- !identical(formals_list[[param_name]], quote(expr = ))
        is_required <- infer_required(param_name, param$required, has_default)

        arg_def <- list(name = param_name, description = param$description %||% "", required = is_required)

        arguments <- c(arguments, list(arg_def))
    }

    return(list(name = fn_name, description = description, group = group, arguments = arguments, .fn = fn))
}
