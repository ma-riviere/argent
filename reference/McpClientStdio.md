# Standard IO MCP Client

A client for interacting with local MCP servers via stdio.

## Super class

[`McpClient`](https://ma-riviere.github.io/argent/reference/McpClient.md)
-\> `McpClientStdio`

## Public fields

- `process`:

  processx process object

## Methods

### Public methods

- [`McpClientStdio$new()`](#method-McpClientStdio-initialize)

- [`McpClientStdio$initialize_connection()`](#method-McpClientStdio-initialize_connection)

- [`McpClientStdio$send_request()`](#method-McpClientStdio-send_request)

- [`McpClientStdio$send_notification()`](#method-McpClientStdio-send_notification)

- [`McpClientStdio$close()`](#method-McpClientStdio-close)

- [`McpClientStdio$is_alive()`](#method-McpClientStdio-is_alive)

- [`McpClientStdio$clone()`](#method-McpClientStdio-clone)

Inherited methods

- [`McpClient$call_tool()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-call_tool)
- [`McpClient$get_prompt()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-get_prompt)
- [`McpClient$is_closed()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-is_closed)
- [`McpClient$list_prompts()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-list_prompts)
- [`McpClient$list_resources()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-list_resources)
- [`McpClient$list_tools()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-list_tools)
- [`McpClient$read_resource()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-read_resource)

------------------------------------------------------------------------

### `McpClientStdio$new()`

Initialize stdio client

#### Usage

    McpClientStdio$new(command, args = character(), env = NULL)

#### Arguments

- `command`:

  Command to run

- `args`:

  Arguments for the command

- `env`:

  Environment variables

------------------------------------------------------------------------

### `McpClientStdio$initialize_connection()`

Initialize MCP connection

#### Usage

    McpClientStdio$initialize_connection()

------------------------------------------------------------------------

### `McpClientStdio$send_request()`

Send request to stdio process

#### Usage

    McpClientStdio$send_request(req)

#### Arguments

- `req`:

  Request list

------------------------------------------------------------------------

### `McpClientStdio$send_notification()`

Send notification (no ID, no response expected)

#### Usage

    McpClientStdio$send_notification(req)

#### Arguments

- `req`:

  Request list

------------------------------------------------------------------------

### `McpClientStdio$close()`

Close the connection and terminate the server process. Attempts graceful
interrupt first, then force-kills if needed.

#### Usage

    McpClientStdio$close()

------------------------------------------------------------------------

### `McpClientStdio$is_alive()`

Check if the server process is alive

#### Usage

    McpClientStdio$is_alive()

#### Returns

Logical

------------------------------------------------------------------------

### `McpClientStdio$clone()`

The objects of this class are cloneable with this method.

#### Usage

    McpClientStdio$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
