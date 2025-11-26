# Function Parser for MCP Tools
#
# Parses function annotations to generate tool definitions

#' Generate tools and schemas definitions from functions annotations
#'
#' @description
#'
#' `as_tool()` parses annotations from a function and converts it to a generic
#' tool definition with an `args_schema` field. This standardized format can be
#' converted to provider-specific formats internally.
#'
#' Annotations use roxygen2-style `#'` comments inside the function body (not
#' outside like regular roxygen2 documentation). The annotation syntax follows
#' plumber2 conventions for type specifications.
#'
#' The package automatically enables source preservation when loaded. If you
#' defined functions before loading the package, simply redefine them after
#' loading argent.
#'
#' @param fn A function with annotations in its body comments using `#'` prefix.
#'   Supported tags:
#'   - `@description`: Function description
#'   - `@param name:type* description`: Parameter specification
#'
#'   Supported types: `string`, `integer`, `number`, `boolean`, `date`,
#'   `date-time`, and arrays using `[type]` syntax (e.g., `[integer]`).
#'   Enhanced support for nested objects: `{prop:Type, prop2:Type2}` and
#'   arrays of objects: `[{prop:Type}]`.
#'
#'   The `*` suffix marks a parameter as required. If a parameter has a
#'   default value in the function signature and no `*` suffix, it is
#'   optional. If it has a `*` suffix, it overrides the default and becomes
#'   required.
#'
#' @return A list with:
#'   - `name`: Tool name (character)
#'   - `description`: Tool description (character)
#'   - `args_schema`: JSON Schema object with `type`, `properties`, and `required` fields
#'   - `.fn`: The original function (with closure) for execution
#'
#' @export
#' @examples
#' \dontrun{
#' options(keep.source = TRUE)
#'
#' # Simple function with primitive types
#' my_fn <- function(x, y = 3L) {
#'     #' @description Add two numbers
#'     #' @param x:number* First number
#'     #' @param y:integer Second number (optional, has default)
#'     x + y
#' }
#'
#' as_tool(my_fn)
#'
#' # Function with nested objects
#' create_user <- function(user, settings = NULL) {
#'     #' @description Create a new user account
#'     #' @param user:{name:string*, email:string*, age:integer} User information
#'     #' @param settings:{theme:string, notifications:boolean} Optional settings
#'     list(user = user, settings = settings)
#' }
#'
#' as_tool(create_user)
#'
#' # Function with arrays
#' search_items <- function(tags, filters = NULL) {
#'     #' @description Search for items
#'     #' @param tags:[string]* List of tags to search
#'     #' @param filters:{category:string, minPrice:number} Optional filters
#'     list(tags = tags, filters = filters)
#' }
#'
#' as_tool(search_items)
#' }
as_tool <- function(fn) {
    if (!is.function(fn)) {
        cli::cli_abort("{.arg fn} must be a function")
    }

    fn_name <- deparse(substitute(fn))
    if (grepl("^function\\(", fn_name)) {
        cli::cli_abort("Anonymous functions are not supported. Assign the function to a variable first.")
    }

    annotations <- extract_annotations(fn)
    if (length(annotations) == 0) {
        cli::cli_abort(c(
            "No MCP annotations found in function {.fn {fn_name}}",
            "x" = "Functions must have inline comments with {.code #'} prefix",
            "i" = "Annotations must be inside the function body, not above it",
            "i" = "If you defined this function before loading argent, redefine it",
            "i" = "For sourced files, use {.code source(file, keep.source = TRUE)}",
            "i" = "Example:",
            " " = "  my_fn <- function(x) {{",
            " " = "    #' @mcp tool",
            " " = "    #' @description Does something",
            " " = "    #' @param x:string Input",
            " " = "    # implementation",
            " " = "  }}"
        ))
    }

    # Group multi-line annotations into complete blocks
    annotations <- group_multiline_annotations(annotations)

    description <- extract_description(annotations)
    params <- extract_params(annotations)

    if (is.null(description)) {
        cli::cli_abort("@description tag is required for function {.fn {fn_name}}")
    }

    formals_list <- formals(fn)
    properties <- list()
    required <- character(0)

    is_schema_fn <- length(formals_list) == 0 && length(params) > 0

    for (param in params) {
        param_name <- param$name
        param_type <- param$type
        param_required <- param$required
        param_desc <- param$description

        if (!is_schema_fn && !param_name %in% names(formals_list)) {
            available_params <- if (length(formals_list) > 0) {
                paste(names(formals_list), collapse = ", ")
            } else {
                "none"
            }
            suggestion <- did_you_mean(param_name, names(formals_list))
            cli::cli_abort(c(
                "Parameter mismatch in function {.fn {fn_name}}",
                "x" = "Annotated parameter {.arg {param_name}} not in function signature",
                "i" = "Available parameters: {.val {available_params}}",
                if (!is.null(suggestion)) paste0("Did you mean: {.arg {suggestion}}")
            ))
        }

        if (is_schema_fn) {
            has_default <- FALSE
        } else {
            has_default <- !identical(formals_list[[param_name]], quote(expr = ))
        }

        # Use new type parser instead of parse_openapi_type()
        parsed <- parse_type_spec(param_type, param_name)

        properties[[param_name]] <- parsed$schema
        if (!is.null(param_desc)) {
            properties[[param_name]]$description <- param_desc
        }

        is_required <- infer_required(param_name, param_required, has_default)

        if (is_required) {
            required <- c(required, param_name)
        }
    }

    # Build args_schema even for no parameters
    args_schema <- list(
        type = "object",
        properties = if (length(params) > 0) properties else named_list(),
        required = if (length(required) > 0) as.list(required) else list()
    )

    list3(name = fn_name, description = description, args_schema = args_schema, .fn = fn)
}

