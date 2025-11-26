test_that("mcp_connect() validates inputs", {
    expect_error(mcp_connect(name = ""), "must be a non-empty string")

    expect_error(mcp_connect(name = "test", type = "invalid"), "must be either 'stdio' or 'http'")

    expect_error(mcp_connect(name = "test", type = "http"), "url.*is required")

    expect_error(mcp_connect(name = "test", type = "stdio"), "command.*is required")
})

test_that("GitHub MCP server connection works", {
    skip_on_cran()
    skip_if_not(nzchar(Sys.getenv("PAT_GITHUB")), "PAT_GITHUB not set")

    # Try to connect to GitHub MCP server via npx
    skip_if_not(Sys.which("npx") != "", "npx not available")

    client <- tryCatch(
        mcp_connect(
            name = "github",
            type = "http",
            url = "https://api.githubcopilot.com/mcp",
            headers = list(Authorization = paste("Bearer", Sys.getenv("PAT_GITHUB")))
        ),
        error = function(e) NULL
    )

    skip_if(is.null(client), "Could not connect to GitHub MCP server")

    expect_s3_class(client, "McpClientHttp")
    expect_equal(client$name, "github")
})

test_that("mcp_tools() retrieves tools from GitHub MCP server", {
    skip_on_cran()
    skip_if_not(nzchar(Sys.getenv("PAT_GITHUB")), "PAT_GITHUB not set")
    skip_if_not(Sys.which("npx") != "", "npx not available")

    client <- tryCatch(
        mcp_connect(
            name = "github",
            type = "http",
            url = "https://api.githubcopilot.com/mcp",
            headers = list(Authorization = paste("Bearer", Sys.getenv("PAT_GITHUB")))
        ),
        error = function(e) NULL
    )

    skip_if(is.null(client), "Could not connect to GitHub MCP server")

    tools <- purrr::possibly(mcp_tools, otherwise = NULL)(client, tools = c("search_code", "get_file_contents"))

    skip_if(is.null(tools), "Could not retrieve tools")

    expect_type(tools, "list")
    expect_true(!purrr::is_empty(tools))

    # Check tool structure
    for (tool in tools) {
        expect_true("name" %in% names(tool))
        expect_true("description" %in% names(tool))
        expect_true("args_schema" %in% names(tool))
        expect_true(".mcp" %in% names(tool))

        # Check .mcp metadata
        expect_equal(tool$.mcp$type, "tool")
        expect_equal(tool$.mcp$server_name, "github")
        expect_s3_class(tool$.mcp$client, "McpClient")
    }

    # Check for some expected GitHub tools
    tool_names <- purrr::map_chr(tools, "name")
    expect_true(any(grepl("search_code", tool_names, ignore.case = TRUE)))

    # Extract a specific tool
    search_code_tool <- get_mcp_tool(tools, "search_code")
    expect_type(search_code_tool, "list")
    expect_equal(search_code_tool$name, "search_code")
    expect_equal(search_code_tool$args_schema$type, "object")
    expect_equal(search_code_tool$args_schema$properties$query$type, "string")
})

test_that("execute_mcp_tool() works with GitHub MCP tools", {
    skip_on_cran()
    skip_if_not(nzchar(Sys.getenv("PAT_GITHUB")), "PAT_GITHUB not set")
    skip_if_not(Sys.which("npx") != "", "npx not available")

    client <- tryCatch(
        mcp_connect(
            name = "github",
            type = "http",
            url = "https://api.githubcopilot.com/mcp",
            headers = list(Authorization = paste("Bearer", Sys.getenv("PAT_GITHUB")))
        ),
        error = function(e) NULL
    )

    skip_if(is.null(client), "Could not connect to GitHub MCP server")

    tools <- purrr::possibly(mcp_tools, otherwise = NULL)(client)
    skip_if(purrr::is_empty(tools), "No tools available")

    # Find a simple tool to test (like search_repositories)
    search_tool <- get_mcp_tool(tools, "search_repositories")
    skip_if(purrr::is_empty(search_tool), "No search tool available")

    # Execute the tool
    result <- tryCatch(
        execute_mcp_tool(search_tool, list(query = "language:r stars:>1000", perPage = 1)),
        error = function(e) NULL
    )

    skip_if(is.null(result), "Tool execution failed")

    expect_type(result, "character")
    expect_true(nchar(result) > 0)
})

