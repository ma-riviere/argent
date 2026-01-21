# Parse a file and extract all MCP definitions (tools/resources/prompts)

Parses an R file and extracts functions with MCP annotations. Functions
must use inline annotations (inside the function body with `#'` prefix)
similar to
[`as_tool()`](https://ma-riviere.github.io/argent/dev/reference/as_tool.md).

Supported annotations:

- `@description`: Function description (required)

- `@mcp tool|resource|prompt`: MCP type (defaults to "tool" if omitted)

- `@group`: Group name for organizing tools (defaults to "general")

- `@param name:type* description`: Parameter specification (for
  tools/prompts)

- `@uri`: Resource URI (for resources)

- `@mimeType`: Resource MIME type (for resources)

## Usage

``` r
parse_mcp_file(file, groups = NULL)
```

## Arguments

- file:

  Character. Path to R file with annotated functions

- groups:

  Character vector. Optional. If provided, only return
  tools/resources/prompts in the specified groups. If NULL (default),
  return all.

## Value

List with `tools`, `resources`, `prompts` fields (each a list)

## Examples

``` r
if (FALSE) { # \dontrun{
# Parse a file with annotated tools
parsed <- parse_mcp_file("inst/examples/zotero_tools.R")

# Parse only specific groups
parsed <- parse_mcp_file("inst/examples/all_tools.R", groups = c("zotero", "web"))

# Inspect results
length(parsed$tools)      # Number of tools found
length(parsed$resources)  # Number of resources found
length(parsed$prompts)    # Number of prompts found

# Access a specific tool
tool <- parsed$tools[[1]]
tool$name
tool$description
tool$group
tool$args_schema
} # }
```
