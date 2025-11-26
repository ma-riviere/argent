# Tests for MCP annotation parsing via parse_mcp_file()
#
# These tests verify that functions with inline annotations (inside the function
# body) are correctly parsed into MCP tool/resource/prompt definitions.

# Helper to create a temp file with R code and return the path
create_temp_mcp_file <- function(code) {
    tmp <- tempfile(fileext = ".R")
    writeLines(code, tmp)
    tmp
}

# -----🔺 parse_mcp_file() basic functionality ----------------------------------

test_that("parse_mcp_file() extracts tools with inline annotations", {
    code <- c(
        "search_items <- function(query, limit = 10L) {",
        "    #' @description Search items by query string",
        "    #' @mcp tool",
        "    #' @param query:string* Search query",
        "    #' @param limit:integer Maximum results (default 10)",
        "    list(query = query, limit = limit)",
        "}"
    )

    tmp <- create_temp_mcp_file(code)
    on.exit(unlink(tmp))

    parsed <- argent:::parse_mcp_file(tmp)

    expect_length(parsed$tools, 1)
    expect_length(parsed$resources, 0)
    expect_length(parsed$prompts, 0)

    tool <- parsed$tools[[1]]
    expect_equal(tool$name, "search_items")
    expect_equal(tool$description, "Search items by query string")
    expect_true(is.function(tool$.fn))

    # Check schema
    expect_equal(tool$args_schema$type, "object")
    expect_contains(tool$args_schema$required, "query")
    expect_false("limit" %in% tool$args_schema$required)

    # Check properties
    expect_equal(tool$args_schema$properties$query$type, "string")
    expect_equal(tool$args_schema$properties$limit$type, "integer")
})

test_that("parse_mcp_file() extracts resources with @mcp resource annotation", {
    code <- c(
        "get_system_status <- function() {",
        "    #' @description Returns system health status",
        "    #' @mcp resource",
        "    #' @uri resource://system/status",
        "    #' @mimeType application/json",
        "    jsonlite::toJSON(list(status = 'ok'), auto_unbox = TRUE)",
        "}"
    )

    tmp <- create_temp_mcp_file(code)
    on.exit(unlink(tmp))

    parsed <- argent:::parse_mcp_file(tmp)

    expect_length(parsed$tools, 0)
    expect_length(parsed$resources, 1)
    expect_length(parsed$prompts, 0)

    resource <- parsed$resources[[1]]
    expect_equal(resource$name, "get_system_status")
    expect_equal(resource$description, "Returns system health status")
    expect_equal(resource$uri, "resource://system/status")
    expect_equal(resource$mimeType, "application/json")
    expect_true(is.function(resource$.fn))
})

test_that("parse_mcp_file() extracts prompts with @mcp prompt annotation", {
    code <- c(
        "greet_prompt <- function(name, style = 'casual') {",
        "    #' @description Creates a personalized greeting",
        "    #' @mcp prompt",
        "    #' @param name:string* Person's name",
        "    #' @param style:string Greeting style (formal/casual)",
        "    msg <- if (style == 'formal') {",
        "        paste0('Good day, ', name, '.')",
        "    } else {",
        "        paste0('Hey ', name, '!')",
        "    }",
        "    list(messages = list(list(role = 'user', content = list(type = 'text', text = msg))))",
        "}"
    )

    tmp <- create_temp_mcp_file(code)
    on.exit(unlink(tmp))

    parsed <- argent:::parse_mcp_file(tmp)

    expect_length(parsed$tools, 0)
    expect_length(parsed$resources, 0)
    expect_length(parsed$prompts, 1)

    prompt <- parsed$prompts[[1]]
    expect_equal(prompt$name, "greet_prompt")
    expect_equal(prompt$description, "Creates a personalized greeting")
    expect_true(is.function(prompt$.fn))

    # Check arguments
    expect_length(prompt$arguments, 2)
    expect_equal(prompt$arguments[[1]]$name, "name")
    expect_true(prompt$arguments[[1]]$required)
    expect_equal(prompt$arguments[[2]]$name, "style")
    expect_false(prompt$arguments[[2]]$required)
})

test_that("parse_mcp_file() handles multiple definitions in one file", {
    code <- c(
        "# Tool 1",
        "get_item <- function(id) {",
        "    #' @description Get item by ID",
        "    #' @mcp tool",
        "    #' @param id:string* Item ID",
        "    id",
        "}",
        "",
        "# Tool 2",
        "delete_item <- function(id) {",
        "    #' @description Delete an item",
        "    #' @mcp tool",
        "    #' @param id:string* Item ID",
        "    id",
        "}",
        "",
        "# Resource",
        "sys_info <- function() {",
        "    #' @description System info resource",
        "    #' @mcp resource",
        "    #' @uri resource://info",
        "    'info'",
        "}"
    )

    tmp <- create_temp_mcp_file(code)
    on.exit(unlink(tmp))

    parsed <- argent:::parse_mcp_file(tmp)

    expect_length(parsed$tools, 2)
    expect_length(parsed$resources, 1)

    tool_names <- purrr::map_chr(parsed$tools, "name")
    expect_contains(tool_names, "get_item")
    expect_contains(tool_names, "delete_item")

    expect_equal(parsed$resources[[1]]$name, "sys_info")
})

