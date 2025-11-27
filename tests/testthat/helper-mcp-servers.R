# Mock MCP Servers for Testing
# These servers are used across multiple test files to ensure consistency

# ----- HELPER FUNCTIONS -------------------------------------------------------

#' Get the full path to Rscript binary
#'
#' This ensures we use the correct Rscript binary on all platforms,
#' avoiding PATH resolution issues on CI systems.
rscript_binary <- function() {
    if (isTRUE(Sys.info()[["sysname"]] == "Windows")) {
        return(file.path(R.home("bin"), "Rscript.exe"))
    }
    file.path(R.home("bin"), "Rscript")
}

# ----- CALCULATOR SERVER (STDIO) ----------------------------------------------

add_numbers <- function(a, b) {
    #' @description Add two numbers
    #' @mcp tool
    #' @param a:number* First number
    #' @param b:number* Second number
    if (!is.numeric(a) || !is.numeric(b)) {
        return(argent:::mcp_error(
            message = "Both arguments must be numbers",
            type = "validation",
            suggestion = "Provide numeric values for a and b"
        ))
    }
    as.character(a + b)
}

greet_person <- function(name, greeting = "Hello") {
    #' @description Greet someone
    #' @mcp tool
    #' @param name:string* Name to greet
    #' @param greeting:string Optional greeting (default: "Hello")
    paste0(greeting, ", ", name, "!")
}

get_timestamp <- function(format = "%Y-%m-%d %H:%M:%S") {
    #' @description Get current date/time
    #' @mcp tool
    #' @param format:string Format string for date
    format(Sys.time(), format)
}

# ----- DATA PROCESSOR SERVER (HTTP) -------------------------------------------

echo_message <- function(message) {
    #' @description Echo input
    #' @mcp tool
    #' @param message:string* Message to echo
    jsonlite::toJSON(list(echo = message), auto_unbox = TRUE)
}

validate_age <- function(age) {
    #' @description Validate age
    #' @mcp tool
    #' @param age:integer* Age to validate
    if (age < 0) {
        return(argent:::mcp_error(
            message = "Age must be non-negative",
            type = "validation",
            details = paste("Received:", age),
            suggestion = "Provide an age >= 0"
        ))
    }
    if (age > 150) {
        return(argent:::mcp_error(
            message = "Age seems unrealistic",
            type = "validation",
            details = paste("Received:", age),
            suggestion = "Provide a realistic age"
        ))
    }
    paste("Valid age:", age)
}

process_list <- function(items, operation = "count") {
    #' @description Process list
    #' @mcp tool
    #' @param items:[string]* List of items
    #' @param operation:string Operation to perform (reverse, sort, count)
    result <- switch(
        operation,
        "reverse" = rev(items),
        "sort" = sort(items),
        "count" = length(items),
        argent:::mcp_error(
            message = "Unknown operation",
            type = "validation",
            suggestion = "Use 'reverse', 'sort', or 'count'"
        )
    )
    jsonlite::toJSON(result, auto_unbox = TRUE)
}

# ----- COMPLEX TYPE TOOLS -----------------------------------------------------

create_user <- function(user) {
    #' @description Creates user with nested address object
    #' @mcp tool
    #' @param user:{name:string*, email:string*, address:{street:string*, city:string*, zip:string}}* User data
    user
}

process_orders <- function(orders) {
    #' @description Process a batch of orders
    #' @mcp tool
    #' @param orders:[{id:string*, items:[{sku:string*, qty:integer*}]*, total:number}]* Order list
    orders
}

# ----- MCP RESOURCES ----------------------------------------------------------

get_system_status <- function() {
    #' @description Returns system health status
    #' @mcp resource
    #' @uri resource://system/status
    #' @mimeType application/json
    jsonlite::toJSON(list(status = "ok", timestamp = Sys.time()), auto_unbox = TRUE)
}

my_resource <- function() {
    #' @description A resource with defaults
    #' @mcp resource
    "content"
}

# ----- MCP PROMPTS ------------------------------------------------------------

greet_prompt <- function(name, style = "casual") {
    #' @description Creates a personalized greeting
    #' @mcp prompt
    #' @param name:string* Person's name
    #' @param style:string Greeting style (formal/casual)
    msg <- if (style == "formal") {
        paste0("Good day, ", name, ".")
    } else {
        paste0("Hey ", name, "!")
    }
    list(messages = list(list(role = "user", content = list(type = "text", text = msg))))
}

# ----- HELPER FUNCTIONS FOR SERVING -------------------------------------------

#' Serve calculator STDIO server (for callr::r_bg)
#'
#' @param helper_file Path to helper-mcp-servers.R file (optional, auto-detected in tests)
serve_calculator_stdio <- function(helper_file = NULL) {
    if (is.null(helper_file)) {
        helper_file <- testthat::test_path("helper-mcp-servers.R")
    }

    tools <- argent:::parse_mcp_file(helper_file)$tools
    server <- argent:::McpServer$new(name = "calculator", version = "1.0.0")

    for (tool_name in c("add_numbers", "greet_person", "get_timestamp")) {
        tool <- argent::get_mcp_tool(tools, tool_name)
        server$add_tool(tool)
    }

    server$serve_stdio()
}

#' Serve data processor HTTP server (for callr::r_bg)
#'
#' @param port Port number to serve on
#' @param helper_file Path to helper-mcp-servers.R file (optional, auto-detected in tests)
serve_processor_http <- function(port, helper_file = NULL) {
    if (is.null(helper_file)) {
        helper_file <- testthat::test_path("helper-mcp-servers.R")
    }

    tools <- argent:::parse_mcp_file(helper_file)$tools
    server <- argent:::McpServer$new(name = "processor", version = "1.0.0")

    for (tool_name in c("echo_message", "validate_age", "process_list")) {
        tool <- argent::get_mcp_tool(tools, tool_name)
        server$add_tool(tool)
    }

    server$serve_http(host = "127.0.0.1", port = port, block = TRUE, silent = TRUE)
}

# ----- TEST HELPERS (from test-mcp-client.R) ----------------------------------

#' Find an available port for testing
find_available_port <- function() {
    repeat {
        port <- sample(8000:9000, 1)
        test <- tryCatch(
            {
                s <- httpuv::startServer("127.0.0.1", port, list(call = function(req) list(status = 200L)))
                httpuv::stopServer(s)
                TRUE
            },
            error = function(e) FALSE
        )
        if (test) return(port)
    }
}

#' Wait for HTTP server to be ready
#'
#' @param port Port number to check
#' @param max_attempts Maximum number of attempts
#' @param delay Delay between attempts in seconds
wait_for_server <- function(port, max_attempts = 20, delay = 0.5) {
    for (i in seq_len(max_attempts)) {
        result <- tryCatch(
            {
                httr2::request(paste0("http://127.0.0.1:", port)) |>
                    httr2::req_method("GET") |>
                    httr2::req_error(is_error = \(resp) FALSE) |>
                    httr2::req_perform()
                TRUE
            },
            error = function(e) FALSE
        )
        if (result) {
            return(TRUE)
        }
        Sys.sleep(delay)
    }
    FALSE
}
