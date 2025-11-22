# argent: Argent: LLM Agents in R

Provides a unified interface for interacting with Large Language Models
(LLMs) from multiple providers, specialized for creating AI agents with
tool calling, multimodal inputs, and universal structured outputs.

The argent package provides a unified interface for creating AI agents
that can interact with multiple Large Language Model (LLM) providers
through R6 classes. It supports Google, Anthropic, OpenAI, OpenRouter,
and local LLM servers (e.g., llama.cpp, Ollama).

argent is specialized for building AI agents with conversation history
management, local function and MCP tools, server-side tools, multimodal
inputs, and universal structured outputs.

## Main Classes

The package provides the following R6 classes:

- [`Google`](https://ma-riviere.github.io/argent/reference/Google.md):

  Client for Google's API with support for chat completions, function
  calling, thinking mode, code execution, and web search

- [`Anthropic`](https://ma-riviere.github.io/argent/reference/Anthropic.md):

  Client for Anthropic's API with prompt caching, tool calling, and
  extended thinking capabilities

- [`OpenAI_Chat`](https://ma-riviere.github.io/argent/reference/OpenAI_Chat.md):

  Client for OpenAI's Chat Completions API

- [`OpenAI_Responses`](https://ma-riviere.github.io/argent/reference/OpenAI_Responses.md):

  Client for OpenAI's Responses API with comprehensive file management,
  vector stores, code execution, and web search

- [`OpenAI_Assistant`](https://ma-riviere.github.io/argent/reference/OpenAI_Assistant.md):

  Client for OpenAI's Assistants API (Deprecated)

- [`OpenRouter`](https://ma-riviere.github.io/argent/reference/OpenRouter.md):

  Client for OpenRouter API providing access to multiple LLM providers
  through a unified interface

- [`LocalLLM`](https://ma-riviere.github.io/argent/reference/LocalLLM.md):

  Client for local LLM servers implementing OpenAI-compatible APIs

## Features

- Unified interface across multiple LLM providers: OpenAI, Anthropic,
  Google, OpenRouter, and Local LLM

- Support for all 3 of OpenAI's APIs: Chat Completions, Responses, and
  Assistants

- Function and MCP tool calling (http & stdio)

- Universal structured JSON outputs (works with any model supporting
  tool calling)

- Multimodal inputs (text, images, PDFs, data files, URLs, R objects),
  customizable and extensible

- Server-side (built-in) tools, like code execution, web search/fetch,
  file search, etc.

- Client-side conversation history management with automatic on-disk
  persistence

- Prompt caching (for providers supporting it)

- File upload and vector/file store management for server-side RAG

## Getting Started

Set up API keys as environment variables:

- `GEMINI_API_KEY` for Google

- `ANTHROPIC_API_KEY` for Anthropic

- `OPENAI_API_KEY` for OpenAI

- `OPENAI_ORG` for OpenAI organization (optional)

- `OPENROUTER_API_KEY` for OpenRouter

## See also

Useful links:

- <https://ma-riviere.github.io/argent>

- <https://github.com/ma-riviere/argent>

## Author

**Maintainer**: Marc-Aurèle Rivière <marc.aurele.riviere@gmail.com>
([ORCID](https://orcid.org/0000-0002-5108-3382))

## Examples

``` r
if (FALSE) { # \dontrun{
# Google
google <- Google$new()
response <- google$chat("What is R programming?")

# Anthropic
anthropic <- Anthropic$new()
response <- anthropic$chat(
  prompt = "Explain quantum computing",
  model = "claude-sonnet-4-5-20250929"
)

# OpenAI Responses API
openai <- OpenAI_Responses$new()
response <- openai$chat(
  prompt = "Write a haiku about R",
  model = "gpt-5-chat-latest"
)

# OpenRouter
openrouter <- OpenRouter$new()
response <- openrouter$chat(
  prompt = "Explain machine learning",
  model = "anthropic/claude-sonnet-4"
)

# Local LLM
llm <- LocalLLM$new(base_url = "http://localhost:5000")
response <- llm$chat(prompt = "Hello!")

get_weather <- function(location) {
  #' @description Get weather information for a location
  #' @param location:string* The location to get weather for
  paste("Weather in", location, "is sunny")
}

google$chat(
  "What's the weather in Paris, London, and Tokyo?",
  tools = list(as_tool(get_weather)),
  model = "gemini-2.5-flash"
)
} # }
```
