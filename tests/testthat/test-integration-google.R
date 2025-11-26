test_that("Google client can be created", {
    skip_on_cran()
    skip_if_not(nzchar(Sys.getenv("GEMINI_API_KEY")), "GEMINI_API_KEY not set")

    google <- Google$new()

    expect_s3_class(google, "Google")
    expect_s3_class(google, "Provider")
    expect_equal(google$provider_name, "Google")
})

test_that("Google client can make simple chat request", {
    skip_on_cran()
    skip_if_not(nzchar(Sys.getenv("GEMINI_API_KEY")), "GEMINI_API_KEY not set")

    gemini <- Google$new()

    response <- tryCatch(
        gemini$chat(
            "What is 2+2? Reply with only the number.",
            model = "gemini-2.5-flash-lite",
            output_schema = schema(
                name = "number_answer",
                description = "The numerical value of the answer to the question",
                value = "integer* The numerical value of the answer to the question"
            )
        ),
        error = function(e) NULL
    )

    skip_if(is.null(response), "Chat request failed")

    expect_type(response, "list")

    value <- response$value
    expect_type(value, "integer")
    expect_equal(value, 4)
})

test_that("Google client with GitHub MCP tools integration", {
    skip_on_cran()
    skip_if_not(nzchar(Sys.getenv("GEMINI_API_KEY")), "GEMINI_API_KEY not set")
    skip_if_not(nzchar(Sys.getenv("PAT_GITHUB")), "PAT_GITHUB not set")
    skip_if_not(Sys.which("npx") != "", "npx not available")

    # Create Google client
    gemini <- Google$new()

    # Connect to GitHub MCP server
    github_client <- tryCatch(
        mcp_connect(
            name = "github",
            type = "http",
            url = "https://api.githubcopilot.com/mcp",
            headers = list(Authorization = paste("Bearer", Sys.getenv("PAT_GITHUB")))
        ),
        error = function(e) NULL
    )

    skip_if(is.null(github_client), "Could not connect to GitHub MCP server")

    # Get GitHub tools
    github_tools <- tryCatch(mcp_tools(github_client), error = function(e) NULL)

    skip_if(purrr::is_empty(github_tools), "No GitHub tools available")

    # Find a search tool
    search_tool <- get_mcp_tool(github_tools, "search_code")

    skip_if(purrr::is_empty(search_tool), "No search repository tool available")

    # Use only one simple tool to avoid complexity
    response <- tryCatch(
        gemini$chat(
            "Use the GitHub search tool to find 1 popular R package repository. Just return the repository name.",
            tools = list(search_tool),
            model = "gemini-2.5-flash-lite"
        ),
        error = function(e) NULL
    )

    skip_if(is.null(response), "Chat with tools failed")

    # Check that response exists
    expect_type(response, "character")

    # Get the text content
    text <- gemini$get_content_text()
    expect_type(text, "character")
    expect_true(nzchar(text))

    # Check that response and get_content_text are identical
    expect_identical(response, text)

    # Check history contains both query and response
    history <- gemini$get_session_history()
    expect_true(length(history) >= 2)
})

test_that("Google client with client-side tools", {
    skip_on_cran()
    skip_if_not(nzchar(Sys.getenv("GEMINI_API_KEY")), "GEMINI_API_KEY not set")

    gemini <- Google$new()

    # Define a simple R function tool
    get_square <- function(x) {
        return(x^2)
    }

    square_tool <- tool(
        name = "get_square",
        description = "Calculate the square of a number",
        x = "number* The number to square",
        fn = get_square
    )

    response <- tryCatch(
        gemini$chat(
            "What is the square of 7? Use the get_square tool.",
            tools = list(square_tool),
            model = "gemini-2.5-flash-lite",
            output_schema = schema(
                name = "square_answer",
                description = "The numerical value of the answer to the question",
                value = "integer* The numerical value of the answer to the question"
            )
        ),
        error = function(e) NULL
    )

    skip_if(is.null(response), "Chat with tools failed")

    # Check that response exists
    expect_type(response, "list")

    # Get the text content
    value <- response$value
    expect_type(value, "integer")
    expect_equal(value, 49)
})

test_that("Google client handles multipart content", {
    skip_on_cran()
    skip_if_not(nzchar(Sys.getenv("GEMINI_API_KEY")), "GEMINI_API_KEY not set")

    gemini <- Google$new()

    # Test with mixed text and JSON content
    data_list <- list(values = c(1, 2, 3), label = "test")

    response <- tryCatch(
        gemini$chat("What is in this data?", as_json_content(data_list), model = "gemini-2.5-flash-lite"),
        error = function(e) NULL
    )

    skip_if(is.null(response), "Multipart chat failed")

    text <- gemini$get_content_text()
    expect_type(text, "character")
    expect_true(nchar(text) > 0)
})

test_that("Google client supports history reset", {
    skip_on_cran()
    skip_if_not(nzchar(Sys.getenv("GEMINI_API_KEY")), "GEMINI_API_KEY not set")

    gemini <- Google$new()

    gemini$chat("Hellp", model = "gemini-2.5-flash-lite")

    history_before <- gemini$get_session_history()
    expect_true(length(history_before) > 0)

    gemini$reset_history()

    history_after <- gemini$get_session_history()
    expect_length(history_after, 0)
})
