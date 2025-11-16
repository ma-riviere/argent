#' Generate tools and schemas definitions from functions annotations, or direct specification
#'
#' @description
#'
#' ## Annotation-based approach
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
#' ## Direct specification approach
#'
#' `tool()` creates a tool definition by directly specifying parameters, as an
#' alternative to using function annotations with `as_tool()`. This approach
#' is useful for complex nested structures or when defining tools without
#' corresponding R functions.
#'
#' `schema()` is similar to `tool()` but designed for structured output schemas.
#' It includes additional fields (`strict` and `additionalProperties`) required
#' by some LLM providers for structured outputs.
#'
#' Parameters are specified as named arguments. Each parameter value can be:
#' - A string: `"type[*] [description]"` (e.g., `"string* The user's name"`)
#' - A list: For nested objects with `type` field and nested properties
#'
#' @param fn A function with annotations in its body comments using `#'` prefix.
#'   Supported tags:
#'   - `@description`: Function description
#'   - `@param name:type* description`: Parameter specification
#'
#'   Supported types: `string`, `integer`, `number`, `boolean`, `date`,
#'   `date-time`, and arrays using `[type]` syntax (e.g., `[integer]`).
#'
#'   The `*` suffix marks a parameter as required. If a parameter has a
#'   default value in the function signature and no `*` suffix, it is
#'   optional. If it has a `*` suffix, it overrides the default and becomes
#'   required.
#' @param name Character. The tool or schema name
#' @param description Character. What the tool does or what the schema represents
#' @param ... Named parameter specifications. See Details.
#' @param strict Logical. For `schema()` only. Whether to use strict mode (defaults to TRUE).
#'   Added at root level of the schema definition.
#' @param additional_properties Logical. For `schema()` only. Whether to allow additional
#'   properties in the schema (defaults to FALSE). Added to `args_schema`.
#'
#' @return For `tool()`: A list with:
#'   - `name`: Tool name (character)
#'   - `description`: Tool description (character)
#'   - `args_schema`: JSON Schema object with `type`, `properties`, and `required` fields
#'
#'   For `schema()`: Same as `tool()` but with additional fields:
#'   - `strict`: Logical (at root level)
#'   - `args_schema$additionalProperties`: Logical (inside args_schema)
#'
#' @details
#' ## Type Specifications (for `tool()`)
#'
#' **Primitive types:** `string`, `integer`, `number`, `boolean`, `date`,
#' `date-time`
#'
#' **Arrays:** Use `[type]` syntax (e.g., `"[string]"`, `"[integer]"`)
#'
#' **Required marker:** Add `*` after type (e.g., `"string*"`)
#'
#' **Descriptions:** Add text after type (e.g., `"string* The user's name"`)
#'
#' **Nested objects:** Use list with `type = "object"` or `type = "object*"`:
#' ```r
#' address = list(
#'   type = "object*",
#'   description = "Mailing address",
#'   street = "string* Street address",
#'   city = "string* City name"
#' )
#' ```
#'
#' **Arrays of objects:** Use `type = "[object]"`:
#' ```r
#' users = list(
#'   type = "[object]*",
#'   description = "List of users",
#'   name = "string*",
#'   email = "string*"
#' )
#' ```
#'
#' @name tool_definitions
#' @examples
#' \dontrun{
#' # Annotation-based approach
#' options(keep.source = TRUE)
#'
#' my_fn <- function(x, y = 3L) {
#'     #' @description Add two numbers
#'     #' @param x:number* First number
#'     #' @param y:integer Second number (optional, has default)
#'     x + y
#' }
#'
#' as_tool(my_fn)
#'
#' # Direct specification - tool()
#' search_tool <- tool(
#'   name = "search_db",
#'   description = "Search the database",
#'   query = "string* Search query",
#'   limit = "integer Maximum results to return"
#' )
#'
#' # Direct specification - schema()
#' output_schema <- schema(
#'   name = "flight_search",
#'   description = "Flight search results",
#'   destination = "string* Destination city",
#'   departure_date = "string* Departure date",
#'   passengers = "integer* Number of passengers",
#'   strict = TRUE,
#'   additional_properties = FALSE
#' )
#'
#' # Nested object
#' create_user_tool <- tool(
#'   name = "create_user",
#'   description = "Create a new user",
#'   name = "string* User's full name",
#'   address = list(
#'     type = "object*",
#'     description = "User's mailing address",
#'     street = "string* Street address",
#'     city = "string* City name",
#'     zip = "string Postal code"
#'   )
#' )
#' }
NULL

