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

test_that("McpServer can add annotated functions using as_tool()", {
    server <- argent:::McpServer$new(name = "test", version = "1.0.0")

    add_numbers <- function(x, y) {
        #' @description Add two numbers
        #' @mcp tool
        #' @param x:number* First number
        #' @param y:number* Second number
        x + y
    }

    tool_def <- as_tool(add_numbers)

    server$add_tool(tool_def)

    expect_length(server$tools, 1)
    expect_true("add_numbers" %in% names(server$tools))
    expect_equal(server$tools$add_numbers$definition$name, "add_numbers")
    expect_true(is.function(server$tools$add_numbers$handler))
})

test_that("McpServer can add tools defined with tool()", {
    server <- argent:::McpServer$new(name = "test", version = "1.0.0")

    # Define tool
    multiply_fn <- function(x, y) x * y

    tool_def <- tool(
        name = "multiply",
        description = "Multiply two numbers",
        x = "number* First number",
        y = "number* Second number",
        fn = multiply_fn
    )

    # Add tool to server
    server$add_tool(tool_def)

    # Check tool was added
    expect_length(server$tools, 1)
    expect_true("multiply" %in% names(server$tools))
    expect_equal(server$tools$multiply$definition$name, "multiply")
    expect_true(is.function(server$tools$multiply$handler))
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

# ----- STDIO SERVER SERVING TESTS ---------------------------------------------

test_that("STDIO server can be served and connected to", {
    skip_on_cran()

    server_file <- test_path("helper-mcp-servers.R")

    # Connect to calculator server (spawns subprocess)
    client <- mcp_connect(
        name = "calculator",
        type = "stdio",
        command = "Rscript",
        args = c("-e", sprintf("source('%s'); serve_calculator_stdio('%s')", server_file, server_file))
    )

    expect_s3_class(client, "McpClientStdio")
    expect_equal(client$name, "calculator")

    # List tools
    tools <- client$list_tools()
    expect_type(tools, "list")
    expect_true(length(tools) >= 3)

    tool_names <- purrr::map_chr(tools, "name")
    expect_contains(tool_names, "add_numbers")
    expect_contains(tool_names, "greet_person")
    expect_contains(tool_names, "get_timestamp")
})

test_that("STDIO server tools can be executed via client", {
    skip_on_cran()

    server_file <- test_path("helper-mcp-servers.R")

    # Connect to calculator server
    client <- mcp_connect(
        name = "calculator",
        type = "stdio",
        command = "Rscript",
        args = c("-e", sprintf("source('%s'); serve_calculator_stdio('%s')", server_file, server_file))
    )

    # Get tools
    tools <- mcp_tools(client)

    # Execute add_numbers tool
    add_tool <- get_mcp_tool(tools, "add_numbers")
    result <- execute_mcp_tool(add_tool, list(a = 5, b = 3))
    expect_equal(result, "8")

    # Execute greet_person tool
    greet_tool <- get_mcp_tool(tools, "greet_person")
    result <- execute_mcp_tool(greet_tool, list(name = "Alice"))
    expect_equal(result, "Hello, Alice!")

    # Execute with optional parameter
    result <- execute_mcp_tool(greet_tool, list(name = "Bob", greeting = "Hi"))
    expect_equal(result, "Hi, Bob!")

    # Execute get_timestamp tool
    timestamp_tool <- get_mcp_tool(tools, "get_timestamp")
    result <- execute_mcp_tool(timestamp_tool, list())
    expect_type(result, "character")
    expect_true(nchar(result) > 0)
})

# ----- HTTP SERVER SERVING TESTS ----------------------------------------------

test_that("HTTP server can be served and connected to", {
    skip_on_cran()

    port <- find_available_port()

    # Start server in background process
    bg_process <- callr::r_bg(
        func = serve_processor_http,
        args = list(port = port, helper_file = test_path("helper-mcp-servers.R")),
        supervise = TRUE
    )

    on.exit(bg_process$kill(), add = TRUE)

    # Wait for server to be ready
    expect_true(wait_for_server(port))

    # Connect to the server
    client <- mcp_connect(name = "processor", type = "http", url = paste0("http://127.0.0.1:", port))

    expect_s3_class(client, "McpClientHttp")
    expect_equal(client$name, "processor")
    expect_false(is.null(client$session_id))

    # List tools
    tools <- client$list_tools()
    expect_type(tools, "list")
    expect_true(length(tools) >= 3)

    tool_names <- purrr::map_chr(tools, "name")
    expect_contains(tool_names, "echo_message")
    expect_contains(tool_names, "validate_age")
    expect_contains(tool_names, "process_list")
})

test_that("HTTP server tools can be executed via client", {
    skip_on_cran()

    port <- find_available_port()

    # Start server in background process
    bg_process <- callr::r_bg(
        func = serve_processor_http,
        args = list(port = port, helper_file = test_path("helper-mcp-servers.R")),
        supervise = TRUE
    )

    on.exit(bg_process$kill(), add = TRUE)

    # Wait for server to be ready
    expect_true(wait_for_server(port))

    # Connect and get tools
    client <- mcp_connect(name = "processor", type = "http", url = paste0("http://127.0.0.1:", port))
    tools <- mcp_tools(client)

    # Execute echo_message tool
    echo_tool <- get_mcp_tool(tools, "echo_message")
    result <- execute_mcp_tool(echo_tool, list(message = "hello"))
    expect_type(result, "character")
    expect_true(grepl("hello", result))

    # Execute validate_age tool with valid input
    validate_tool <- get_mcp_tool(tools, "validate_age")
    result <- execute_mcp_tool(validate_tool, list(age = 25L))
    expect_type(result, "character")
    expect_true(grepl("Valid age", result))

    # Execute process_list tool
    process_tool <- get_mcp_tool(tools, "process_list")
    result <- execute_mcp_tool(process_tool, list(items = c("a", "b", "c"), operation = "count"))
    parsed_result <- jsonlite::fromJSON(result)
    expect_equal(parsed_result, 3)
})

test_that("HTTP server returns correct protocol version", {
    skip_on_cran()

    port <- find_available_port()

    # Start server in background process
    bg_process <- callr::r_bg(
        func = serve_processor_http,
        args = list(port = port, helper_file = test_path("helper-mcp-servers.R")),
        supervise = TRUE
    )

    on.exit(bg_process$kill(), add = TRUE)

    # Wait for server to be ready
    expect_true(wait_for_server(port))

    # Send initialize request
    init_req <- list(
        jsonrpc = "2.0",
        id = 1,
        method = "initialize",
        params = list(
            protocolVersion = "2025-06-18",
            capabilities = list(),
            clientInfo = list(name = "test-client", version = "1.0")
        )
    )

    resp <- httr2::request(paste0("http://127.0.0.1:", port)) |> httr2::req_body_json(init_req) |> httr2::req_perform()

    expect_equal(httr2::resp_status(resp), 200)

    # Check protocol version header
    mcp_version <- httr2::resp_header(resp, "MCP-Protocol-Version")
    expect_equal(mcp_version, "2025-06-18")

    # Check session ID header
    session_id <- httr2::resp_header(resp, "Mcp-Session-Id")
    expect_false(is.null(session_id))
    expect_true(grepl("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", session_id))

    # Check response body
    body <- httr2::resp_body_json(resp)
    expect_equal(body$result$protocolVersion, "2025-06-18")
})

test_that("HTTP server handles GET and DELETE methods", {
    skip_on_cran()

    port <- find_available_port()

    # Start server in background process
    bg_process <- callr::r_bg(
        func = serve_processor_http,
        args = list(port = port, helper_file = test_path("helper-mcp-servers.R")),
        supervise = TRUE
    )

    on.exit(bg_process$kill(), add = TRUE)

    # Wait for server to be ready
    expect_true(wait_for_server(port))

    # Test GET method returns 405
    get_resp <- httr2::request(paste0("http://127.0.0.1:", port)) |>
        httr2::req_method("GET") |>
        httr2::req_error(is_error = \(resp) FALSE) |>
        httr2::req_perform()

    expect_equal(httr2::resp_status(get_resp), 405)
    get_body <- httr2::resp_body_json(get_resp)
    expect_equal(get_body$error, "Method Not Allowed")

    # Initialize session first
    init_req <- list(
        jsonrpc = "2.0",
        id = 1,
        method = "initialize",
        params = list(
            protocolVersion = "2025-06-18",
            capabilities = list(),
            clientInfo = list(name = "test-client", version = "1.0")
        )
    )

    init_resp <- httr2::request(paste0("http://127.0.0.1:", port)) |>
        httr2::req_body_json(init_req) |>
        httr2::req_perform()

    session_id <- httr2::resp_header(init_resp, "Mcp-Session-Id")

    # Test DELETE method
    delete_resp <- httr2::request(paste0("http://127.0.0.1:", port)) |>
        httr2::req_method("DELETE") |>
        httr2::req_headers(`Mcp-Session-Id` = session_id) |>
        httr2::req_error(is_error = \(resp) FALSE) |>
        httr2::req_perform()

    expect_equal(httr2::resp_status(delete_resp), 204)

    # Small delay to ensure DELETE completes
    Sys.sleep(0.1)

    # Try to use session after DELETE
    tools_req <- list(jsonrpc = "2.0", id = 2, method = "tools/list", params = list())

    error_resp <- tryCatch(
        httr2::request(paste0("http://127.0.0.1:", port)) |>
            httr2::req_body_json(tools_req) |>
            httr2::req_headers(`Mcp-Session-Id` = session_id) |>
            httr2::req_error(is_error = \(resp) FALSE) |>
            httr2::req_perform(),
        error = function(e) NULL
    )

    # Either got a 404 response or connection failed (NULL)
    if (is.null(error_resp)) {
        expect_true(TRUE)
    } else {
        expect_equal(httr2::resp_status(error_resp), 404)
    }
})

test_that("HTTP server returns 202 for notifications", {
    skip_on_cran()

    port <- find_available_port()

    # Start server in background process
    bg_process <- callr::r_bg(
        func = serve_processor_http,
        args = list(port = port, helper_file = test_path("helper-mcp-servers.R")),
        supervise = TRUE
    )

    on.exit(bg_process$kill(), add = TRUE)

    # Wait for server to be ready
    expect_true(wait_for_server(port))

    # Initialize session
    init_req <- list(
        jsonrpc = "2.0",
        id = 1,
        method = "initialize",
        params = list(
            protocolVersion = "2025-06-18",
            capabilities = list(),
            clientInfo = list(name = "test-client", version = "1.0")
        )
    )

    init_resp <- httr2::request(paste0("http://127.0.0.1:", port)) |>
        httr2::req_body_json(init_req) |>
        httr2::req_perform()

    session_id <- httr2::resp_header(init_resp, "Mcp-Session-Id")

    # Send notification (no ID field)
    notif_req <- list(jsonrpc = "2.0", method = "notifications/initialized", params = list())

    notif_resp <- httr2::request(paste0("http://127.0.0.1:", port)) |>
        httr2::req_body_json(notif_req) |>
        httr2::req_headers(`Mcp-Session-Id` = session_id) |>
        httr2::req_perform()

    expect_equal(httr2::resp_status(notif_resp), 202)
})
