# HTTP MCP Client

A client for interacting with remote MCP servers via HTTP.

## Super class

[`argent::McpClient`](https://ma-riviere.github.io/argent/reference/McpClient.md)
-\> `McpClientHttp`

## Public fields

- `url`:

  Server URL

- `headers`:

  HTTP headers

- `session_id`:

  Session ID from server

## Methods

### Public methods

- [`McpClientHttp$new()`](#method-McpClientHttp-new)

- [`McpClientHttp$initialize_connection()`](#method-McpClientHttp-initialize_connection)

- [`McpClientHttp$send_request()`](#method-McpClientHttp-send_request)

- [`McpClientHttp$clone()`](#method-McpClientHttp-clone)

Inherited methods

- [`argent::McpClient$call_tool()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-call_tool)
- [`argent::McpClient$get_prompt()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-get_prompt)
- [`argent::McpClient$list_prompts()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-list_prompts)
- [`argent::McpClient$list_resources()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-list_resources)
- [`argent::McpClient$list_tools()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-list_tools)
- [`argent::McpClient$read_resource()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-read_resource)

------------------------------------------------------------------------

### Method `new()`

Initialize HTTP client

#### Usage

    McpClientHttp$new(url, headers = NULL)

#### Arguments

- `url`:

  Server URL

- `headers`:

  Named list of headers

------------------------------------------------------------------------

### Method `initialize_connection()`

Initialize connection

#### Usage

    McpClientHttp$initialize_connection()

------------------------------------------------------------------------

### Method `send_request()`

Send request via HTTP

#### Usage

    McpClientHttp$send_request(req, is_init = FALSE)

#### Arguments

- `req`:

  Request list

- `is_init`:

  Boolean, if TRUE, captures session ID

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    McpClientHttp$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
