# argent: Argent: LLM Agents in R

Provides a unified interface for interacting with Large Language Models
(LLMs) from multiple providers, specialized for creating AI agents with
tool calling, multimodal inputs, and structured outputs.

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

- Unified interface across multiple LLM providers

- Function and MCP tool calling with parallel execution support

- Universal structured JSON outputs (works with any model supporting
  tool calling)

- Multimodal inputs (text, images, PDFs, data files, URLs, R objects)

- Server-side tools (code execution, web search, file search, RAG)

- Conversation history management with automatic persistence

- Prompt caching (Anthropic, OpenAI)

- File upload and vector store management (Google, Anthropic, OpenAI)

- Reasoning and thinking modes (Google, Anthropic, OpenAI)

## Parallel Tool Calls

Tool calls can be executed in parallel using
[`mirai::daemons()`](https://mirai.r-lib.org/reference/daemons.html).
This can significantly speed up responses when multiple tools are called
simultaneously.

To enable parallel execution:

- Set up mirai daemons before making requests: `mirai::daemons(6)`

- argent will automatically parallelize multiple tool calls in the same
  response

- Without daemons, tool calls execute sequentially (default fallback
  behavior)

To ensure parallel execution is always used, add
[`mirai::require_daemons()`](https://mirai.r-lib.org/reference/require_daemons.html)
before making requests. To disable parallel processing, call
`mirai::daemons(0)`.

Performance considerations:

- Parallelization overhead can outweigh benefits for very fast tool
  calls

- Most beneficial when tools take 100+ microseconds per call

- As a rule of thumb, use at most one fewer daemon than available CPU
  cores

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

# Parallel tool calling
library(mirai)
daemons(4)  # Set up 4 parallel workers

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
# Tool calls will execute in parallel across the 4 workers

daemons(0)  # Clean up when done
} # }
```
