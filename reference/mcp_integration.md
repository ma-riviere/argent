# MCP (Model Context Protocol) Integration

Functions for integrating MCP servers with argent. MCP servers provide
tools, resources, and prompts that LLMs can use during conversations.

### MCP Server Connection

`mcp_server()` creates a connection to an MCP server using programmatic
configuration. For stdio servers, the server is spawned as a subprocess
and communicates via JSON-RPC over stdin/stdout. For HTTP servers,
communication happens via HTTP requests to the specified endpoint.

### Tool Discovery

`mcp_tools()` retrieves tool definitions from an MCP server and converts
them to argent's tool format. Tools can then be passed to `chat()`
alongside client-defined and provider server tools.

### Resources and Prompts

`mcp_resources()` retrieves file-like structured data that LLMs can
access. `mcp_prompts()` retrieves predefined templates for interactions.

## Usage

``` r
mcp_server(
  name,
  type = "stdio",
  command = NULL,
  args = NULL,
  env = NULL,
  url = NULL,
  headers = NULL
)

mcp_tools(server, tools = NULL)

mcp_resources(server, resources = NULL)

mcp_prompts(server, prompts = NULL)
```

## Arguments

- name:

  Character. Name identifier for the MCP server

- type:

  Character. Server type: "stdio" for command-line or "http" for HTTP
  endpoint (default: "stdio")

- command:

  Character. Command to execute (for stdio servers, e.g., "docker",
  "npx")

- args:

  Character vector. Arguments to pass to the command (for stdio servers)

- env:

  Named list. Environment variables for the server process (for stdio
  servers)

- url:

  Character. HTTP endpoint URL (for http servers, e.g.,
  "https://api.githubcopilot.com/mcp")

- headers:

  Named list. HTTP headers (for http servers, e.g., list(Authorization =
  "Bearer token"))

- server:

  An MCP server object created by `mcp_server()`

- tools:

  Character vector. Specific tool names to retrieve. If NULL, retrieves
  all tools

- resources:

  Character vector. Specific resource URIs to retrieve. If NULL,
  retrieves all

- prompts:

  Character vector. Specific prompt names to retrieve. If NULL,
  retrieves all

## Value

- `mcp_server()`: An MCP server connection object (list with class
  "mcp_server")

- `mcp_tools()`: List of tool definitions in argent format

- `mcp_resources()`: List of resource definitions

- `mcp_prompts()`: List of prompt definitions

## Examples

``` r
if (FALSE) { # \dontrun{
# HTTP server configuration (GitHub Copilot MCP)
github <- mcp_server(
  name = "github",
  type = "http",
  url = "https://api.githubcopilot.com/mcp",
  headers = list(
    Authorization = paste("Bearer", Sys.getenv("GITHUB_PAT"))
  )
)

# Stdio server configuration (Docker)
filesystem <- mcp_server(
  name = "filesystem",
  type = "stdio",
  command = "docker",
  args = c("run", "-i", "--rm", "mcp/filesystem"),
  env = list()
)

# Get all tools from server
github_tools <- mcp_tools(github)

# Get specific tools only
issue_tools <- mcp_tools(github, tools = c("search_issues", "create_issue"))

# Use in chat with other tools
google <- Google$new()
google$chat(
  "Create an issue for the bug I found",
  tools = list(
    github_tools,
    as_tool(my_custom_function)
  )
)

# Get resources
github_resources <- mcp_resources(github)
} # }
```
