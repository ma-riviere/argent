# Client for OpenAI's Chat Completions API

R6 class for interacting with OpenAI's Chat Completions API
(v1/chat/completions). Provides methods for chat completions.

This class inherits file management and vector store functionalities
from its parent class OpenAI.

## Features

- Client-side chat history management

- Tool calling

- Multimodal inputs

- Uploaded file inputs

- Structured outputs

## Useful links

- API reference: https://platform.openai.com/docs/api-reference/chat

- API docs:
  https://platform.openai.com/docs/guides/completions/introduction

## Server-side tools

- "web_search" for web search grounding via OpenAI's web plugin

## Super classes

[`argent::Provider`](https://ma-riviere.github.io/argent/reference/Provider.md)
-\>
[`argent::OpenAI`](https://ma-riviere.github.io/argent/reference/OpenAI.md)
-\> `OpenAI_Chat`

## Public fields

- `provider_name`:

  Character. Provider name (OpenAI Chat)

- `server_tools`:

  Character vector. Server-side tools to use for API requests

## Methods

### Public methods

- [`OpenAI_Chat$new()`](#method-OpenAI_Chat-new)

- [`OpenAI_Chat$chat()`](#method-OpenAI_Chat-chat)

- [`OpenAI_Chat$clone()`](#method-OpenAI_Chat-clone)

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
- [`argent::OpenAI$add_file_to_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-add_file_to_store)
- [`argent::OpenAI$create_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-create_store)
- [`argent::OpenAI$delete_all_files()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-delete_all_files)
- [`argent::OpenAI$delete_all_files_from_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-delete_all_files_from_store)
- [`argent::OpenAI$delete_all_stores()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-delete_all_stores)
- [`argent::OpenAI$delete_file()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-delete_file)
- [`argent::OpenAI$delete_file_from_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-delete_file_from_store)
- [`argent::OpenAI$delete_files()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-delete_files)
- [`argent::OpenAI$delete_files_from_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-delete_files_from_store)
- [`argent::OpenAI$delete_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-delete_store)
- [`argent::OpenAI$delete_store_and_files()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-delete_store_and_files)
- [`argent::OpenAI$delete_stores()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-delete_stores)
- [`argent::OpenAI$download_file()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-download_file)
- [`argent::OpenAI$embeddings()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-embeddings)
- [`argent::OpenAI$find_assistants()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-find_assistants)
- [`argent::OpenAI$find_file()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-find_file)
- [`argent::OpenAI$find_file_in_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-find_file_in_store)
- [`argent::OpenAI$find_models()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-find_models)
- [`argent::OpenAI$find_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-find_store)
- [`argent::OpenAI$get_file()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-get_file)
- [`argent::OpenAI$get_file_content()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-get_file_content)
- [`argent::OpenAI$get_model_info()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-get_model_info)
- [`argent::OpenAI$list_assistants()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-list_assistants)
- [`argent::OpenAI$list_files()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-list_files)
- [`argent::OpenAI$list_files_in_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-list_files_in_store)
- [`argent::OpenAI$list_models()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-list_models)
- [`argent::OpenAI$list_stores()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-list_stores)
- [`argent::OpenAI$read_file_from_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-read_file_from_store)
- [`argent::OpenAI$read_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-read_store)
- [`argent::OpenAI$update_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-update_store)
- [`argent::OpenAI$upload_file()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-upload_file)
- [`argent::OpenAI$upload_file_from_df()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-upload_file_from_df)

------------------------------------------------------------------------

### Method `new()`

Initialize a new OpenAI Chat client

#### Usage

    OpenAI_Chat$new(
      api_key = Sys.getenv("OPENAI_API_KEY"),
      org = Sys.getenv("OPENAI_ORG"),
      base_url = "https://api.openai.com",
      rate_limit = 60/60,
      auto_save_history = TRUE
    )

#### Arguments

- `api_key`:

  Character. API key (default: from OPENAI_API_KEY env var)

- `org`:

  Character. Organization ID (default: from OPENAI_ORG env var)

- `base_url`:

  Character. Base URL for API (default: "https://api.openai.com")

- `rate_limit`:

  Numeric. Rate limit in requests per second (default: 60/60)

- `auto_save_history`:

  Logical. Enable/disable automatic history sync (default: TRUE)

------------------------------------------------------------------------

### Method `chat()`

Send a chat completion request to OpenAI

#### Usage

    OpenAI_Chat$chat(
      ...,
      system = .default_system_prompt,
      model = "gpt-5-mini",
      temperature = 1,
      max_completion_tokens = 4096,
      top_p = 1,
      frequency_penalty = 0,
      presence_penalty = 0,
      logprobs = FALSE,
      top_logprobs = NULL,
      n = 1,
      logit_bias = NULL,
      tools = NULL,
      tool_choice = "auto",
      output_schema = NULL,
      reasoning_effort = NULL,
      verbosity = "medium",
      store = FALSE,
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

  Character. Model to use (default: "gpt-5-mini")

- `temperature`:

  Numeric. Sampling temperature (default: 1)

- `max_completion_tokens`:

  Integer. Maximum tokens to generate (default: 4096)

- `top_p`:

  Numeric. Nucleus sampling parameter 0-1 (default: 1). Alternative to
  temperature. We recommend altering this or temperature but not both.

- `frequency_penalty`:

  Numeric. Penalty for token frequency -2.0 to 2.0 (default: 0).
  Positive values decrease likelihood of repeating the same line
  verbatim.

- `presence_penalty`:

  Numeric. Penalty for token presence -2.0 to 2.0 (default: 0). Positive
  values increase likelihood of talking about new topics.

- `logprobs`:

  Logical. Whether to return log probabilities (default: FALSE)

- `top_logprobs`:

  Integer. Number of most likely tokens (0-20) to return at each
  position (default: NULL). Requires logprobs = TRUE.

- `n`:

  Integer. Number of chat completion choices to generate (default: 1)

- `logit_bias`:

  Named list. Modify likelihood of specified tokens by token ID
  (default: NULL). Values from -100 to 100.

- `tools`:

  List. Client-side function definitions for tool calling (optional).
  For web search with search-enabled models (gpt-4o-mini-search-preview,
  gpt-4o-search-preview, gpt-5-search-api), pass as:
  `list("web_search")` or with options:
  `list(list(type = "web_search", user_location = list(...), search_context_size = "medium"))`.
  Supported web_search options:

  - `user_location`: list with `type = "approximate"` and `approximate`
    containing `country` (ISO 3166-1), `city`, `region`, and/or
    `timezone` (IANA)

  - `search_context_size`: "low", "medium" (default), or "high"

  **Note**: Search models do not support standard sampling parameters
  (temperature, top_p, frequency_penalty, presence_penalty, n). These
  are automatically omitted when using search models.

- `tool_choice`:

  Character or List. Tool choice mode (default: "auto")

- `output_schema`:

  List. JSON schema for structured output (optional)

- `reasoning_effort`:

  Character. Reasoning effort level for reasoning models: "low",
  "medium", or "high" (optional). Only applicable to reasoning models
  (o1, o3, o4, gpt-5). Default: NULL (uses model default)

- `verbosity`:

  Character. Verbosity level for output: "low", "medium", or "high"
  (default: "medium")

- `store`:

  Logical. Whether or not to store the output of this chat completion
  request in OpenAI servers (default: FALSE)

- `return_full_response`:

  Logical. Return full API response (default: FALSE)

#### Returns

Character (or List if return_full_response = TRUE). OpenAI Chat API's
response object.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    OpenAI_Chat$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
# Initialize with API key from environment
openai <- OpenAI_Chat$new()

# Or provide API key explicitly
openai <- OpenAI_Chat$new(api_key = "your-api-key")

# Simple chat completion
response <- openai$chat(
  prompt = "What is R programming?",
  model = "gpt-5-chat-latest"
)

# With tools/function calling
response <- openai$chat(
  prompt = "What's the weather in Paris?",
  tools = list(get_weather_tool)
)

# Upload file and use in chat
file <- openai$upload_file("document.pdf", purpose = "user_data")
response <- openai$chat(
  prompt = openai$multimodal_input(
    "Summarize this document:",
    as_file_ref(file$id)
  )
)
} # }
```
