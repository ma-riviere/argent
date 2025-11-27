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

# -----🔺 parse_mcp_file() basic functionality ---------------------------------

test_that("parse_mcp_file() extracts tools with inline annotations", {
    helper_file <- test_path("helper-mcp-servers.R")
    skip_if_not(file.exists(helper_file), "helper-mcp-servers.R not found")

    parsed <- argent:::parse_mcp_file(helper_file)

    # Use greet_person as example (has required and optional params)
    tool <- argent::get_mcp_tool(parsed$tools, "greet_person")

    expect_equal(tool$name, "greet_person")
    expect_equal(tool$description, "Greet someone")
    expect_true(is.function(tool$.fn))

    # Check schema
    expect_equal(tool$args_schema$type, "object")
    expect_contains(tool$args_schema$required, "name")
    expect_false("greeting" %in% tool$args_schema$required)

    # Check properties
    expect_equal(tool$args_schema$properties$name$type, "string")
    expect_equal(tool$args_schema$properties$greeting$type, "string")
})

test_that("parse_mcp_file() extracts resources with @mcp resource annotation", {
    helper_file <- test_path("helper-mcp-servers.R")
    skip_if_not(file.exists(helper_file), "helper-mcp-servers.R not found")

    parsed <- argent:::parse_mcp_file(helper_file)

    expect_true(length(parsed$resources) >= 1)

    resource <- argent::get_mcp_resource(parsed$resources, resource_uri = "resource://system/status")
    expect_equal(resource$name, "get_system_status")
    expect_equal(resource$description, "Returns system health status")
    expect_equal(resource$uri, "resource://system/status")
    expect_equal(resource$mimeType, "application/json")
    expect_true(is.function(resource$.fn))
})

test_that("parse_mcp_file() extracts prompts with @mcp prompt annotation", {
    helper_file <- test_path("helper-mcp-servers.R")
    skip_if_not(file.exists(helper_file), "helper-mcp-servers.R not found")

    parsed <- argent:::parse_mcp_file(helper_file)

    expect_true(length(parsed$prompts) >= 1)

    prompt <- argent::get_mcp_prompt(parsed$prompts, prompt_name = "greet_prompt")
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
    helper_file <- test_path("helper-mcp-servers.R")
    skip_if_not(file.exists(helper_file), "helper-mcp-servers.R not found")

    parsed <- argent:::parse_mcp_file(helper_file)

    # Helper file has multiple tools from both calculator and processor servers
    expect_true(length(parsed$tools) >= 6)

    tool_names <- purrr::map_chr(parsed$tools, "name")
    expect_contains(tool_names, "add_numbers")
    expect_contains(tool_names, "greet_person")
    expect_contains(tool_names, "echo_message")
})

# -----🔺 Complex type annotations in parse_mcp_file() -------------------------

test_that("parse_mcp_file() handles nested object type annotations", {
    helper_file <- test_path("helper-mcp-servers.R")
    skip_if_not(file.exists(helper_file), "helper-mcp-servers.R not found")

    parsed <- argent:::parse_mcp_file(helper_file)

    tool <- argent::get_mcp_tool(parsed$tools, "create_user")

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
    helper_file <- test_path("helper-mcp-servers.R")
    skip_if_not(file.exists(helper_file), "helper-mcp-servers.R not found")

    parsed <- argent:::parse_mcp_file(helper_file)

    tool <- argent::get_mcp_tool(parsed$tools, "process_orders")

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

# -----🔺 Edge cases -----------------------------------------------------------

test_that("parse_mcp_file() handles tool with no required parameters", {
    helper_file <- test_path("helper-mcp-servers.R")
    skip_if_not(file.exists(helper_file), "helper-mcp-servers.R not found")

    parsed <- argent:::parse_mcp_file(helper_file)

    # get_timestamp has only optional parameters
    tool <- argent::get_mcp_tool(parsed$tools, "get_timestamp")

    expect_equal(tool$name, "get_timestamp")
    expect_equal(tool$args_schema$type, "object")
    expect_length(tool$args_schema$required, 0)
    expect_true(length(tool$args_schema$properties) > 0) # Has format param
})

test_that("parse_mcp_file() handles tool with optional parameters", {
    helper_file <- test_path("helper-mcp-servers.R")
    skip_if_not(file.exists(helper_file), "helper-mcp-servers.R not found")

    parsed <- argent:::parse_mcp_file(helper_file)

    # process_list has one required (items) and one optional (operation)
    tool <- argent::get_mcp_tool(parsed$tools, "process_list")

    expect_equal(tool$name, "process_list")
    expect_length(tool$args_schema$properties, 2)

    # items is required, operation is optional
    expect_contains(tool$args_schema$required, "items")
    expect_false("operation" %in% tool$args_schema$required)

    expect_equal(tool$args_schema$properties$items$type, "array")
    expect_equal(tool$args_schema$properties$operation$type, "string")
})

test_that("parse_mcp_file() handles mixed required and optional parameters", {
    helper_file <- test_path("helper-mcp-servers.R")
    skip_if_not(file.exists(helper_file), "helper-mcp-servers.R not found")

    parsed <- argent:::parse_mcp_file(helper_file)

    # greet_person has one required (name) and one optional (greeting)
    tool <- argent::get_mcp_tool(parsed$tools, "greet_person")

    # Check required parameters
    expect_contains(tool$args_schema$required, "name")

    # Check optional parameters
    expect_false("greeting" %in% tool$args_schema$required)
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
    helper_file <- test_path("helper-mcp-servers.R")
    skip_if_not(file.exists(helper_file), "helper-mcp-servers.R not found")

    parsed <- argent:::parse_mcp_file(helper_file)

    expect_true(length(parsed$resources) >= 1)

    resource <- argent::get_mcp_resource(parsed$resources, resource_uri = "resource://my_resource")
    expect_equal(resource$uri, "resource://my_resource")
    expect_equal(resource$name, "my_resource")
    expect_equal(resource$mimeType, "text/plain")
})

# -----🔺 MCP JSON Schema compliance -------------------------------------------

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
    helper_file <- test_path("helper-mcp-servers.R")
    skip_if_not(file.exists(helper_file), "helper-mcp-servers.R not found")

    parsed <- argent:::parse_mcp_file(helper_file)

    # Execute add_numbers function
    tool <- argent::get_mcp_tool(parsed$tools, "add_numbers")
    result <- tool$.fn(5, 3)
    expect_equal(result, "8") # Returns as character
})

