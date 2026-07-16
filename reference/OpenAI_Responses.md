# Client for OpenAI's Responses API

R6 class for interacting with OpenAI's Responses API (v1/responses).
Inherits file management and vector store methods from OpenAI_Base.

## Features

- Client-side conversation state management

- Server-side conversation state management via previous_response_id &
  response forking

- Client-side tools

- Server-side tools

- Multimodal inputs (files, images, PDFs, R objects)

- File uploads and management

- Server-side RAG with stores & `file_search` server tool

- Reasoning

- Structured outputs

## Useful links

- API reference:
  https://platform.openai.com/docs/api-reference/responses/create

- API docs: https://platform.openai.com/docs/quickstart

## Main entrypoints

- `chat()`: Multi-turn multimodal conversations with tool use and
  structured outputs.

- `embeddings()`: Vector embeddings for text inputs.

## Server-side tools

- "web_search" for web search grounding via OpenAI's web plugin

- "file_search" for file search with vector stores

- "code_interpreter" for Python code execution in sandboxed containers

## Structured outputs

Fully native structured outputs via JSON schema. No additional API calls
required.

## Super classes

[`Provider`](https://ma-riviere.github.io/argent/reference/Provider.md)
-\> [`OpenAI`](https://ma-riviere.github.io/argent/reference/OpenAI.md)
-\> `OpenAI_Responses`

## Methods

### Public methods

- [`OpenAI_Responses$new()`](#method-OpenAI_Responses-initialize)

- [`OpenAI_Responses$get_last_response_id()`](#method-OpenAI_Responses-get_last_response_id)

- [`OpenAI_Responses$create_container()`](#method-OpenAI_Responses-create_container)

- [`OpenAI_Responses$list_containers()`](#method-OpenAI_Responses-list_containers)

- [`OpenAI_Responses$get_container()`](#method-OpenAI_Responses-get_container)

- [`OpenAI_Responses$delete_container()`](#method-OpenAI_Responses-delete_container)

- [`OpenAI_Responses$list_container_files()`](#method-OpenAI_Responses-list_container_files)

- [`OpenAI_Responses$get_container_file_metadata()`](#method-OpenAI_Responses-get_container_file_metadata)

- [`OpenAI_Responses$get_container_file_content()`](#method-OpenAI_Responses-get_container_file_content)

- [`OpenAI_Responses$download_container_file()`](#method-OpenAI_Responses-download_container_file)

- [`OpenAI_Responses$chat()`](#method-OpenAI_Responses-chat)

- [`OpenAI_Responses$clone()`](#method-OpenAI_Responses-clone)

Inherited methods

- [`Provider$download_generated_files()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-download_generated_files)
- [`Provider$dump_history()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-dump_history)
- [`Provider$get_auto_save_history()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_auto_save_history)
- [`Provider$get_chat_history()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_chat_history)
- [`Provider$get_content_text()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_content_text)
- [`Provider$get_generated_code()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_generated_code)
- [`Provider$get_generated_files()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_generated_files)
- [`Provider$get_history()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_history)
- [`Provider$get_history_file_path()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_history_file_path)
- [`Provider$get_last_response()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_last_response)
- [`Provider$get_rate_limit()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_rate_limit)
- [`Provider$get_reasoning_text()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_reasoning_text)
- [`Provider$get_session_cumulative_token_count()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_session_cumulative_token_count)
- [`Provider$get_session_history()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_session_history)
- [`Provider$get_session_last_token_count()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_session_last_token_count)
- [`Provider$get_supplementary()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_supplementary)
- [`Provider$load_history()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-load_history)
- [`Provider$print()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-print)
- [`Provider$reset_history()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-reset_history)
- [`Provider$set_auto_save_history()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-set_auto_save_history)
- [`Provider$set_history()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-set_history)
- [`Provider$set_rate_limit()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-set_rate_limit)
- [`OpenAI$add_file_to_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-add_file_to_store)
- [`OpenAI$create_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-create_store)
- [`OpenAI$delete_all_files()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-delete_all_files)
- [`OpenAI$delete_all_files_from_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-delete_all_files_from_store)
- [`OpenAI$delete_all_stores()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-delete_all_stores)
- [`OpenAI$delete_file()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-delete_file)
- [`OpenAI$delete_file_from_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-delete_file_from_store)
- [`OpenAI$delete_files()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-delete_files)
- [`OpenAI$delete_files_from_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-delete_files_from_store)
- [`OpenAI$delete_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-delete_store)
- [`OpenAI$delete_store_and_files()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-delete_store_and_files)
- [`OpenAI$delete_stores()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-delete_stores)
- [`OpenAI$download_file()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-download_file)
- [`OpenAI$embeddings()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-embeddings)
- [`OpenAI$find_assistants()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-find_assistants)
- [`OpenAI$find_file()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-find_file)
- [`OpenAI$find_file_in_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-find_file_in_store)
- [`OpenAI$find_models()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-find_models)
- [`OpenAI$find_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-find_store)
- [`OpenAI$get_file()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-get_file)
- [`OpenAI$get_file_content()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-get_file_content)
- [`OpenAI$get_model_info()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-get_model_info)
- [`OpenAI$list_assistants()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-list_assistants)
- [`OpenAI$list_files()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-list_files)
- [`OpenAI$list_files_in_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-list_files_in_store)
- [`OpenAI$list_models()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-list_models)
- [`OpenAI$list_stores()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-list_stores)
- [`OpenAI$read_file_from_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-read_file_from_store)
- [`OpenAI$read_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-read_store)
- [`OpenAI$update_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-update_store)
- [`OpenAI$upload_file()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-upload_file)
- [`OpenAI$upload_file_from_df()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-upload_file_from_df)

------------------------------------------------------------------------

### `OpenAI_Responses$new()`

Initialize a new OpenAI Responses client

#### Usage

    OpenAI_Responses$new(
      base_url = "https://api.openai.com",
      api_key = Sys.getenv("OPENAI_API_KEY"),
      provider_name = "OpenAI Responses",
      rate_limit = 60/60,
      server_tools = c("web_search", "file_search", "code_interpreter"),
      default_model = "gpt-5-mini",
      org = Sys.getenv("OPENAI_ORG"),
      auto_save_history = TRUE
    )

#### Arguments

- `base_url`:

  Character. Base URL for API (default: "https://api.openai.com")

- `api_key`:

  Character. API key (default: from OPENAI_API_KEY env var)

- `provider_name`:

  Character. Provider name (default: "OpenAI Responses")

- `rate_limit`:

  Numeric. Rate limit in requests per second (default: 60/60)

- `server_tools`:

  Character vector. Server-side tools available (default:
  c("web_search", "file_search", "code_interpreter"))

- `default_model`:

  Character. Default model to use for chat requests (default:
  "gpt-5-mini")

- `org`:

  Character. Organization ID (default: from OPENAI_ORG env var)

- `auto_save_history`:

  Logical. Enable/disable automatic history sync (default: TRUE)

------------------------------------------------------------------------

### `OpenAI_Responses$get_last_response_id()`

Get the ID from the last response for conversation chaining

This is a convenience wrapper around get_last_response()\$id, useful for
chaining responses via the previous_response_id parameter.

#### Usage

    OpenAI_Responses$get_last_response_id()

#### Returns

Character. The ID of the last response, or NULL if no previous response
exists

#### Examples

    responses <- OpenAI_Responses$new()
    res1 <- responses$chat(prompt = "Tell me a joke", model = "gpt-5-mini")
    id <- responses$get_last_response_id()
    res2 <- responses$chat(
      prompt = "Explain why it's funny",
      previous_response_id = id
    )

------------------------------------------------------------------------

### `OpenAI_Responses$create_container()`

Create a new container for code execution

Containers are sandboxed virtual machines where code_interpreter can
execute Python code. Each container costs \$0.03 and is active for 1
hour with 20 minute idle timeout.

#### Usage

    OpenAI_Responses$create_container(file_ids = NULL)

#### Arguments

- `file_ids`:

  Character vector. Optional file IDs to initialize container with.

#### Returns

List. Container object with id, created_at, status

#### Examples

    responses <- OpenAI_Responses$new()
    container <- responses$create_container()
    container <- responses$create_container(file_ids = c("file-123", "file-456"))

------------------------------------------------------------------------

### `OpenAI_Responses$list_containers()`

List all containers

#### Usage

    OpenAI_Responses$list_containers()

#### Returns

Data frame. Available containers with id, created_at, status

#### Examples

    responses <- OpenAI_Responses$new()
    containers <- responses$list_containers()

------------------------------------------------------------------------

### `OpenAI_Responses$get_container()`

Get information about a specific container

#### Usage

    OpenAI_Responses$get_container(container_id)

#### Arguments

- `container_id`:

  Character. Container ID to retrieve.

#### Returns

List. Container metadata

#### Examples

    responses <- OpenAI_Responses$new()
    container <- responses$get_container("container-123")

------------------------------------------------------------------------

### `OpenAI_Responses$delete_container()`

Delete a container

#### Usage

    OpenAI_Responses$delete_container(container_id)

#### Arguments

- `container_id`:

  Character. Container ID to delete.

#### Returns

List. Deletion confirmation

#### Examples

    responses <- OpenAI_Responses$new()
    responses$delete_container("container-123")

------------------------------------------------------------------------

### `OpenAI_Responses$list_container_files()`

List files in a container

#### Usage

    OpenAI_Responses$list_container_files(container_id)

#### Arguments

- `container_id`:

  Character. Container ID to list files from.

#### Returns

Data frame. Files in container with paths

#### Examples

    responses <- OpenAI_Responses$new()
    files <- responses$list_container_files("container-123")

------------------------------------------------------------------------

### `OpenAI_Responses$get_container_file_metadata()`

Get metadata for a specific file in a container

#### Usage

    OpenAI_Responses$get_container_file_metadata(container_id, file_id)

#### Arguments

- `container_id`:

  Character. Container ID.

- `file_id`:

  Character. Container file ID (e.g., "cfile_abc123xyz").

#### Returns

List. File metadata.

------------------------------------------------------------------------

### `OpenAI_Responses$get_container_file_content()`

Get file content from container

#### Usage

    OpenAI_Responses$get_container_file_content(container_id, file_id)

#### Arguments

- `container_id`:

  Character. Container ID.

- `file_id`:

  Character. Container file ID (e.g., "cfile_abc123xyz").

#### Returns

Raw. File content as raw bytes

#### Examples

    responses <- OpenAI_Responses$new()
    annotations <- responses$get_last_annotations()
    file_id <- annotations[[1]]$file_id
    content <- responses$get_container_file_content("container-123", file_id)

------------------------------------------------------------------------

### `OpenAI_Responses$download_container_file()`

Download file from container to local filesystem

Downloads the file content and saves it to the specified path. If
dest_path is a directory, the file is saved with its original filename.
If dest_path is a file path, it is used as the complete destination
path.

#### Usage

    OpenAI_Responses$download_container_file(
      container_id,
      file_id,
      dest_path = "data",
      overwrite = TRUE
    )

#### Arguments

- `container_id`:

  Character. Container ID.

- `file_id`:

  Character. Container file ID (e.g., "cfile_abc123xyz").

- `dest_path`:

  Character. Destination path (default: "data"). Can be either a
  directory path or a complete file path. Created if it doesn't exist.

- `overwrite`:

  Logical. Whether to overwrite existing files (default: TRUE).

- `filename`:

  Character. Optional filename to use when dest_path is a directory. If
  NULL, fetches filename from container file list.

#### Returns

Character. Path to downloaded file (invisibly)

#### Examples

    responses <- OpenAI_Responses$new()
    annotations <- responses$get_last_annotations()
    file_id <- annotations[[1]]$file_id

    # Download to a directory
    path <- responses$download_container_file("container-123", file_id, "downloads")

    # Download with specific filename
    path <- responses$download_container_file("container-123", file_id, "downloads/output.png")

    # Pass filename explicitly (from annotations)
    path <- responses$download_container_file(
      "container-123",
      file_id,
      "downloads",
      filename = annotations[[1]]$filename
    )

------------------------------------------------------------------------

### `OpenAI_Responses$chat()`

Create a response from the Responses API

See: <https://platform.openai.com/docs/api-reference/responses/create>

#### Usage

    OpenAI_Responses$chat(
      ...,
      model = self$default_model,
      system = .default_system_prompt,
      temperature = 1,
      max_tokens = 4096,
      top_p = 1,
      top_logprobs = NULL,
      input_truncation = "disabled",
      previous_response_id = NULL,
      store = TRUE,
      include = NULL,
      tools = NULL,
      tool_choice = "auto",
      max_tool_calls = NULL,
      parallel_tool_calls = TRUE,
      output_schema = NULL,
      output_verbosity = "medium",
      reasoning_effort = NULL,
      reasoning_summary = NULL
    )

#### Arguments

- `...`:

  One or more inputs for the prompt. Can be text strings, file paths,
  URLs, R objects, or content wrapped with `as_*_content()` functions. R
  objects (but not plain strings) will include their names and structure
  in the context sent to the model.

- `model`:

  Character. Model to use (default: "gpt-5-mini")

- `system`:

  Character. System prompt/instructions (default:
  .default_system_prompt)

- `temperature`:

  Numeric. Sampling temperature 0-2 (default: 1)

- `max_tokens`:

  Integer. Maximum output tokens to generate (default: 4096)

- `top_p`:

  Numeric. Nucleus sampling parameter 0-1 (default: 1). Alternative to
  temperature. We recommend altering this or temperature but not both.

- `top_logprobs`:

  Integer. Number of most likely tokens (0-20) to return at each
  position with associated log probabilities (default: NULL)

- `input_truncation`:

  Character. Truncation strategy: "auto" or "disabled" (default:
  "disabled")

- `previous_response_id`:

  Character. ID of previous response to chain from for server-side state
  management. When provided, only the new prompt is sent (not full chat
  history). Cannot be used with conversation parameter. (default: NULL)

- `store`:

  Logical. Whether to store response server-side for later retrieval
  (default: TRUE)

- `include`:

  Character vector. Additional output data to include in the model
  response. Supported values:

  - "web_search_call.action.sources" - Include sources of web search
    tool calls

  - "code_interpreter_call.outputs" - Include Python code execution
    outputs

  - "computer_call_output.output.image_url" - Include image URLs from
    computer call output

  - "file_search_call.results" - Include file search tool call results

  - "message.input_image.image_url" - Include input message image URLs

  - "message.output_text.logprobs" - Include logprobs with assistant
    messages

  - "reasoning.encrypted_content" - Include encrypted reasoning tokens
    for multi-turn conversations

- `tools`:

  List. Tool definitions (server-side or client-side functions).
  Server-side tools:

  - list(type = "web_search") for web search

  - list(type = "file_search", store_ids = list("vs_123")) for file
    search with vector stores Client-side functions: use created with
    the `as_tool(fn)` or
    [`tool()`](https://ma-riviere.github.io/argent/reference/tool_definitions.md)
    helpers.

- `tool_choice`:

  Character or List. Tool choice mode (default: "auto")

- `max_tool_calls`:

  Integer. Maximum number of tool calls (default: NULL)

- `parallel_tool_calls`:

  Logical. Allow parallel tool calls (default: TRUE)

- `output_schema`:

  List. JSON schema for structured output via
  build_output_schema_openai() (optional)

- `output_verbosity`:

  Character. Output verbosity: "low", "medium", or "high" (default:
  "medium")

- `reasoning_effort`:

  Character. Reasoning effort for reasoning models: "minimal", "low",
  "medium", or "high" (optional, only for o1/o3/gpt-5 models)

- `reasoning_summary`:

  Character. Reasoning summary mode: "auto", "concise", or "detailed"
  (optional, requires reasoning_effort to be set)

#### Returns

Character. OpenAI Responses API's response object.

------------------------------------------------------------------------

### `OpenAI_Responses$clone()`

The objects of this class are cloneable with this method.

#### Usage

    OpenAI_Responses$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
# Initialize
responses <- OpenAI_Responses$new()

# Simple response
res <- responses$chat(
  prompt = "What is R programming?",
  model = "gpt-5-mini"
)

# Continue conversation
res2 <- responses$chat(
  prompt = "Tell me more",
  previous_response_id = res$id
)

# With web search
res <- responses$chat(
  prompt = "What are the latest AI developments?",
  tools = list(list(type = "web_search"))
)

# With file search and vector stores
file_id <- responses$upload_file("document.pdf", purpose = "assistants")
store <- responses$create_store("docs", file_ids = list(file_id))
res <- responses$chat(
  prompt = "Summarize the document",
  tools = list(list(type = "file_search", store_ids = list(store$id)))
)
} # }

## ------------------------------------------------
## Method `OpenAI_Responses$get_last_response_id()`
## ------------------------------------------------

if (FALSE) { # \dontrun{
responses <- OpenAI_Responses$new()
res1 <- responses$chat(prompt = "Tell me a joke", model = "gpt-5-mini")
id <- responses$get_last_response_id()
res2 <- responses$chat(
  prompt = "Explain why it's funny",
  previous_response_id = id
)
} # }

## ------------------------------------------------
## Method `OpenAI_Responses$create_container()`
## ------------------------------------------------

if (FALSE) { # \dontrun{
responses <- OpenAI_Responses$new()
container <- responses$create_container()
container <- responses$create_container(file_ids = c("file-123", "file-456"))
} # }

## ------------------------------------------------
## Method `OpenAI_Responses$list_containers()`
## ------------------------------------------------

if (FALSE) { # \dontrun{
responses <- OpenAI_Responses$new()
containers <- responses$list_containers()
} # }

## ------------------------------------------------
## Method `OpenAI_Responses$get_container()`
## ------------------------------------------------

if (FALSE) { # \dontrun{
responses <- OpenAI_Responses$new()
container <- responses$get_container("container-123")
} # }

## ------------------------------------------------
## Method `OpenAI_Responses$delete_container()`
## ------------------------------------------------

if (FALSE) { # \dontrun{
responses <- OpenAI_Responses$new()
responses$delete_container("container-123")
} # }

## ------------------------------------------------
## Method `OpenAI_Responses$list_container_files()`
## ------------------------------------------------

if (FALSE) { # \dontrun{
responses <- OpenAI_Responses$new()
files <- responses$list_container_files("container-123")
} # }

## ------------------------------------------------
## Method `OpenAI_Responses$get_container_file_content()`
## ------------------------------------------------

if (FALSE) { # \dontrun{
responses <- OpenAI_Responses$new()
annotations <- responses$get_last_annotations()
file_id <- annotations[[1]]$file_id
content <- responses$get_container_file_content("container-123", file_id)
} # }

## ------------------------------------------------
## Method `OpenAI_Responses$download_container_file()`
## ------------------------------------------------

if (FALSE) { # \dontrun{
responses <- OpenAI_Responses$new()
annotations <- responses$get_last_annotations()
file_id <- annotations[[1]]$file_id

# Download to a directory
path <- responses$download_container_file("container-123", file_id, "downloads")

# Download with specific filename
path <- responses$download_container_file("container-123", file_id, "downloads/output.png")

# Pass filename explicitly (from annotations)
path <- responses$download_container_file(
  "container-123",
  file_id,
  "downloads",
  filename = annotations[[1]]$filename
)
} # }
```
