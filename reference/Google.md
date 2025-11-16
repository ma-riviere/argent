# Google API Client

R6 class for interacting with Google's API. Provides methods for chat
completions, model information retrieval, function calling capabilities,
structured outputs, and context caching.

## Useful links

- API reference: https://ai.google.dev/api/generate-content

- API docs: https://ai.google.dev/gemini-api/docs

## Server-side tools

- `code_execution`: Execute Python code

- `google_search`: Web search with grounding

- `url_context`: Fetch and process URLs

- `google_maps`: Location-aware data

- `file_search`: Search through uploaded files

## Super class

[`argent::Provider`](https://ma-riviere.github.io/argent/reference/Provider.md)
-\> `Google`

## Methods

### Public methods

- [`Google$new()`](#method-Google-new)

- [`Google$list_models()`](#method-Google-list_models)

- [`Google$get_model_info()`](#method-Google-get_model_info)

- [`Google$embeddings()`](#method-Google-embeddings)

- [`Google$upload_file()`](#method-Google-upload_file)

- [`Google$get_file_metadata()`](#method-Google-get_file_metadata)

- [`Google$list_files()`](#method-Google-list_files)

- [`Google$delete_file()`](#method-Google-delete_file)

- [`Google$create_store()`](#method-Google-create_store)

- [`Google$list_stores()`](#method-Google-list_stores)

- [`Google$read_store()`](#method-Google-read_store)

- [`Google$delete_store()`](#method-Google-delete_store)

- [`Google$add_file_to_store()`](#method-Google-add_file_to_store)

- [`Google$import_file_to_store()`](#method-Google-import_file_to_store)

- [`Google$list_files_in_store()`](#method-Google-list_files_in_store)

- [`Google$read_file_from_store()`](#method-Google-read_file_from_store)

- [`Google$delete_file_from_store()`](#method-Google-delete_file_from_store)

- [`Google$query_file()`](#method-Google-query_file)

- [`Google$get_operation()`](#method-Google-get_operation)

- [`Google$chat()`](#method-Google-chat)

- [`Google$clone()`](#method-Google-clone)

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

Initialize a new Google Gemini client

#### Usage

    Google$new(
      base_url = "https://generativelanguage.googleapis.com",
      api_key = Sys.getenv("GEMINI_API_KEY"),
      provider_name = "Google",
      rate_limit = 5/60,
      server_tools = c("code_execution", "google_search", "url_context", "google_maps",
        "file_search"),
      default_model = "gemini-2.5-flash",
      auto_save_history = TRUE
    )

#### Arguments

- `base_url`:

  Character. Base URL for API (default:
  "https://generativelanguage.googleapis.com")

- `api_key`:

  Character. API key (default: from GEMINI_API_KEY env var)

- `provider_name`:

  Character. Provider name (default: "Google")

- `rate_limit`:

  Numeric. Rate limit in requests per second (default: 5/60, free tier
  for 2.5 Pro)

- `server_tools`:

  Character vector. Server-side tools available (default:
  c("code_execution", "google_search", "url_context", "google_maps",
  "file_search"))

- `default_model`:

  Character. Default model to use for chat requests (default:
  "gemini-2.5-flash")

- `auto_save_history`:

  Logical. Enable/disable automatic history sync (default: TRUE)

------------------------------------------------------------------------

### Method `list_models()`

List all available Google models

#### Usage

    Google$list_models()

#### Returns

Data frame. Available models with their specifications

------------------------------------------------------------------------

### Method `get_model_info()`

Get information about a specific Google model

#### Usage

    Google$get_model_info(model_id)

#### Arguments

- `model_id`:

  Character. Model ID (e.g., "gemini-2.5-pro")

#### Returns

List. Model information

------------------------------------------------------------------------

### Method `embeddings()`

Generate embeddings for text input using Google's embedding models

#### Usage

    Google$embeddings(
      input,
      model,
      task_type = NULL,
      output_dimensionality = NULL,
      return_full_response = FALSE
    )

#### Arguments

- `input`:

  Character vector. Text(s) to embed

- `model`:

  Character. Model to use (e.g., "text-embedding-004",
  "text-embedding-preview-0815")

- `task_type`:

  Character. Task type for optimization (optional). One of:

  - "RETRIEVAL_QUERY": For search queries

  - "RETRIEVAL_DOCUMENT": For documents in search corpus

  - "SEMANTIC_SIMILARITY": For similarity comparison

  - "CLASSIFICATION": For text classification

  - "CLUSTERING": For clustering tasks

- `output_dimensionality`:

  Integer. Number of dimensions for output (optional, 128-3072 for
  supported models)

- `return_full_response`:

  Logical. Return full API response (default: FALSE)

#### Returns

Numeric matrix (or List if return_full_response = TRUE). Embeddings with
one row per input text

#### Examples

    \dontrun{
    google <- Google$new()

    # Generate embeddings
    embeddings <- google$embeddings(
      input = c("Hello world", "How are you?"),
      model = "text-embedding-004"
    )

    # With task type for optimization
    embeddings <- google$embeddings(
      input = "Sample query",
      model = "text-embedding-004",
      task_type = "RETRIEVAL_QUERY"
    )

    # With dimension reduction
    embeddings <- google$embeddings(
      input = "Sample text",
      model = "text-embedding-004",
      output_dimensionality = 256
    )
    }

------------------------------------------------------------------------

### Method `upload_file()`

Upload a file to Google Files API (uses resumable upload)

#### Usage

    Google$upload_file(file_path, name = NULL, mime_type = NULL)

#### Arguments

- `file_path`:

  Character. Path to the file to upload, or URL to a remote file

- `name`:

  Character. Display name for the file (optional, uses filename if NULL)

- `mime_type`:

  Character. MIME type (optional, auto-detected if NULL)

#### Returns

List. File metadata or NULL on error

------------------------------------------------------------------------

### Method `get_file_metadata()`

Get metadata for an uploaded file

#### Usage

    Google$get_file_metadata(file_name)

#### Arguments

- `file_name`:

  Character. File name (e.g., "files/abc123")

#### Returns

List. File metadata or NULL on error

------------------------------------------------------------------------

### Method `list_files()`

List all uploaded files

#### Usage

    Google$list_files(page_size = 100, page_token = NULL, as_df = TRUE)

#### Arguments

- `page_size`:

  Integer. Number of files per page (default: 100)

- `page_token`:

  Character. Page token for pagination (optional)

- `as_df`:

  Logical. Whether to return files as a data frame (default: TRUE). If
  FALSE, returns raw list.

#### Returns

Data frame (if as_df = TRUE) or list otherwise. Files metadata and next
page token (list only).

------------------------------------------------------------------------

### Method `delete_file()`

Delete an uploaded file

#### Usage

    Google$delete_file(file_name)

#### Arguments

- `file_name`:

  Character. File name (e.g., "files/abc123")

#### Returns

Logical. TRUE if successful, FALSE otherwise

------------------------------------------------------------------------

### Method `create_store()`

Create a new file search store for RAG operations

#### Usage

    Google$create_store(name = NULL)

#### Arguments

- `name`:

  Character. Display name for the store (optional)

#### Returns

List. File search store metadata or NULL on error

------------------------------------------------------------------------

### Method `list_stores()`

List all file search stores

#### Usage

    Google$list_stores(page_size = 10, page_token = NULL, as_df = TRUE)

#### Arguments

- `page_size`:

  Integer. Number of stores per page (default: 10, max: 100)

- `page_token`:

  Character. Page token for pagination (optional)

- `as_df`:

  Logical. Whether to return stores as a data frame (default: TRUE). If
  FALSE, returns raw list.

#### Returns

Data frame (if as_df = TRUE) or list otherwise. File search stores
metadata.

------------------------------------------------------------------------

### Method `read_store()`

Get information about a specific file search store

#### Usage

    Google$read_store(name)

#### Arguments

- `name`:

  Character. Store name (e.g., "fileSearchStores/abc123")

#### Returns

List. File search store metadata or NULL on error

------------------------------------------------------------------------

### Method `delete_store()`

Delete a file search store

#### Usage

    Google$delete_store(name, force = FALSE)

#### Arguments

- `name`:

  Character. Store name (e.g., "fileSearchStores/abc123")

- `force`:

  Logical. If TRUE, delete the store even if it contains documents
  (default: FALSE)

#### Returns

Logical. TRUE if successful, FALSE otherwise

------------------------------------------------------------------------

### Method `add_file_to_store()`

Upload a file directly to a file search store using resumable upload.
Supports custom chunking configuration and metadata.

#### Usage

    Google$add_file_to_store(
      file_path,
      store_name,
      file_name = NULL,
      custom_metadata = NULL,
      chunking_config = NULL
    )

#### Arguments

- `file_path`:

  Character. Path to the file to upload, or URL to a remote file

- `store_name`:

  Character. Store name (e.g., "fileSearchStores/abc123")

- `file_name`:

  Character. Display name for the file (optional, uses filename if NULL)

- `custom_metadata`:

  List. Custom metadata as key-value pairs (optional)

- `chunking_config`:

  List. Chunking configuration with max_tokens_per_chunk and
  max_overlap_tokens (optional)

#### Returns

List. Document metadata or NULL on error

------------------------------------------------------------------------

### Method `import_file_to_store()`

Import an existing File API file to a file search store. Note: The
importFile endpoint does not support custom chunking configuration.
Files will be chunked automatically by Google's API.

#### Usage

    Google$import_file_to_store(file_name, store_name, custom_metadata = NULL)

#### Arguments

- `file_name`:

  Character. File name from File API (e.g., "files/abc123")

- `store_name`:

  Character. Store name (e.g., "fileSearchStores/abc123")

- `custom_metadata`:

  List. Custom metadata as key-value pairs (optional)

#### Returns

List. Document metadata or NULL on error

------------------------------------------------------------------------

### Method `list_files_in_store()`

List files in a file search store

#### Usage

    Google$list_files_in_store(
      store_name,
      page_size = 10,
      page_token = NULL,
      as_df = TRUE
    )

#### Arguments

- `store_name`:

  Character. Store name (e.g., "fileSearchStores/abc123")

- `page_size`:

  Integer. Number of files per page (default: 10, max: 100)

- `page_token`:

  Character. Page token for pagination (optional)

- `as_df`:

  Logical. Whether to return files as a data frame (default: TRUE). If
  FALSE, returns raw list.

#### Returns

Data frame (if as_df = TRUE) or list otherwise. Files metadata.

------------------------------------------------------------------------

### Method `read_file_from_store()`

Get information about a specific file in a store

#### Usage

    Google$read_file_from_store(file_name)

#### Arguments

- `file_name`:

  Character. File name (e.g., "fileSearchStores/xyz/documents/abc123")

#### Returns

List. File metadata or NULL on error

------------------------------------------------------------------------

### Method `delete_file_from_store()`

Delete a file from a file search store

#### Usage

    Google$delete_file_from_store(file_name, force = TRUE)

#### Arguments

- `file_name`:

  Character. File name (e.g., "fileSearchStores/xyz/documents/abc123")

- `force`:

  Logical. If TRUE, force deletion of non-empty documents (default:
  TRUE)

#### Returns

Logical. TRUE if successful, FALSE otherwise

------------------------------------------------------------------------

### Method `query_file()`

Query a specific file in a file search store

#### Usage

    Google$query_file(
      file_name,
      query,
      results_count = 10,
      metadata_filters = NULL
    )

#### Arguments

- `file_name`:

  Character. File name (e.g., "fileSearchStores/xyz/documents/abc123")

- `query`:

  Character. Query string

- `results_count`:

  Integer. Number of results to return (default: 10)

- `metadata_filters`:

  Character. Metadata filter string (optional, e.g., "author=John")

#### Returns

List. Query results or NULL on error

------------------------------------------------------------------------

### Method `get_operation()`

Get the status of a long-running operation

#### Usage

    Google$get_operation(operation_name)

#### Arguments

- `operation_name`:

  Character. Operation name (e.g.,
  "fileSearchStores/xyz/operations/abc123")

#### Returns

List. Operation status or NULL on error

------------------------------------------------------------------------

### Method `chat()`

Send a chat completion request to Google

**Note on thinking with function calling**: When thinking and function
calling are both enabled, the model returns thought signatures in the
response. These encrypted representations of the model's thought process
are automatically included in subsequent turns via chat_history,
allowing the model to maintain thought context across multi-turn
conversations. However, thought signatures increase input token costs
when sent back in requests. See
<https://ai.google.dev/gemini-api/docs/thinking#signatures>

#### Usage

    Google$chat(
      ...,
      model = "gemini-2.5-flash",
      system = .default_system_prompt,
      max_tokens = 8000,
      temperature = 1,
      top_p = NULL,
      top_k = NULL,
      stop_sequences = NULL,
      tools = NULL,
      tool_choice = list(mode = "AUTO"),
      output_schema = NULL,
      thinking_budget = 0,
      include_thoughts = FALSE,
      return_full_response = FALSE
    )

#### Arguments

- `...`:

  One or more inputs for the prompt. Can be text strings, file paths,
  URLs, R objects, or content wrapped with `as_*_content()` functions. R
  objects (but not plain strings) will include their names and structure
  in the context sent to the model.

- `model`:

  Character. Model to use (default: "gemini-2.5-flash")

- `system`:

  Character. System instructions (optional)

- `max_tokens`:

  Integer. Maximum tokens to generate (default: 8000)

- `temperature`:

  Numeric. Sampling temperature 0-2 (default: 1)

- `top_p`:

  Numeric. Nucleus sampling - cumulative probability cutoff. Range:
  0.0-1.0 (optional)

- `top_k`:

  Integer. Top-K sampling - sample from top K options. Range: 1+
  (optional)

- `stop_sequences`:

  Character vector. Sequences that stop generation when encountered
  (optional)

- `tools`:

  List. Function definitions for tool calling (optional). Supports both
  client-side functions and server-side tools:

  **Server-side tools:**

  - `"code_execution"` or
    `list(type = "code_execution", file_ids = list("files/xyz"))` -
    Execute Python code

  - `"google_search"` - Web search with grounding

  - `"url_context"` - Fetch and process URLs

  - `"google_maps"` or
    `list(type = "google_maps", enable_widget = TRUE, location = list(latitude, longitude))` -
    Location-aware data

  - `"file_search"` or
    `list(type = "file_search", store_names = list("fileSearchStores/xyz"), metadata_filter = "key=value")` -
    Search through uploaded files

  **Client-side functions:** Use `as_tool(fn)` to wrap R functions for
  tool calling.

- `tool_choice`:

  Character or List. Controls how the model uses function declarations
  (default: list(mode = "AUTO")). Only applies to client function tools,
  not server tools.

  **Modes:**

  - `"AUTO"` (default): Model decides whether to call functions or
    respond with natural language

  - `"ANY"`: Model must always call a function (never responds with
    natural language)

  - `"NONE"`: Model cannot call functions (temporarily disable without
    removing tool definitions)

  - `"VALIDATED"` (Preview): Model can call functions or respond
    naturally, with schema validation

  **Limiting function selection (optional):** When mode is "ANY" or
  "VALIDATED", you can specify which functions are allowed:
  `list(mode = "ANY", allowed_function_names = c("func1", "func2"))`

  **Examples:**

  - `tool_choice = "AUTO"` - Simple mode specification (character)

  - `tool_choice = list(mode = "ANY")` - Force function call from any
    available function

  - `tool_choice = list(mode = "ANY", allowed_function_names = c("get_weather"))` -
    Force specific function

- `output_schema`:

  List. JSON schema for structured output (optional)

- `thinking_budget`:

  Integer. Thinking budget in tokens: 0 (disabled), -1 (dynamic), or
  0-24575/32768 (fixed budget). Default: 0.

- `include_thoughts`:

  Logical. Whether to include thought parts in the response (default:
  FALSE). If TRUE but thinking_budget is 0, a warning is issued and
  include_thoughts is set to FALSE.

- `return_full_response`:

  Logical. Return full API response (default: FALSE)

#### Returns

Character (or List if return_full_response = TRUE). Google API's
response object.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Google$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
# Initialize with API key from environment
google <- Google$new()

# Or provide API key explicitly
google <- Google$new(api_key = "your-api-key")

# Simple chat completion
response <- google$chat(
  "What is R programming?",
  model = "gemini-2.5-pro"
)

# With system instructions
response <- google$chat(
  "Explain quantum computing",
  model = "gemini-2.5-pro",
  system = "You are a physics professor"
)

# With R objects (names captured automatically)
my_data <- mtcars
response <- google$chat(
  my_data, "Analyze this dataset",
  model = "gemini-2.5-pro"
)

# With context caching for repeated queries
cache_name <- google$create_cache(
  model = "gemini-2.5-flash",
  system = "You are an expert data analyst",
  ttl = "3600s"
)
} # }

## ------------------------------------------------
## Method `Google$embeddings`
## ------------------------------------------------

if (FALSE) { # \dontrun{
google <- Google$new()

# Generate embeddings
embeddings <- google$embeddings(
  input = c("Hello world", "How are you?"),
  model = "text-embedding-004"
)

# With task type for optimization
embeddings <- google$embeddings(
  input = "Sample query",
  model = "text-embedding-004",
  task_type = "RETRIEVAL_QUERY"
)

# With dimension reduction
embeddings <- google$embeddings(
  input = "Sample text",
  model = "text-embedding-004",
  output_dimensionality = 256
)
} # }
```