#' @export
#' @rdname tool_definitions
as_tool <- function(fn) {
    if (!is.function(fn)) {
        cli::cli_abort("{.arg fn} must be a function")
    }

    fn_name <- deparse(substitute(fn))
    if (grepl("^function\\(", fn_name)) {
        cli::cli_abort(
            "Anonymous functions are not supported. Assign the function to a variable first."
        )
    }

    annotations <- extract_annotations(fn)
    if (length(annotations) == 0) {
        cli::cli_abort(
            c(
                "No annotations found in function {.fn {fn_name}}",
                "i" = "Annotations must be inside the function body as comments starting with {.code #'}",
                "i" = "If you defined this function before loading argent, simply redefine it.",
                "i" = "For sourced files, use {.code source(..., keep.source = TRUE)}."
            )
        )
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
            cli::cli_abort(
                "Parameter {.arg {param_name}} in annotations does not exist in function signature"
            )
        }

        if (is_schema_fn) {
            has_default <- FALSE
        } else {
            has_default <- !identical(formals_list[[param_name]], quote(expr = ))
        }

        is_required <- infer_required(param_name, param_required, has_default)

        properties[[param_name]] <- parse_openapi_type(param_type)
        if (!is.null(param_desc)) {
            properties[[param_name]]$description <- param_desc
        }

        if (is_required) {
            required <- c(required, param_name)
        }
    }

    # If no parameters, don't include args_schema
    args_schema <- if (length(params) > 0) {
        list(
            type = "object",
            properties = properties,
            required = if (length(required) > 0) as.list(required) else list()
        )
    } else {
        NULL
    }

    list3(
        name = fn_name,
        description = description,
        args_schema = args_schema
    )
}


# Internal helper functions ---------------------------------------------------

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
                comments <- grep("^\\s*#\\*", line_text, value = TRUE)
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
    if (length(desc_lines) == 0) return(NULL)
    paste(gsub("^@description\\s+", "", desc_lines), collapse = " ")
}

#' Extract parameter specifications from annotations
#' @noRd
extract_params <- function(annotations) {
    param_lines <- grep("^@param\\s+", annotations, value = TRUE)
    if (length(param_lines) == 0) return(list())

    lapply(param_lines, function(line) {
        line <- gsub("^@param\\s+", "", line)
        split_param_spec(line)
    })
}

#' Split parameter specification into components
#' Adapted from plumber2
#' @noRd
split_param_spec <- function(x) {
    pattern <- "^(\\w*)(:?(.*?))?((?<!,|:)\\s(.*))?$"
    matches <- regmatches(x, regexec(pattern, x, perl = TRUE))[[1]]

    if (length(matches) < 2) {
        cli::cli_abort("Invalid parameter specification: {.val {x}}")
    }

    name <- matches[2]
    type_spec <- if (nchar(matches[4]) > 0) matches[4] else "string"
    description <- if (length(matches) >= 6 && nchar(matches[6]) > 0) matches[6] else NULL

    type_info <- split_type_spec(type_spec)

    list(
        name = name,
        type = type_info$type,
        required = type_info$required,
        description = description
    )
}

#' Split type specification into components
#' Adapted from plumber2
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

    list(
        type = type,
        required = required
    )
}

