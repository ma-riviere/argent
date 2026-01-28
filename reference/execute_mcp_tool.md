# Execute an MCP tool

This is meant to test MCP tools manually, simulating a tool call from an
LLM.

## Usage

``` r
execute_mcp_tool(tool_def, arguments = list())
```

## Arguments

- tool_def:

  List. The tool definition (e.g. one of the items returned by
  [`mcp_tools()`](https://ma-riviere.github.io/argent/reference/mcp_integration.md)).

- arguments:

  List. The arguments to pass to the tool

## Value

The result of the tool execution
