# Create a structured error response for MCP tools

Returns a structured error object that MCP servers can format
appropriately for LLM agents. This provides actionable feedback instead
of generic errors.

## Usage

``` r
mcp_error(message, type = "error", details = NULL, suggestion = NULL)
```

## Arguments

- message:

  Character. Primary error message

- type:

  Character. Error category: "not_found", "validation", "api_error",
  "not_ready", or "unsupported"

- details:

  Character. Additional context about the error

- suggestion:

  Character. Actionable suggestion for fixing the error

## Value

A list with class "mcp_error" containing structured error information