# -----🔺 Integration with helper-mcp-servers.R --------------------------------

test_that("parse_mcp_file() correctly parses calculator server tools from helper", {
    helper_file <- test_path("helper-mcp-servers.R")
    skip_if_not(file.exists(helper_file), "helper-mcp-servers.R not found")

    parsed <- argent:::parse_mcp_file(helper_file)

    # Should have tools from both calculator and processor servers
    expect_true(length(parsed$tools) >= 6)

    # Check calculator tools
    tool_names <- purrr::map_chr(parsed$tools, "name")
    expect_contains(tool_names, "add_numbers")
    expect_contains(tool_names, "greet_person")
    expect_contains(tool_names, "get_timestamp")

    # Verify add_numbers structure
    add_tool <- argent::get_mcp_tool(parsed$tools, "add_numbers")
    expect_equal(add_tool$args_schema$type, "object")
    expect_contains(add_tool$args_schema$required, "a")
    expect_contains(add_tool$args_schema$required, "b")
    expect_equal(add_tool$args_schema$properties$a$type, "number")
    expect_equal(add_tool$args_schema$properties$b$type, "number")

    # Verify greet_person has optional parameter
    greet_tool <- argent::get_mcp_tool(parsed$tools, "greet_person")
    expect_contains(greet_tool$args_schema$required, "name")
    expect_false("greeting" %in% greet_tool$args_schema$required)
})

test_that("parse_mcp_file() correctly parses processor server tools from helper", {
    helper_file <- test_path("helper-mcp-servers.R")
    skip_if_not(file.exists(helper_file), "helper-mcp-servers.R not found")

    parsed <- argent:::parse_mcp_file(helper_file)

    # Check processor tools
    tool_names <- purrr::map_chr(parsed$tools, "name")
    expect_contains(tool_names, "echo_message")
    expect_contains(tool_names, "validate_age")
    expect_contains(tool_names, "process_list")

    # Verify validate_age structure
    validate_tool <- argent::get_mcp_tool(parsed$tools, "validate_age")
    expect_equal(validate_tool$args_schema$properties$age$type, "integer")
    expect_contains(validate_tool$args_schema$required, "age")

    # Verify process_list has array parameter
    process_tool <- argent::get_mcp_tool(parsed$tools, "process_list")
    expect_equal(process_tool$args_schema$properties$items$type, "array")
    expect_equal(process_tool$args_schema$properties$items$items$type, "string")
    expect_contains(process_tool$args_schema$required, "items")
    expect_false("operation" %in% process_tool$args_schema$required)
})

test_that("Helper server tools are executable and return expected types", {
    helper_file <- test_path("helper-mcp-servers.R")
    skip_if_not(file.exists(helper_file), "helper-mcp-servers.R not found")

    parsed <- argent:::parse_mcp_file(helper_file)
    tools <- parsed$tools

    # Test add_numbers
    add_tool <- argent::get_mcp_tool(tools, "add_numbers")
    result <- add_tool$.fn(5, 3)
    expect_equal(result, "8")

    # Test add_numbers with error
    error_result <- add_tool$.fn("not", "numbers")
    expect_s3_class(error_result, "mcp_error")
    expect_equal(error_result$type, "validation")

    # Test greet_person
    greet_tool <- argent::get_mcp_tool(tools, "greet_person")
    result <- greet_tool$.fn("Alice")
    expect_equal(result, "Hello, Alice!")
    result <- greet_tool$.fn("Bob", "Hi")
    expect_equal(result, "Hi, Bob!")

    # Test get_timestamp
    timestamp_tool <- argent::get_mcp_tool(tools, "get_timestamp")
    result <- timestamp_tool$.fn()
    expect_type(result, "character")
    expect_true(nchar(result) > 0)

    # Test validate_age
    validate_tool <- argent::get_mcp_tool(tools, "validate_age")
    result <- validate_tool$.fn(25)
    expect_type(result, "character")
    expect_true(grepl("Valid age", result))

    # Test validate_age with error
    error_result <- validate_tool$.fn(-5)
    expect_s3_class(error_result, "mcp_error")
    expect_equal(error_result$type, "validation")

    # Test process_list
    process_tool <- argent::get_mcp_tool(tools, "process_list")
    result <- process_tool$.fn(c("a", "b", "c"), "count")
    parsed_result <- jsonlite::fromJSON(result)
    expect_equal(parsed_result, 3)
})
