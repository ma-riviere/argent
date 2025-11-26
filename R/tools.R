#' Generate tools and schemas definitions from direct specification
#'
#' @description
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
#' @param name Character. The tool or schema name
#' @param description Character. What the tool does or what the schema represents
#' @param ... Named parameter specifications. See Details.
#' @param fn Function. For `tool()` only. Optional function implementation to store with the
#'   tool definition. When provided, this function (with its closure) will be called when the
#'   LLM invokes the tool, supporting locally-defined functions with access to local variables.
#'   If NULL (default), the function is looked up by name in the global environment.
#' @param strict Logical. For `schema()` only. Whether to use strict mode (defaults to TRUE).
#'   Added at root level of the schema definition.
#' @param additional_properties Logical. For `schema()` only. Whether to allow additional
#'   properties in the schema (defaults to FALSE). Added to `args_schema`.
#'
#' @return For `tool()`: A list with:
#'   - `name`: Tool name (character)
#'   - `description`: Tool description (character)
#'   - `args_schema`: JSON Schema object with `type`, `properties`, and `required` fields
#'   - `.fn`: Optional function implementation (if `fn` parameter provided)
#'
#'   For `schema()`: A list with:
#'   - `name`: Schema name (character)
#'   - `description`: Schema description (character)
#'   - `args_schema`: JSON Schema object with `type`, `properties`, and `required` fields
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
#' **Nested objects (string syntax):** Use `{prop:type, ...}` inline:
#' ```r
#' address = "{street:string*, city:string*, zip:string}* Mailing address"
#' ```
#'
#' **Nested objects (list syntax):** Use list with `type = "object"`:
#' ```r
#' address = list(
#'   type = "object*",
#'   description = "Mailing address",
#'   street = "string* Street address",
#'   city = "string* City name"
#' )
#' ```
#'
#' **Arrays of objects:** Use `[{...}]` or `type = "[object]"`:
#' ```r
#' # String syntax
#' items = "[{name:string*, qty:integer*}]* Order items"
#'
#' # List syntax
#' items = list(
#'   type = "[object]*",
#'   description = "Order items",
#'   name = "string*",
#'   qty = "integer*"
#' )
#' ```
#'
#' @name tool_definitions
#' @examples
#' \dontrun{
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
#' # Nested object using string syntax (new!)
#' create_order <- tool(
#'   name = "create_order",
#'   description = "Create a new order",
#'   customer = "{name:string*, email:string*}* Customer information",
#'   items = "[{product:string*, quantity:integer*}]* Order items"
#' )
#'
#' # Nested object using list syntax (original)
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

#' @rdname tool_definitions
#' @export
tool <- function(name, description, ..., fn = NULL) {
    if (!is.character(name) || length(name) != 1 || nchar(name) == 0) {
        cli::cli_abort("{.arg name} must be a non-empty string")
    }

    if (!is.character(description) || length(description) != 1 || nchar(description) == 0) {
        cli::cli_abort("{.arg description} must be a non-empty string")
    }

    if (!is.null(fn) && !is.function(fn)) {
        cli::cli_abort("{.arg fn} must be a function or NULL")
    }

    params <- list(...)

    result <- build_spec_from_params(name, description, params)

    if (!is.null(fn)) {
        result$.fn <- fn
    }

    result
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

    if (length(params) == 0 && isTRUE(getOption("argent.debug"))) {
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

    # Build args_schema even for no parameters
    args_schema <- list(
        type = "object",
        properties = if (length(params) > 0) properties else named_list(),
        required = if (length(required) > 0) as.list(required) else list()
    )
    if (!is.null(additional_properties)) {
        args_schema$additionalProperties <- additional_properties
    }

    list3(name = name, description = description, strict = strict, args_schema = args_schema)
}

#' Parse a single parameter specification
#' @keywords internal
#' @noRd
parse_param_spec <- function(spec, param_name) {
    if (is.character(spec) && length(spec) == 1) {
        return(parse_string_spec(spec, param_name))
    }

    if (is.list(spec)) {
        return(parse_list_spec(spec, param_name))
    }

    cli::cli_abort("Parameter {.arg {param_name}} must be a string or list specification")
}

#' Parse string type specification
#'
#' Handles specs like "string* Description" or "{name:string*, age:integer} User info"
#' Uses the shared type parser from tools-parse-types.R for full nested type support.
#'
#' @keywords internal
#' @noRd
parse_string_spec <- function(spec_str, param_name = "param") {
    # Use find_type_end() to properly split type from description
    # This handles nested brackets correctly: "{a:string, b:integer} Description"
    type_end <- find_type_end(spec_str)
    type_str <- trimws(substr(spec_str, 1, type_end))
    desc_str <- trimws(substr(spec_str, type_end + 1, nchar(spec_str)))

    if (nchar(type_str) == 0) {
        cli::cli_abort("Invalid type specification: {.val {spec_str}}")
    }

    # Use the shared type parser (supports primitives, arrays, nested objects)
    parsed <- parse_type_spec(type_str, param_name)

    # Add description if present
    if (nchar(desc_str) > 0) {
        parsed$schema$description <- desc_str
    }

    return(parsed)
}

#' Parse list specification for nested objects
#' @keywords internal
#' @noRd
parse_list_spec <- function(spec_list, param_name) {
    if (is.null(spec_list$type)) {
        cli::cli_abort("List specification for {.arg {param_name}} must have a {.field type} field")
    }

    type_str <- spec_list$type
    required <- grepl("\\*", type_str)
    type_clean <- gsub("\\*", "", type_str)

    is_array <- grepl("^\\[object\\]$", type_clean)
    is_object <- type_clean == "object"

    if (!is_array && !is_object) {
        cli::cli_abort(c(
            "List specifications are only supported for object types",
            "i" = "Got type: {.val {type_clean}} for {.arg {param_name}}"
        ))
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

    list(schema = final_schema, required = required)
}

# -----🔺 UTILS ----------------------------------------------------------------

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

#' Check if an object is an MCP tool
#'
#' MCP tools are tools provided by Model Context Protocol servers and contain
#' metadata in the `.mcp` field that includes the client reference and server name.
#'
#' @param obj Object to check
#' @return Logical. TRUE if obj is an MCP tool, FALSE otherwise
#' @keywords internal
#' @noRd
is_mcp_tool <- function(obj) {
    if (!is.list(obj)) {
        return(FALSE)
    }

    return(!is.null(obj[[".mcp"]]))
}

#' Check if an object is a valid custom tool definition
#'
#' Validates that an object conforms to the expected structure for a custom tool
#' definition, with a name, description, and one of the schema fields
#' (args_schema, parameters, or input_schema). Custom tools are user-defined
#' functions with parameter schemas, as opposed to server tools or MCP tools.
#'
#' @param obj Object to check
#' @return Logical. TRUE if obj is a valid custom tool definition, FALSE otherwise
#' @keywords internal
#' @noRd
is_client_tool <- function(obj) {
    if (!is.list(obj)) {
        return(FALSE)
    }

    # MCP tools are not client tools
    if (!is.null(obj$.mcp)) {
        return(FALSE)
    }

    if (!is.null(obj$.fn)) {
        return(TRUE)
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
