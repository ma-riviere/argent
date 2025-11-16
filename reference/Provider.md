# Provider Base Class: shared interface & common functionalities for all LLM providers

Base R6 class for all LLM provider clients. Provides shared
infrastructure for:

- Chat history management (get, set, reset, append)

- Automatic history persistence to JSON (enabled by default,
  per-instance control)

- Rate limiting configuration

- Token usage tracking

This class is inherited by all provider classes (Google, Anthropic,
OpenAI_Base) to ensure consistent interfaces and eliminate code
duplication.

## History Auto-Save

History auto-save is controlled per-instance and enabled by default. To
control it:

- At initialization: Pass `auto_save_history = TRUE/FALSE` to `$new()`
  (default: TRUE)

- After creation: Use `$set_auto_save_history(TRUE/FALSE)` or
  `$get_auto_save_history()`

Manual save/load available via `dump_history()` and `load_history()`.

## Public fields

- `base_url`:

  Character. Base URL for API endpoint

- `provider_name`:

  Character. Provider name

- `rate_limit`:

  Numeric. Rate limit in requests per second

- `history_file_path`:

  Character. Full file path for persistent history storage

- `chat_history`:

  List. Conversation history (provider-specific format)

- `session_history`:

  List. Ground truth: alternating query_data and API responses

- `server_tools`:

  Character vector. Server-side tools to use for API requests

- `default_model`:

  Character. Default model to use for chat requests

## Methods

### Public methods

