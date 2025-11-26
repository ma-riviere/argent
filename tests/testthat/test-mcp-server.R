test_that("McpServer can be created", {
    server <- argent:::McpServer$new(name = "test_server", version = "1.0.0")

    expect_s3_class(server, "McpServer")
    expect_equal(server$name, "test_server")
    expect_equal(server$version, "1.0.0")
    expect_type(server$tools, "list")
    expect_type(server$resources, "list")
    expect_type(server$prompts, "list")
    expect_length(server$tools, 0)
})

test_that("McpServer can add tools with explicit handler", {
    server <- argent:::McpServer$new(name = "test", version = "1.0.0")

    tool_def <- tool(
        name = "add",
        description = "Add two numbers",
        x = "number* First number",
        y = "number* Second number"
    )

    handler_fn <- \(x, y) x + y

    server$add_tool(tool_def, handler = handler_fn)

    expect_length(server$tools, 1)
    expect_true("add" %in% names(server$tools))
    expect_equal(server$tools$add$definition$name, "add")
    expect_true(is.function(server$tools$add$handler))
})

test_that("McpServer can add tools with .fn field", {
    server <- argent:::McpServer$new(name = "test", version = "1.0.0")

    multiply_fn <- function(x, y) x * y

    tool_def <- tool(
        name = "multiply",
        description = "Multiply two numbers",
        x = "number* First number",
        y = "number* Second number",
        fn = multiply_fn
    )

    server$add_tool(tool_def)

    expect_length(server$tools, 1)
    expect_equal(server$tools$multiply$handler, multiply_fn)
})

test_that("McpServer validates handler is a function", {
    server <- argent:::McpServer$new(name = "test", version = "1.0.0")

    tool_def <- tool(name = "test_tool", description = "Test", x = "string* Input")

    expect_error(server$add_tool(tool_def, handler = "not_a_function"), "must be a function")
})

test_that("McpServer requires handler if .fn not in tool_def", {
    server <- argent:::McpServer$new(name = "test", version = "1.0.0")

    tool_def <- tool(name = "test_tool", description = "Test", x = "string* Input")

    expect_error(server$add_tool(tool_def), "handler.*must be provided")
})

test_that("McpServer tools can be executed manually", {
    server <- argent:::McpServer$new(name = "test", version = "1.0.0")

    greet_fn <- function(person_name, greeting = "Hello") {
        paste0(greeting, ", ", person_name, "!")
    }

    tool_def <- tool(
        name = "greet",
        description = "Greet someone",
        person_name = "string* Name to greet",
        greeting = "string Greeting to use",
        fn = greet_fn
    )

    server$add_tool(tool_def)

    # Execute tool manually
    result <- server$tools$greet$handler(person_name = "Alice")
    expect_equal(result, "Hello, Alice!")

    result2 <- server$tools$greet$handler(person_name = "Bob", greeting = "Hi")
    expect_equal(result2, "Hi, Bob!")
})

test_that("mcp_error creates structured error response", {
    error <- argent:::mcp_error(
        message = "Resource not found",
        type = "not_found",
        details = "The requested item does not exist",
        suggestion = "Check the item ID and try again"
    )

    expect_s3_class(error, "mcp_error")
    expect_true(error$.error)
    expect_equal(error$type, "not_found")
    expect_equal(error$message, "Resource not found")
    expect_equal(error$details, "The requested item does not exist")
    expect_equal(error$suggestion, "Check the item ID and try again")
})

test_that("mcp_success creates structured success response", {
    success <- argent:::mcp_success(data = list(result = "OK"), warning = "This is a deprecation warning")

    expect_s3_class(success, "mcp_success")
    expect_true(success$.success)
    expect_equal(success$data$result, "OK")
    expect_equal(success$warning, "This is a deprecation warning")
})

test_that("MCP server tools can return mcp_error", {
    server <- argent:::McpServer$new(name = "test", version = "1.0.0")

    validate_fn <- function(value) {
        if (value < 0) {
            return(argent:::mcp_error(
                message = "Value must be non-negative",
                type = "validation",
                details = paste("Received:", value),
                suggestion = "Provide a value >= 0"
            ))
        }
        return(paste("Valid:", value))
    }

    tool_def <- tool(
        name = "validate",
        description = "Validate input",
        value = "number* Value to validate",
        fn = validate_fn
    )

    server$add_tool(tool_def)

    # Test error case
    result <- server$tools$validate$handler(value = -5)
    expect_s3_class(result, "mcp_error")
    expect_equal(result$type, "validation")

    # Test success case
    result2 <- server$tools$validate$handler(value = 10)
    expect_equal(result2, "Valid: 10")
})

test_that("MCP server can handle tools with no required parameters", {
    server <- argent:::McpServer$new(name = "test", version = "1.0.0")

    get_time_fn <- function(format = "%Y-%m-%d %H:%M:%S") {
        format(Sys.time(), format)
    }

    tool_def <- tool(
        name = "get_time",
        description = "Get current time",
        format = "string Time format string",
        fn = get_time_fn
    )

    server$add_tool(tool_def)

    # Can call with no arguments (all optional)
    result <- server$tools$get_time$handler()
    expect_type(result, "character")
    expect_true(nchar(result) > 0)

    # Can call with format argument
    result2 <- server$tools$get_time$handler(format = "%Y")
    expect_match(result2, "^\\d{4}$")
})
