#' OpenAI Base API Client
#'
#' @description
#' Base R6 class for OpenAI API interactions. Provides shared infrastructure for file management,
#' vector stores, and HTTP request handling. This class is inherited by OpenAI_Chat, OpenAI_Responses,
#' and OpenAI_Assistant to provide consistent interfaces across different OpenAI APIs.
#'
#' @keywords internal
OpenAI <- R6::R6Class( # nolint
    classname = "OpenAI",
    inherit = Provider,
    public = list(

        # ------🔺 INIT --------------------------------------------------------
        
        #' @description
        #' Initialize a new OpenAI base client
        #' @param base_url Character. Base URL for API (default: "https://api.openai.com")
        #' @param api_key Character. API key (default: from OPENAI_API_KEY env var)
        #' @param provider_name Character. Provider name (default: "OpenAI")
        #' @param rate_limit Numeric. Rate limit in requests per second (default: 60/60)
        #' @param server_tools Character vector. Server-side tools available (default: character(0))
        #' @param default_model Character. Default model to use for chat requests (default: "gpt-5-mini")
        #' @param org Character. Organization ID (default: from OPENAI_ORG env var)
        #' @param auto_save_history Logical. Enable/disable automatic history sync (default: TRUE)
        initialize = function(
            base_url = "https://api.openai.com",
            api_key = Sys.getenv("OPENAI_API_KEY"),
            provider_name = "OpenAI",
            rate_limit = 60 / 60,
            server_tools = character(0),
            default_model = "gpt-5-mini",
            org = Sys.getenv("OPENAI_ORG"),
            auto_save_history = TRUE
        ) {
            super$initialize(
                base_url = base_url,
                api_key = api_key,
                provider_name = provider_name,
                rate_limit = rate_limit,
                server_tools = server_tools,
                default_model = default_model,
                auto_save_history = auto_save_history
            )
            private$org <- org
        },

        # ------🔺 MODELS ------------------------------------------------------

        #' @description
        #' List all available models
        #' @return Data frame. Available models
        list_models = function() {
            private$list(paste0(self$base_url, "/v1/models")) |>
                dplyr::mutate(created = lubridate::as_datetime(created)) |>
                dplyr::arrange(dplyr::desc(created), id)
        },

        #' @description
        #' Find models matching criteria
        #' @param ... Named arguments for filtering
        #' @return Data frame. Filtered models
        find_models = function(...) {
            private$find(paste0(self$base_url, "/v1/models"), ..., as_df = TRUE) |>
                dplyr::mutate(created = lubridate::as_datetime(created)) |>
                dplyr::arrange(dplyr::desc(created), id)
        },

        #' @description
        #' Get information about a specific model
        #' @param model_id Character. The ID of the model to get information about.
        #' @return A list containing information about the model.
        get_model_info = function(model_id) {
            private$request(paste0(self$base_url, "/v1/models/", model_id)) |>
                purrr::modify_at("created", lubridate::as_datetime)
        },

        # ------🔺 EMBEDDINGS --------------------------------------------------

        #' @description
        #' Generate embeddings for text input
        #' @param input Character vector. Text(s) to embed
        #' @param model Character. Model to use (e.g., "text-embedding-3-small", "text-embedding-3-large")
        #' @param encoding_format Character. Format of embeddings: "float" or "base64" (default: "float")
        #' @param dimensions Integer. Number of dimensions for output (only for embedding-3 models)
        #' @param return_full_response Logical. Return full API response (default: FALSE)
        #' @return Numeric matrix (or List if return_full_response = TRUE). Embeddings with one row
        #'   per input text
        #' @examples
        #' \dontrun{
        #' openai <- OpenAI_Chat$new()
        #'
        #' # Generate embeddings
        #' embeddings <- openai$embeddings(
        #'   input = c("Hello world", "How are you?"),
        #'   model = "text-embedding-3-small"
        #' )
        #'
        #' # With dimension reduction
        #' embeddings <- openai$embeddings(
        #'   input = "Sample text",
        #'   model = "text-embedding-3-large",
        #'   dimensions = 256
        #' )
        #' }
        embeddings = function(
            input,
            model,
            encoding_format = "float",
            dimensions = NULL,
            return_full_response = FALSE
        ) {
            # Validate input
            if (!is.character(input) || length(input) == 0) {
                cli::cli_abort("[{self$provider_name}] Input must be a non-empty character vector.")
            }

            # Validate model
            if (is.null(model) || !nzchar(model)) {
                cli::cli_abort("[{self$provider_name}] Model must be specified.")
            }

            # Build API request
            query_data <- list3(
                input = input,
                model = model,
                encoding_format = encoding_format,
                dimensions = dimensions
            )

            # Make API request
            res <- private$request(
                paste0(self$base_url, "/v1/embeddings"),
                query_data,
                headers = list(`Content-Type` = "application/json")
            )

            # Handle API errors
            if (purrr::is_empty(res$data)) {
                cli::cli_abort("[{self$provider_name}] Error: API request failed or returned no data")
            }

            # Return full response if requested
            if (isTRUE(return_full_response)) {
                return(res)
            }

            # Extract embeddings and return as matrix
            embeddings_list <- purrr::map(res$data, "embedding")

            # Flatten to numeric vector, then reshape to matrix
            embeddings_matrix <- matrix(
                unlist(embeddings_list, use.names = FALSE),
                nrow = length(embeddings_list),
                ncol = length(embeddings_list[[1]]),
                byrow = TRUE
            )

            return(embeddings_matrix)
        },

        # ------🔺 ASSISTANTS --------------------------------------------------

        #' @description
        #' List all assistants.
        #' @return A data frame of assistants.
        list_assistants = function() {
            private$list(paste0(self$base_url, "/v1/assistants")) |>
                dplyr::mutate(created_at = lubridate::as_datetime(created_at)) |> 
                dplyr::arrange(dplyr::desc(created_at), id)
        },

        #' @description
        #' Find assistants matching criteria.
        #' @param ... Named arguments for filtering.
        #' @param as_df Logical. Whether to return a data frame.
        #' @return A data frame of matching assistants.
        find_assistants = function(..., as_df = TRUE) {
            private$find(paste0(self$base_url, "/v1/assistants"), ..., as_df = as_df)
        },

        # ------🔺 FILES -------------------------------------------------------
        # https://platform.openai.com/docs/api-reference/files

        #' @description
        #' Upload a file to OpenAI for use across various endpoints/features.
        #'
        #' Files are uploaded to OpenAI and can be used with features like Assistants, fine-tuning,
        #' Batch API, and more. Maximum file size is 512 MB per file. Organizations have a 100 GB
        #' total storage limit across all files.
        #'
        #' @param file_path Character. Path to the file to upload, or URL to a remote file.
        #' @param file_name Character. Optional custom name for the uploaded file. If NULL (default),
        #'   uses the basename of file_path.
        #' @param purpose Character. The intended purpose of the uploaded file. Must be one of:
        #'   - "assistants": For use with the Assistants API and server tools (file_search, code_interpreter)
        #'   - "user_data": For user data storage and retrieval (default)
        #'   - "fine-tune": For fine-tuning custom models
        #'   - "batch": For Batch API operations
        #'   - "vision": For vision-related tasks
        #' @return List. File object containing:
        #'   - `id`: Unique file identifier
        #'   - `object`: Object type (always "file")
        #'   - `bytes`: File size in bytes
        #'   - `created_at`: Unix timestamp of creation
        #'   - `filename`: Name of the file
        #'   - `purpose`: The purpose specified during upload
        #'   - `status`: Processing status ("uploaded", "processed", "error")
        #'   - `status_details`: Additional details if status is "error" (optional)
        #' @examples
        #' \dontrun{
        #' openai <- OpenAI_Chat$new()
        #'
        #' # Upload a document for assistants
        #' file <- openai$upload_file("document.pdf", purpose = "assistants")
        #' cat("File ID:", file$id, "\n")
        #'
        #' # Upload data with custom name
        #' file <- openai$upload_file("data.csv", file_name = "my_data.csv", purpose = "user_data")
        #'
        #' # Upload for fine-tuning
        #' file <- openai$upload_file("training_data.jsonl", purpose = "fine-tune")
        #' }
        upload_file = function(file_path, file_name = NULL, purpose = "user_data") {
            if (is_url(file_path)) {
                file_path <- download_temp_file(file_path)
                on.exit(unlink(file_path))
            }

            if (!is_file(file_path)) {
                cli::cli_abort("[OpenAI] File not found: {.path {file_path}}")
            }

            file_name <- file_name %||% basename(file_path)

            valid_purposes <- c("assistants", "user_data", "fine-tune", "batch", "vision")
            if (!purpose %in% valid_purposes) {
                cli::cli_abort(
                    "[OpenAI] Invalid purpose '{purpose}'. Must be one of: {paste(valid_purposes, collapse = ', ')}"
                )
            }

            result <- private$base_request(
                paste0(self$base_url, "/v1/files"),
                headers = list(`Content-Type` = "multipart/form-data")
            ) |>
                httr2::req_body_multipart(
                    purpose = purpose,
                    file = curl::form_file(file_path, name = file_name)
                ) |>
                httr2::req_perform() |>
                httr2::resp_body_json()

            # Check for API errors in response
            if ("error" %in% names(result)) {
                cli::cli_abort(
                    c(
                        "[OpenAI] File upload failed: {result$error$message}",
                        "i" = "Error type: {result$error$type}"
                    )
                )
            }

            cli::cli_alert_success("[OpenAI] File uploaded: {result$id}")

            invisible(result)
        },

        #' @description
        #' Upload a file from a data frame.
        #'
        #' Convenience method to upload a data frame as a tab-separated text file to OpenAI.
        #' Creates a temporary file, uploads it, then cleans up.
        #'
        #' @param df Data frame. The data to upload.
        #' @param file_name Character. Name for the uploaded file (default: "data.txt").
        #' @param purpose Character. The purpose of the file (default: "user_data").
        #'   See `upload_file()` for valid purposes.
        #' @return List. File object (see `upload_file()` for structure).
        #' @examples
        #' \dontrun{
        #' openai <- OpenAI_Chat$new()
        #'
        #' # Upload a data frame
        #' df <- data.frame(x = 1:10, y = letters[1:10])
        #' file <- openai$upload_file_from_df(df, file_name = "my_data.txt")
        #' }
        upload_file_from_df = function(df, file_name = "data.txt", purpose = "user_data") {
            temp_file <- tempfile(fileext = ".txt")
            write.table(df, file = temp_file, sep = "\t", col.names = FALSE, row.names = FALSE, quote = FALSE)

            result <- self$upload_file(temp_file, file_name, purpose)

            file.remove(temp_file)

            return(result)
        },

        #' @description
        #' List all files belonging to the organization.
        #'
        #' Returns a list of all files that have been uploaded to OpenAI, ordered by creation date
        #' (most recent first).
        #'
        #' @param purpose Character. Optional filter by purpose. If provided, only returns files
        #'   with the specified purpose. Valid values: "assistants", "user_data", "fine-tune",
        #'   "batch", "vision".
        #' @return Data frame with columns:
        #'   - `id`: File identifier
        #'   - `object`: Object type ("file")
        #'   - `bytes`: File size
        #'   - `created_at`: Creation timestamp (POSIXct)
        #'   - `filename`: File name
        #'   - `purpose`: File purpose
        #'   - `status`: Processing status
        #'   - `status_details`: Error details if applicable
        #' @examples
        #' \dontrun{
        #' openai <- OpenAI_Chat$new()
        #'
        #' # List all files
        #' all_files <- openai$list_files()
        #'
        #' # List only assistant files
        #' assistant_files <- openai$list_files(purpose = "assistants")
        #' }
        list_files = function(purpose = NULL) {
            endpoint <- paste0(self$base_url, "/v1/files")

            if (!is.null(purpose)) {
                valid_purposes <- c("assistants", "user_data", "fine-tune", "batch", "vision")
                if (!purpose %in% valid_purposes) {
                    cli::cli_abort(
                        "[OpenAI] Invalid purpose '{purpose}'. Must be one of: {paste(valid_purposes, collapse = ', ')}"
                    )
                }
                endpoint <- paste0(endpoint, "?purpose=", purpose)
            }

            private$list(endpoint) |>
                dplyr::mutate(created_at = lubridate::as_datetime(created_at)) |> 
                dplyr::arrange(dplyr::desc(created_at), id)
        },

        #' @description
        #' Find files matching specific criteria.
        #'
        #' Filters the list of files based on provided criteria (e.g., filename, purpose, status).
        #'
        #' @param ... Named arguments for filtering (e.g., `filename = "data.csv"`,
        #'   `purpose = "assistants"`).
        #' @param as_df Logical. Whether to return results as a data frame (default: TRUE).
        #'   If FALSE, returns a list.
        #' @return Data frame (or list) of matching files.
        #' @examples
        #' \dontrun{
        #' openai <- OpenAI_Chat$new()
        #'
        #' # Find files by name
        #' files <- openai$find_file(filename = "data.csv")
        #'
        #' # Find assistant files
        #' files <- openai$find_file(purpose = "assistants")
        #' }
        find_file = function(..., as_df = TRUE) {
            private$find(paste0(self$base_url, "/v1/files"), ..., as_df = as_df)
        },

        #' @description
        #' Retrieve information about a specific file.
        #'
        #' Returns metadata about a file, including its status, size, and purpose. Does not return
        #' the file contents (use `download_file()` or `get_file_content()` for that).
        #'
        #' @param file_id Character. The ID of the file to retrieve.
        #' @return List. File object containing:
        #'   - `id`: File identifier
        #'   - `object`: Object type ("file")
        #'   - `bytes`: File size in bytes
        #'   - `created_at`: Unix timestamp of creation
        #'   - `filename`: Name of the file
        #'   - `purpose`: File purpose
        #'   - `status`: Processing status
        #'   - `status_details`: Error details if status is "error"
        #' @examples
        #' \dontrun{
        #' openai <- OpenAI_Chat$new()
        #'
        #' # Get file info
        #' file_info <- openai$get_file(file_id = "file-abc123")
        #' cat("File:", file_info$filename, "Status:", file_info$status, "\n")
        #' }
        get_file = function(file_id) {
            if (is.null(file_id) || file_id == "") {
                cli::cli_abort("[OpenAI] file_id cannot be NULL or empty")
            }
            private$request(paste0(self$base_url, "/v1/files/", file_id))
        },

        #' @description
        #' Retrieve the contents of a file.
        #'
        #' Returns the raw content of the specified file as a character string. Note that files
        #' with purpose "assistants" cannot be retrieved.
        #'
        #' @param file_id Character. The ID of the file to retrieve.
        #' @return Character. The file contents as a string.
        #' @examples
        #' \dontrun{
        #' openai <- OpenAI_Chat$new()
        #'
        #' # Get file content
        #' content <- openai$get_file_content(file_id = "file-abc123")
        #' cat(content)
        #' }
        get_file_content = function(file_id) {
            if (is.null(file_id) || file_id == "") {
                cli::cli_abort("[OpenAI] file_id cannot be NULL or empty")
            }

            file_data <- self$get_file(file_id)

            if (file_data$purpose == "assistants") {
                cli::cli_abort(
                    "[OpenAI] Files with purpose 'assistants' cannot be retrieved. File ID: {file_id}"
                )
            }

            return(
                private$base_request(paste0(self$base_url, "/v1/files/", file_id, "/content"))
                |> httr2::req_perform()
                |> httr2::resp_body_string()
            )
        },

        #' @description
        #' Download a file to disk.
        #'
        #' Downloads the file content and saves it to the specified path. Files with purpose
        #' "assistants" cannot be downloaded. If dest_path is a directory, the file is saved with
        #' its original filename. If dest_path is a file path, it is used as the complete
        #' destination path.
        #'
        #' @param file_id Character. The ID of the file to download.
        #' @param dest_path Character. Destination path (default: "data"). Can be either a directory
        #'   path or a complete file path. Created if it doesn't exist.
        #' @param overwrite Logical. Whether to overwrite existing files (default: TRUE).
        #' @return Character. Path to the downloaded file (invisibly).
        #' @examples
        #' \dontrun{
        #' openai <- OpenAI_Chat$new()
        #'
        #' # Download to a directory
        #' path <- openai$download_file(file_id = "file-abc123", dest_path = "downloads")
        #'
        #' # Download with specific filename
        #' path <- openai$download_file(file_id = "file-abc123", dest_path = "downloads/myfile.txt")
        #' }
        download_file = function(file_id, dest_path = "data", overwrite = TRUE) {
            if (is.null(file_id) || file_id == "") {
                cli::cli_abort("[OpenAI] file_id cannot be NULL or empty")
            }

            file_data <- self$get_file(file_id)

            if (file_data$purpose == "assistants") {
                cli::cli_abort(
                    "[OpenAI] Files with purpose 'assistants' cannot be downloaded. File ID: {file_id}"
                )
            }

            # Code interpreter files may have paths like "sandbox:/mnt/data/file.csv" or "/mnt/data/file.csv"
            # Remove "sandbox:" prefix and extract basename only
            clean_filename <- sub("^sandbox:", "", file_data$filename)
            clean_filename <- basename(clean_filename)
            final_path <- resolve_download_path(dest_path, clean_filename)

            if (is_file(final_path) && !overwrite) {
                cli::cli_abort(
                    "[OpenAI] File already exists: {.path {final_path}}. Use overwrite = TRUE to replace it."
                )
            }

            raw_content <- private$base_request(paste0(self$base_url, "/v1/files/", file_id, "/content")) |>
                httr2::req_perform() |>
                httr2::resp_body_raw()

            writeBin(raw_content, final_path)

            cli::cli_alert_success("[OpenAI] File downloaded to: {.path {final_path}}")

            invisible(final_path)
        },

        #' @description
        #' Delete a file from OpenAI.
        #'
        #' Permanently deletes the specified file. This action cannot be undone.
        #'
        #' @param file_id Character. The ID of the file to delete.
        #' @return List. Deletion confirmation containing:
        #'   - `id`: The deleted file ID
        #'   - `object`: Object type ("file")
        #'   - `deleted`: Boolean indicating successful deletion
        #' @examples
        #' \dontrun{
        #' openai <- OpenAI_Chat$new()
        #'
        #' # Delete a file
        #' result <- openai$delete_file(file_id = "file-abc123")
        #' if (result$deleted) cat("File deleted successfully\n")
        #' }
        delete_file = function(file_id) {
            if (is.null(file_id) || file_id == "") {
                cli::cli_abort("[OpenAI] file_id cannot be NULL or empty")
            }

            res <- private$delete(paste0(self$base_url, "/v1/files/"), file_id)

            if (!is.null(res) && is.null(res$error) && !is.null(res$deleted) && res$deleted) {
                cli::cli_alert_success("[OpenAI] File deleted: {file_id}")
            }
            invisible(res)
        },

        #' @description
        #' Delete multiple files from OpenAI.
        #'
        #' Convenience method to delete multiple files at once. Each deletion is performed
        #' sequentially.
        #'
        #' @param file_ids Character vector. File IDs to delete.
        #' @return Data frame. Deletion results for each file.
        #' @examples
        #' \dontrun{
        #' openai <- OpenAI_Chat$new()
        #'
        #' # Delete multiple files
        #' results <- openai$delete_files(c("file-abc123", "file-def456"))
        #' }
        delete_files = function(file_ids) {
            if (purrr::is_empty(file_ids)) {
                return(data.frame())
            }

            purrr::map(file_ids, self$delete_file) |> 
                purrr::list_rbind()
        },

        #' @description
        #' Delete all files from OpenAI.
        #'
        #' WARNING: This permanently deletes ALL files in your organization. Use with extreme caution.
        #'
        #' @return Data frame. Deletion results for all files.
        #' @examples
        #' \dontrun{
        #' openai <- OpenAI_Chat$new()
        #'
        #' # Delete all files (use with caution!)
        #' results <- openai$delete_all_files()
        #' }
        delete_all_files = function() {
            items <- private$list(paste0(self$base_url, "/v1/files"))
            self$delete_files(purrr::pluck(items, "id"))
        },

        # ------🔺 VECTOR STORES -----------------------------------------------
        # https://platform.openai.com/docs/api-reference/vector-stores

        #' @description
        #' Create a vector store.
        #' @param name Character. The name of the vector store.
        #' @param file_ids A character vector of file IDs.
        #' @return A list containing information about the vector store.
        create_store = function(name, file_ids = NULL) {
            store <- private$create_store_(name, file_ids)

            counter <- 1
            while (store$status != "completed") {

                counter <- counter + 1
                Sys.sleep(1)

                store <- self$read_store(store$id)

                if (counter > 15) {
                    cli::cli_abort(c(
                        "[{self$provider_name}] The store was not created after 15 seconds.",
                        "i" = "Please try again later."
                    ))
                }
            }

            cli::cli_alert_success("[OpenAI] Store created: {store$id}")

            invisible(store)
        },

        #' @description
        #' Read a vector store.
        #' @param store_id Character. The ID of the vector store to read.
        #' @return A list containing information about the vector store.
        read_store = function(store_id) {
            private$request(paste0(self$base_url, "/v1/vector_stores/", store_id))
        },

        #' @description
        #' List all vector stores.
        #' @return A data frame of vector stores.
        list_stores = function() {
            private$list(paste0(self$base_url, "/v1/vector_stores")) |> 
                dplyr::mutate(created_at = lubridate::as_datetime(created_at)) |> 
                dplyr::arrange(dplyr::desc(created_at), id)
        },
        
        #' @description
        #' Find a vector store matching criteria.
        #' @param ... Named arguments for filtering.
        #' @param as_df Logical. Whether to return a data frame.
        #' @return A data frame of matching vector stores.
        find_store = function(..., as_df = TRUE) {
            private$find(paste0(self$base_url, "/v1/vector_stores"), ..., as_df = as_df)
        },

        #' @description
        #' Update a vector store.
        #' @param store_id Character. The ID of the vector store to update.
        #' @param new_name Character. The new name of the vector store.
        #' @return A list containing information about the updated vector store.
        update_store = function(store_id, new_name) {
            private$request(
                paste0(self$base_url, "/v1/vector_stores/", store_id),
                list(name = new_name)
            )
        },

        #' @description
        #' Delete a vector store.
        #' @param store_id Character. The ID of the vector store to delete.
        #' @return A list containing information about the deleted vector store.
        delete_store = function(store_id) {
            result <- private$delete(paste0(self$base_url, "/v1/vector_stores/"), store_id)

            if (!is.null(result) && is.null(result$error) && !is.null(result$deleted) && result$deleted) {
                cli::cli_alert_success("[OpenAI] Store deleted: {store_id}")
            }
            invisible(result)
        },

        #' @description
        #' Delete multiple vector stores.
        #' @param store_ids A character vector of vector store IDs.
        #' @return A data frame of deleted vector stores.
        delete_stores = function(store_ids) {
            if (purrr::is_empty(store_ids)) {
                return(data.frame())
            }

            purrr::map(store_ids, self$delete_store) |>
                purrr::list_rbind()
        },

        #' @description
        #' Delete all vector stores.
        #' @return A data frame of deleted vector stores.
        delete_all_stores = function() {
            items <- private$list(paste0(self$base_url, "/v1/vector_stores"))
            self$delete_stores(purrr::pluck(items, "id"))
        },

        #' @description
        #' Delete a vector store and its files.
        #' @param store_id Character. The ID of the vector store to delete.
        #' @return A list containing information about the deleted vector store and files.
        delete_store_and_files = function(store_id) {
            files_deletion_res <- self$delete_all_files_from_store(store_id)
            store_deletion_res <- self$delete_store(store_id)

            return(list(
                files = files_deletion_res,
                store = store_deletion_res
            ))
        },

        # ------🔺 FILES IN STORES ---------------------------------------------

        #' @description
        #' Add a file to a vector store.
        #' @param store_id Character. The ID of the vector store.
        #' @param file_id Character. The ID of the file.
        #' @return A list containing information about the file in the vector store.
        add_file_to_store = function(store_id, file_id) {

            file_in_store <- private$add_file_to_store_(store_id, file_id)

            counter <- 0
            while (file_in_store$status != "completed") {

                counter <- counter + 1
                Sys.sleep(1)

                file_in_store <- self$read_file_from_store(file_in_store$vector_store_id, file_in_store$id)

                if (counter > 10) {
                    cli::cli_abort("The file could not be added to the store.")
                }
            }

            cli::cli_alert_success("[OpenAI] File added to store: {file_id}")

            invisible(file_in_store)
        },

        #' @description
        #' Read a file from a vector store.
        #' @param store_id Character. The ID of the vector store.
        #' @param file_id Character. The ID of the file.
        #' @return A list containing information about the file in the vector store.
        read_file_from_store = function(store_id, file_id) {
            private$request(paste0(self$base_url, "/v1/vector_stores/", store_id, "/files/", file_id))
        },

        #' @description
        #' List all files in a vector store.
        #' @param store_id Character. The ID of the vector store.
        #' @return A data frame of files in the vector store.
        list_files_in_store = function(store_id) {
            private$list(paste0(self$base_url, "/v1/vector_stores/", store_id, "/files")) |> 
                dplyr::mutate(created_at = lubridate::as_datetime(created_at)) |> 
                dplyr::arrange(dplyr::desc(created_at), id)
        },

        #' @description
        #' Find a file in a vector store matching criteria.
        #' @param store_id Character. The ID of the vector store.
        #' @param ... Named arguments for filtering.
        #' @param as_df Logical. Whether to return a data frame.
        #' @return A data frame of matching files.
        find_file_in_store = function(store_id, ..., as_df = TRUE) {
            private$find(paste0(self$base_url, "/v1/vector_stores/", store_id, "/files"), ..., as_df = as_df)
        },

        #' @description
        #' Delete a file from a vector store.
        #' @param store_id Character. The ID of the vector store.
        #' @param file_id Character. The ID of the file.
        #' @return A list containing information about the deleted file.
        delete_file_from_store = function(store_id, file_id) {
            result <- private$delete(paste0(self$base_url, "/v1/vector_stores/", store_id, "/files/"), file_id)

            if (!is.null(result) && is.null(result$error) && !is.null(result$deleted) && result$deleted) {
                cli::cli_alert_success("[OpenAI] File removed from store: {file_id}")
            }
            invisible(result)
        },

        #' @description
        #' Delete multiple files from a vector store.
        #' @param store_id Character. The ID of the vector store.
        #' @param file_ids A character vector of file IDs.
        #' @return A data frame of deleted files.
        delete_files_from_store = function(store_id, file_ids) {
            if (purrr::is_empty(file_ids)) {
                return(data.frame())
            }

            purrr::map(file_ids, \(fid) self$delete_file_from_store(store_id, fid))
        },

        #' @description
        #' Delete all files from a vector store.
        #' @param store_id Character. The ID of the vector store.
        #' @return A data frame of deleted files.
        delete_all_files_from_store = function(store_id) {
            items <- private$list(paste0(self$base_url, "/v1/vector_stores/", store_id, "/files"))
            self$delete_files_from_store(store_id, purrr::pluck(items, "id"))
        }
    ),
    private = list(
        api_key = NULL,
        org = NULL,

        # ------🔺 REQUESTS ----------------------------------------------------

        # Add OpenAI authentication (Bearer token + organization header)
        add_auth = function(req) {
            httr2::req_headers_redacted(
                req,
                Authorization = paste0("Bearer ", private$api_key),
                `OpenAI-Organization` = private$org
            )
        },

        # Override base_request to accept headers parameter
        base_request = function(
            endpoint,
            headers = list(`Content-Type` = "application/json", `OpenAI-Beta` = "assistants=v2")
        ) {
            super$base_request(endpoint, headers = headers)
        },

        # Override request to accept headers parameter
        request = function(
            endpoint,
            query_data = NULL,
            headers = list(`Content-Type` = "application/json", `OpenAI-Beta` = "assistants=v2")
        ) {
            super$request(endpoint, query_data, headers)
        },

        # ------🔺 HELPERS -----------------------------------------------------

        list = function(endpoint) {
            resp <- private$request(endpoint)

            if (purrr::is_empty(resp)) {
                return(NULL)
            }

            data <- purrr::pluck(resp, "data")

            if (purrr::is_empty(data)) {
                return(data.frame())
            }

            lol_to_df(data)
        },

        delete = function(endpoint, id) {
            resp <- private$base_request(endpoint) |>
                httr2::req_url_path_append(id) |>
                httr2::req_method("DELETE") |>
                httr2::req_perform() |>
                httr2::resp_body_json()

            if ("error" %in% names(resp)) {
                cli::cli_alert_danger("[OpenAI] Error in API request:")
                cat(purrr::pluck(resp, "error", "message", .default = "Unknown error"), "\n", sep = "")
                return(NULL)
            }

            invisible(resp)
        },

        # ------🔺 INTERNAL STORE METHODS --------------------------------------

        # Create a vector store (internal method without polling)
        create_store_ = function(name, file_ids = NULL) {
            payload <- list(name = name)

            if (!is.null(file_ids)) {
                payload$file_ids <- file_ids
            }

            private$request(paste0(self$base_url, "/v1/vector_stores"), payload)
        },

        # Add a file to a vector store (internal method without polling)
        add_file_to_store_ = function(store_id, file_id) {
            private$request(
                paste0(self$base_url, "/v1/vector_stores/", store_id, "/files"),
                list(file_id = file_id)
            )
        }
    )
)

