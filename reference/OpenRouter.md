# Client for the OpenRouter API

R6 class for interacting with OpenRouter's API.

## Features

- Client-side conversation state management

- Client-side tools

- Server-side tools

- Multimodal inputs (files, images, PDFs, R objects)

- Provider routing and preferences

- Reasoning

- Structured outputs

## Useful links

- API reference: https://openrouter.ai/docs/api-reference/overview

- API docs: https://openrouter.ai/docs/quickstart

## Main entrypoints

- `chat()`: Multi-turn multimodal conversations with tool use and
  structured outputs.

- `embeddings()`: Vector embeddings for text inputs.

## Server-side tools

- "web_search" for web search grounding via OpenRouter's web plugin

## Structured outputs

Function-call trick for all models: uses tool calling to simulate
structured outputs, always requiring an additional API query with full
chat history (incurs extra cost).

## Super class

[`argent::Provider`](https://ma-riviere.github.io/argent/reference/Provider.md)
-\> `OpenRouter`

## Public fields

- `allowed_providers`:

  Character vector. Allowed provider slugs (default: NULL)

- `blocked_providers`:

  Character vector. Blocked provider slugs (default: NULL)

## Methods

### Public methods

- [`OpenRouter$new()`](#method-OpenRouter-new)

- [`OpenRouter$get_allowed_providers()`](#method-OpenRouter-get_allowed_providers)

- [`OpenRouter$set_allowed_providers()`](#method-OpenRouter-set_allowed_providers)

- [`OpenRouter$get_blocked_providers()`](#method-OpenRouter-get_blocked_providers)

- [`OpenRouter$set_blocked_providers()`](#method-OpenRouter-set_blocked_providers)

- [`OpenRouter$list_providers()`](#method-OpenRouter-list_providers)

- [`OpenRouter$list_models()`](#method-OpenRouter-list_models)

- [`OpenRouter$get_model_info()`](#method-OpenRouter-get_model_info)

- [`OpenRouter$embeddings()`](#method-OpenRouter-embeddings)

- [`OpenRouter$chat()`](#method-OpenRouter-chat)

- [`OpenRouter$clone()`](#method-OpenRouter-clone)

Inherited methods

- [`argent::Provider$download_generated_files()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-download_generated_files)
- [`argent::Provider$dump_history()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-dump_history)
- [`argent::Provider$get_auto_save_history()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_auto_save_history)
- [`argent::Provider$get_chat_history()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_chat_history)
- [`argent::Provider$get_content_text()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_content_text)
- [`argent::Provider$get_generated_code()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_generated_code)
- [`argent::Provider$get_generated_files()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_generated_files)
- [`argent::Provider$get_history()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_history)
- [`argent::Provider$get_history_file_path()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_history_file_path)
- [`argent::Provider$get_last_response()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_last_response)
- [`argent::Provider$get_rate_limit()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_rate_limit)
- [`argent::Provider$get_reasoning_text()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_reasoning_text)
- [`argent::Provider$get_session_cumulative_token_count()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_session_cumulative_token_count)
- [`argent::Provider$get_session_history()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_session_history)
- [`argent::Provider$get_session_last_token_count()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_session_last_token_count)
- [`argent::Provider$get_supplementary()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_supplementary)
- [`argent::Provider$load_history()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-load_history)
- [`argent::Provider$print()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-print)
- [`argent::Provider$reset_history()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-reset_history)
- [`argent::Provider$set_auto_save_history()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-set_auto_save_history)
- [`argent::Provider$set_history()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-set_history)
- [`argent::Provider$set_rate_limit()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-set_rate_limit)

------------------------------------------------------------------------

### Method `new()`

Initialize a new OpenRouter client

#### Usage

    OpenRouter$new(
      base_url = "https://openrouter.ai/api",
      api_key = Sys.getenv("OPENROUTER_API_KEY"),
      provider_name = "OpenRouter",
      rate_limit = 20/60,
      server_tools = c("web_search"),
      default_model = "openrouter/auto",
      allowed_providers = NULL,
      blocked_providers = NULL,
      auto_save_history = TRUE
    )

#### Arguments

- `base_url`:

  Character. Base URL for API (default: "https://openrouter.ai/api")

- `api_key`:

  Character. API key (default: from OPENROUTER_API_KEY env var)

- `provider_name`:

  Character. Provider name (default: "OpenRouter")

- `rate_limit`:

  Numeric. Rate limit in requests per second (default: 20/60)

- `server_tools`:

  Character vector. Server-side tools available (default:
  c("web_search"))

- `default_model`:

  Character. Default model to use for chat requests (default:
  "openrouter/auto")

- `allowed_providers`:

  Character vector. Allowed provider slugs (default: NULL)

- `blocked_providers`:

  Character vector. Blocked provider slugs (default: NULL)

- `auto_save_history`:

  Logical. Enable/disable automatic history sync (default: TRUE)

------------------------------------------------------------------------

### Method `get_allowed_providers()`

Get the list of allowed providers

#### Usage

    OpenRouter$get_allowed_providers()

#### Returns

Character vector. Allowed provider slugs, or NULL if none set

------------------------------------------------------------------------

### Method `set_allowed_providers()`

Set the list of allowed providers for all requests

#### Usage

    OpenRouter$set_allowed_providers(providers)

#### Arguments

- `providers`:

  Character vector. Provider slugs to allow (e.g., c("anthropic",
  "openai"))

------------------------------------------------------------------------

### Method `get_blocked_providers()`

Get the list of blocked providers

#### Usage

    OpenRouter$get_blocked_providers()

#### Returns

Character vector. Blocked provider slugs, or NULL if none set

------------------------------------------------------------------------

### Method `set_blocked_providers()`

Set the list of blocked providers for all requests

#### Usage

    OpenRouter$set_blocked_providers(providers)

#### Arguments

- `providers`:

  Character vector. Provider slugs to block (e.g., c("deepinfra",
  "together"))

------------------------------------------------------------------------

### Method `list_providers()`

List all available providers from OpenRouter

#### Usage

    OpenRouter$list_providers()

#### Returns

Data frame. Available providers with their specifications

------------------------------------------------------------------------

### Method `list_models()`

List all available models from OpenRouter

#### Usage

    OpenRouter$list_models(supported_parameters = NULL)

#### Arguments

- `supported_parameters`:

  Character vector. Supported parameters to filter models by. Options
  include: "tools", "temperature", "top_p", "top_k", "min_p", "top_a",
  "frequency_penalty", "presence_penalty", "repetition_penalty",
  "max_tokens", "logit_bias", "logprobs", "top_logprobs", "seed",
  "response_format", "structured_outputs", "stop",
  "parallel_tool_calls", "include_reasoning", "reasoning",
  "web_search_options", "verbosity". Example: c("tools",
  "response_format")

#### Returns

Data frame. Available models with their specifications

------------------------------------------------------------------------

### Method `get_model_info()`

Get information about a specific model

#### Usage

    OpenRouter$get_model_info(model_id)

#### Arguments

- `model_id`:

  Character. Model ID (e.g., "anthropic/claude-3.5-sonnet")

#### Returns

List. Model information

------------------------------------------------------------------------

### Method `embeddings()`

Generate embeddings for text input

#### Usage

    OpenRouter$embeddings(
      input,
      model,
      encoding_format = "float",
      dimensions = NULL,
      provider = NULL,
      return_full_response = FALSE
    )

#### Arguments

- `input`:

  Character vector. Text(s) to embed

- `model`:

  Character. Model to use (e.g., "text-embedding-3-small",
  "text-embedding-3-large")

- `encoding_format`:

  Character. Format of embeddings: "float" or "base64" (default:
  "float")

- `dimensions`:

  Integer. Number of dimensions for output (only for embedding-3 models)

- `provider`:

  Character. Specific provider to use (optional, enables provider
  routing)

- `return_full_response`:

  Logical. Return full API response (default: FALSE)

#### Returns

Numeric matrix (or List if return_full_response = TRUE). Embeddings with
one row per input text

#### Examples

    \dontrun{
    openrouter <- OpenRouter$new()

    # Generate embeddings
    embeddings <- openrouter$embeddings(
      input = c("Hello world", "How are you?"),
      model = "openai/text-embedding-3-small"
    )

    # With dimension reduction
    embeddings <- openrouter$embeddings(
      input = "Sample text",
      model = "openai/text-embedding-3-large",
      dimensions = 256
    )

    # With provider routing
    embeddings <- openrouter$embeddings(
      input = "Sample text",
      model = "text-embedding-3-small",
      provider = "openai"
    )
    }

------------------------------------------------------------------------

### Method `chat()`

Send a chat completion request to OpenRouter

#### Usage

    OpenRouter$chat(
      ...,
      system = .default_system_prompt,
      model = "openrouter/auto",
      temperature = 1,
      max_tokens = 4096,
      top_p = NULL,
      top_k = NULL,
      frequency_penalty = NULL,
      presence_penalty = NULL,
      repetition_penalty = NULL,
      min_p = NULL,
      top_a = NULL,
      seed = NULL,
      stop_sequences = NULL,
      logit_bias = NULL,
      logprobs = NULL,
      top_logprobs = NULL,
      tools = NULL,
      tool_choice = "auto",
      parallel_tool_calls = NULL,
      cache_prompt = FALSE,
      cache_system = FALSE,
      thinking_budget = 0,
      verbosity = NULL,
      provider_options = NULL,
      output_schema = NULL,
      return_full_response = FALSE
    )

#### Arguments

- `...`:

  One or more inputs for the prompt. Can be text strings, file paths,
  URLs, R objects, or content wrapped with `as_*_content()` functions. R
  objects (but not plain strings) will include their names and structure
  in the context sent to the model.

- `system`:

  Character. System instructions (optional)

- `model`:

  Character. Model to use (e.g., "anthropic/claude-3.5-sonnet")

- `temperature`:

  Numeric. Sampling temperature (default: 1)

- `max_tokens`:

  Integer. Maximum tokens to generate (default: 4096)

- `top_p`:

  Numeric. Nucleus sampling - restricts token selection to those whose
  cumulative probability equals top_p. Range: 0.0-1.0 (optional)

- `top_k`:

  Integer. Top-K sampling - limits token choices to top N selections.
  Set to 1 for deterministic output (optional)

- `frequency_penalty`:

  Numeric. Reduces reuse of tokens appearing frequently in input. Range:
  -2.0 to 2.0 (optional)

- `presence_penalty`:

  Numeric. Penalizes token reuse regardless of frequency. Range: -2.0 to
  2.0 (optional)

- `repetition_penalty`:

  Numeric. Decreases token repetition from input. Range: 0.0-2.0
  (optional)

- `min_p`:

  Numeric. Minimum relative probability threshold for token
  consideration. Range: 0.0-1.0 (optional)

- `top_a`:

  Numeric. Filters tokens based on sufficiently high probabilities
  relative to the most likely token. Range: 0.0-1.0 (optional)

- `seed`:

  Integer. Enables deterministic sampling when repeated with identical
  parameters (optional)

- `stop_sequences`:

  Character vector. Sequences that halt generation when encountered
  (optional)

- `logit_bias`:

  Named list. Applies bias values (-100 to 100) to token logits before
  sampling (optional)

- `logprobs`:

  Logical. Returns log probabilities for output tokens when enabled
  (optional)

- `top_logprobs`:

  Integer. Number of most probable tokens with log probabilities to
  return. Range: 0-20. Requires logprobs = TRUE (optional)

- `tools`:

  List. Function definitions for tool calling, or server tools
  (optional). Server-side tools:

  - "web_search" for web search grounding via OpenRouter's web plugin

  - list(type = "web_search", engine = "exa", max_results = 3) for
    advanced configuration

    - engine: "native" (provider's server-side search), "exa" (Exa API),
      or NULL (auto-select)

    - max_results: Maximum results to include (default: 5, only for Exa)

    - search_prompt: Custom prompt for results (optional) Pricing: Exa
      charges \$4/1000 results (~\$0.02 per request with default 5
      results). Native search pricing varies by provider.

- `tool_choice`:

  Character or List. Tool choice mode (default: "auto"). Note: Some
  models don't support "auto". If you get an error about "does not
  support auto tool", either:

  - Use tool_choice = "none" to disable tools

  - Use tool_choice = list(type = "function", function = list(name =
    "tool_name")) to force a specific tool (model will always use it)

  - Choose a different model that supports "auto"

- `parallel_tool_calls`:

  Logical. Allow simultaneous tool execution (default: TRUE) (optional)

- `cache_prompt`:

  Logical. Cache the user prompt (default: FALSE). For Anthropic/Google
  models, adds cache_control breakpoint. Minimum 1024 tokens for Google
  2.5 Flash, 2048 for Google 2.5 Pro, 4096 for Anthropic. Other
  providers cache automatically.

- `cache_system`:

  Logical. Cache system instructions (default: FALSE). For
  Anthropic/Google models only.

- `thinking_budget`:

  Integer. Thinking budget in tokens: 0 (disabled) or any positive
  integer (default: 0). Only for models that support reasoning tokens
  (e.g., o1, DeepSeek-R1).

- `verbosity`:

  Character. Adjusts response length and detail level: "low", "medium",
  or "high" (default: "medium") (optional)

- `provider_options`:

  List. Provider routing options (optional). See
  https://openrouter.ai/docs/features/provider-routing for details.
  Possible elements:

  - order: Character vector. List of provider slugs to try in order

  - allow_fallbacks: Logical. Allow backup providers when primary is
    unavailable (default: TRUE)

  - require_parameters: Logical. Only use providers supporting all
    parameters (default: FALSE)

  - data_collection: Character. "allow" or "deny" - control provider
    data storage

  - zdr: Logical. Restrict routing to only ZDR (Zero Data Retention)
    endpoints

  - enforce_distillable_text: Logical. Restrict routing to only models
    allowing text distillation

  - only: Character vector. List of provider slugs to allow (overrides
    class-level allowed_providers)

  - ignore: Character vector. List of provider slugs to skip (overrides
    class-level blocked_providers)

  - quantizations: Character vector. List of quantization levels to
    filter by (e.g., c("int4", "int8"))

  - sort: Character. Sort providers by "price" or "throughput"

  - max_price: List. Maximum pricing (e.g., list(prompt = 0.001,
    completion = 0.002))

- `output_schema`:

  List. JSON schema for structured output (optional)

- `return_full_response`:

  Logical. Return full API response (default: FALSE)

#### Returns

Character (or List if return_full_response = TRUE). OpenRouter API's
response object.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    OpenRouter$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
# Initialize with API key from environment
openrouter <- OpenRouter$new()

# Or provide API key explicitly
openrouter <- OpenRouter$new(api_key = "your-api-key")

# Simple chat completion
response <- openrouter$chat(
  prompt = "What is R programming?",
  model = "anthropic/claude-3.5-sonnet"
)

# With web search (simple method)
response <- openrouter$chat(
  prompt = "What are the latest developments in quantum computing?",
  model = "anthropic/claude-3.5-sonnet",
  tools = list("web_search")
)

# With web search using specific engine and custom settings
response <- openrouter$chat(
  prompt = "Recent news about R programming language",
  model = "openai/gpt-4o",
  tools = list(
    list(type = "web_search", engine = "exa", max_results = 3)
  )
)

# With tools/function calling
response <- openrouter$chat(
  prompt = "What's the weather in Paris?",
  model = "anthropic/claude-3.5-sonnet",
  tools = list(get_weather_tool)
)
} # }

## ------------------------------------------------
## Method `OpenRouter$embeddings`
## ------------------------------------------------

if (FALSE) { # \dontrun{
openrouter <- OpenRouter$new()

# Generate embeddings
embeddings <- openrouter$embeddings(
  input = c("Hello world", "How are you?"),
  model = "openai/text-embedding-3-small"
)

# With dimension reduction
embeddings <- openrouter$embeddings(
  input = "Sample text",
  model = "openai/text-embedding-3-large",
  dimensions = 256
)

# With provider routing
embeddings <- openrouter$embeddings(
  input = "Sample text",
  model = "text-embedding-3-small",
  provider = "openai"
)
} # }
```
