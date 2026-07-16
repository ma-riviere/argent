# HTTP MCP Client

A client for interacting with remote MCP servers via HTTP.

## Super class

[`McpClient`](https://ma-riviere.github.io/argent/reference/McpClient.md)
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

- [`McpClientHttp$new()`](#method-McpClientHttp-initialize)

- [`McpClientHttp$initialize_connection()`](#method-McpClientHttp-initialize_connection)

- [`McpClientHttp$send_request()`](#method-McpClientHttp-send_request)

- [`McpClientHttp$terminate_session()`](#method-McpClientHttp-terminate_session)

- [`McpClientHttp$close()`](#method-McpClientHttp-close)

- [`McpClientHttp$clone()`](#method-McpClientHttp-clone)

Inherited methods

- [`McpClient$call_tool()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-call_tool)
- [`McpClient$get_prompt()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-get_prompt)
- [`McpClient$is_closed()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-is_closed)
- [`McpClient$list_prompts()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-list_prompts)
- [`McpClient$list_resources()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-list_resources)
- [`McpClient$list_tools()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-list_tools)
- [`McpClient$read_resource()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-read_resource)

------------------------------------------------------------------------

### `McpClientHttp$new()`

Initialize HTTP client

#### Usage

    McpClientHttp$new(url, headers = NULL)

#### Arguments

- `url`:

  Server URL

- `headers`:

  Named list of headers

------------------------------------------------------------------------

### `McpClientHttp$initialize_connection()`

Initialize connection

#### Usage

    McpClientHttp$initialize_connection()

------------------------------------------------------------------------

### `McpClientHttp$send_request()`

Send request via HTTP

#### Usage

    McpClientHttp$send_request(req, is_init = FALSE)

#### Arguments

- `req`:

  Request list

- `is_init`:

  Boolean, if TRUE, captures session ID

------------------------------------------------------------------------

### `McpClientHttp$terminate_session()`

Terminate the HTTP session

#### Usage

    McpClientHttp$terminate_session()

------------------------------------------------------------------------

### `McpClientHttp$close()`

Close the client connection and terminate the HTTP session.

#### Usage

    McpClientHttp$close()

------------------------------------------------------------------------

### `McpClientHttp$clone()`

The objects of this class are cloneable with this method.

#### Usage

    McpClientHttp$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