# ------🔺 SCHEMAS -------------------------------------------------------------

#' Convert generic tool schema to OpenAI format (internal)
#' @param tool_schema List. Generic tool schema from as_tool() function
#' @return List. Tool definition in OpenAI format
#' @keywords internal
#' @noRd
as_tool_openai <- function(tool_schema) {
    if (!is.null(tool_schema$parameters) && !is.null(tool_schema$type)) {
        return(tool_schema)
    }

    list3(
        type = "function",
        name = tool_schema$name,
        description = tool_schema$description,
        parameters = tool_schema$args_schema
    )
}

#' Convert schema to structured output format for Responses API (internal)
#' @param output_schema List. Schema definition with name, description, and args_schema/schema
#' @return List. Structured output format for Responses API
#' @keywords internal
#' @noRd
as_schema_openai <- function(output_schema) {
    if (!is.null(output_schema$type) && output_schema$type == "json_schema") {
        return(output_schema)
    }

    if (!is.null(output_schema$args_schema)) {
        schema_to_use <- output_schema$args_schema
    } else if (!is.null(output_schema$schema)) {
        schema_to_use <- output_schema$schema
    } else {
        cli::cli_abort(
            "[{self$provider_name}] output_schema needs one of {.field {c('args_schema', 'schema')}}"
        )
    }

    list3(
        # type = "json_schema", # Only for responses API
        name = output_schema$name,
        description = output_schema$description,
        strict = output_schema$strict %||% TRUE,
        schema = schema_to_use
    )
}

#' Convert response schema to tool format (internal)
#' @param response_schema List. Response schema definition
#' @return List. Tool definition in OpenAI format
#' @keywords internal
#' @noRd
response_schema_to_tool_openai <- function(response_schema) {
    schema_to_use <- if (!is.null(response_schema$schema)) {
        response_schema$schema
    } else if (!is.null(response_schema$args_schema)) {
        response_schema$args_schema
    } else {
        cli::cli_abort("Response schema must have either {.field schema} or {.field args_schema}")
    }

    tool_def <- list(
        type = "function",
        name = "json_formatting_tool",
        description = response_schema$description %||%
            "This tool is used to reformat the response to the user into a well-structured JSON object.",
        parameters = schema_to_use
    )
    return(tool_def)
}