# -----🔺 INTERNAL -------------------------------------------------------------

#' Extract annotation lines from function body
#' @noRd
extract_annotations <- function(fn) {
    body_expr <- body(fn)

    if (!is.call(body_expr) || as.character(body_expr[[1]]) != "{") {
        return(character(0))
    }

    body_lines <- as.list(body_expr[-1])
    comment_lines <- character(0)

    for (line in body_lines) {
        src_line <- attr(line, "srcref")
        if (!is.null(src_line)) {
            srcfile <- attr(src_line, "srcfile")
            if (!is.null(srcfile) && !is.null(srcfile$lines)) {
                line_text <- srcfile$lines[src_line[1]:src_line[3]]
                comments <- grep("^\\s*#'", line_text, value = TRUE)
                comment_lines <- c(comment_lines, comments)
            }
        }
    }

    if (length(comment_lines) == 0) {
        fn_src <- attr(fn, "srcref")
        if (!is.null(fn_src)) {
            srcfile <- attr(fn_src, "srcfile")
            if (!is.null(srcfile) && !is.null(srcfile$lines)) {
                if (length(srcfile$lines) == 1) {
                    all_lines <- strsplit(srcfile$lines, "\n")[[1]]
                    start_line <- fn_src[1]
                    end_line <- fn_src[3]
                    all_lines <- all_lines[start_line:end_line]
                } else {
                    start_line <- fn_src[1]
                    end_line <- fn_src[3]
                    all_lines <- srcfile$lines[start_line:end_line]
                }
                comment_lines <- grep("^\\s*#'", all_lines, value = TRUE)
            }
        }
    }

    gsub("^\\s*#'\\s*", "", comment_lines)
}

#' Group multi-line annotations into complete blocks
#' @noRd
group_multiline_annotations <- function(annotations) {
    if (length(annotations) == 0) {
        return(character(0))
    }

    grouped <- character(0)
    current_block <- NULL

    for (line in annotations) {
        # Check if line starts a new tag block
        if (grepl("^@\\w+", line)) {
            # Save previous block if it exists
            if (!is.null(current_block)) {
                grouped <- c(grouped, current_block)
            }
            # Start new block
            current_block <- line
        } else {
            # Continuation line - append to current block
            if (!is.null(current_block)) {
                # Trim leading whitespace and join with space
                line_trimmed <- trimws(line)
                if (nchar(line_trimmed) > 0) {
                    current_block <- paste(current_block, line_trimmed)
                }
            }
        }
    }

    # Don't forget the last block
    if (!is.null(current_block)) {
        grouped <- c(grouped, current_block)
    }

    grouped
}

