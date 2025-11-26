# Type Parser for MCP Tools
#
# Parses enhanced type specifications supporting:
# - Nested objects: {prop:Type, prop2:Type2}
# - Arrays: [Type]
# - Required marker: *
# - Primitives: string, integer, number, boolean

#' Parse type specification into JSON Schema
#'
#' @param spec_str Character. Type specification string
#' @param param_name Character. Parameter name (for error messages)
#' @return List with `schema` (JSON Schema) and `required` (logical)
#' @keywords internal
#' @noRd
parse_type_spec <- function(spec_str, param_name) {
    if (is.null(spec_str) || nchar(trimws(spec_str)) == 0) {
        cli::cli_abort("Empty type specification for parameter {.arg {param_name}}")
    }

    spec_str <- trimws(spec_str)

    # Check for required marker (*)
    required <- grepl("\\*$", spec_str)
    if (required) {
        spec_str <- sub("\\*$", "", spec_str)
        spec_str <- trimws(spec_str)
    }

    # Dispatch based on structure
    if (startsWith(spec_str, "[")) {
        schema <- parse_array_type(spec_str, param_name)
    } else if (startsWith(spec_str, "{")) {
        schema <- parse_object_type(spec_str, param_name)
    } else {
        schema <- parse_primitive_type(spec_str, param_name)
    }

    return(list(schema = schema, required = required))
}

#' Parse primitive type
#'
#' @param spec_str Character. Type string (e.g., "string", "integer")
#' @param param_name Character. Parameter name (for error messages)
#' @return List with JSON Schema type
#' @keywords internal
#' @noRd
parse_primitive_type <- function(spec_str, param_name) {
    type_map <- list(
        string = list(type = "string"),
        integer = list(type = "integer"),
        number = list(type = "number"),
        boolean = list(type = "boolean"),
        date = list(type = "string", format = "date"),
        "date-time" = list(type = "string", format = "date-time")
    )

    if (spec_str %in% names(type_map)) {
        return(type_map[[spec_str]])
    }

    cli::cli_warn(c(
        "Unknown type {.val {spec_str}} for parameter {.arg {param_name}}",
        "i" = "Defaulting to {.val string}",
        "i" = "Supported types: string, integer, number, boolean, date, date-time"
    ))
    return(list(type = "string"))
}

#' Parse array type
#'
#' @param spec_str Character. Array specification (e.g., "[string]", or nested objects)
#' @param param_name Character. Parameter name (for error messages)
#' @return List with JSON Schema array type
#' @keywords internal
#' @noRd
parse_array_type <- function(spec_str, param_name) {
    if (!grepl("^\\[.+\\]$", spec_str)) {
        cli::cli_abort("Invalid array specification {.val {spec_str}} for parameter {.arg {param_name}}")
    }

    # Extract inner type: "[string]" -> "string"
    inner <- substr(spec_str, 2, nchar(spec_str) - 1)
    inner <- trimws(inner)

    if (nchar(inner) == 0) {
        cli::cli_abort("Empty array type specification for parameter {.arg {param_name}}")
    }

    # Recursively parse inner type
    parsed <- parse_type_spec(inner, paste0(param_name, "[item]"))

    return(list(type = "array", items = parsed$schema))
}

#' Parse object type
#'
#' @param spec_str Character. Object specification (e.g., "{name:string*, age:integer}")
#' @param param_name Character. Parameter name (for error messages)
#' @return List with JSON Schema object type
#' @keywords internal
#' @noRd
parse_object_type <- function(spec_str, param_name) {
    if (!grepl("^\\{.+\\}$", spec_str)) {
        cli::cli_abort("Invalid object specification {.val {spec_str}} for parameter {.arg {param_name}}")
    }

    # Strip outer braces: "{name:string*, age:integer}" -> "name:string*, age:integer"
    inner <- substr(spec_str, 2, nchar(spec_str) - 1)
    inner <- trimws(inner)

    if (nchar(inner) == 0) {
        # Empty object is valid
        return(list(type = "object", properties = named_list(), required = list()))
    }

    # Split by commas respecting nesting
    prop_specs <- split_by_comma_with_depth(inner)

    properties <- list()
    required <- character()

    for (prop_spec in prop_specs) {
        prop_spec <- trimws(prop_spec)

        # Find first colon to split "name:type"
        colon_pos <- regexpr(":", prop_spec)
        if (colon_pos == -1) {
            cli::cli_abort(c(
                "Invalid property specification {.val {prop_spec}} in object for parameter {.arg {param_name}}",
                "i" = "Expected format: {.code name:type}"
            ))
        }

        prop_name <- trimws(substr(prop_spec, 1, colon_pos - 1))
        prop_type <- trimws(substr(prop_spec, colon_pos + 1, nchar(prop_spec)))

        if (nchar(prop_name) == 0) {
            cli::cli_abort("Empty property name in object specification for parameter {.arg {param_name}}")
        }

        if (nchar(prop_type) == 0) {
            cli::cli_abort("Empty property type for {.val {prop_name}} in object for parameter {.arg {param_name}}")
        }

        # Recursively parse property type
        parsed <- parse_type_spec(prop_type, paste0(param_name, ".", prop_name))
        properties[[prop_name]] <- parsed$schema

        if (parsed$required) {
            required <- c(required, prop_name)
        }
    }

    return(list(
        type = "object",
        properties = properties,
        required = if (length(required) > 0) as.list(required) else list()
    ))
}

#' Split string by commas, respecting bracket/brace depth
#'
#' This function splits a string by top-level commas only, ignoring commas
#' that appear inside nested brackets or braces.
#'
#' @param str Character. String to split
#' @return Character vector of parts
#' @keywords internal
#' @noRd
split_by_comma_with_depth <- function(str) {
    depth <- 0
    parts <- list()
    current <- ""

    chars <- strsplit(str, "")[[1]]

    for (char in chars) {
        if (char %in% c("{", "[")) {
            depth <- depth + 1
            current <- paste0(current, char)
        } else if (char %in% c("}", "]")) {
            depth <- depth - 1
            current <- paste0(current, char)

            # Check for negative depth (mismatched brackets)
            if (depth < 0) {
                cli::cli_abort(c(
                    "Mismatched brackets in type specification",
                    "i" = "Found closing bracket without matching opening bracket",
                    "i" = "String: {.val {str}}"
                ))
            }
        } else if (char == "," && depth == 0) {
            # Top-level comma - split here
            parts <- c(parts, trimws(current))
            current <- ""
        } else {
            current <- paste0(current, char)
        }
    }

    # Check for unclosed brackets
    if (depth != 0) {
        cli::cli_abort(c(
            "Unclosed brackets in type specification",
            "i" = "Depth at end: {depth}",
            "i" = "String: {.val {str}}"
        ))
    }

    # Don't forget the last part
    if (nchar(trimws(current)) > 0) {
        parts <- c(parts, trimws(current))
    }

    # Return empty character vector if no parts
    if (length(parts) == 0) {
        return(character(0))
    }

    unlist(parts)
}
