# argent: Argent: LLM Agents in R

Provides a unified R6-based interface for creating AI agents that can
interact with multiple Large Language Model (LLM) providers including
Google Gemini, Anthropic Claude, OpenAI GPT, OpenRouter, and local LLM
servers. Supports chat completions, function calling, structured
outputs, conversation history, and advanced features like prompt caching
and vector stores.

The argent package provides a unified interface for creating AI agents
that can interact with multiple Large Language Model (LLM) providers
through R6 classes. It supports Google, Anthropic, OpenAI, OpenRouter,
and local LLM servers (e.g., llama.cpp, Ollama).

## Main Classes

The package provides the following R6 classes:

- [`Google`](https://ma-riviere.github.io/argent/reference/Google.md):

  Client for Google's API with support for chat completions, function
  calling, and thinking mode

- [`Anthropic`](https://ma-riviere.github.io/argent/reference/Anthropic.md):

  Client for Anthropic's API with prompt caching and tool calling
  capabilities

- [`OpenAI`](https://ma-riviere.github.io/argent/reference/OpenAI.md):

  Client for OpenAI's API with comprehensive file management, vector
  stores, and chat completions

- `OpenAIAssistant`:

  Client for OpenAI's Assistants API with thread management and
  persistent conversations

- [`OpenRouter`](https://ma-riviere.github.io/argent/reference/OpenRouter.md):

  Client for OpenRouter API providing access to multiple LLM providers
  through a unified interface

- [`LocalLLM`](https://ma-riviere.github.io/argent/reference/LocalLLM.md):

  Client for local LLM servers implementing OpenAI-compatible APIs

## Features

- Unified interface across multiple LLM providers

- Support for function/tool calling

- Structured JSON outputs

- Conversation history management

- Prompt caching (Anthropic)

- File and vector store management (OpenAI)

- Local LLM support

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

- <https://ma-riviere.github.io/argent/>

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

# OpenAI
openai <- OpenAI$new()
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
} # }
```
