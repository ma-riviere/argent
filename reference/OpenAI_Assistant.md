# OpenAI Assistant API Client

R6 class for interacting with OpenAI's Assistants API. Provides methods
for creating and managing assistants, threads, and runs with support for
file search and function calling.

## Deprecation Notice

**DEPRECATED:** OpenAI has deprecated the Assistants API in favor of the
new Responses API. It will shut down on August 26, 2026.

Users should migrate to the [Responses
API](https://ma-riviere.github.io/argent/reference/responses-api.md)
instead.

For more information, see:
https://platform.openai.com/docs/assistants/migration

## Useful links

- API reference:
  https://platform.openai.com/docs/api-reference/assistants

- API docs: https://platform.openai.com/docs/assistants/deep-dive

## Server-side tools

- "file_search" for file search with vector stores

- "code_interpreter" for Python code execution in sandboxed containers

## History Management

The Assistants API uses server-side thread state for conversation
history. However, this class maintains client-side `session_history` for
tracking conversations with token counts.

- `chat_history` methods are overridden and not applicable (server-side
  threads)

- `session_history` is maintained for use with
  [`print()`](https://rdrr.io/r/base/print.html) and token tracking

- Use `get_thread_msgs()` to retrieve server-side conversation history

- Use `get_history()` or `get_session_history()` for client-side
  tracking

## Super classes

[`argent::Provider`](https://ma-riviere.github.io/argent/reference/Provider.md)
-\>
[`argent::OpenAI`](https://ma-riviere.github.io/argent/reference/OpenAI.md)
-\> `OpenAIAssistant`

## Public fields

- `assistant`:

  List. Current assistant object

- `thread`:

  List. Current thread object

- `provider_name`:

  Character. Provider name (OpenAI Assistant)

- `server_tools`:

  Character vector. Server-side tools to use for API requests

## Methods

### Public methods

- [`OpenAI_Assistant$new()`](#method-OpenAIAssistant-new)

- [`OpenAI_Assistant$list_models()`](#method-OpenAIAssistant-list_models)

- [`OpenAI_Assistant$get_chat_history()`](#method-OpenAIAssistant-get_chat_history)

- [`OpenAI_Assistant$dump_chat_history()`](#method-OpenAIAssistant-dump_chat_history)

- [`OpenAI_Assistant$load_chat_history()`](#method-OpenAIAssistant-load_chat_history)

- [`OpenAI_Assistant$get_total_tokens()`](#method-OpenAIAssistant-get_total_tokens)

- [`OpenAI_Assistant$get_assistant()`](#method-OpenAIAssistant-get_assistant)

- [`OpenAI_Assistant$get_assistant_id()`](#method-OpenAIAssistant-get_assistant_id)

- [`OpenAI_Assistant$set_assistant_id()`](#method-OpenAIAssistant-set_assistant_id)

- [`OpenAI_Assistant$create_assistant()`](#method-OpenAIAssistant-create_assistant)

- [`OpenAI_Assistant$load_assistant()`](#method-OpenAIAssistant-load_assistant)

- [`OpenAI_Assistant$read_assistant()`](#method-OpenAIAssistant-read_assistant)

- [`OpenAI_Assistant$delete_assistant()`](#method-OpenAIAssistant-delete_assistant)

- [`OpenAI_Assistant$delete_assistant_and_contents()`](#method-OpenAIAssistant-delete_assistant_and_contents)

- [`OpenAI_Assistant$chat()`](#method-OpenAIAssistant-chat)

- [`OpenAI_Assistant$clone()`](#method-OpenAIAssistant-clone)

Inherited methods

- [`argent::Provider$download_generated_files()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-download_generated_files)
- [`argent::Provider$dump_history()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-dump_history)
- [`argent::Provider$get_auto_save_history()`](https://ma-riviere.github.io/argent/reference/Provider.html#method-get_auto_save_history)
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
- [`argent::OpenAI$list_stores()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-list_stores)
- [`argent::OpenAI$read_file_from_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-read_file_from_store)
- [`argent::OpenAI$read_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-read_store)
- [`argent::OpenAI$update_store()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-update_store)
- [`argent::OpenAI$upload_file()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-upload_file)
- [`argent::OpenAI$upload_file_from_df()`](https://ma-riviere.github.io/argent/reference/OpenAI.html#method-upload_file_from_df)

------------------------------------------------------------------------

### Method `new()`

Initialize a new OpenAI Assistant client

#### Usage

    OpenAI_Assistant$new(
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

### Method `list_models()`

Override list_models to warn about gpt-5 incompatibility

#### Usage

    OpenAI_Assistant$list_models()

#### Returns

Data frame. Available models

------------------------------------------------------------------------

### Method `get_chat_history()`

Get chat history from the current thread (server-side state). Returns
the content array from the thread messages.

#### Usage

    OpenAI_Assistant$get_chat_history()

#### Returns

List. The content array from thread messages, or NULL if no thread
exists.

------------------------------------------------------------------------

### Method `dump_chat_history()`

Dump chat history (not applicable - server-side state)

#### Usage

    OpenAI_Assistant$dump_chat_history(file_path = NULL)

#### Arguments

- `file_path`:

  Character. File path

------------------------------------------------------------------------

### Method `load_chat_history()`

Load chat history (not applicable - server-side state)

#### Usage

    OpenAI_Assistant$load_chat_history(file_path)

#### Arguments

- `file_path`:

  Character. File path

------------------------------------------------------------------------

### Method `get_total_tokens()`

Get total tokens (not applicable - per-run tracking)

#### Usage

    OpenAI_Assistant$get_total_tokens()

------------------------------------------------------------------------

### Method `get_assistant()`

Get the current assistant.

#### Usage

    OpenAI_Assistant$get_assistant()

#### Returns

The current assistant.

------------------------------------------------------------------------

### Method `get_assistant_id()`

Get the ID of the current assistant.

#### Usage

    OpenAI_Assistant$get_assistant_id()

#### Returns

The ID of the current assistant.

------------------------------------------------------------------------

### Method `set_assistant_id()`

Set the current assistant by ID.

#### Usage

    OpenAI_Assistant$set_assistant_id(assistant_id)

#### Arguments

- `assistant_id`:

  The ID of the assistant to set.

------------------------------------------------------------------------

### Method `create_assistant()`

Create a new assistant

#### Usage

    OpenAI_Assistant$create_assistant(
      name,
      model = "gpt-4o",
      system = .default_system_prompt,
      temperature = 1,
      top_p = 1,
      tools = NULL,
      response_format = "auto"
    )

#### Arguments

- `name`:

  Character. Name of the assistant

- `model`:

  Character. Model to use (default: "gpt-4o")

- `system`:

  Character. System instructions (default: .default_system_prompt)

- `temperature`:

  Numeric. Sampling temperature 0-2 (default: 1)

- `top_p`:

  Numeric. Nucleus sampling parameter 0-1 (default: 1). Alternative to
  temperature. We recommend altering this or temperature but not both.

- `tools`:

  List. Tool definitions (optional). Supports three formats:

  - String form: "file_search", "code_interpreter"

  - List form with resources: list(type = "file_search", store_ids =
    list("vs_123")) or list(type = "code_interpreter", file_ids =
    list("file-123"))

  - Client-side functions: created with the `as_tool(fn)` or
    [`tool()`](https://ma-riviere.github.io/argent/reference/tool_definitions.md)
    helpers

- `response_format`:

  Character. Response format: "auto" (default), or list for JSON schema

#### Returns

The assistant object (invisibly)

#### Examples

    \dontrun{
    assistant <- OpenAI_Assistant$new()
    assistant$create_assistant(
      name = "My Assistant",
      model = "gpt-4o",
      system = "You are a helpful assistant"
    )
    }

------------------------------------------------------------------------

### Method `load_assistant()`

Load an existing assistant by ID

#### Usage

    OpenAI_Assistant$load_assistant(id)

#### Arguments

- `id`:

  Character. Assistant ID to load

#### Returns

The assistant object (invisibly)

#### Examples

    \dontrun{
    assistant <- OpenAI_Assistant$new()
    assistant$load_assistant(id = "asst_...")
    }

------------------------------------------------------------------------

### Method `read_assistant()`

Read an assistant.

#### Usage

    OpenAI_Assistant$read_assistant(assistant_id = self$assistant$id)

#### Arguments

- `assistant_id`:

  The ID of the assistant to read.

#### Returns

The assistant object.

------------------------------------------------------------------------

### Method `delete_assistant()`

Delete an assistant.

#### Usage

    OpenAI_Assistant$delete_assistant(assistant_id = self$assistant$id)

#### Arguments

- `assistant_id`:

  The ID of the assistant to delete.

#### Returns

The deletion status.

------------------------------------------------------------------------

### Method `delete_assistant_and_contents()`

Delete an assistant and its contents.

#### Usage

    OpenAI_Assistant$delete_assistant_and_contents(
      assistant_id = self$assistant$id
    )

#### Arguments

- `assistant_id`:

  The ID of the assistant to delete.

#### Returns

A list with the deletion status for the assistant and its contents.

------------------------------------------------------------------------

### Method `chat()`

Send a chat message to the assistant.

Note: Unlike OpenAI\$chat(), assistant configuration (model,
temperature, tools, system) is set during initialization and cannot be
changed per-chat.

After sending a message, you can use base class methods like
`get_content_text()`, `get_supplementary()`, or
`download_generated_files()` to extract information from responses.

#### Usage

    OpenAI_Assistant$chat(
      ...,
      in_new_thread = FALSE,
      output_schema = NULL,
      remove_citations = TRUE,
      return_full_response = FALSE
    )

#### Arguments

- `...`:

  One or more inputs for the prompt. Can be text strings, file paths,
  URLs, R objects, or content wrapped with `as_*_content()` functions. R
  objects (but not plain strings) will include their names and structure
  in the context sent to the model.

- `in_new_thread`:

  Logical. Start new thread (default: FALSE). Assistant-specific:
  Controls thread management. Set TRUE to start a fresh conversation.

- `output_schema`:

  List. JSON schema for structured output (optional). When assistant
  uses server tools, forces a second call with only the schema to ensure
  structured output.

- `remove_citations`:

  Logical. Remove file_search citation markers (default: TRUE). When
  TRUE, removes citation markers like 【35†source】 and \[3:0†source\]
  from responses. Only applies when return_full_response = FALSE.

- `return_full_response`:

  Logical. Return full message object (default: FALSE). If FALSE,
  returns only the text content via cat(). If TRUE, returns complete
  message object.

#### Returns

Character (or List if return_full_response = TRUE). OpenAI Assistant
API's response object.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    OpenAI_Assistant$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
# Initialize client
assistant <- OpenAI_Assistant$new()

# Create a new assistant
assistant$create_assistant(
  name = "My Assistant",
  model = "gpt-4o",
  instructions = "You are a helpful assistant"
)

# Or load an existing assistant
assistant$load_assistant(id = "asst_...")

# Send a message
response <- assistant$chat("Hello!")

# Create assistant with tools
assistant <- OpenAI_Assistant$new()
assistant$create_assistant(
  name = "Research Assistant",
  model = "gpt-4o",
  instructions = "Research assistant with web access",
  tools = list(
    list(type = "file_search", store_ids = list(store_id)),
    list(
      name = "web_search",
      description = "Search the web",
      parameters = list(
        type = "object",
        properties = list(query = list(type = "string", description = "The search query"))
      )
    )
  )
)

# Code execution with embedded file resources
assistant <- OpenAI_Assistant$new()
assistant$create_assistant(
  name = "Data Analyst",
  model = "gpt-4o",
  tools = list(list(type = "code_interpreter", file_ids = list(file_id)))
)

# Using PDFs and files in messages
# PDFs are automatically uploaded and attached to messages
assistant <- OpenAI_Assistant$new()
assistant$create_assistant(
  name = "Document Analyst",
  model = "gpt-4o",
  tools = list(list(type = "file_search"))
)
response <- assistant$chat("Summarize this document", "path/to/document.pdf")
} # }

## ------------------------------------------------
## Method `OpenAI_Assistant$create_assistant`
## ------------------------------------------------

if (FALSE) { # \dontrun{
assistant <- OpenAI_Assistant$new()
assistant$create_assistant(
  name = "My Assistant",
  model = "gpt-4o",
  system = "You are a helpful assistant"
)
} # }

## ------------------------------------------------
## Method `OpenAI_Assistant$load_assistant`
## ------------------------------------------------

if (FALSE) { # \dontrun{
assistant <- OpenAI_Assistant$new()
assistant$load_assistant(id = "asst_...")
} # }
```