# -----🔺 Complex type annotations in parse_mcp_file() --------------------------

test_that("parse_mcp_file() handles nested object type annotations", {
    code <- c(
        "create_user <- function(user) {",
        "    #' @description Creates user with nested address object",
        "    #' @mcp tool",
        "    #' @param user:{name:string*, email:string*, address:{street:string*, city:string*, zip:string}}* User data",
        "    user",
        "}"
    )

    tmp <- create_temp_mcp_file(code)
    on.exit(unlink(tmp))

    parsed <- argent:::parse_mcp_file(tmp)
    tool <- parsed$tools[[1]]

    props <- tool$args_schema$properties

    # Check user is required and is an object
    expect_contains(tool$args_schema$required, "user")
    expect_equal(props$user$type, "object")

    # Check nested user properties
    expect_equal(props$user$properties$name$type, "string")
    expect_equal(props$user$properties$email$type, "string")
    expect_contains(props$user$required, "name")
    expect_contains(props$user$required, "email")

    # Check deeply nested address object
    address <- props$user$properties$address
    expect_equal(address$type, "object")
    expect_equal(address$properties$street$type, "string")
    expect_equal(address$properties$city$type, "string")
    expect_equal(address$properties$zip$type, "string")
    expect_contains(address$required, "street")
    expect_contains(address$required, "city")
    expect_false("zip" %in% address$required)
})

test_that("parse_mcp_file() handles array of objects type annotations", {
    code <- c(
        "process_orders <- function(orders) {",
        "    #' @description Process a batch of orders",
        "    #' @mcp tool",
        "    #' @param orders:[{id:string*, items:[{sku:string*, qty:integer*}]*, total:number}]* Order list",
        "    orders",
        "}"
    )

    tmp <- create_temp_mcp_file(code)
    on.exit(unlink(tmp))

    parsed <- argent:::parse_mcp_file(tmp)
    tool <- parsed$tools[[1]]

    props <- tool$args_schema$properties

    # Check orders is required array
    expect_contains(tool$args_schema$required, "orders")
    expect_equal(props$orders$type, "array")

    # Check order object structure
    order_schema <- props$orders$items
    expect_equal(order_schema$type, "object")
    expect_equal(order_schema$properties$id$type, "string")
    expect_equal(order_schema$properties$total$type, "number")
    expect_contains(order_schema$required, "id")
    expect_contains(order_schema$required, "items")
    expect_false("total" %in% order_schema$required)

    # Check nested items array
    items_schema <- order_schema$properties$items
    expect_equal(items_schema$type, "array")

    # Check item object
    item_schema <- items_schema$items
    expect_equal(item_schema$type, "object")
    expect_equal(item_schema$properties$sku$type, "string")
    expect_equal(item_schema$properties$qty$type, "integer")
    expect_contains(item_schema$required, "sku")
    expect_contains(item_schema$required, "qty")
})

# -----🔺 Edge cases ------------------------------------------------------------

test_that("parse_mcp_file() handles tool with no parameters", {
    code <- c(
        "get_timestamp <- function() {",
        "    #' @description Returns current Unix timestamp",
        "    #' @mcp tool",
        "    as.integer(Sys.time())",
        "}"
    )

    tmp <- create_temp_mcp_file(code)
    on.exit(unlink(tmp))

    parsed <- argent:::parse_mcp_file(tmp)
    tool <- parsed$tools[[1]]

    expect_equal(tool$name, "get_timestamp")
    expect_equal(tool$args_schema$type, "object")
    expect_length(tool$args_schema$properties, 0)
    expect_length(tool$args_schema$required, 0)
})

test_that("parse_mcp_file() handles tool with all optional parameters", {
    code <- c(
        "list_items <- function(page = 1L, limit = 10L, sort = 'id') {",
        "    #' @description List items with optional pagination",
        "    #' @mcp tool",
        "    #' @param page:integer Page number",
        "    #' @param limit:integer Items per page",
        "    #' @param sort:string Sort field",
        "    list(page = page, limit = limit, sort = sort)",
        "}"
    )

    tmp <- create_temp_mcp_file(code)
    on.exit(unlink(tmp))

    parsed <- argent:::parse_mcp_file(tmp)
    tool <- parsed$tools[[1]]

    expect_equal(tool$name, "list_items")
    expect_length(tool$args_schema$required, 0)
    expect_length(tool$args_schema$properties, 3)

    # All parameters should exist but none required
    expect_equal(tool$args_schema$properties$page$type, "integer")
    expect_equal(tool$args_schema$properties$limit$type, "integer")
    expect_equal(tool$args_schema$properties$sort$type, "string")
})