- [`Provider$new()`](#method-Provider-new)

- [`Provider$get_rate_limit()`](#method-Provider-get_rate_limit)

- [`Provider$set_rate_limit()`](#method-Provider-set_rate_limit)

- [`Provider$get_history()`](#method-Provider-get_history)

- [`Provider$set_history()`](#method-Provider-set_history)

- [`Provider$get_chat_history()`](#method-Provider-get_chat_history)

- [`Provider$get_session_history()`](#method-Provider-get_session_history)

- [`Provider$dump_history()`](#method-Provider-dump_history)

- [`Provider$reset_history()`](#method-Provider-reset_history)

- [`Provider$get_history_file_path()`](#method-Provider-get_history_file_path)

- [`Provider$load_history()`](#method-Provider-load_history)

- [`Provider$get_auto_save_history()`](#method-Provider-get_auto_save_history)

- [`Provider$set_auto_save_history()`](#method-Provider-set_auto_save_history)

- [`Provider$get_session_last_token_count()`](#method-Provider-get_session_last_token_count)

- [`Provider$get_session_cumulative_token_count()`](#method-Provider-get_session_cumulative_token_count)

- [`Provider$get_last_response()`](#method-Provider-get_last_response)

- [`Provider$get_content_text()`](#method-Provider-get_content_text)

- [`Provider$get_reasoning_text()`](#method-Provider-get_reasoning_text)

- [`Provider$get_generated_code()`](#method-Provider-get_generated_code)

- [`Provider$get_generated_files()`](#method-Provider-get_generated_files)

- [`Provider$download_generated_files()`](#method-Provider-download_generated_files)

- [`Provider$get_supplementary()`](#method-Provider-get_supplementary)

- [`Provider$print()`](#method-Provider-print)

- [`Provider$clone()`](#method-Provider-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize a new Provider instance

#### Usage

    Provider$new(
      base_url = NULL,
      api_key = NULL,
      provider_name = "Provider",
      rate_limit = NULL,
      server_tools = character(0),
      default_model = NULL,
      auto_save_history = TRUE
    )

#### Arguments

- `base_url`:

  Character. Base URL for API endpoint

- `api_key`:

  Character. API key for the provider

- `provider_name`:

  Character. Provider name

- `rate_limit`:

  Numeric. Rate limit in requests per second

- `server_tools`:

  Character vector. Server-side tools available

- `default_model`:

  Character. Default model to use for chat requests

- `auto_save_history`:

  Logical. Enable/disable automatic history sync (default: TRUE)

------------------------------------------------------------------------

### Method `get_rate_limit()`

Get the rate limit

#### Usage

    Provider$get_rate_limit()

#### Returns

Numeric. Rate limit in requests per second

------------------------------------------------------------------------

### Method `set_rate_limit()`

Set the rate limit

#### Usage

    Provider$set_rate_limit(rate_limit)

#### Arguments

- `rate_limit`:

  Numeric. Rate limit in requests per second

------------------------------------------------------------------------

### Method `get_history()`

Get both chat and session history

#### Usage

    Provider$get_history()

#### Returns

List. History containing both chat_history and session_history

------------------------------------------------------------------------

### Method `set_history()`

Set both chat and session history

#### Usage

    Provider$set_history(history)

#### Arguments

- `history`:

  List. Chat and session history to set (list(chat_history = ...,
  session_history = ...))

#### Returns

Self (invisibly) for method chaining

------------------------------------------------------------------------

### Method `get_chat_history()`

Get the chat history. The chat history is the history of messages
exchanged between the user and the model.

#### Usage

    Provider$get_chat_history()

#### Returns

List. Chat history

------------------------------------------------------------------------

### Method `get_session_history()`

Get the session history

#### Usage

    Provider$get_session_history()

#### Returns

List. Session history (alternating query_data and responses)

------------------------------------------------------------------------

### Method `dump_history()`

Dump both chat and session history to JSON file

#### Usage

    Provider$dump_history(dest_path = NULL)

#### Arguments

- `dest_path`:

  Character. Optional custom file path. If NULL, uses history_file_path.

#### Returns

Character. Path to saved file (invisibly)

------------------------------------------------------------------------

### Method `reset_history()`

Reset both chat and session history

#### Usage

    Provider$reset_history()

#### Details

Archives current history before resetting, then generates new
history_file_path

------------------------------------------------------------------------

### Method `get_history_file_path()`

Get the history file path

#### Usage

    Provider$get_history_file_path()

#### Returns

Character. History file path

------------------------------------------------------------------------

### Method `load_history()`

Load both chat and session history from JSON file

#### Usage

    Provider$load_history(file_path)

#### Arguments

- `file_path`:

  Character. Path to history file (absolute or relative to project root)
  or just filename

#### Returns

Self (invisibly) for method chaining

------------------------------------------------------------------------

### Method `get_auto_save_history()`

Get the auto-save history setting

#### Usage

    Provider$get_auto_save_history()

#### Returns

Logical. Auto-save history setting

------------------------------------------------------------------------

### Method `set_auto_save_history()`

Set the auto-save history setting

#### Usage

    Provider$set_auto_save_history(enabled)

#### Arguments

- `enabled`:

  Logical. Enable/disable automatic history sync

------------------------------------------------------------------------

### Method `get_session_last_token_count()`

Get the total tokens used from session_history

#### Usage

    Provider$get_session_last_token_count()

#### Returns

Integer. Total tokens used at last API call

------------------------------------------------------------------------

### Method `get_session_cumulative_token_count()`

Get the cumulative tokens used from session_history

#### Usage

    Provider$get_session_cumulative_token_count(up_to_index = NULL)

#### Arguments

- `up_to_index`:

  Integer. Index up to which to calculate the cumulative tokens
  (default: NULL)

#### Returns

Integer. Cumulative tokens used computed from session_history, up to the
specified index

------------------------------------------------------------------------

### Method `get_last_response()`

Get the last API response

#### Usage

    Provider$get_last_response()

#### Returns

List. Last API response object, or NULL if no response has been stored

------------------------------------------------------------------------

### Method `get_content_text()`

Get the text content from an API response

#### Usage

    Provider$get_content_text(api_res = self$get_last_response())

#### Arguments

- `api_res`:

  List. API response object (defaults to last response)

#### Returns

Character. Text content from response

------------------------------------------------------------------------

### Method `get_reasoning_text()`

Get the text content from reasoning in an API response

#### Usage

    Provider$get_reasoning_text(api_res = self$get_last_response())

#### Arguments

- `api_res`:

  List. API response object (defaults to last response)

#### Returns

Character or List. Text content from reasoning in response

------------------------------------------------------------------------

### Method `get_generated_code()`

Get generated code from an API response (e.g. from code execution tools)

#### Usage

    Provider$get_generated_code(
      api_res = self$get_last_response(),
      langs = NULL,
      as_chunks = FALSE
    )

#### Arguments

- `api_res`:

  List. API response object (defaults to last response)

- `langs`:

  Character vector. Languages to filter code parts by (default: NULL)

- `as_chunks`:

  Logical. Whether to return the code as a list of chunks (default:
  FALSE)

#### Returns

Character or List. Code content from response as list of chunks or as
single string

------------------------------------------------------------------------

### Method `get_generated_files()`

Get generated files from an API response (e.g. from code execution
tools)

#### Usage

    Provider$get_generated_files(api_res = self$get_last_response())

#### Arguments

- `api_res`:

  List. API response object (defaults to last response)

#### Returns

List. Files from response (each with mime_type and data), or NULL if
none found

------------------------------------------------------------------------

### Method `download_generated_files()`

Download files generated by code execution from an API response (e.g.
from code execution tools)

#### Usage

    Provider$download_generated_files(
      api_res = self$get_last_response(),
      dest_path = "data",
      overwrite = TRUE
    )

#### Arguments

- `api_res`:

  List. API response object (defaults to last response)

- `dest_path`:

  Character. Destination path for downloaded files

- `overwrite`:

  Logical. Whether to overwrite existing files

#### Returns

Character vector. Paths to saved files (invisibly)

------------------------------------------------------------------------

### Method `get_supplementary()`

Get supplementary data from an API response (annotations, citations,
grounding metadata, etc.)

#### Usage

    Provider$get_supplementary(api_res = self$get_last_response())

#### Arguments

- `api_res`:

  List. API response object (defaults to last response)

#### Returns

List. Supplementary data from response (provider-specific structure)

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print chat history in a formatted view. Inspired by ellmer

#### Usage

    Provider$print(
      show_system = TRUE,
      show_reasoning = TRUE,
      show_code = FALSE,
      show_tools = FALSE,
      show_supplementary = FALSE,
      max_content_length = 999
    )

#### Arguments

- `show_system`:

  Logical. Include system messages (default: TRUE)

- `show_reasoning`:

  Logical. Include reasoning/thinking blocks (default: TRUE)

- `show_code`:

  Logical. Include code blocks (default: FALSE)

- `show_tools`:

  Logical. Include tool calls and results (default: FALSE)

- `show_supplementary`:

  Logical. Include supplementary data like annotations, citations
  (default: FALSE)

- `max_content_length`:

  Integer. Maximum content length before truncation (default: 999)

#### Returns

Self (invisibly) for method chaining

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Provider$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
