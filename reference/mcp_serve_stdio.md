# Create and serve MCP server from file over stdio

Parses an R file with annotated functions and serves them as an MCP
server over stdio (standard input/output). This is a convenience wrapper
around creating an McpServer instance, parsing the file, registering
tools/resources/prompts, and starting the server.

## Usage

``` r
mcp_serve_stdio(file, name = NULL, version = NULL, groups = NULL)
```

## Arguments

- file:

  Character. Path to R file with annotated functions. Functions should
  use `#' @mcp tool|resource|prompt` annotations. Tools use `#' @param`
  tags, resources use `#' @uri` and `#' @mimeType` tags, prompts use
  `#' @param` tags for arguments.

- name:

  Character. Server name. If NULL, auto-detected from filename.

- version:

  Character. Server version. If NULL, defaults to "1.0.0".

- groups:

  Character vector. Optional. If provided, only serve
  tools/resources/prompts in the specified groups. Use the `@group`
  annotation to assign functions to groups.

## Value

NULL (server runs blocking)

## Examples

``` r
if (FALSE) { # \dontrun{
# Simple usage - auto-detects name from filename
mcp_serve_stdio("zotero_tools.R")

# Serve only specific groups
mcp_serve_stdio("all_tools.R", groups = c("zotero", "web"))

# Explicit name and version
mcp_serve_stdio("tools.R", name = "my-server", version = "2.0.0")

# Typical usage in an MCP server script
if (!interactive()) {
    mcp_serve_stdio(
        rstudioapi::getActiveDocumentContext()$path,
        name = "my-server"
    )
}
} # }
```
