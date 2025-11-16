# Client for OpenAI's Responses API

R6 class for interacting with OpenAI's Responses API (v1/responses).
Provides methods for chat completions and container management.

This class inherits file management and vector store functionalities
from its parent class OpenAI.

## Features

- Server-side conversation state management via previous_response_id

- Server-side tools: web_search, file_search, code_interpreter

- Reasoning budget support for extended thinking

- Response forking: continue from any point in conversation history

## Useful links

- API reference:
  https://platform.openai.com/docs/api-reference/responses/create

- API docs: https://platform.openai.com/docs/quickstart

## Server-side tools

- "web_search" for web search grounding via OpenAI's web plugin

- "file_search" for file search with vector stores

- "code_interpreter" for Python code execution in sandboxed containers

## Super classes

[`argent::Provider`](https://ma-riviere.github.io/argent/reference/Provider.md)
-\>
[`argent::OpenAI`](https://ma-riviere.github.io/argent/reference/OpenAI.md)
-\> `OpenAI_Responses`

## Public fields

- `provider_name`:

  Character. Provider name (OpenAI Responses)

- `server_tools`:

  Character vector. Server-side tools to use for API requests

## Methods

### Public methods

- [`OpenAI_Responses$new()`](#method-OpenAI_Responses-new)

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

Initialize a new OpenAI Responses client

#### Usage

    OpenAI_Responses$new(
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

### Method `get_last_response_id()`

Get the ID from the last response for conversation chaining

This is a convenience wrapper around get_last_response()\$id, useful for
chaining responses via the previous_response_id parameter.

#### Usage

    OpenAI_Responses$get_last_response_id()

#### Returns

Character. The ID of the last response, or NULL if no previous response
exists

#### Examples

    \dontrun{
    responses <- OpenAI_Responses$new()
    res1 <- responses$chat(prompt = "Tell me a joke", model = "gpt-5-mini")
    id <- responses$get_last_response_id()
    res2 <- responses$chat(
      prompt = "Explain why it's funny",
      previous_response_id = id
    )
    }

------------------------------------------------------------------------

### Method `create_container()`

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

    \dontrun{
    responses <- OpenAI_Responses$new()
    container <- responses$create_container()
    container <- responses$create_container(file_ids = c("file-123", "file-456"))
    }

------------------------------------------------------------------------

### Method `list_containers()`

List all containers

#### Usage

    OpenAI_Responses$list_containers()

#### Returns

Data frame. Available containers with id, created_at, status

#### Examples

    \dontrun{
    responses <- OpenAI_Responses$new()
    containers <- responses$list_containers()
    }

------------------------------------------------------------------------

### Method `get_container()`

Get information about a specific container

#### Usage

    OpenAI_Responses$get_container(container_id)

#### Arguments

- `container_id`:

  Character. Container ID to retrieve.

#### Returns

List. Container metadata

#### Examples

    \dontrun{
    responses <- OpenAI_Responses$new()
    container <- responses$get_container("container-123")
    }

------------------------------------------------------------------------

### Method `delete_container()`

Delete a container

#### Usage

    OpenAI_Responses$delete_container(container_id)

#### Arguments

- `container_id`:

  Character. Container ID to delete.

#### Returns

List. Deletion confirmation

#### Examples

    \dontrun{
    responses <- OpenAI_Responses$new()
    responses$delete_container("container-123")
    }

------------------------------------------------------------------------

### Method `list_container_files()`

List files in a container

#### Usage

    OpenAI_Responses$list_container_files(container_id)

#### Arguments

- `container_id`:

  Character. Container ID to list files from.

#### Returns

Data frame. Files in container with paths

#### Examples

    \dontrun{
    responses <- OpenAI_Responses$new()
    files <- responses$list_container_files("container-123")
    }

------------------------------------------------------------------------

### Method `get_container_file_metadata()`

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

### Method `get_container_file_content()`

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

    \dontrun{
    responses <- OpenAI_Responses$new()
    annotations <- responses$get_last_annotations()
    file_id <- annotations[[1]]$file_id
    content <- responses$get_container_file_content("container-123", file_id)
    }

------------------------------------------------------------------------

### Method `download_container_file()`

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

    \dontrun{
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
    }

------------------------------------------------------------------------

### Method `chat()`

Create a response from the Responses API

See: <https://platform.openai.com/docs/api-reference/responses/create>

#### Usage

    OpenAI_Responses$chat(
      ...,
      model = "gpt-5-mini",
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
      reasoning_summary = NULL,
      return_full_response = FALSE
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

- `return_full_response`:

  Logical. Return full API response (default: FALSE)

#### Returns

Character (or List if return_full_response = TRUE). OpenAI Responses
API's response object.

------------------------------------------------------------------------

### Method `clone()`

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
## Method `OpenAI_Responses$get_last_response_id`
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
## Method `OpenAI_Responses$create_container`
## ------------------------------------------------

if (FALSE) { # \dontrun{
responses <- OpenAI_Responses$new()
container <- responses$create_container()
container <- responses$create_container(file_ids = c("file-123", "file-456"))
} # }

## ------------------------------------------------
## Method `OpenAI_Responses$list_containers`
## ------------------------------------------------

if (FALSE) { # \dontrun{
responses <- OpenAI_Responses$new()
containers <- responses$list_containers()
} # }

## ------------------------------------------------
## Method `OpenAI_Responses$get_container`
## ------------------------------------------------

if (FALSE) { # \dontrun{
responses <- OpenAI_Responses$new()
container <- responses$get_container("container-123")
} # }

## ------------------------------------------------
## Method `OpenAI_Responses$delete_container`
## ------------------------------------------------

if (FALSE) { # \dontrun{
responses <- OpenAI_Responses$new()
responses$delete_container("container-123")
} # }

## ------------------------------------------------
## Method `OpenAI_Responses$list_container_files`
## ------------------------------------------------

if (FALSE) { # \dontrun{
responses <- OpenAI_Responses$new()
files <- responses$list_container_files("container-123")
} # }

## ------------------------------------------------
## Method `OpenAI_Responses$get_container_file_content`
## ------------------------------------------------

if (FALSE) { # \dontrun{
responses <- OpenAI_Responses$new()
annotations <- responses$get_last_annotations()
file_id <- annotations[[1]]$file_id
content <- responses$get_container_file_content("container-123", file_id)
} # }

## ------------------------------------------------
## Method `OpenAI_Responses$download_container_file`
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