test_that("parse_mcp_file() handles mixed required and optional parameters", {
    code <- c(
        "update_user <- function(user_id, name = NULL, email = NULL, active) {",
        "    #' @description Update user by ID with optional fields",
        "    #' @mcp tool",
        "    #' @param user_id:string* User ID to update",
        "    #' @param name:string New name",
        "    #' @param email:string New email",
        "    #' @param active:boolean* Account status",
        "    list(user_id = user_id, name = name, email = email, active = active)",
        "}"
    )

    tmp <- create_temp_mcp_file(code)
    on.exit(unlink(tmp))

    parsed <- argent:::parse_mcp_file(tmp)
    tool <- parsed$tools[[1]]

    # Check required parameters
    expect_contains(tool$args_schema$required, "user_id")
    expect_contains(tool$args_schema$required, "active")

    # Check optional parameters
    expect_false("name" %in% tool$args_schema$required)
    expect_false("email" %in% tool$args_schema$required)
})

test_that("parse_mcp_file() defaults to tool when @mcp tag is omitted", {
    code <- c(
        "add_numbers <- function(x, y) {",
        "    #' @description A utility that adds numbers",
        "    #' @param x:number* First number",
        "    #' @param y:number* Second number",
        "    x + y",
        "}"
    )

    tmp <- create_temp_mcp_file(code)
    on.exit(unlink(tmp))

    parsed <- argent:::parse_mcp_file(tmp)

    # Should be parsed as a tool (default)
    expect_length(parsed$tools, 1)
    expect_equal(parsed$tools[[1]]$name, "add_numbers")
})

test_that("parse_mcp_file() skips functions without annotations", {
    code <- c(
        "# A helper function without annotations",
        "helper <- function(x) { x * 2 }",
        "",
        "real_tool <- function(x) {",
        "    #' @description Annotated tool",
        "    #' @mcp tool",
        "    #' @param x:number* Input",
        "    x",
        "}"
    )

    tmp <- create_temp_mcp_file(code)
    on.exit(unlink(tmp))

    parsed <- argent:::parse_mcp_file(tmp)

    expect_length(parsed$tools, 1)
    expect_equal(parsed$tools[[1]]$name, "real_tool")
})

test_that("parse_mcp_file() handles resource with default URI and mimeType", {
    code <- c(
        "my_resource <- function() {",
        "    #' @description A resource with defaults",
        "    #' @mcp resource",
        "    'content'",
        "}"
    )

    tmp <- create_temp_mcp_file(code)
    on.exit(unlink(tmp))

    parsed <- argent:::parse_mcp_file(tmp)

    expect_length(parsed$resources, 1)
    resource <- parsed$resources[[1]]
    expect_equal(resource$uri, "resource://my_resource")
    expect_equal(resource$mimeType, "text/plain")
})

# -----🔺 MCP JSON Schema compliance --------------------------------------------

test_that("parse_mcp_file() produces valid MCP JSON Schema structure", {
    code <- c(
        "process_data <- function(config, items, callback = NULL) {",
        "    #' @description Process data with complex schema",
        "    #' @mcp tool",
        "    #' @param config:{mode:string*, retries:integer} Configuration object",
        "    #' @param items:[string]* List of items to process",
        "    #' @param callback:string Optional callback URL",
        "    list(config = config, items = items, callback = callback)",
        "}"
    )

    tmp <- create_temp_mcp_file(code)
    on.exit(unlink(tmp))

    parsed <- argent:::parse_mcp_file(tmp)
    tool <- parsed$tools[[1]]

    # Verify top-level MCP schema structure
    expect_true("name" %in% names(tool))
    expect_true("description" %in% names(tool))
    expect_true("args_schema" %in% names(tool))
    expect_true(".fn" %in% names(tool))

    # Verify args_schema structure
    expect_equal(tool$args_schema$type, "object")
    expect_type(tool$args_schema$properties, "list")
    expect_type(tool$args_schema$required, "list")

    # Verify each property has type
    for (prop_name in names(tool$args_schema$properties)) {
        prop <- tool$args_schema$properties[[prop_name]]
        expect_true("type" %in% names(prop), info = paste("Property", prop_name, "missing type"))
    }
})

test_that("parse_mcp_file() tool functions are executable", {
    code <- c(
        "calc_sum <- function(x, y) {",
        "    #' @description Add two numbers",
        "    #' @mcp tool",
        "    #' @param x:number* First number",
        "    #' @param y:number* Second number",
        "    x + y",
        "}"
    )

    tmp <- create_temp_mcp_file(code)
    on.exit(unlink(tmp))

    parsed <- argent:::parse_mcp_file(tmp)
    tool <- parsed$tools[[1]]

    # Execute the function
    result <- tool$.fn(5, 3)
    expect_equal(result, 8)
})
