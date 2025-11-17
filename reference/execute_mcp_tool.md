# Execute an MCP tool

Execute an MCP tool

## Usage

``` r
execute_mcp_tool(tool_def, arguments)
```

## Arguments

- tool_def:

  List. The tool definition with .mcp metadata

- arguments:

  List. The arguments to pass to the tool

## Value

The result of the tool execution

## Examples

``` r
if (FALSE) { # \dontrun{
# Assuming you have a tool_def from mcp_tools()
execute_mcp_tool(
  tool_def = github_tools[[1]],
  arguments = list(owner = "ma-riviere", repo = "argent", path = "R/aaa-utils.R", ref = "main")
)
} # }
```