test_that("MCP HTTP server session management works", {
    skip_on_cran()

    server <- McpServer$new(name = "test-server", version = "1.0.0")

    server$add_tool(
        tool_def = list(
            name = "echo",
            description = "Echo back the input",
            inputSchema = list(
                type = "object",
                properties = list(message = list(type = "string", description = "Message to echo")),
                required = list("message")
            )
        ),
        handler = function(message) {
            jsonlite::toJSON(list(echo = message), auto_unbox = TRUE)
        }
    )

    port <- 8081
    server_obj <- server$serve_http(host = "127.0.0.1", port = port, block = FALSE, silent = TRUE)
    on.exit(httpuv::stopServer(server_obj), add = TRUE)

    Sys.sleep(0.5)

    client <- mcp_connect(name = "test-server", type = "http", url = paste0("http://127.0.0.1:", port))

    expect_s3_class(client, "McpClientHttp")
    expect_false(is.null(client$session_id))

    tools <- client$list_tools()
    expect_type(tools, "list")
    expect_equal(length(tools), 1)
    expect_equal(tools[[1]]$name, "echo")

    result <- client$call_tool("echo", list(message = "hello"))
    expect_type(result, "character")
    expect_true(grepl("hello", result))

    if (!is.null(client$terminate_session)) {
        client$terminate_session()
        expect_null(client$session_id)
    }
})

test_that("MCP HTTP server returns correct protocol version", {
    skip_on_cran()

    server <- McpServer$new(name = "test-server", version = "1.0.0")

    port <- 8082
    server_obj <- server$serve_http(host = "127.0.0.1", port = port, block = FALSE, silent = TRUE)
    on.exit(httpuv::stopServer(server_obj), add = TRUE)

    Sys.sleep(0.5)

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

    mcp_version <- httr2::resp_header(resp, "MCP-Protocol-Version")
    expect_equal(mcp_version, "2025-06-18")

    session_id <- httr2::resp_header(resp, "Mcp-Session-Id")
    expect_false(is.null(session_id))
    expect_true(grepl("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", session_id))

    body <- httr2::resp_body_json(resp)
    expect_equal(body$result$protocolVersion, "2025-06-18")
})

test_that("MCP HTTP server handles GET and DELETE methods", {
    skip_on_cran()

    server <- McpServer$new(name = "test-server", version = "1.0.0")

    port <- 8083
    server_obj <- server$serve_http(host = "127.0.0.1", port = port, block = FALSE, silent = TRUE)
    on.exit(httpuv::stopServer(server_obj), add = TRUE)

    Sys.sleep(0.5)

    get_resp <- httr2::request(paste0("http://127.0.0.1:", port)) |> httr2::req_method("GET") |> httr2::req_perform()

    expect_equal(httr2::resp_status(get_resp), 405)
    get_body <- httr2::resp_body_json(get_resp)
    expect_equal(get_body$error, "Method Not Allowed")

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

    delete_resp <- httr2::request(paste0("http://127.0.0.1:", port)) |>
        httr2::req_method("DELETE") |>
        httr2::req_headers(`Mcp-Session-Id` = session_id) |>
        httr2::req_perform()

    expect_equal(httr2::resp_status(delete_resp), 204)

    tools_req <- list(jsonrpc = "2.0", id = 2, method = "tools/list", params = list())

    error_resp <- httr2::request(paste0("http://127.0.0.1:", port)) |>
        httr2::req_body_json(tools_req) |>
        httr2::req_headers(`Mcp-Session-Id` = session_id) |>
        httr2::req_error(is_error = \(resp) FALSE) |>
        httr2::req_perform()

    expect_equal(httr2::resp_status(error_resp), 404)
})

test_that("MCP HTTP server returns 202 for notifications", {
    skip_on_cran()

    server <- McpServer$new(name = "test-server", version = "1.0.0")

    port <- 8084
    server_obj <- server$serve_http(host = "127.0.0.1", port = port, block = FALSE, silent = TRUE)
    on.exit(httpuv::stopServer(server_obj), add = TRUE)

    Sys.sleep(0.5)

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

    notif_req <- list(jsonrpc = "2.0", method = "notifications/initialized", params = list())

    notif_resp <- httr2::request(paste0("http://127.0.0.1:", port)) |>
        httr2::req_body_json(notif_req) |>
        httr2::req_headers(`Mcp-Session-Id` = session_id) |>
        httr2::req_perform()

    expect_equal(httr2::resp_status(notif_resp), 202)
})