#' Parse plumber2 type specification to OpenAPI/JSON Schema
#' Adapted from plumber2
#' @noRd
parse_openapi_type <- function(type_str) {
    if (grepl("^\\[(.+)\\]$", type_str)) {
        inner_type <- gsub("^\\[(.+)\\]$", "\\1", type_str)
        return(list(
            type = "array",
            items = parse_openapi_type(inner_type)
        ))
    }

    type_map <- list(
        string = list(type = "string"),
        integer = list(type = "integer"),
        number = list(type = "number"),
        boolean = list(type = "boolean"),
        date = list(type = "string", format = "date"),
        "date-time" = list(type = "string", format = "date-time")
    )

    if (type_str %in% names(type_map)) {
        return(type_map[[type_str]])
    }

    cli::cli_warn(
        "Unknown type {.val {type_str}}, defaulting to {.val string}"
    )
    list(type = "string")
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

# Direct specification functions ----------------------------------------------

#' @rdname tool_definitions
#' @export
tool <- function(name, description, ...) {
    if (!is.character(name) || length(name) != 1 || nchar(name) == 0) {
        cli::cli_abort("{.arg name} must be a non-empty string")
    }

    if (!is.character(description) || length(description) != 1 || nchar(description) == 0) {
        cli::cli_abort("{.arg description} must be a non-empty string")
    }

    params <- list(...)

    if (length(params) == 0) {
        cli::cli_warn("No parameters specified for tool {.val {name}}")
    }

    build_spec_from_params(name, description, params)
}

#' @rdname tool_definitions
#' @export
schema <- function(name, description, ..., strict = TRUE, additional_properties = FALSE) {
    if (!is.character(name) || length(name) != 1 || nchar(name) == 0) {
        cli::cli_abort("{.arg name} must be a non-empty string")
    }

    if (!is.character(description) || length(description) != 1 || nchar(description) == 0) {
        cli::cli_abort("{.arg description} must be a non-empty string")
    }

    params <- list(...)

    if (length(params) == 0) {
        cli::cli_warn("No parameters specified for schema {.val {name}}")
    }

    build_spec_from_params(name, description, params, strict = strict, additional_properties = additional_properties)
}

# -----🔺 INTERNAL -------------------------------------------------------------

#' Build specification from parameter list
#' @keywords internal
#' @noRd
build_spec_from_params <- function(name, description, params, strict = NULL, additional_properties = NULL) {
    properties <- list()
    required <- character(0)

    for (param_name in names(params)) {
        parsed <- parse_param_spec(params[[param_name]], param_name)

        properties[[param_name]] <- parsed$schema

        if (parsed$required) {
            required <- c(required, param_name)
        }
    }

    # If no parameters, don't include args_schema
    args_schema <- NULL
    if (length(params) > 0) {
        args_schema <- list(
            type = "object",
            properties = properties,
            required = if (length(required) > 0) as.list(required) else list()
        )
        if (!is.null(additional_properties)) {
            args_schema$additionalProperties <- additional_properties
        }
    }

    list3(
        name = name,
        description = description,
        strict = strict,
        args_schema = args_schema
    )
}

#' Parse a single parameter specification
#' @keywords internal
#' @noRd
parse_param_spec <- function(spec, param_name) {
    if (is.character(spec) && length(spec) == 1) {
        return(parse_string_spec(spec))
    }

    if (is.list(spec)) {
        return(parse_list_spec(spec, param_name))
    }

    cli::cli_abort(
        "Parameter {.arg {param_name}} must be a string or list specification"
    )
}

#' Parse string type specification
#' @keywords internal
#' @noRd
parse_string_spec <- function(spec_str) {
    required <- grepl("\\*", spec_str)
    spec_clean <- gsub("\\*", "", spec_str)

    pattern <- "^(\\S+)\\s*(.*)"
    matches <- regmatches(spec_clean, regexec(pattern, spec_clean))[[1]]

    if (length(matches) < 2) {
        cli::cli_abort("Invalid type specification: {.val {spec_str}}")
    }

    type_str <- matches[2]
    desc_str <- if (length(matches) >= 3 && nchar(matches[3]) > 0) matches[3] else NULL

    if (grepl("^\\[(.+)\\]$", type_str)) {
        inner_type <- gsub("^\\[(.+)\\]$", "\\1", type_str)
        schema <- list(
            type = "array",
            items = parse_openapi_type(inner_type)
        )
    } else {
        schema <- parse_openapi_type(type_str)
    }

    if (!is.null(desc_str)) {
        schema$description <- desc_str
    }

    list(
        schema = schema,
        required = required
    )
}

#' Parse list specification for nested objects
#' @keywords internal
#' @noRd
parse_list_spec <- function(spec_list, param_name) {
    if (is.null(spec_list$type)) {
        cli::cli_abort(
            "List specification for {.arg {param_name}} must have a {.field type} field"
        )
    }

    type_str <- spec_list$type
    required <- grepl("\\*", type_str)
    type_clean <- gsub("\\*", "", type_str)

    is_array <- grepl("^\\[object\\]$", type_clean)
    is_object <- type_clean == "object"

    if (!is_array && !is_object) {
        cli::cli_abort(
            c(
                "List specifications are only supported for object types",
                "i" = "Got type: {.val {type_clean}} for {.arg {param_name}}"
            )
        )
    }

    meta_fields <- c("type", "description")
    prop_names <- setdiff(names(spec_list), meta_fields)

    properties <- list()
    required_fields <- character(0)

    for (prop_name in prop_names) {
        parsed <- parse_param_spec(spec_list[[prop_name]], prop_name)
        properties[[prop_name]] <- parsed$schema

        if (parsed$required) {
            required_fields <- c(required_fields, prop_name)
        }
    }

    object_schema <- list(
        type = "object",
        properties = properties,
        required = if (length(required_fields) > 0) as.list(required_fields) else list()
    )

    if (!is.null(spec_list$description)) {
        object_schema$description <- spec_list$description
    }

    if (is_array) {
        # Build array schema with correct field order
        final_schema <- list(type = "array")
        
        # Add description before items if it exists
        if (!is.null(spec_list$description)) {
            final_schema$description <- spec_list$description
        }
        
        # Add items last (without description in object_schema)
        object_schema$description <- NULL
        final_schema$items <- object_schema
    } else {
        final_schema <- object_schema
    }

    list(
        schema = final_schema,
        required = required
    )
}

# Tool validation functions ---------------------------------------------------

#' Check if an object is a valid custom tool definition
#'
#' Validates that an object conforms to the expected structure for a custom tool
#' definition, with a name, description, and one of the schema fields
#' (args_schema, parameters, or input_schema). Custom tools are user-defined
#' functions with parameter schemas, as opposed to server tools.
#'
#' @param obj Object to check
#' @return Logical. TRUE if obj is a valid custom tool definition, FALSE otherwise
#' @keywords internal
#' @noRd
is_client_tool <- function(obj) {
    if (!is.list(obj)) {
        return(FALSE)
    }

    has_name <- !is.null(obj$name) && is.character(obj$name) && length(obj$name) == 1
    if (isFALSE(has_name)) {
        return(FALSE)
    }

    # Must have one of the schema fields (args_schema, parameters, input_schema)
    has_schema <- !is.null(obj$args_schema) || !is.null(obj$parameters) || !is.null(obj$input_schema)
    if (has_schema) {
        # Validate the schema is a list with type and properties
        schema <- obj$args_schema %||% obj$parameters %||% obj$input_schema

        if (!is.list(schema)) {
            return(FALSE)
        }

        return(TRUE)
    } else {
        has_type <- !is.null(obj$type) && is.character(obj$type) && length(obj$type) == 1
        if (isTRUE(has_type)) {
            # OpenAI-like schema will have type = "function"
            if (obj$type == "function") {
                return(TRUE)
            }
            # Anthropic server tools will have type = something else (e.g. web_search_20250305, ...)
            return(FALSE)
        }

        # For tools without arguments (no parameters/properties), consider it a custom tool anyway
        return(TRUE)
    }
}

#' Check if a tool specification is a server tool
#'
#' Identifies whether a tool is a server tool by matching against valid names.
#' Supports string specifications and list specifications with name or type fields.
#' For list specifications, checks the name field first (for versioned tools),
#' then falls back to the type field.
#'
#' @param tool Character string or list. The tool specification to check
#' @param names Character vector. Valid canonical names (e.g., c("code_execution", "web_search"))
#' @return Logical. TRUE if tool matches any of the specified names, FALSE otherwise
#' @keywords internal
#' @noRd
is_server_tool <- function(tool, names) {
    if (is.character(tool)) {
        return(tool %in% names)
    }
    if (is.list(tool)) {
        # Check name field first (for versioned tools like type="web_search_20250305", name="web_search")
        # Then fall back to type field
        canonical_name <- tool$name %||% tool$type
        if (purrr::is_empty(canonical_name)) {
            return(FALSE)
        }

        if (!canonical_name %in% names) {
            return(FALSE)
        }

        is_client_tool <- is_client_tool(tool)
        if (is_client_tool) {
            return(FALSE)
        }

        return(TRUE)
    }
    return(FALSE)
}

#' Extract canonical name from server tool specification
#'
#' Extracts the canonical tool name from a server tool specification.
#' For list specifications, prioritizes the name field over the type field
#' to support versioned tool types.
#'
#' @param tool Character string or list. The server tool specification
#' @return Character or NULL. The canonical tool name, or NULL if not found
#' @keywords internal
#' @noRd
get_server_tool_name <- function(tool) {
    if (is.character(tool)) {
        return(tool)
    }
    if (is.list(tool)) {
        return(tool$name %||% tool$type)
    }
    return(NULL)
}
