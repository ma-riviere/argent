# MCP Client Implementation

R6 classes for connecting to and interacting with MCP servers. Supports
both stdio (local process) and HTTP transports.

## Public fields

- `name`:

  Client name

## Methods

### Public methods

- [`McpClient$new()`](#method-McpClient-new)

- [`McpClient$list_tools()`](#method-McpClient-list_tools)

- [`McpClient$call_tool()`](#method-McpClient-call_tool)

- [`McpClient$list_resources()`](#method-McpClient-list_resources)

- [`McpClient$read_resource()`](#method-McpClient-read_resource)

- [`McpClient$list_prompts()`](#method-McpClient-list_prompts)

- [`McpClient$get_prompt()`](#method-McpClient-get_prompt)

- [`McpClient$send_request()`](#method-McpClient-send_request)

- [`McpClient$clone()`](#method-McpClient-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize client

#### Usage

    McpClient$new()

------------------------------------------------------------------------

### Method `list_tools()`

List tools available on the server

#### Usage

    McpClient$list_tools()

------------------------------------------------------------------------

### Method `call_tool()`

Call a tool on the server

#### Usage

    McpClient$call_tool(tool_name, args)

#### Arguments

- `tool_name`:

  Name of the tool

- `args`:

  List of arguments

------------------------------------------------------------------------

### Method `list_resources()`

List resources available on the server

#### Usage

    McpClient$list_resources()

------------------------------------------------------------------------

### Method `read_resource()`

Read a resource from the server

#### Usage

    McpClient$read_resource(uri)

#### Arguments

- `uri`:

  URI of the resource to read

------------------------------------------------------------------------

### Method `list_prompts()`

List prompts available on the server

#### Usage

    McpClient$list_prompts()

------------------------------------------------------------------------

### Method `get_prompt()`

Get a prompt from the server

#### Usage

    McpClient$get_prompt(name, arguments = NULL)

#### Arguments

- `name`:

  Name of the prompt

- `arguments`:

  List of arguments for the prompt

------------------------------------------------------------------------

### Method `send_request()`

Send a JSON-RPC request

#### Usage

    McpClient$send_request(req)

#### Arguments

- `req`:

  List containing method and params

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    McpClient$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
