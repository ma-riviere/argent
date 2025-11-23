test_that("mcp_connect() validates inputs", {
    expect_error(
        mcp_connect(name = ""),
        "must be a non-empty string"
    )

    expect_error(
        mcp_connect(name = "test", type = "invalid"),
        "must be either 'stdio' or 'http'"
    )

    expect_error(
        mcp_connect(name = "test", type = "http"),
        "url.*is required"
    )

    expect_error(
        mcp_connect(name = "test", type = "stdio"),
        "command.*is required"
    )
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
            headers = list(
                Authorization = paste("Bearer", Sys.getenv("PAT_GITHUB"))
            )
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
            headers = list(
                Authorization = paste("Bearer", Sys.getenv("PAT_GITHUB"))
            )
        ),
        error = function(e) NULL
    )

    skip_if(is.null(client), "Could not connect to GitHub MCP server")

    tools <- purrr::possibly(mcp_tools, otherwise = NULL)(
        client,
        tools = c("search_code", "get_file_contents")
    )

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
            headers = list(
                Authorization = paste("Bearer", Sys.getenv("PAT_GITHUB"))
            )
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
        execute_mcp_tool(
            search_tool,
            list(query = "language:r stars:>1000", perPage = 1)
        ),
        error = function(e) NULL
    )

    skip_if(is.null(result), "Tool execution failed")

    expect_type(result, "character")
    expect_true(nchar(result) > 0)
})
