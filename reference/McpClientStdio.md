# Standard IO MCP Client

A client for interacting with local MCP servers via stdio.

## Super class

[`argent::McpClient`](https://ma-riviere.github.io/argent/reference/McpClient.md)
-\> `McpClientStdio`

## Public fields

- `process`:

  processx process object

## Methods

### Public methods

- [`McpClientStdio$new()`](#method-McpClientStdio-new)

- [`McpClientStdio$initialize_connection()`](#method-McpClientStdio-initialize_connection)

- [`McpClientStdio$send_request()`](#method-McpClientStdio-send_request)

- [`McpClientStdio$send_notification()`](#method-McpClientStdio-send_notification)

- [`McpClientStdio$close()`](#method-McpClientStdio-close)

- [`McpClientStdio$is_alive()`](#method-McpClientStdio-is_alive)

- [`McpClientStdio$clone()`](#method-McpClientStdio-clone)

Inherited methods

- [`argent::McpClient$call_tool()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-call_tool)
- [`argent::McpClient$get_prompt()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-get_prompt)
- [`argent::McpClient$is_closed()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-is_closed)
- [`argent::McpClient$list_prompts()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-list_prompts)
- [`argent::McpClient$list_resources()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-list_resources)
- [`argent::McpClient$list_tools()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-list_tools)
- [`argent::McpClient$read_resource()`](https://ma-riviere.github.io/argent/reference/McpClient.html#method-read_resource)

------------------------------------------------------------------------

### Method `new()`

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

### Method `initialize_connection()`

Initialize MCP connection

#### Usage

    McpClientStdio$initialize_connection()

------------------------------------------------------------------------

### Method `send_request()`

Send request to stdio process

#### Usage

    McpClientStdio$send_request(req)

#### Arguments

- `req`:

  Request list

------------------------------------------------------------------------

### Method `send_notification()`

Send notification (no ID, no response expected)

#### Usage

    McpClientStdio$send_notification(req)

#### Arguments

- `req`:

  Request list

------------------------------------------------------------------------

### Method [`close()`](https://rdrr.io/r/base/connections.html)

Close the connection and terminate the server process. Attempts graceful
interrupt first, then force-kills if needed.

#### Usage

    McpClientStdio$close()

------------------------------------------------------------------------

### Method `is_alive()`

Check if the server process is alive

#### Usage

    McpClientStdio$is_alive()

#### Returns

Logical

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    McpClientStdio$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
