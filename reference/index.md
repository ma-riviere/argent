# Package index

## Provider Classes

### Main Provider Classes

Main classes for the supported LLM providers

- [`Google`](https://ma-riviere.github.io/argent/reference/Google.md) :
  Client for Google's Gemini API
- [`Anthropic`](https://ma-riviere.github.io/argent/reference/Anthropic.md)
  : Client for Anthropic's Claude API
- [`OpenAI_Assistant`](https://ma-riviere.github.io/argent/reference/OpenAI_Assistant.md)
  : Client for OpenAI's Assistants API
- [`OpenAI_Chat`](https://ma-riviere.github.io/argent/reference/OpenAI_Chat.md)
  : Client for OpenAI's Chat Completions API
- [`OpenAI_Responses`](https://ma-riviere.github.io/argent/reference/OpenAI_Responses.md)
  : Client for OpenAI's Responses API
- [`OpenRouter`](https://ma-riviere.github.io/argent/reference/OpenRouter.md)
  : Client for the OpenRouter API
- [`LocalLLM`](https://ma-riviere.github.io/argent/reference/LocalLLM.md)
  : Client for local LLM servers (e.g., llama.cpp, Ollama)

### Internal Classes

Parent (internal) classes

- [`Provider`](https://ma-riviere.github.io/argent/reference/Provider.md)
  : Provider Base Class: shared interface & common functionalities for
  all LLM providers
- [`OpenAI`](https://ma-riviere.github.io/argent/reference/OpenAI.md) :
  Parent class for OpenAI API clients (Responses, Chat Completions,
  Assistants)

## Utilities

### Multimodal Inputs

Helper functions for processing different types of inputs

- [`as_text_content()`](https://ma-riviere.github.io/argent/reference/content_converters.md)
  [`as_image_content()`](https://ma-riviere.github.io/argent/reference/content_converters.md)
  [`as_file_content()`](https://ma-riviere.github.io/argent/reference/content_converters.md)
  [`as_pdf_content()`](https://ma-riviere.github.io/argent/reference/content_converters.md)
  [`as_json_content()`](https://ma-riviere.github.io/argent/reference/content_converters.md)
  : Convert file paths, URLs or R objects to the specified content
  format before passing it to the LLM API

### Tools & Schemas definitions

Helper functions to define tools and schemas for structured outputs
using annotations or direct specification

- [`as_tool()`](https://ma-riviere.github.io/argent/reference/tool_definitions.md)
  [`tool()`](https://ma-riviere.github.io/argent/reference/tool_definitions.md)
  [`schema()`](https://ma-riviere.github.io/argent/reference/tool_definitions.md)
  : Generate tools and schemas definitions from functions annotations,
  or direct specification

### MCP

Helper functions for MCP integration

- [`mcp_server()`](https://ma-riviere.github.io/argent/reference/mcp_integration.md)
  [`mcp_tools()`](https://ma-riviere.github.io/argent/reference/mcp_integration.md)
  [`mcp_resources()`](https://ma-riviere.github.io/argent/reference/mcp_integration.md)
  [`mcp_prompts()`](https://ma-riviere.github.io/argent/reference/mcp_integration.md)
  : MCP (Model Context Protocol) Integration
- [`execute_mcp_tool()`](https://ma-riviere.github.io/argent/reference/execute_mcp_tool.md)
  : Execute an MCP tool

### Helpers

Helper functions

- [`flat_list()`](https://ma-riviere.github.io/argent/reference/flat_list.md)
  : Flatten a list of elements to a single-depth list
