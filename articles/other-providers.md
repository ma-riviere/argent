# OpenAI or Anthropic compatible APIs

## Overview

The argent provider classes can be used with any API that implements
compatible protocols. This flexibility allows you to use argent with
various LLM providers beyond the default ones (Google, Anthropic,
OpenAI, OpenRouter) by simply changing the `base_url` parameter.

## Key Concepts

All argent provider classes accept a `base_url` parameter in their
constructor. By providing a different base URL, you can point the same
provider class to a compatible alternative service.

Common patterns:

- **Anthropic-compatible APIs**: Use the `Anthropic` class with a
  different base_url
- **OpenAI-compatible APIs**: Use `OpenAI_Chat` or `OpenAI_Responses`
  with a different base_url

## Examples

### Minimax API (Anthropic-compatible)

Minimax provides an Anthropic-compatible API. You can use argent’s
`Anthropic` class by simply changing the base URL:

``` r
minimax <- Anthropic$new(
    base_url = "https://api.minimax.io/anthropic",
    api_key = Sys.getenv("MINIMAX_API_KEY"),
    provider_name = "Minimax",
    default_model = "MiniMax-M2"
)

minimax$chat("What is the R programming language? Answer in two sentences.")
```

All features of the `Anthropic` class will work with Minimax, except
server-side tools.
