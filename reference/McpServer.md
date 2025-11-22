# MCP Server Implementation

An R6 class to create and run Model Context Protocol (MCP) servers. Use
this to expose R functions as tools to LLMs via the MCP protocol.

## Public fields

- `name`:

  Server name

- `version`:

  Server version

- `tools`:

  List of registered tools

- `resources`:

  List of registered resources

- `prompts`:

  List of registered prompts

## Methods

### Public methods

- [`McpServer$new()`](#method-McpServer-new)

- [`McpServer$add_tool()`](#method-McpServer-add_tool)

- [`McpServer$add_resource()`](#method-McpServer-add_resource)

- [`McpServer$add_prompt()`](#method-McpServer-add_prompt)

- [`McpServer$serve_stdio()`](#method-McpServer-serve_stdio)

- [`McpServer$handle_request()`](#method-McpServer-handle_request)

- [`McpServer$clone()`](#method-McpServer-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize a new MCP server

#### Usage

    McpServer$new(name, version)

#### Arguments

- `name`:

  Character string. Server name.

- `version`:

  Character string. Server version.

------------------------------------------------------------------------

### Method `add_tool()`

Add a tool to the server

#### Usage

    McpServer$add_tool(tool_def, handler)

#### Arguments

- `tool_def`:

  List definition of the tool (name, description, args_schema)

- `handler`:

  Function to execute when the tool is called. Should have named
  parameters matching the tool's arguments, with defaults for optional
  parameters. Returns a result (character, list, or other).

------------------------------------------------------------------------

### Method `add_resource()`

Add a resource to the server

#### Usage

    McpServer$add_resource(resource_def, handler)

#### Arguments

- `resource_def`:

  List definition of the resource (uri, name, description, mimeType)

- `handler`:

  Function to execute when the resource is read. Should take a uri and
  return content (text or blob).

------------------------------------------------------------------------

### Method `add_prompt()`

Add a prompt to the server

#### Usage

    McpServer$add_prompt(prompt_def, handler)

#### Arguments

- `prompt_def`:

  List definition of the prompt (name, description, arguments)

- `handler`:

  Function to execute when the prompt is requested. Should have named
  parameters matching the prompt's arguments, with defaults for optional
  parameters. Returns a list with 'messages' field (and optional
  'description' field).

------------------------------------------------------------------------

### Method `serve_stdio()`

Serve the MCP protocol over stdio This method blocks and listens for
JSON-RPC requests on stdin.

#### Usage

    McpServer$serve_stdio()

------------------------------------------------------------------------

### Method `handle_request()`

Handle a single JSON-RPC request line

#### Usage

    McpServer$handle_request(line)

#### Arguments

- `line`:

  JSON string

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    McpServer$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
