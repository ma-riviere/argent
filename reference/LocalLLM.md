# Client for local LLM servers (e.g., llama.cpp, Ollama)

R6 class for interacting with local LLM servers (e.g., llama.cpp,
Ollama) that implement OpenAI-compatible APIs. Provides methods for chat
completions, embeddings, and tool calling capabilities.

## Super class

[`argent::Provider`](https://ma-riviere.github.io/argent/reference/Provider.md)
-\> `LocalLLM`

## Methods

### Public methods

- [`LocalLLM$new()`](#method-LocalLLM-new)

- [`LocalLLM$get_default_model_id()`](#method-LocalLLM-get_default_model_id)

- [`LocalLLM$set_default_model_id()`](#method-LocalLLM-set_default_model_id)

- [`LocalLLM$get_model_name()`](#method-LocalLLM-get_model_name)

- [`LocalLLM$list_models()`](#method-LocalLLM-list_models)

- [`LocalLLM$chat()`](#method-LocalLLM-chat)

- [`LocalLLM$embeddings()`](#method-LocalLLM-embeddings)

- [`LocalLLM$clone()`](#method-LocalLLM-clone)

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

Initialize a new Local LLM client

#### Usage

    LocalLLM$new(
      base_url = "http://localhost:5000",
      api_key = "not-needed",
      provider_name = "LocalLLM",
      rate_limit = 999999,
      server_tools = character(0),
      default_model = NULL,
      auto_save_history = TRUE
    )

#### Arguments

- `base_url`:

  Character. Base URL of the local server (default:
  "http://localhost:5000")

- `api_key`:

  Character. API key (default: "not-needed")

- `provider_name`:

  Character. Provider name (default: "LocalLLM")

- `rate_limit`:

  Numeric. Rate limit in requests per second (default: 999999)

- `server_tools`:

  Character vector. Server-side tools available (default: character(0))

- `default_model`:

  Character. Default model name (auto-detected if NULL)

- `auto_save_history`:

  Logical. Enable/disable automatic history sync (default: TRUE)

------------------------------------------------------------------------

### Method `get_default_model_id()`

Get the current model

#### Usage

    LocalLLM$get_default_model_id()

#### Returns

Character. Model name

------------------------------------------------------------------------

### Method `set_default_model_id()`

Set the model to use

#### Usage

    LocalLLM$set_default_model_id(model)

#### Arguments

- `model`:

  Character. Model name

------------------------------------------------------------------------

### Method `get_model_name()`

Get the model name (basename)

#### Usage

    LocalLLM$get_model_name()

#### Returns

Character. Model basename

------------------------------------------------------------------------

### Method `list_models()`

List all available models from the local server

#### Usage

    LocalLLM$list_models()

#### Returns

Data frame. Available models

------------------------------------------------------------------------

### Method `chat()`

Send a chat completion request to the local LLM

#### Usage

    LocalLLM$chat(
      ...,
      system = .default_system_prompt,
      model = NULL,
      temperature = 1,
      max_tokens = 4096,
      top_p = NULL,
      top_k = NULL,
      min_p = NULL,
      repeat_penalty = NULL,
      presence_penalty = NULL,
      frequency_penalty = NULL,
      mirostat = NULL,
      mirostat_tau = NULL,
      mirostat_eta = NULL,
      seed = NULL,
      tools = NULL,
      tool_choice = "auto",
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

  Character. Model to use (default: current model)

- `temperature`:

  Numeric. Sampling temperature (default: 1)

- `max_tokens`:

  Integer. Maximum tokens to generate (default: 4096)

- `top_p`:

  Numeric. Top-p (nucleus) sampling (default: 0.9, 1.0 = disabled)

- `top_k`:

  Integer. Top-k sampling (default: 40, 0 = disabled)

- `min_p`:

  Numeric. Min-p sampling (default: 0.1, 0.0 = disabled)

- `repeat_penalty`:

  Numeric. Penalize repeat sequence of tokens (default: 1.0, 1.0 =
  disabled)

- `presence_penalty`:

  Numeric. Repeat alpha presence penalty (default: 0.0, 0.0 = disabled)

- `frequency_penalty`:

  Numeric. Repeat alpha frequency penalty (default: 0.0, 0.0 = disabled)

- `mirostat`:

  Integer. Use Mirostat sampling (default: 0, 0 = disabled, 1 =
  Mirostat, 2 = Mirostat 2.0)

- `mirostat_tau`:

  Numeric. Mirostat target entropy, parameter tau (default: 5.0)

- `mirostat_eta`:

  Numeric. Mirostat learning rate, parameter eta (default: 0.1)

- `seed`:

  Integer. RNG seed (default: -1, use random seed for -1)

- `tools`:

  List. Function definitions for tool calling (optional)

- `tool_choice`:

  Character or List. Tool choice mode (default: "auto")

- `output_schema`:

  List. JSON schema for structured output (optional)

- `return_full_response`:

  Logical. Return full API response (default: FALSE)

#### Returns

Character (or List if return_full_response = TRUE). Local LLM API's
response object.

------------------------------------------------------------------------

### Method `embeddings()`

Generate embeddings for text input

#### Usage

    LocalLLM$embeddings(input, model = NULL, return_full_response = FALSE)

#### Arguments

- `input`:

  Character vector. Text(s) to embed

- `model`:

  Character. Model to use (default: current model)

- `return_full_response`:

  Logical. Return full API response (default: FALSE)

#### Returns

Numeric matrix (or List if return_full_response = TRUE). Embeddings with
one row per input text

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    LocalLLM$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
# Connect to local llama.cpp server
llm <- LocalLLM$new(base_url = "http://localhost:8080")

# With specific model
llm <- LocalLLM$new(
  base_url = "http://localhost:8080",
  model = "llama-3-8b"
)

# Simple chat completion
response <- llm$chat(
  prompt = "What is R programming?",
  temperature = 0.7
)

# With additional sampling parameters
response <- llm$chat(
  prompt = "Explain quantum computing",
  temperature = 0.8,
  top_p = 0.9,
  top_k = 40,
  min_p = 0.05,
  repeat_penalty = 1.1
)
} # }
```
