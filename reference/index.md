# Package index

## Provider Classes

### Main Provider Classes

Main classes for the supported LLM providers

- [`Google`](https://ma-riviere.github.io/argent/reference/Google.md) :
  Google API Client
- [`Anthropic`](https://ma-riviere.github.io/argent/reference/Anthropic.md)
  : Anthropic API Client
- [`OpenAI_Assistant`](https://ma-riviere.github.io/argent/reference/OpenAI_Assistant.md)
  : OpenAI Assistant API Client
- [`OpenAI_Chat`](https://ma-riviere.github.io/argent/reference/OpenAI_Chat.md)
  : OpenAI Chat Completions API Client
- [`OpenAI_Responses`](https://ma-riviere.github.io/argent/reference/OpenAI_Responses.md)
  : OpenAI Responses API Client
- [`OpenRouter`](https://ma-riviere.github.io/argent/reference/OpenRouter.md)
  : OpenRouter API Client
- [`LocalLLM`](https://ma-riviere.github.io/argent/reference/LocalLLM.md)
  : Local LLM API Client

### Parent Provider Class

Parent class for all LLM providers (internal use only)

- [`Provider`](https://ma-riviere.github.io/argent/reference/Provider.md)
  : Provider Base Class

## Utilities

### Multimodal Inputs

Helper functions for processing different types of inputs

- [`as_text_content()`](https://ma-riviere.github.io/argent/reference/content_converters.md)
  [`as_image_content()`](https://ma-riviere.github.io/argent/reference/content_converters.md)
  [`as_file_content()`](https://ma-riviere.github.io/argent/reference/content_converters.md)
  [`as_pdf_content()`](https://ma-riviere.github.io/argent/reference/content_converters.md)
  [`as_json_content()`](https://ma-riviere.github.io/argent/reference/content_converters.md)
  : Convert inputs to content for multimodal API requests

### Tools & Schemas definitions

Helper functions to define tools and schemas for structured outputs
using annotations or direct specification

- [`as_tool()`](https://ma-riviere.github.io/argent/reference/tool_definitions.md)
  [`tool()`](https://ma-riviere.github.io/argent/reference/tool_definitions.md)
  [`schema()`](https://ma-riviere.github.io/argent/reference/tool_definitions.md)
  : Tool Definitions
