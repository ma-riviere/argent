# Anthropic API Client

R6 class for interacting with Anthropic's API. Provides methods for chat
completions with support for prompt caching, tool calling, and
structured outputs.

## Useful links

- API reference: https://docs.claude.com/en/api/overview

- API docs: https://docs.claude.com/en/docs/intro

## Server-side tools

- "code_execution" for bash commands and file operations (pricing:
  \$0.05/session-hour, 5-min min)

- "web_search" for web search capabilities. Can also be a list with
  `search_options`.

- "web_fetch" to fetch content from a URL provided in the prompt.

## Super class

[`argent::Provider`](https://ma-riviere.github.io/argent/reference/Provider.md)
-\> `Anthropic`

## Public fields

- `default_beta_features`:

  Character vector. Default beta features to use for API requests

## Methods

### Public methods

- [`Anthropic$new()`](#method-Anthropic-new)

- [`Anthropic$list_models()`](#method-Anthropic-list_models)

- [`Anthropic$get_model_info()`](#method-Anthropic-get_model_info)

- [`Anthropic$upload_file()`](#method-Anthropic-upload_file)

- [`Anthropic$get_file_metadata()`](#method-Anthropic-get_file_metadata)

- [`Anthropic$download_file()`](#method-Anthropic-download_file)

- [`Anthropic$list_files()`](#method-Anthropic-list_files)

- [`Anthropic$delete_file()`](#method-Anthropic-delete_file)

- [`Anthropic$embeddings()`](#method-Anthropic-embeddings)

- [`Anthropic$chat()`](#method-Anthropic-chat)

- [`Anthropic$clone()`](#method-Anthropic-clone)

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

Initialize a new Anthropic client

#### Usage

    Anthropic$new(
      base_url = "https://api.anthropic.com",
      api_key = Sys.getenv("ANTHROPIC_API_KEY"),
      provider_name = "Anthropic",
      rate_limit = 50/60,
      server_tools = c("code_execution", "web_search", "web_fetch"),
      default_model = "claude-haiku-4-5-20251001",
      auto_save_history = TRUE
    )

#### Arguments

- `base_url`:

  Character. Base URL for API (default: "https://api.anthropic.com")

- `api_key`:

  Character. API key (default: from ANTHROPIC_API_KEY env var)

- `provider_name`:

  Character. Provider name (default: "Anthropic")

- `rate_limit`:

  Numeric. Rate limit in requests per second (default: 50/60)

- `server_tools`:

  Character vector. Server-side tools available (default:
  c("code_execution", "web_search", "web_fetch"))

- `default_model`:

  Character. Default model to use for chat requests (default:
  "claude-haiku-4-5-20251001")

- `auto_save_history`:

  Logical. Enable/disable automatic history sync (default: TRUE)

------------------------------------------------------------------------

### Method `list_models()`

List all available Anthropic models

#### Usage

    Anthropic$list_models()

#### Returns

Data frame. Available models with their specifications

------------------------------------------------------------------------

### Method `get_model_info()`

Get information about a specific Anthropic model

#### Usage

    Anthropic$get_model_info(model_id)

#### Arguments

- `model_id`:

  Character. Model ID (e.g., "claude-sonnet-4-5-20250929")

#### Returns

List. Model information

------------------------------------------------------------------------

### Method `upload_file()`

Upload a file to Anthropic Files API

#### Usage

    Anthropic$upload_file(file_path, file_name = NULL)

#### Arguments

- `file_path`:

  Character. Path to the file to upload, or URL to a remote file

- `file_name`:

  Character. Optional custom name for the uploaded file. If NULL
  (default), uses the basename of file_path.

#### Returns

List. File metadata or NULL on error

------------------------------------------------------------------------

### Method `get_file_metadata()`

Get metadata for an uploaded file

#### Usage

    Anthropic$get_file_metadata(file_id)

#### Arguments

- `file_id`:

  Character. File ID (e.g., "file-abc123")

#### Returns

List. File metadata or NULL on error

------------------------------------------------------------------------

### Method `download_file()`

Download file content. Only files created by Anthropic's Code Execution
tool can be downloaded.

Downloads the file content and saves it to the specified path. If
dest_path is a directory, the file is saved with its original filename.
If dest_path is a file path, it is used as the complete destination
path.

#### Usage

    Anthropic$download_file(file_id, dest_path = "data", overwrite = TRUE)

#### Arguments

- `file_id`:

  Character. File ID (e.g., "file-abc123")

- `dest_path`:

  Character. Destination path (default: "data"). Can be either a
  directory path or a complete file path. If NULL, returns content as
  raw bytes without saving. Created if it doesn't exist.

- `overwrite`:

  Logical. Whether to overwrite existing files (default: TRUE).

#### Returns

Raw vector (if dest_path is NULL) or Character path to downloaded file
(invisibly)

#### Examples

    \dontrun{
    anthropic <- Anthropic$new()

    # Download to a directory
    path <- anthropic$download_file(file_id = "file-abc123", dest_path = "downloads")

    # Download with specific filename
    path <- anthropic$download_file(file_id = "file-abc123", dest_path = "downloads/myfile.txt")

    # Get raw bytes without saving
    raw_content <- anthropic$download_file(file_id = "file-abc123", dest_path = NULL)
    }

------------------------------------------------------------------------

### Method `list_files()`

List all uploaded files

#### Usage

    Anthropic$list_files(
      limit = 20,
      before_id = NULL,
      after_id = NULL,
      as_df = TRUE
    )

#### Arguments

- `limit`:

  Integer. Number of files per page (default: 20, max: 1000)

- `before_id`:

  Character. ID for pagination (optional)

- `after_id`:

  Character. ID for pagination (optional)

- `as_df`:

  Logical. Whether to return files as a data frame (default: TRUE). If
  FALSE, returns raw list.

#### Returns

Data frame (if as_df = TRUE) or list (if as_df = FALSE). Files metadata
and pagination info.

------------------------------------------------------------------------

### Method `delete_file()`

Delete an uploaded file

#### Usage

    Anthropic$delete_file(file_id)

#### Arguments

- `file_id`:

  Character. File ID (e.g., "file-abc123")

#### Returns

Logical. TRUE if successful, FALSE otherwise

------------------------------------------------------------------------

### Method `embeddings()`

Generate embeddings for text input

Note: Anthropic does not provide a native embeddings API. For
embeddings, consider using:

- Voyage AI (recommended by Anthropic)

- OpenAI (text-embedding-3-small, text-embedding-3-large)

- Google (text-embedding-004)

- Other embedding providers available through OpenRouter

#### Usage

    Anthropic$embeddings(...)

#### Arguments

- `...`:

  Arguments (not used, included for method signature consistency)

#### Returns

This method always throws an error

------------------------------------------------------------------------

### Method `chat()`

Send a chat completion request to Anthropic

#### Usage

    Anthropic$chat(
      ...,
      cache_prompt = FALSE,
      model = "claude-haiku-4-5-20251001",
      system = .default_system_prompt,
      cache_system = FALSE,
      max_tokens = 4096,
      temperature = 1,
      top_p = NULL,
      top_k = NULL,
      tools = NULL,
      tool_choice = list(type = "auto"),
      cache_tools = FALSE,
      output_schema = NULL,
      thinking_budget = 0,
      return_full_response = FALSE
    )

#### Arguments

- `...`:

  One or more inputs for the prompt. Can be text strings, file paths,
  URLs, R objects, or content wrapped with `as_*_content()` functions. R
  objects (but not plain strings) will include their names and structure
  in the context sent to the model.

- `cache_prompt`:

  Logical. Cache the prompt for reuse (default: FALSE)

- `model`:

  Character. Model to use (default: "claude-haiku-4-5-20251001")

- `system`:

  Character. System instructions (optional)

- `cache_system`:

  Logical. Cache system instructions (default: FALSE)

- `max_tokens`:

  Integer. Maximum tokens to generate (default: 4096)

- `temperature`:

  Numeric. Sampling temperature (default: 1). Range: 0.0-1.0

- `top_p`:

  Numeric. Nucleus sampling - use cumulative probability distribution.
  Range: 0.0-1.0 (optional). Should be used instead of temperature for
  advanced use cases

- `top_k`:

  Integer. Sample from top K options only. Minimum: 0 (optional). For
  advanced use cases

- `tools`:

  List. Tool definitions (server-side or client-side functions).
  Server-side tools:

  - "code_execution" for bash commands and file operations (pricing:
    \$0.05/session-hour, 5-min min)

  - list(type = "code_execution", container = container_id) to reuse an
    existing container

  - "web_search" for web search capabilities. Can also be a list with
    `search_options`.

  - "web_fetch" to fetch content from a URL provided in the prompt.
    Client-side functions: created with the `as_tool(fn)` or
    [`tool()`](https://ma-riviere.github.io/argent/reference/tool_definitions.md)
    helpers. Note: Code execution has no internet access, 5GB RAM/disk,
    1 CPU. Containers expire 30 days after creation.

- `tool_choice`:

  List. Tool choice configuration: list(type = "auto"), list(type =
  "any"), list(type = "tool", name = "tool_name"), or NULL for none
  (default: list(type = "auto"))

- `cache_tools`:

  Logical. Cache tool definitions (default: FALSE)

- `output_schema`:

  List. JSON schema for structured output (optional)

- `thinking_budget`:

  Integer. Thinking budget in tokens: 0 (disabled), or 1024-max_tokens
  (default: 0). Minimum is 1024 tokens.

- `return_full_response`:

  Logical. Return full API response (default: FALSE)

#### Returns

Character (or List if return_full_response = TRUE). Anthropic API's
response object.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Anthropic$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
# Initialize with API key from environment
anthropic <- Anthropic$new()

# Or provide API key explicitly
anthropic <- Anthropic$new(api_key = "your-api-key")

# Simple chat completion
response <- anthropic$chat(
  prompt = "What is R programming?",
  model = "claude-sonnet-4-5-20250929"
)

# With prompt caching
response <- anthropic$chat(
  prompt = "Analyze this data",
  cache_prompt = TRUE,
  cache_system = TRUE
)

# With extended thinking (10k token budget)
response <- anthropic$chat(
  prompt = "Solve this complex math problem: ...",
  thinking_budget = 10000
)

# With custom thinking budget
response <- anthropic$chat(
  prompt = "Analyze this complex scenario: ...",
  thinking_budget = 16000
)
} # }

## ------------------------------------------------
## Method `Anthropic$download_file`
## ------------------------------------------------

if (FALSE) { # \dontrun{
anthropic <- Anthropic$new()

# Download to a directory
path <- anthropic$download_file(file_id = "file-abc123", dest_path = "downloads")

# Download with specific filename
path <- anthropic$download_file(file_id = "file-abc123", dest_path = "downloads/myfile.txt")

# Get raw bytes without saving
raw_content <- anthropic$download_file(file_id = "file-abc123", dest_path = NULL)
} # }
```
