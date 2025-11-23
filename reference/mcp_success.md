# Create a structured success response for MCP tools

Returns a structured success object that can include warnings or
additional context for LLM agents.

## Usage

``` r
mcp_success(data, warning = NULL)
```

## Arguments

- data:

  The result data (character, list, or other R object)

- warning:

  Character. Optional warning message to include with success

## Value

A list with class "mcp_success" containing the data and optional warning