#' Extract description from annotations
#' @noRd
extract_description <- function(annotations) {
    desc_lines <- grep("^@description\\s+", annotations, value = TRUE)
    if (length(desc_lines) == 0) {
        return(NULL)
    }
    paste(gsub("^@description\\s+", "", desc_lines), collapse = " ")
}

#' Extract parameter specifications from annotations
#' @noRd
extract_params <- function(annotations) {
    param_lines <- grep("^@param\\s+", annotations, value = TRUE)
    if (length(param_lines) == 0) {
        return(list())
    }

    lapply(param_lines, function(line) {
        line <- gsub("^@param\\s+", "", line)
        split_param_spec(line)
    })
}

#' Split parameter specification into components
#'
#' Adapted from plumber2 with enhancements for complex nested types.
#'
#' @param x Character. Parameter spec string (e.g., "name:string* Description")
#' @return List with name, type, required, and description fields
#' @noRd
split_param_spec <- function(x) {
    # Find first colon to split name from rest
    colon_pos <- regexpr(":", x)
    if (colon_pos == -1) {
        # No colon - assume simple name with default type
        return(list(name = trimws(x), type = "string", required = FALSE, description = NULL))
    }

    name <- trimws(substr(x, 1, colon_pos - 1))
    rest <- trimws(substr(x, colon_pos + 1, nchar(x)))

    # Find where type ends (before description)
    # Description starts at first space outside brackets/braces
    type_end <- find_type_end(rest)
    type_spec <- trimws(substr(rest, 1, type_end))
    description <- trimws(substr(rest, type_end + 1, nchar(rest)))

    # Parse type specification for required marker
    type_info <- split_type_spec(type_spec)

    return(list(
        name = name,
        type = type_info$type,
        required = type_info$required,
        description = if (nchar(description) > 0) description else NULL
    ))
}

#' Find where type specification ends in a param spec
#'
#' Searches for the first space outside of brackets, braces, or parens.
#' This space marks the boundary between type and description.
#'
#' @param str Character. String containing type and possibly description
#' @return Integer. Position where type ends (last character of type)
#' @noRd
find_type_end <- function(str) {
    depth <- 0

    for (i in seq_len(nchar(str))) {
        char <- substr(str, i, i)

        if (char %in% c("{", "[", "(")) {
            depth <- depth + 1
        } else if (char %in% c("}", "]", ")")) {
            depth <- depth - 1
        } else if (char == " " && depth == 0) {
            # Space outside brackets = end of type
            return(i - 1)
        }
    }

    # No space found = entire string is type
    return(nchar(str))
}

#' Split type specification into components
#'
#' Extracts the type and required marker from a type spec string.
#'
#' @param x Character. Type spec (e.g., "string*", "[integer]", "{name:string*}")
#' @return List with type and required fields
#' @noRd
split_type_spec <- function(x) {
    pattern <- "^(.*?)(\\*)?$"
    matches <- regmatches(x, regexec(pattern, x, perl = TRUE))[[1]]

    if (length(matches) < 2) {
        return(list(type = "string", required = FALSE))
    }

    type <- matches[2]
    required <- length(matches) >= 3 && nchar(matches[3]) > 0

    if (nchar(type) == 0) {
        type <- "string"
    }

    return(list(type = type, required = required))
}

#' Infer whether a parameter is required
#' @noRd
infer_required <- function(param_name, has_star, has_default) {
    if (has_star) {
        return(TRUE)
    }
    if (has_default) {
        return(FALSE)
    }
    return(FALSE)
}

#' Suggest a parameter name based on string distance
#' @noRd
did_you_mean <- function(input, options) {
    if (length(options) == 0) {
        return(NULL)
    }
    distances <- adist(input, options)
    min_dist <- min(distances)
    if (min_dist > 3) {
        return(NULL)
    }
    options[which.min(distances)]
}
