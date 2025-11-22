# MCP (Model Context Protocol) Integration

Functions for integrating MCP servers with argent. MCP servers provide
tools, resources, and prompts that LLMs can use during conversations.

### MCP Server Connection

`mcp_connect()` creates a client connection to an MCP server.

- For **stdio** servers (command-line tools), it spawns a subprocess.

- For **HTTP** servers (remote APIs), it configures the endpoint.

### Capability Discovery

- `mcp_tools()` retrieves tool definitions from a connected MCP client
  and converts them to argent's tool format.

- `mcp_resources()` retrieves resource definitions from a connected MCP
  client. Resources expose data/content via URIs (files, datasets,
  documentation, etc.).

- `mcp_prompts()` retrieves prompt definitions from a connected MCP
  client. Prompts are pre-defined message templates with optional
  arguments.

## Usage

``` r
mcp_connect(
  name,
  type = "stdio",
  command = NULL,
  args = NULL,
  env = NULL,
  url = NULL,
  headers = NULL
)

mcp_tools(client, tools = NULL)

mcp_resources(client, resources = NULL)

mcp_prompts(client, prompts = NULL)
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

  Character. HTTP endpoint URL (for http servers)

- headers:

  Named list. HTTP headers (for http servers)

- client:

  An MCP client object returned by `mcp_connect()`

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

- `mcp_connect()`: An `McpClient` object (R6)

- `mcp_tools()`: List of tool definitions in argent format

- `mcp_resources()`: List of resource definitions in argent format

- `mcp_prompts()`: List of prompt definitions in argent format
