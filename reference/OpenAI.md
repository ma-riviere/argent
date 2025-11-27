# Parent class for OpenAI API clients (Responses, Chat Completions, Assistants)

Parent class for OpenAI API clients (Responses, Chat Completions,
Assistants). Provides shared infrastructure for file management, vector
stores, and API requests. This class is inherited by OpenAI_Chat,
OpenAI_Responses, and OpenAI_Assistant to provide consistent interfaces
across different OpenAI API clients.

## Super class

[`argent::Provider`](https://ma-riviere.github.io/argent/reference/Provider.md)
-\> `OpenAI`

## Methods

### Public methods

- [`OpenAI$new()`](#method-OpenAI-new)

- [`OpenAI$list_models()`](#method-OpenAI-list_models)

- [`OpenAI$find_models()`](#method-OpenAI-find_models)

- [`OpenAI$get_model_info()`](#method-OpenAI-get_model_info)

- [`OpenAI$embeddings()`](#method-OpenAI-embeddings)

- [`OpenAI$list_assistants()`](#method-OpenAI-list_assistants)

- [`OpenAI$find_assistants()`](#method-OpenAI-find_assistants)

- [`OpenAI$upload_file()`](#method-OpenAI-upload_file)

- [`OpenAI$upload_file_from_df()`](#method-OpenAI-upload_file_from_df)

- [`OpenAI$list_files()`](#method-OpenAI-list_files)

- [`OpenAI$find_file()`](#method-OpenAI-find_file)

- [`OpenAI$get_file()`](#method-OpenAI-get_file)

- [`OpenAI$get_file_content()`](#method-OpenAI-get_file_content)

- [`OpenAI$download_file()`](#method-OpenAI-download_file)

- [`OpenAI$delete_file()`](#method-OpenAI-delete_file)

- [`OpenAI$delete_files()`](#method-OpenAI-delete_files)

- [`OpenAI$delete_all_files()`](#method-OpenAI-delete_all_files)

- [`OpenAI$create_store()`](#method-OpenAI-create_store)

- [`OpenAI$read_store()`](#method-OpenAI-read_store)

- [`OpenAI$list_stores()`](#method-OpenAI-list_stores)

- [`OpenAI$find_store()`](#method-OpenAI-find_store)

- [`OpenAI$update_store()`](#method-OpenAI-update_store)

- [`OpenAI$delete_store()`](#method-OpenAI-delete_store)

- [`OpenAI$delete_stores()`](#method-OpenAI-delete_stores)

- [`OpenAI$delete_all_stores()`](#method-OpenAI-delete_all_stores)

- [`OpenAI$delete_store_and_files()`](#method-OpenAI-delete_store_and_files)

- [`OpenAI$add_file_to_store()`](#method-OpenAI-add_file_to_store)

- [`OpenAI$read_file_from_store()`](#method-OpenAI-read_file_from_store)

- [`OpenAI$list_files_in_store()`](#method-OpenAI-list_files_in_store)

- [`OpenAI$find_file_in_store()`](#method-OpenAI-find_file_in_store)

- [`OpenAI$delete_file_from_store()`](#method-OpenAI-delete_file_from_store)

- [`OpenAI$delete_files_from_store()`](#method-OpenAI-delete_files_from_store)

- [`OpenAI$delete_all_files_from_store()`](#method-OpenAI-delete_all_files_from_store)

- [`OpenAI$clone()`](#method-OpenAI-clone)

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

Initialize a new OpenAI base client

#### Usage

    OpenAI$new(
      base_url = "https://api.openai.com",
      api_key = Sys.getenv("OPENAI_API_KEY"),
      provider_name = "OpenAI",
      rate_limit = 60/60,
      server_tools = character(0),
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

  Character. Provider name (default: "OpenAI")

- `rate_limit`:

  Numeric. Rate limit in requests per second (default: 60/60)

- `server_tools`:

  Character vector. Server-side tools available (default: character(0))

- `default_model`:

  Character. Default model to use for chat requests (default:
  "gpt-5-mini")

- `org`:

  Character. Organization ID (default: from OPENAI_ORG env var)

- `auto_save_history`:

  Logical. Enable/disable automatic history sync (default: TRUE)

------------------------------------------------------------------------

### Method `list_models()`

List all available models

#### Usage

    OpenAI$list_models()

#### Returns

Data frame. Available models

------------------------------------------------------------------------

### Method `find_models()`

Find models matching criteria

#### Usage

    OpenAI$find_models(...)

#### Arguments

- `...`:

  Named arguments for filtering

#### Returns

Data frame. Filtered models

------------------------------------------------------------------------

### Method `get_model_info()`

Get information about a specific model

#### Usage

    OpenAI$get_model_info(model_id)

#### Arguments

- `model_id`:

  Character. The ID of the model to get information about.

#### Returns

A list containing information about the model.

------------------------------------------------------------------------

### Method `embeddings()`

Generate embeddings for text input

#### Usage

    OpenAI$embeddings(
      input,
      model,
      encoding_format = "float",
      dimensions = NULL,
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

- `return_full_response`:

  Logical. Return full API response (default: FALSE)

#### Returns

Numeric matrix (or List if return_full_response = TRUE). Embeddings with
one row per input text

#### Examples

    \dontrun{
    openai <- OpenAI_Chat$new()

    # Generate embeddings
    embeddings <- openai$embeddings(
      input = c("Hello world", "How are you?"),
      model = "text-embedding-3-small"
    )

    # With dimension reduction
    embeddings <- openai$embeddings(
      input = "Sample text",
      model = "text-embedding-3-large",
      dimensions = 256
    )
    }

------------------------------------------------------------------------

### Method `list_assistants()`

List all assistants.

#### Usage

    OpenAI$list_assistants()

#### Returns

A data frame of assistants.

------------------------------------------------------------------------

### Method `find_assistants()`

Find assistants matching criteria.

#### Usage

    OpenAI$find_assistants(..., as_df = TRUE)

#### Arguments

- `...`:

  Named arguments for filtering.

- `as_df`:

  Logical. Whether to return a data frame.

#### Returns

A data frame of matching assistants.

------------------------------------------------------------------------

### Method `upload_file()`

Upload a file to OpenAI for use across various endpoints/features.

Files are uploaded to OpenAI and can be used with features like
Assistants, fine-tuning, Batch API, and more. Maximum file size is 512
MB per file. Organizations have a 100 GB total storage limit across all
files.

#### Usage

    OpenAI$upload_file(file_path, file_name = NULL, purpose = "user_data")

#### Arguments

- `file_path`:

  Character. Path to the file to upload, or URL to a remote file.

- `file_name`:

  Character. Optional custom name for the uploaded file. If NULL
  (default), uses the basename of file_path.

- `purpose`:

  Character. The intended purpose of the uploaded file. Must be one of:

  - "assistants": For use with the Assistants API and server tools
    (file_search, code_interpreter)

  - "user_data": For user data storage and retrieval (default)

  - "fine-tune": For fine-tuning custom models

  - "batch": For Batch API operations

  - "vision": For vision-related tasks

#### Returns

List. File object containing:

- `id`: Unique file identifier

- `object`: Object type (always "file")

- `bytes`: File size in bytes

- `created_at`: Unix timestamp of creation

- `filename`: Name of the file

- `purpose`: The purpose specified during upload

- `status`: Processing status ("uploaded", "processed", "error")

- `status_details`: Additional details if status is "error" (optional)

#### Examples

    \dontrun{
    openai <- OpenAI_Chat$new()

    # Upload a document for assistants
    file <- openai$upload_file("document.pdf", purpose = "assistants")
    cat("File ID:", file$id, "\n")

    # Upload data with custom name
    file <- openai$upload_file("data.csv", file_name = "my_data.csv", purpose = "user_data")

    # Upload for fine-tuning
    file <- openai$upload_file("training_data.jsonl", purpose = "fine-tune")
    }

------------------------------------------------------------------------

### Method `upload_file_from_df()`

Upload a file from a data frame.

Convenience method to upload a data frame as a tab-separated text file
to OpenAI. Creates a temporary file, uploads it, then cleans up.

#### Usage

    OpenAI$upload_file_from_df(df, file_name = "data.txt", purpose = "user_data")

#### Arguments

- `df`:

  Data frame. The data to upload.

- `file_name`:

  Character. Name for the uploaded file (default: "data.txt").

- `purpose`:

  Character. The purpose of the file (default: "user_data"). See
  `upload_file()` for valid purposes.

#### Returns

List. File object (see `upload_file()` for structure).

#### Examples

    \dontrun{
    openai <- OpenAI_Chat$new()

    # Upload a data frame
    df <- data.frame(x = 1:10, y = letters[1:10])
    file <- openai$upload_file_from_df(df, file_name = "my_data.txt")
    }

------------------------------------------------------------------------

### Method `list_files()`

List all files belonging to the organization.

Returns a list of all files that have been uploaded to OpenAI, ordered
by creation date (most recent first).

#### Usage

    OpenAI$list_files(purpose = NULL)

#### Arguments

- `purpose`:

  Character. Optional filter by purpose. If provided, only returns files
  with the specified purpose. Valid values: "assistants", "user_data",
  "fine-tune", "batch", "vision".

#### Returns

Data frame with columns:

- `id`: File identifier

- `object`: Object type ("file")

- `bytes`: File size

- `created_at`: Creation timestamp (POSIXct)

- `filename`: File name

- `purpose`: File purpose

- `status`: Processing status

- `status_details`: Error details if applicable

#### Examples

    \dontrun{
    openai <- OpenAI_Chat$new()

    # List all files
    all_files <- openai$list_files()

    # List only assistant files
    assistant_files <- openai$list_files(purpose = "assistants")
    }

------------------------------------------------------------------------

### Method `find_file()`

Find files matching specific criteria.

Filters the list of files based on provided criteria (e.g., filename,
purpose, status).

#### Usage

    OpenAI$find_file(..., as_df = TRUE)

#### Arguments

- `...`:

  Named arguments for filtering (e.g., `filename = "data.csv"`,
  `purpose = "assistants"`).

- `as_df`:

  Logical. Whether to return results as a data frame (default: TRUE). If
  FALSE, returns a list.

#### Returns

Data frame (or list) of matching files.

#### Examples

    \dontrun{
    openai <- OpenAI_Chat$new()

    # Find files by name
    files <- openai$find_file(filename = "data.csv")

    # Find assistant files
    files <- openai$find_file(purpose = "assistants")
    }

------------------------------------------------------------------------

### Method `get_file()`

Retrieve information about a specific file.

Returns metadata about a file, including its status, size, and purpose.
Does not return the file contents (use `download_file()` or
`get_file_content()` for that).

#### Usage

    OpenAI$get_file(file_id)

#### Arguments

- `file_id`:

  Character. The ID of the file to retrieve.

#### Returns

List. File object containing:

- `id`: File identifier

- `object`: Object type ("file")

- `bytes`: File size in bytes

- `created_at`: Unix timestamp of creation

- `filename`: Name of the file

- `purpose`: File purpose

- `status`: Processing status

- `status_details`: Error details if status is "error"

#### Examples

    \dontrun{
    openai <- OpenAI_Chat$new()

    # Get file info
    file_info <- openai$get_file(file_id = "file-abc123")
    cat("File:", file_info$filename, "Status:", file_info$status, "\n")
    }

------------------------------------------------------------------------

### Method `get_file_content()`

Retrieve the contents of a file.

Returns the raw content of the specified file as a character string.
Note that files with purpose "assistants" cannot be retrieved.

#### Usage

    OpenAI$get_file_content(file_id)

#### Arguments

- `file_id`:

  Character. The ID of the file to retrieve.

#### Returns

Character. The file contents as a string.

#### Examples

    \dontrun{
    openai <- OpenAI_Chat$new()

    # Get file content
    content <- openai$get_file_content(file_id = "file-abc123")
    cat(content)
    }

------------------------------------------------------------------------

### Method `download_file()`

Download a file to disk.

Downloads the file content and saves it to the specified path. Files
with purpose "assistants" cannot be downloaded. If dest_path is a
directory, the file is saved with its original filename. If dest_path is
a file path, it is used as the complete destination path.

#### Usage

    OpenAI$download_file(file_id, dest_path = "data", overwrite = TRUE)

#### Arguments

- `file_id`:

  Character. The ID of the file to download.

- `dest_path`:

  Character. Destination path (default: "data"). Can be either a
  directory path or a complete file path. Created if it doesn't exist.

- `overwrite`:

  Logical. Whether to overwrite existing files (default: TRUE).

#### Returns

Character. Path to the downloaded file (invisibly).

#### Examples

    \dontrun{
    openai <- OpenAI_Chat$new()

    # Download to a directory
    path <- openai$download_file(file_id = "file-abc123", dest_path = "downloads")

    # Download with specific filename
    path <- openai$download_file(file_id = "file-abc123", dest_path = "downloads/myfile.txt")
    }

------------------------------------------------------------------------

### Method `delete_file()`

Delete a file from OpenAI.

Permanently deletes the specified file. This action cannot be undone.

#### Usage

    OpenAI$delete_file(file_id)

#### Arguments

- `file_id`:

  Character. The ID of the file to delete.

#### Returns

List. Deletion confirmation containing:

- `id`: The deleted file ID

- `object`: Object type ("file")

- `deleted`: Boolean indicating successful deletion

#### Examples

    \dontrun{
    openai <- OpenAI_Chat$new()

    # Delete a file
    result <- openai$delete_file(file_id = "file-abc123")
    if (result$deleted) cat("File deleted successfully\n")
    }

------------------------------------------------------------------------

### Method `delete_files()`

Delete multiple files from OpenAI.

Convenience method to delete multiple files at once. Each deletion is
performed sequentially.

#### Usage

    OpenAI$delete_files(file_ids)

#### Arguments

- `file_ids`:

  Character vector. File IDs to delete.

#### Returns

Data frame. Deletion results for each file.

#### Examples

    \dontrun{
    openai <- OpenAI_Chat$new()

    # Delete multiple files
    results <- openai$delete_files(c("file-abc123", "file-def456"))
    }

------------------------------------------------------------------------

### Method `delete_all_files()`

Delete all files from OpenAI.

WARNING: This permanently deletes ALL files in your organization. Use
with extreme caution.

#### Usage

    OpenAI$delete_all_files()

#### Returns

Data frame. Deletion results for all files.

#### Examples

    \dontrun{
    openai <- OpenAI_Chat$new()

    # Delete all files (use with caution!)
    results <- openai$delete_all_files()
    }

------------------------------------------------------------------------

### Method `create_store()`

Create a vector store.

#### Usage

    OpenAI$create_store(name, file_ids = NULL)

#### Arguments

- `name`:

  Character. The name of the vector store.

- `file_ids`:

  A character vector of file IDs.

#### Returns

A list containing information about the vector store.

------------------------------------------------------------------------

### Method `read_store()`

Read a vector store.

#### Usage

    OpenAI$read_store(store_id)

#### Arguments

- `store_id`:

  Character. The ID of the vector store to read.

#### Returns

A list containing information about the vector store.

------------------------------------------------------------------------

### Method `list_stores()`

List all vector stores.

#### Usage

    OpenAI$list_stores()

#### Returns

A data frame of vector stores.

------------------------------------------------------------------------

### Method `find_store()`

Find a vector store matching criteria.

#### Usage

    OpenAI$find_store(..., as_df = TRUE)

#### Arguments

- `...`:

  Named arguments for filtering.

- `as_df`:

  Logical. Whether to return a data frame.

#### Returns

A data frame of matching vector stores.

------------------------------------------------------------------------

### Method `update_store()`

Update a vector store.

#### Usage

    OpenAI$update_store(store_id, new_name)

#### Arguments

- `store_id`:

  Character. The ID of the vector store to update.

- `new_name`:

  Character. The new name of the vector store.

#### Returns

A list containing information about the updated vector store.

------------------------------------------------------------------------

### Method `delete_store()`

Delete a vector store.

#### Usage

    OpenAI$delete_store(store_id)

#### Arguments

- `store_id`:

  Character. The ID of the vector store to delete.

#### Returns

A list containing information about the deleted vector store.

------------------------------------------------------------------------

### Method `delete_stores()`

Delete multiple vector stores.

#### Usage

    OpenAI$delete_stores(store_ids)

#### Arguments

- `store_ids`:

  A character vector of vector store IDs.

#### Returns

A data frame of deleted vector stores.

------------------------------------------------------------------------

### Method `delete_all_stores()`

Delete all vector stores.

#### Usage

    OpenAI$delete_all_stores()

#### Returns

A data frame of deleted vector stores.

------------------------------------------------------------------------

### Method `delete_store_and_files()`

Delete a vector store and its files.

#### Usage

    OpenAI$delete_store_and_files(store_id)

#### Arguments

- `store_id`:

  Character. The ID of the vector store to delete.

#### Returns

A list containing information about the deleted vector store and files.

------------------------------------------------------------------------

### Method `add_file_to_store()`

Add a file to a vector store.

#### Usage

    OpenAI$add_file_to_store(store_id, file_id)

#### Arguments

- `store_id`:

  Character. The ID of the vector store.

- `file_id`:

  Character. The ID of the file.

#### Returns

A list containing information about the file in the vector store.

------------------------------------------------------------------------

### Method `read_file_from_store()`

Read a file from a vector store.

#### Usage

    OpenAI$read_file_from_store(store_id, file_id)

#### Arguments

- `store_id`:

  Character. The ID of the vector store.

- `file_id`:

  Character. The ID of the file.

#### Returns

A list containing information about the file in the vector store.

------------------------------------------------------------------------

### Method `list_files_in_store()`

List all files in a vector store.

#### Usage

    OpenAI$list_files_in_store(store_id)

#### Arguments

- `store_id`:

  Character. The ID of the vector store.

#### Returns

A data frame of files in the vector store.

------------------------------------------------------------------------

### Method `find_file_in_store()`

Find a file in a vector store matching criteria.

#### Usage

    OpenAI$find_file_in_store(store_id, ..., as_df = TRUE)

#### Arguments

- `store_id`:

  Character. The ID of the vector store.

- `...`:

  Named arguments for filtering.

- `as_df`:

  Logical. Whether to return a data frame.

#### Returns

A data frame of matching files.

------------------------------------------------------------------------

### Method `delete_file_from_store()`

Delete a file from a vector store.

#### Usage

    OpenAI$delete_file_from_store(store_id, file_id)

#### Arguments

- `store_id`:

  Character. The ID of the vector store.

- `file_id`:

  Character. The ID of the file.

#### Returns

A list containing information about the deleted file.

------------------------------------------------------------------------

### Method `delete_files_from_store()`

Delete multiple files from a vector store.

#### Usage

    OpenAI$delete_files_from_store(store_id, file_ids)

#### Arguments

- `store_id`:

  Character. The ID of the vector store.

- `file_ids`:

  A character vector of file IDs.

#### Returns

A data frame of deleted files.

------------------------------------------------------------------------

### Method `delete_all_files_from_store()`

Delete all files from a vector store.

#### Usage

    OpenAI$delete_all_files_from_store(store_id)

#### Arguments

- `store_id`:

  Character. The ID of the vector store.

#### Returns

A data frame of deleted files.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    OpenAI$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
## ------------------------------------------------
## Method `OpenAI$embeddings`
## ------------------------------------------------

if (FALSE) { # \dontrun{
openai <- OpenAI_Chat$new()

# Generate embeddings
embeddings <- openai$embeddings(
  input = c("Hello world", "How are you?"),
  model = "text-embedding-3-small"
)

# With dimension reduction
embeddings <- openai$embeddings(
  input = "Sample text",
  model = "text-embedding-3-large",
  dimensions = 256
)
} # }

## ------------------------------------------------
## Method `OpenAI$upload_file`
## ------------------------------------------------

if (FALSE) { # \dontrun{
openai <- OpenAI_Chat$new()

# Upload a document for assistants
file <- openai$upload_file("document.pdf", purpose = "assistants")
cat("File ID:", file$id, "\n")

# Upload data with custom name
file <- openai$upload_file("data.csv", file_name = "my_data.csv", purpose = "user_data")

# Upload for fine-tuning
file <- openai$upload_file("training_data.jsonl", purpose = "fine-tune")
} # }

## ------------------------------------------------
## Method `OpenAI$upload_file_from_df`
## ------------------------------------------------

if (FALSE) { # \dontrun{
openai <- OpenAI_Chat$new()

# Upload a data frame
df <- data.frame(x = 1:10, y = letters[1:10])
file <- openai$upload_file_from_df(df, file_name = "my_data.txt")
} # }

## ------------------------------------------------
## Method `OpenAI$list_files`
## ------------------------------------------------

if (FALSE) { # \dontrun{
openai <- OpenAI_Chat$new()

# List all files
all_files <- openai$list_files()

# List only assistant files
assistant_files <- openai$list_files(purpose = "assistants")
} # }

## ------------------------------------------------
## Method `OpenAI$find_file`
## ------------------------------------------------

if (FALSE) { # \dontrun{
openai <- OpenAI_Chat$new()

# Find files by name
files <- openai$find_file(filename = "data.csv")

# Find assistant files
files <- openai$find_file(purpose = "assistants")
} # }

## ------------------------------------------------
## Method `OpenAI$get_file`
## ------------------------------------------------

if (FALSE) { # \dontrun{
openai <- OpenAI_Chat$new()

# Get file info
file_info <- openai$get_file(file_id = "file-abc123")
cat("File:", file_info$filename, "Status:", file_info$status, "\n")
} # }

## ------------------------------------------------
## Method `OpenAI$get_file_content`
## ------------------------------------------------

if (FALSE) { # \dontrun{
openai <- OpenAI_Chat$new()

# Get file content
content <- openai$get_file_content(file_id = "file-abc123")
cat(content)
} # }

## ------------------------------------------------
## Method `OpenAI$download_file`
## ------------------------------------------------

if (FALSE) { # \dontrun{
openai <- OpenAI_Chat$new()

# Download to a directory
path <- openai$download_file(file_id = "file-abc123", dest_path = "downloads")

# Download with specific filename
path <- openai$download_file(file_id = "file-abc123", dest_path = "downloads/myfile.txt")
} # }

## ------------------------------------------------
## Method `OpenAI$delete_file`
## ------------------------------------------------

if (FALSE) { # \dontrun{
openai <- OpenAI_Chat$new()

# Delete a file
result <- openai$delete_file(file_id = "file-abc123")
if (result$deleted) cat("File deleted successfully\n")
} # }

## ------------------------------------------------
## Method `OpenAI$delete_files`
## ------------------------------------------------

if (FALSE) { # \dontrun{
openai <- OpenAI_Chat$new()

# Delete multiple files
results <- openai$delete_files(c("file-abc123", "file-def456"))
} # }

## ------------------------------------------------
## Method `OpenAI$delete_all_files`
## ------------------------------------------------

if (FALSE) { # \dontrun{
openai <- OpenAI_Chat$new()

# Delete all files (use with caution!)
results <- openai$delete_all_files()
} # }
```
