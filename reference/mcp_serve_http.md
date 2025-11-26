# Create and serve MCP server from file over HTTP

Parses an R file with annotated functions and serves them as an MCP
server over HTTP. This is a convenience wrapper around creating an
McpServer instance, parsing the file, registering
tools/resources/prompts, and starting the server.

## Usage

``` r
mcp_serve_http(
  file,
  name = NULL,
  version = NULL,
  groups = NULL,
  host = "127.0.0.1",
  port = 8080,
  ...
)
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

- host:

  Character. Host to bind to (default: "127.0.0.1")

- port:

  Integer. Port to listen on (default: 8080)

- ...:

  Additional arguments passed to `McpServer$serve_http()`

## Value

NULL (server runs blocking by default)

## Examples

``` r
if (FALSE) { # \dontrun{
# Simple usage - auto-detects name from filename
mcp_serve_http("zotero_tools.R", port = 8080)

# Serve only specific groups
mcp_serve_http("all_tools.R", groups = c("zotero", "web"), port = 8080)

# Explicit name and version
mcp_serve_http("tools.R", name = "my-server", version = "2.0.0", port = 8080)

# With custom settings
mcp_serve_http(
    "tools.R",
    name = "my-server",
    port = 8080,
    block = TRUE,
    silent = FALSE
)
} # }
```
