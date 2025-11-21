#' Client for Google's Gemini API
#'
#' @description
#' R6 class for interacting with Google's Gemini API.
#'
#' @section Features:
#' - Client-side conversation state management
#' - Client-side tools
#' - Server-side tools
#' - Multimodal inputs (files, images, PDFs, R objects)
#' - File uploads and management
#' - Server-side RAG with stores & `file_search` server tool
#' - Reasoning
#' - Structured outputs
#'
#' @section Useful links:
#' - API reference: https://ai.google.dev/api/generate-content
#' - API docs: https://ai.google.dev/gemini-api/docs
#' 
#' @section Main entrypoints:
#' - `chat()`: Multi-turn multimodal conversations with tool use and structured outputs.
#' - `embeddings()`: Vector embeddings for text inputs.
#'
#' @section Server-side tools:
#' - `code_execution`: Execute Python code
#' - `google_search`: Web search with grounding
#' - `url_context`: Fetch and process URLs
#' - `google_maps`: Location-aware data
#' - `file_search`: Search through uploaded files
#'
#' @section Structured outputs:
#' Hybrid approach for structured outputs:
#' - Native support for Sonnet and Pro models via JSON schema.
#' - Function-call trick for other models: uses tool calling to simulate structured outputs, requiring an
#'   additional API query with full chat history (incurs extra cost).
#'
#' @export
#' @examples
#' \dontrun{
#' # Initialize with API key from environment
#' google <- Google$new()
#' 
#' # Or provide API key explicitly
#' google <- Google$new(api_key = "your-api-key")
#' 
#' # Simple chat completion
#' response <- google$chat(
#'   "What is R programming?",
#'   model = "gemini-2.5-pro"
#' )
#' 
#' # With system instructions
#' response <- google$chat(
#'   "Explain quantum computing",
#'   model = "gemini-2.5-pro",
#'   system = "You are a physics professor"
#' )
#' 
#' # With R objects (names captured automatically)
#' my_data <- mtcars
#' response <- google$chat(
#'   my_data, "Analyze this dataset",
#'   model = "gemini-2.5-pro"
#' )
#' 
#' # With context caching for repeated queries
#' cache_name <- google$create_cache(
#'   model = "gemini-2.5-flash",
#'   system = "You are an expert data analyst",
#'   ttl = "3600s"
#' )
#' }
Google <- R6::R6Class( # nolint
    classname = "Google",
    inherit = Provider,
    public = list(
        
        # ------🔺 INIT --------------------------------------------------------

        #' @description
        #' Initialize a new Google Gemini client
        #' @param base_url Character. Base URL for API (default:
        #'   "https://generativelanguage.googleapis.com")
        #' @param api_key Character. API key (default: from GEMINI_API_KEY env var)
        #' @param provider_name Character. Provider name (default: "Google")
        #' @param rate_limit Numeric. Rate limit in requests per second (default: 5/60, free tier for
        #'   2.5 Pro)
        #' @param server_tools Character vector. Server-side tools available (default: c("code_execution",
        #'   "google_search", "url_context", "google_maps", "file_search"))
        #' @param default_model Character. Default model to use for chat requests (default:
        #'   "gemini-2.5-flash")
        #' @param auto_save_history Logical. Enable/disable automatic history sync (default: TRUE)
        initialize = function(
            base_url = "https://generativelanguage.googleapis.com",
            api_key = Sys.getenv("GEMINI_API_KEY"),
            provider_name = "Google",
            rate_limit = 5 / 60,
            server_tools = c("code_execution", "google_search", "url_context", "google_maps", "file_search"),
            default_model = "gemini-2.5-flash",
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
        },

        # ------🔺 MODELS ------------------------------------------------------

        #' @description
        #' List all available Google models
        #' @return Data frame. Available models with their specifications
        list_models = function() {
            endpoint <- paste0(self$base_url, "/v1beta/models")
            
            resp <- private$request(endpoint) |> 
                purrr::pluck("models") |> 
                lol_to_df()

            resp <- resp |>
                dplyr::select(name, description, inputTokenLimit, outputTokenLimit) |>
                dplyr::mutate(name = stringr::str_remove(name, "models/")) |>
                dplyr::arrange(name)

            return(resp)
        },
        
        #' @description
        #' Get information about a specific Google model
        #' @param model_id Character. Model ID (e.g., "gemini-2.5-pro")
        #' @return List. Model information
        get_model_info = function(model_id) {
            endpoint <- paste0(self$base_url, "/v1beta/models/", model_id)
            
            resp <- private$request(endpoint)
            
            return(resp)
        },

        # ------🔺 EMBEDDINGS --------------------------------------------------

        #' @description
        #' Generate embeddings for text input using Google's embedding models
        #' @param input Character vector. Text(s) to embed
        #' @param model Character. Model to use (e.g., "text-embedding-004", "text-embedding-preview-0815")
        #' @param task_type Character. Task type for optimization (optional). One of:
        #'   - "RETRIEVAL_QUERY": For search queries
        #'   - "RETRIEVAL_DOCUMENT": For documents in search corpus
        #'   - "SEMANTIC_SIMILARITY": For similarity comparison
        #'   - "CLASSIFICATION": For text classification
        #'   - "CLUSTERING": For clustering tasks
        #' @param output_dimensionality Integer. Number of dimensions for output (optional, 128-3072 for supported models)
        #' @param return_full_response Logical. Return full API response (default: FALSE)
        #' @return Numeric matrix (or List if return_full_response = TRUE). Embeddings with one row per input text
        #' @examples
        #' \dontrun{
        #' google <- Google$new()
        #'
        #' # Generate embeddings
        #' embeddings <- google$embeddings(
        #'   input = c("Hello world", "How are you?"),
        #'   model = "text-embedding-004"
        #' )
        #'
        #' # With task type for optimization
        #' embeddings <- google$embeddings(
        #'   input = "Sample query",
        #'   model = "text-embedding-004",
        #'   task_type = "RETRIEVAL_QUERY"
        #' )
        #'
        #' # With dimension reduction
        #' embeddings <- google$embeddings(
        #'   input = "Sample text",
        #'   model = "text-embedding-004",
        #'   output_dimensionality = 256
        #' )
        #' }
        embeddings = function(
            input,
            model,
            task_type = NULL,
            output_dimensionality = NULL,
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

            # Validate task_type if provided
            if (!is.null(task_type)) {
                valid_task_types <- c(
                    "RETRIEVAL_QUERY", "RETRIEVAL_DOCUMENT", "SEMANTIC_SIMILARITY",
                    "CLASSIFICATION", "CLUSTERING"
                )
                if (!task_type %in% valid_task_types) {
                    cli::cli_abort(
                        "[{self$provider_name}] Invalid task_type. Must be one of: {paste(valid_task_types, collapse = ', ')}"
                    )
                }
            }

            # Build requests - Google expects one request per input text
            embeddings_list <- list()

            for (i in seq_along(input)) {
                query_data <- list3(
                    content = list(parts = list(list(text = input[i]))),
                    task_type = task_type,
                    output_dimensionality = output_dimensionality
                )

                # Make API request
                endpoint <- paste0(self$base_url, "/v1beta/models/", model, ":embedContent")
                res <- private$request(endpoint, query_data)

                # Handle API errors
                if (purrr::is_empty(purrr::pluck(res, "embedding", "values"))) {
                    cli::cli_abort(
                        "[{self$provider_name}] Error: API request failed or returned no embedding for input {i}"
                    )
                }

                embeddings_list[[i]] <- purrr::pluck(res, "embedding", "values")
            }

            # Return full response if requested (return last response or list of all responses)
            if (isTRUE(return_full_response)) {
                return(res)
            }

            # Flatten to numeric vector, then reshape to matrix
            embeddings_matrix <- matrix(
                unlist(embeddings_list, use.names = FALSE),
                nrow = length(embeddings_list),
                ncol = length(embeddings_list[[1]]),
                byrow = TRUE
            )

            return(embeddings_matrix)
        },

        # ------🔺 FILES -------------------------------------------------------

        #' @description
        #' Upload a file to Google Files API (uses resumable upload)
        #' @param file_path Character. Path to the file to upload, or URL to a remote file
        #' @param name Character. Display name for the file (optional, uses filename if NULL)
        #' @param mime_type Character. MIME type (optional, auto-detected if NULL)
        #' @return List. File metadata or NULL on error
        upload_file = function(file_path, name = NULL, mime_type = NULL) {
            if (is_url(file_path)) {
                file_path <- download_temp_file(file_path)
                on.exit(unlink(file_path))
            }

            if (!is_file(file_path)) {
                cli::cli_abort("[{self$provider_name}] File not found: {.path {file_path}}")
            }

            if (is.null(name)) {
                name <- basename(file_path)
            }

            if (is.null(mime_type)) {
                mime_type <- mime::guess_type(file_path)
            }

            file_size <- file.info(file_path)$size

            if (file_size > 2e9) {
                cli::cli_abort("[{self$provider_name}] File size exceeds 2GB limit")
            }

            init_endpoint <- paste0(self$base_url, "/upload/v1beta/files")
            request_body <- list(file = list(display_name = name))

            result <- private$resumable_upload(init_endpoint, request_body, file_path, file_size, mime_type)

            if (is.null(result)) {
                return(NULL)
            }

            file_metadata <- result$file
            cli::cli_alert_success("[{self$provider_name}] File uploaded: {file_metadata$name}")
            invisible(file_metadata)
        },

        #' @description
        #' Get metadata for an uploaded file
        #' @param file_name Character. File name (e.g., "files/abc123")
        #' @return List. File metadata or NULL on error
        get_file_metadata = function(file_name) {
            endpoint <- paste0(self$base_url, "/v1beta/", file_name)
            return(private$request(endpoint))
        },

        #' @description
        #' List all uploaded files
        #' @param page_size Integer. Number of files per page (default: 100)
        #' @param page_token Character. Page token for pagination (optional)
        #' @param as_df Logical. Whether to return files as a data frame (default: TRUE). If FALSE, returns raw list.
        #' @return Data frame (if as_df = TRUE) or list otherwise. Files metadata and next page token (list only).
        list_files = function(page_size = 100, page_token = NULL, as_df = TRUE) {
            endpoint <- paste0(self$base_url, "/v1beta/files")
            res <- private$list(endpoint, page_size, page_token)

            if (is.null(res)) {
                return(NULL)
            }

            if (is.null(res$files) || purrr::is_empty(res$files)) {
                if (as_df) {
                    return(data.frame())
                } else {
                    return(list(files = list(), nextPageToken = NULL))
                }
            }

            if (as_df) {
                return(lol_to_df(res$files))
            } else {
                return(res)
            }
        },

        #' @description
        #' Delete an uploaded file
        #' @param file_name Character. File name (e.g., "files/abc123")
        #' @return Logical. TRUE if successful, FALSE otherwise
        delete_file = function(file_name) {
            endpoint <- paste0(self$base_url, "/v1beta/", file_name)
            result <- private$delete(endpoint)

            if (is.null(result)) {
                return(FALSE)
            }

            cli::cli_alert_success("[{self$provider_name}] File deleted: {file_name}")
            invisible(TRUE)
        },

        # ------🔺 FILE SEARCH STORES ------------------------------------------

        #' @description
        #' Create a new file search store for RAG operations
        #' @param name Character. Display name for the store (optional)
        #' @return List. File search store metadata or NULL on error
        create_store = function(name = NULL) {
            endpoint <- paste0(self$base_url, "/v1beta/fileSearchStores")
            query_data <- list3(displayName = name)

            res <- private$request(endpoint, query_data)

            if (!is.null(res)) {
                cli::cli_alert_success("[{self$provider_name}] File search store created: {res$name}")
            }
            invisible(res)
        },

        #' @description
        #' List all file search stores
        #' @param page_size Integer. Number of stores per page (default: 10, max: 100)
        #' @param page_token Character. Page token for pagination (optional)
        #' @param as_df Logical. Whether to return stores as a data frame (default: TRUE). If FALSE, returns raw list.
        #' @return Data frame (if as_df = TRUE) or list otherwise. File search stores metadata.
        list_stores = function(page_size = 10, page_token = NULL, as_df = TRUE) {
            endpoint <- paste0(self$base_url, "/v1beta/fileSearchStores")
            res <- private$list(endpoint, page_size, page_token)

            if (is.null(res)) {
                return(NULL)
            }

            if (purrr::is_empty(res$fileSearchStores)) {
                if (as_df) {
                    return(data.frame())
                }
                return(list(fileSearchStores = list(), nextPageToken = NULL))
            }

            if (as_df) {
                return(lol_to_df(res$fileSearchStores))
            }
            return(res)
        },

        #' @description
        #' Get information about a specific file search store
        #' @param name Character. Store name (e.g., "fileSearchStores/abc123")
        #' @return List. File search store metadata or NULL on error
        read_store = function(name) {
            endpoint <- paste0(self$base_url, "/v1beta/", name)
            return(private$request(endpoint))
        },

        #' @description
        #' Delete a file search store
        #' @param name Character. Store name (e.g., "fileSearchStores/abc123")
        #' @param force Logical. If TRUE, delete the store even if it contains documents (default: FALSE)
        #' @return Logical. TRUE if successful, FALSE otherwise
        delete_store = function(name, force = FALSE) {
            endpoint <- paste0(self$base_url, "/v1beta/", name)
            result <- private$delete(endpoint, force = force)

            if (is.null(result)) {
                cli::cli_alert_danger("[{self$provider_name}] Failed to delete store: {name}")
                return(FALSE)
            }

            cli::cli_alert_success("[{self$provider_name}] File search store deleted: {name}")
            invisible(TRUE)
        },

        # ------🔺 FILES IN STORES ---------------------------------------------

        #' @description
        #' Upload a file directly to a file search store using resumable upload.
        #' Supports custom chunking configuration and metadata.
        #' @param file_path Character. Path to the file to upload, or URL to a remote file
        #' @param store_name Character. Store name (e.g., "fileSearchStores/abc123")
        #' @param file_name Character. Display name for the file (optional, uses filename if NULL)
        #' @param custom_metadata List. Custom metadata as key-value pairs (optional)
        #' @param chunking_config List. Chunking configuration with max_tokens_per_chunk and max_overlap_tokens
        #'   (optional)
        #' @return List. Document metadata or NULL on error
        add_file_to_store = function(
            file_path,
            store_name,
            file_name = NULL,
            custom_metadata = NULL,
            chunking_config = NULL
        ) {
            # Prepare display name
            if (is.null(file_name)) {
                file_name <- basename(file_path)
            }

            # Download remote file if URL
            local_file_path <- if (is_url(file_path)) {
                temp_file <- tempfile(fileext = paste0(".", tools::file_ext(file_path)))
                utils::download.file(file_path, temp_file, mode = "wb", quiet = TRUE)
                temp_file
            } else {
                file_path
            }

            # Get file info
            file_info <- file.info(local_file_path)
            file_size <- file_info$size
            mime_type <- mime::guess_type(local_file_path)

            # Build custom metadata list
            custom_metadata_list <- if (!is.null(custom_metadata)) {
                unname(purrr::imap(custom_metadata, function(value, key) {
                    if (is.numeric(value)) {
                        list(key = key, numericValue = value)
                    } else {
                        list(key = key, stringValue = as.character(value))
                    }
                }))
            }

            # Build chunking config
            chunking_config_obj <- NULL
            if (!is.null(chunking_config)) {
                max_tokens <- purrr::pluck(chunking_config, "max_tokens_per_chunk")
                max_overlap <- purrr::pluck(chunking_config, "max_overlap_tokens")

                # Validate chunking parameters
                if (!is.null(max_tokens)) {
                    if (!is.numeric(max_tokens) || max_tokens < 0 || max_tokens > 512) {
                        cli::cli_abort(
                            "{.arg max_tokens_per_chunk} must be between 0 and 512, got {max_tokens}"
                        )
                    }
                }

                if (!is.null(max_overlap)) {
                    if (!is.numeric(max_overlap) || max_overlap < 0) {
                        cli::cli_abort("{.arg max_overlap_tokens} must be >= 0, got {max_overlap}")
                    }
                }

                if (!is.null(max_tokens) || !is.null(max_overlap)) {
                    chunking_config_obj <- list(
                        whiteSpaceConfig = list3(
                            maxTokensPerChunk = max_tokens,
                            maxOverlapTokens = max_overlap
                        )
                    )
                }
            }

            # Build request body for resumable upload initialization
            request_body <- list3(
                displayName = file_name,
                mimeType = mime_type,
                customMetadata = custom_metadata_list,
                chunkingConfig = chunking_config_obj
            )

            # Initialize resumable upload to store
            init_endpoint <- paste0(
                self$base_url,
                "/upload/v1beta/",
                store_name,
                ":uploadToFileSearchStore"
            )

            init_req <- httr2::request(init_endpoint) |>
                httr2::req_url_query(key = private$api_key) |>
                httr2::req_headers(
                    "X-Goog-Upload-Protocol" = "resumable",
                    "X-Goog-Upload-Command" = "start",
                    "X-Goog-Upload-Header-Content-Length" = as.character(file_size),
                    "X-Goog-Upload-Header-Content-Type" = mime_type,
                    "Content-Type" = "application/json"
                ) |>
                httr2::req_body_json(request_body) |>
                httr2::req_error(is_error = \(resp) FALSE)

            init_resp <- httr2::req_perform(init_req)

            if (httr2::resp_is_error(init_resp)) {
                cli::cli_alert_danger("[{self$provider_name}] Failed to initiate upload to store")
                return(NULL)
            }

            upload_url <- httr2::resp_header(init_resp, "X-Goog-Upload-URL")

            if (is.null(upload_url)) {
                cli::cli_alert_danger("[{self$provider_name}] No upload URL returned")
                return(NULL)
            }

            # Upload file content
            upload_req <- httr2::request(upload_url) |>
                httr2::req_headers(
                    "Content-Length" = as.character(file_size),
                    "X-Goog-Upload-Offset" = "0",
                    "X-Goog-Upload-Command" = "upload, finalize"
                ) |>
                httr2::req_body_file(local_file_path) |>
                httr2::req_error(is_error = \(resp) FALSE) |>
                httr2::req_timeout(300)

            upload_resp <- httr2::req_perform(upload_req)

            # Clean up temp file if we downloaded one
            if (is_url(file_path)) {
                unlink(local_file_path)
            }

            if (httr2::resp_is_error(upload_resp)) {
                error_body <- tryCatch(
                    httr2::resp_body_json(upload_resp),
                    error = function(e) list(error = list(message = "Unknown error"))
                )
                error_msg <- purrr::pluck(error_body, "error", "message", .default = "Unknown error")
                cli::cli_alert_danger("[{self$provider_name}] Upload failed: {error_msg}")
                return(NULL)
            }

            result <- httr2::resp_body_json(upload_resp)

            if ("error" %in% names(result)) {
                cli::cli_alert_danger("[{self$provider_name}] Upload error: {result$error$message}")
                return(NULL)
            }

            # Wait for operation to complete
            if (!is.null(result$name)) {
                document <- private$wait_for_operation(result$name, result)

                if (!purrr::is_empty(document)) {
                    # Add full path to document if not present
                    if (is.null(document$name)) {
                        document$name <- paste0(store_name, "/documents/", document$documentName)
                    }
                    cli::cli_alert_success(
                        "[{self$provider_name}] File uploaded to store: {document$name}"
                    )
                    return(invisible(document))
                }
            }

            return(NULL)
        },

        #' @description
        #' Import an existing File API file to a file search store.
        #' Note: The importFile endpoint does not support custom chunking configuration.
        #' Files will be chunked automatically by Google's API.
        #' @param file_name Character. File name from File API (e.g., "files/abc123")
        #' @param store_name Character. Store name (e.g., "fileSearchStores/abc123")
        #' @param custom_metadata List. Custom metadata as key-value pairs (optional)
        #' @return List. Document metadata or NULL on error
        import_file_to_store = function(
            file_name,
            store_name,
            custom_metadata = NULL
        ) {
            endpoint <- paste0(self$base_url, "/v1beta/", store_name, ":importFile")

            custom_metadata_list <- if (!is.null(custom_metadata)) {
                unname(purrr::imap(custom_metadata, function(value, key) {
                    if (is.numeric(value)) {
                        list(key = key, numericValue = value)
                    } else {
                        list(key = key, stringValue = as.character(value))
                    }
                }))
            }

            query_data <- list3(
                fileName = file_name,
                customMetadata = custom_metadata_list
            )

            operation_metadata <- private$request(endpoint, query_data)

            if ("error" %in% names(operation_metadata)) {
                cli::cli_alert_danger("[{self$provider_name}] Import error: {operation_metadata$error$message}")
                return(NULL)
            }

            if (is.null(operation_metadata$name) || purrr::is_empty(operation_metadata$name)) {
                cli::cli_alert_danger("[{self$provider_name}] Import failed: No operation name returned")
                return(NULL)
            }

            document <- private$wait_for_operation(operation_metadata$name, operation_metadata)

            if (purrr::is_empty(document)) {
                return(NULL)
            }

            # Add full path to document if not present
            if (is.null(document$name)) {
                document$name <- paste0(store_name, "/documents/", document$documentName)
            }
            cli::cli_alert_success("[{self$provider_name}] File imported: {document$name}")
            invisible(document)
        },

        #' @description
        #' List files in a file search store
        #' @param store_name Character. Store name (e.g., "fileSearchStores/abc123")
        #' @param page_size Integer. Number of files per page (default: 10, max: 100)
        #' @param page_token Character. Page token for pagination (optional)
        #' @param as_df Logical. Whether to return files as a data frame (default: TRUE). If FALSE, returns raw list.
        #' @return Data frame (if as_df = TRUE) or list otherwise. Files metadata.
        list_files_in_store = function(store_name, page_size = 10, page_token = NULL, as_df = TRUE) {
            endpoint <- paste0(self$base_url, "/v1beta/", store_name, "/documents")
            res <- private$list(endpoint, page_size, page_token)

            if (purrr::is_empty(res)) {
                return(NULL)
            }

            if (purrr::is_empty(res$documents)) {
                if (as_df) {
                    return(data.frame())
                }
                return(list(documents = list(), nextPageToken = NULL))
            }

            if (as_df) {
                return(lol_to_df(res$documents))
            }
            return(res)
        },

        #' @description
        #' Get information about a specific file in a store
        #' @param file_name Character. File name (e.g., "fileSearchStores/xyz/documents/abc123")
        #' @return List. File metadata or NULL on error
        read_file_from_store = function(file_name) {
            endpoint <- paste0(self$base_url, "/v1beta/", file_name)
            return(private$request(endpoint))
        },

        #' @description
        #' Delete a file from a file search store
        #' @param file_name Character. File name (e.g., "fileSearchStores/xyz/documents/abc123")
        #' @param force Logical. If TRUE, force deletion of non-empty documents (default: TRUE)
        #' @return Logical. TRUE if successful, FALSE otherwise
        delete_file_from_store = function(file_name, force = TRUE) {
            endpoint <- paste0(self$base_url, "/v1beta/", file_name)
            result <- private$delete(endpoint, force = force)

            if (is.null(result)) {
                cli::cli_alert_danger("[{self$provider_name}] Failed to delete file: {file_name}")
                return(FALSE)
            }

            cli::cli_alert_success("[{self$provider_name}] File deleted: {file_name}")
            invisible(TRUE)
        },

        #' @description
        #' Query a specific file in a file search store
        #' @param file_name Character. File name (e.g., "fileSearchStores/xyz/documents/abc123")
        #' @param query Character. Query string
        #' @param results_count Integer. Number of results to return (default: 10)
        #' @param metadata_filters Character. Metadata filter string (optional, e.g., "author=John")
        #' @return List. Query results or NULL on error
        query_file = function(file_name, query, results_count = 10, metadata_filters = NULL) {
            endpoint <- paste0(self$base_url, "/v1beta/", file_name, ":query")

            query_data <- list3(
                query = query,
                resultsCount = results_count,
                metadataFilters = metadata_filters
            )

            return(private$request(endpoint, query_data))
        },

        # ------🔺 OPERATIONS --------------------------------------------------

        #' @description
        #' Get the status of a long-running operation
        #' @param operation_name Character. Operation name (e.g., "fileSearchStores/xyz/operations/abc123")
        #' @return List. Operation status or NULL on error
        get_operation = function(operation_name) {
            endpoint <- paste0(self$base_url, "/v1beta/", operation_name)
            return(private$request(endpoint))
        },

        # ------🔺 CHAT --------------------------------------------------------
        
        #' @description
        #' Send a chat completion request to Google
        #'
        #' **Note on thinking with function calling**: When thinking and function calling are both enabled,
        #' the model returns thought signatures in the response. These encrypted representations of the
        #' model's thought process are automatically included in subsequent turns via chat_history,
        #' allowing the model to maintain thought context across multi-turn conversations. However, thought
        #' signatures increase input token costs when sent back in requests. See
        #' \url{https://ai.google.dev/gemini-api/docs/thinking#signatures}
        #'
        #' @param ... One or more inputs for the prompt. Can be text strings, file paths, URLs, R objects,
        #'   or content wrapped with `as_*_content()` functions. R objects (but not plain strings) will
        #'   include their names and structure in the context sent to the model.
        #' @param model Character. Model to use (default: "gemini-2.5-flash")
        #' @param system Character. System instructions (optional)
        #' @param max_tokens Integer. Maximum tokens to generate (default: 8000)
        #' @param temperature Numeric. Sampling temperature 0-2 (default: 1)
        #' @param top_p Numeric. Nucleus sampling - cumulative probability cutoff. Range: 0.0-1.0 (optional)
        #' @param top_k Integer. Top-K sampling - sample from top K options. Range: 1+ (optional)
        #' @param stop_sequences Character vector. Sequences that stop generation when encountered (optional)
        #' @param tools List. Function definitions for tool calling (optional). Supports both client-side
        #'   functions and server-side tools:
        #'
        #'   **Server-side tools:**
        #'   * `"code_execution"` or `list(type = "code_execution", file_ids = list("files/xyz"))` - Execute Python code
        #'   * `"google_search"` - Web search with grounding
        #'   * `"url_context"` - Fetch and process URLs
        #'   * `"google_maps"` or `list(type = "google_maps", enable_widget = TRUE, location = list(latitude, longitude))` - Location-aware data
        #'   * `"file_search"` or `list(type = "file_search", store_names = list("fileSearchStores/xyz"), metadata_filter = "key=value")` - Search through uploaded files
        #'
        #'   **Client-side functions:**
        #'   Use `as_tool(fn)` to wrap R functions for tool calling.
        #' @param tool_choice Character or List. Controls how the model uses function declarations
        #'   (default: list(mode = "AUTO")). Only applies to client function tools, not server tools.
        #'
        #'   **Modes:**
        #'   * `"AUTO"` (default): Model decides whether to call functions or respond with natural language
        #'   * `"ANY"`: Model must always call a function (never responds with natural language)
        #'   * `"NONE"`: Model cannot call functions (temporarily disable without removing tool definitions)
        #'   * `"VALIDATED"` (Preview): Model can call functions or respond naturally, with schema validation
        #'
        #'   **Limiting function selection (optional):**
        #'   When mode is "ANY" or "VALIDATED", you can specify which functions are allowed:
        #'   `list(mode = "ANY", allowed_function_names = c("func1", "func2"))`
        #'
        #'   **Examples:**
        #'   * `tool_choice = "AUTO"` - Simple mode specification (character)
        #'   * `tool_choice = list(mode = "ANY")` - Force function call from any available function
        #'   * `tool_choice = list(mode = "ANY", allowed_function_names = c("get_weather"))` - Force specific function
        #' @param output_schema List. JSON schema for structured output (optional)
        #' @param thinking_budget Integer. Thinking budget in tokens: 0 (disabled), -1 (dynamic),
        #'   or 0-24575/32768 (fixed budget). Default: 0.
        #' @param include_thoughts Logical. Whether to include thought parts in the response (default: FALSE).
        #'   If TRUE but thinking_budget is 0, a warning is issued and include_thoughts is set to FALSE.
        #' @return Character. Text response from the model.
        chat = function(
            ...,
            model = self$default_model,
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
            include_thoughts = FALSE
        ) {

            # ---- Validate parameters ----

            if (temperature < 0 | temperature > 2) {
                cli::cli_alert_danger("[{self$provider_name}] Error: Parameter 'temperature' must be between 0 and 2")
                return(NULL)
            }

            # Note: for Google, the system instructions are passed as query_data, not as part of the chat history.

            # ---- Build input ----

            # Capture prompt inputs as quosures
            inputs <- rlang::enquos(...)
            
            # Adding the prompt to the chat history if it's not empty
            # It will be NULL when the prompt is the result of function calling
            new_message_parts <- NULL
            if (!purrr::is_empty(inputs)) {
                new_message_parts <- private$process_multipart_content(inputs)
            }

            # ---- Process tools and inject into message ----

            private$reset_active_tools()

            tool_list <- list()
            function_declarations <- list()
            built_in_added <- character(0)
            maps_location <- NULL

            if (!is.null(tools)) {
                for (tool in tools) {
                    if (is_mcp_tool(tool)) {
                        converted_tool <- as_tool_google(tool)
                        function_declarations <- append(function_declarations, list(converted_tool))

                        # We add the original tool because the converted one no longer has the .mcp metadata
                        private$add_active_tool(type = "mcp", tool = tool)

                    } else if (is_client_tool(tool)) {
                        converted_tool <- as_tool_google(tool)
                        function_declarations <- append(function_declarations, list(converted_tool))

                        private$add_active_tool(type = "client", tool = tool)

                    } else if (is_server_tool(tool, self$server_tools)) {
                        tool_name <- get_server_tool_name(tool)

                        if (tool_name %in% c("code_execution")) {
                            # Inject files into message if list form
                            if (is.list(tool) && !is.null(tool$file_ids)) {
                                for (file_id in tool$file_ids) {
                                    # Get file metadata to retrieve mime_type and uri
                                    file_metadata <- self$get_file_metadata(file_id)
                                    if (!is.null(file_metadata)) {
                                        file_part <- list(file_data = list(
                                            mime_type = file_metadata$mimeType,
                                            file_uri = file_metadata$uri
                                        ))
                                        new_message_parts <- append(new_message_parts, list(file_part))
                                    }
                                }
                            }

                            # Add code_execution tool (only once)
                            if (!"code_execution" %in% built_in_added) {
                                tool_list[["code_execution"]] <- named_list()
                                built_in_added <- union(built_in_added, "code_execution")
                            }
                        } else if (tool_name == "google_search") {
                            # Add google_search tool (only once)
                            if (!"google_search" %in% built_in_added) {
                                tool_list[["google_search"]] <- named_list()
                                built_in_added <- c(built_in_added, "google_search")
                            }
                        } else if (tool_name == "url_context") {
                            # Add url_context tool (only once)
                            if (!"url_context" %in% built_in_added) {
                                tool_list[["url_context"]] <- named_list()
                                built_in_added <- c(built_in_added, "url_context")
                            }
                        } else if (tool_name == "google_maps") {
                            # Add google_maps tool (only once)
                            if (!"google_maps" %in% built_in_added) {
                                # Extract enable_widget if provided
                                if (is.list(tool) && !is.null(tool$enable_widget)) {
                                    tool_list[["google_maps"]] <- list(enableWidget = tool$enable_widget)
                                } else {
                                    tool_list[["google_maps"]] <- named_list()
                                }

                                # Extract location for toolConfig if provided
                                if (is.list(tool) && !is.null(tool$location)) {
                                    maps_location <- tool$location
                                }

                                built_in_added <- c(built_in_added, "google_maps")
                            }
                        } else if (tool_name == "file_search") {
                            # Add file_search tool (only once)
                            if (!"file_search" %in% built_in_added) {
                                # Build the tool definition
                                if (is.list(tool)) {
                                    # Extract parameters from list form
                                    tool_list[["file_search"]] <- list3(
                                        file_search_store_names = as.list(purrr::pluck(tool, "store_names")),
                                        metadata_filter = purrr::pluck(tool, "metadata_filter")
                                    )
                                } else {
                                    # String form - just enable tool
                                    tool_list[["file_search"]] <- named_list()
                                }
                                built_in_added <- c(built_in_added, "file_search")
                            }
                        }
                    } else {
                        tool_name <- get_server_tool_name(tool)
                        if (!purrr::is_empty(tool_name)) {
                            cli::cli_abort(c(
                                "[{self$provider_name}] Invalid server tool: {tool_name}.",
                                "i" = "Options are: {.field {self$server_tools}}"
                            ))
                        } else {
                            cli::cli_abort("[{self$provider_name}] Invalid tool: {.field {tool}}")
                        }
                    }
                }

                # Add function declarations if any
                if (length(function_declarations) > 0) {
                    tool_list <- append(tool_list, list(function_declarations = function_declarations))
                }
            }

            # Append message to history if not empty
            if (!is.null(new_message_parts) && !purrr::is_empty(new_message_parts)) {
                private$append_to_chat_history(list(role = "user", parts = new_message_parts))
            }

            # ---- Build API request ----

            query_data <- list(
                contents = self$chat_history,
                generationConfig = list3(
                    temperature = temperature,
                    maxOutputTokens = max_tokens,
                    topP = top_p,
                    topK = top_k,
                    stopSequences = stop_sequences
                )
            )

            if (!is.null(system)) {
                query_data$systemInstruction <- list(parts = list(list(text = system)))
            }
            
            if (!is.null(tools)) {
                query_data$tools <- tool_list

                # Build toolConfig based on what's needed
                tool_config_obj <- list()

                # Add function calling config for client tools
                if (length(function_declarations) > 0) {
                    validated_config <- private$validate_tool_choice(tool_choice)
                    tool_config_obj$functionCallingConfig <- validated_config
                }

                # Add retrieval config for Google Maps location context
                if (!is.null(maps_location)) {
                    tool_config_obj$retrievalConfig <- list(
                        latLng = list(
                            latitude = maps_location$latitude,
                            longitude = maps_location$longitude
                        )
                    )
                }

                # Only add toolConfig if there's something to configure
                if (length(tool_config_obj) > 0) {
                    query_data$toolConfig <- tool_config_obj
                }
            }
            
            # Add thinking_budget to generationConfig if provided
            # Validate thinking budget based on model
            if (!is.null(thinking_budget)) {
                # Determine model type
                is_pro <- stringr::str_detect(model, "2\\.5-pro")
                is_flash <- stringr::str_detect(model, "2\\.5-flash") &&
                    !stringr::str_detect(model, "lite")
                is_flash_lite <- stringr::str_detect(model, "2\\.5-flash-lite")

                # Pro requires thinking (cannot be disabled)
                if (is_pro && thinking_budget == 0) {
                    cli::cli_alert_warning(paste(
                        "[{self$provider_name}] Gemini 2.5 Pro requires thinking to be enabled.",
                        "Setting thinking_budget to -1 (dynamic). Give a specific value to avoid this warning."
                    ))
                    thinking_budget <- -1
                }

                # Validate ranges per model
                if (thinking_budget != 0 && thinking_budget != -1) {
                    min_budget <- if (is_pro) 128 else if (is_flash) 8 else 512
                    max_budget <- if (is_pro) 32768 else 24576

                    if (thinking_budget < min_budget | thinking_budget > max_budget) {
                        model_name <- if (is_pro) "2.5 Pro" else if (is_flash) "2.5 Flash" else "2.5 Flash Lite"
                        cli::cli_alert_danger(paste(
                            "[{self$provider_name}] Error: thinking_budget for Gemini {model_name}",
                            "must be -1 (dynamic), 0 (disabled), or between {min_budget} and {max_budget}"
                        ))
                        return(NULL)
                    }
                }

                # Validate and handle include_thoughts
                if (!is.logical(include_thoughts)) {
                    cli::cli_alert_warning(c(
                        "[{self$provider_name}] include_thoughts must be TRUE or FALSE.",
                        "Setting to FALSE."
                    ))
                    include_thoughts <- FALSE
                }

                if (include_thoughts && thinking_budget == 0) {
                    cli::cli_alert_warning(c(
                        "[{self$provider_name}] include_thoughts is TRUE but thinking_budget is 0.",
                        "Setting include_thoughts to FALSE."
                    ))
                    include_thoughts <- FALSE
                }

                # Add to config if thinking is enabled
                if (thinking_budget != 0) {
                    query_data$generationConfig$thinkingConfig <- list(
                        thinkingBudget = thinking_budget,
                        includeThoughts = include_thoughts
                    )
                }
            }

            # Add native structured output if requested
            # Note: Only applied when no tools are present (Google API limitation)
            if (is.list(output_schema) && is.null(tools)) {
                query_data$generationConfig$responseMimeType <- "application/json"
                query_data$generationConfig$responseSchema <- as_schema_google(output_schema)
            }

            # ---- Make API request ----

            endpoint <- paste0(self$base_url, "/v1beta/models/", model, ":generateContent")

            res <- private$request(endpoint = endpoint, query_data = query_data)

            # ---- Handle response ----

            # Handle API errors
            if (purrr::is_empty(private$extract_root(res))) {
                cli::cli_abort("[{self$provider_name}] Error: API request failed or returned no choices")
            }

            # Report cache hit statistics in debug mode
            if (!is.null(res$usageMetadata) && isTRUE(getOption("argent.debug", default = FALSE))) {
                cached_tokens <- purrr::pluck(res, "usageMetadata", "cachedContentTokenCount")
                if (!is.null(cached_tokens) && cached_tokens > 0) {
                    cli::cli_alert_info("[{self$provider_name}] Cache hit: {cached_tokens} tokens from cache")
                }
            }

            # Save to session history and add response to chat history
            private$save_to_session_history(query_data, res)
            private$response_to_chat_history(res)

            # ---- Process response ----
            
            if (private$is_tool_call(res)) {
                private$tool_results_to_chat_history(private$use_tools(res))

                # Recurse to continue conversation, suppressing output_schema during tool execution
                # (will apply structured output after tools are done)
                return(
                    self$chat(
                        model = model,
                        system = system,
                        max_tokens = max_tokens,
                        temperature = temperature,
                        top_p = top_p,
                        top_k = top_k,
                        stop_sequences = stop_sequences,
                        tools = tools,
                        tool_choice = tool_choice,
                        output_schema = output_schema,
                        thinking_budget = thinking_budget,
                        include_thoughts = include_thoughts
                    )
                )
            }

            # ---- Final response ----

            # Handle structured output
            if (is.list(output_schema)) {

                # If tools were present, we need a separate formatting call
                # (Google doesn't support using both tools and responseSchema simultaneously)
                if (!is.null(tools)) {

                    format_instance <- Google$new(
                        api_key = private$api_key,
                        base_url = self$base_url,
                        rate_limit = self$rate_limit,
                        auto_save_history = FALSE
                    )
                    format_instance$set_history(self$get_history())

                    # Make final call with native structured output (no tools)
                    return(
                        self$chat(
                            "Please format your previous response according to the requested schema.",
                            model = model,
                            system = system,
                            max_tokens = max_tokens,
                            temperature = 0,
                            tools = NULL,
                            output_schema = output_schema,
                            thinking_budget = thinking_budget
                        )
                    )
                }

                # No tools were present, native structured output was already applied
                text_output <- self$get_content_text(res)
                return(jsonlite::fromJSON(text_output, simplifyDataFrame = FALSE))
            }

            # No output schema: return the response text
            return(self$get_content_text(res))
        }
    ),
    private = list(
        api_key = NULL,

        # ------🔺 EXTRACTION --------------------------------------------------

        is_root = function(input) {
            return(is.list(input) && !is.null(input$role) && !is.null(input$parts))
        },

        extract_root = function(input) {
            if (!is.null(purrr::pluck(input, "candidates"))) {
                # For API response && session_history -> <"response" turn> -> data
                root <- purrr::pluck(input, "candidates", 1, "content") |> purrr::compact()
            } else if (!is.null(purrr::pluck(input, "contents"))) {
                # For session_history -> <"query" turn> -> data (in provider$format_session_entry())
                root <- purrr::pluck(input, "contents") |> purrr::compact()
            } else {
                cli::cli_abort("[{self$provider_name}] Cannot extract root, from list({.field {input}}).")
            }

            if (purrr::is_empty(root)) {
                return(NULL)
            }
            return(root)
        },

        extract_role = function(root) {
            return(purrr::pluck(root, "role", .default = "unknown"))
        },

        extract_content = function(root) {
            role <- private$extract_role(root)

            if (role %in% c("model", "user")) {
                answers <- purrr::pluck(root, "parts") |> 
                    purrr::keep(\(part) !is.null(purrr::pluck(part, "text")) && is.null(purrr::pluck(part, "thought")))
                
                if (purrr::is_empty(answers)) {
                    return(NULL)
                }
                return(answers)
            }
            return(NULL)
        },

        extract_content_text = function(root) {
            answer_text <- private$extract_content(root) |> 
                purrr::map_chr("text")
            if (is.null(answer_text) || purrr::is_empty(answer_text)) {
                return(NULL)
            }
            if (length(answer_text) == 1) {
                return(first(answer_text))
            }
            return(paste0(answer_text, collapse = "\n"))
        },

        # For Google, the system instructions are out of the 'root'
        extract_system_instructions = function(entry_data) {
            system_instructions <- purrr::pluck(entry_data, "systemInstruction", "parts") |> 
                purrr::map_chr("text")
            if (purrr::is_empty(system_instructions)) {
                return(NULL)
            }
            return(paste0(system_instructions, collapse = "\n"))
        },

        extract_reasoning = function(root) {
            role <- private$extract_role(root)

            if (role %in% c("model")) {
                reasoning <- purrr::pluck(root, "parts") |>
                    purrr::keep(\(part) isTRUE(purrr::pluck(part, "thought")))
                if (purrr::is_empty(reasoning)) {
                    return(NULL)
                }
                return(reasoning)
            }
            return(NULL)
        },

        extract_reasoning_text = function(root) {
            reasoning_text <- private$extract_reasoning(root) |> 
                purrr::map_chr("text")
            if (is.null(reasoning_text) || purrr::is_empty(reasoning_text)) {
                return(NULL)
            }
            if (length(reasoning_text) == 1) {
                return(first(reasoning_text))
            }
            return(paste0(reasoning_text, collapse = "\n"))
        },

        extract_tool_calls = function(root) {
            role <- private$extract_role(root)

            if (role %in% c("model")) {
                tool_calls <- purrr::pluck(root, "parts") |>
                    purrr::keep(\(part) !is.null(part$functionCall)) |>
                    purrr::map("functionCall") # Note: thoughtSignature preserved in chat_history
                
                if (purrr::is_empty(tool_calls)) {
                    return(NULL)
                }
                return(tool_calls)
            }
            return(NULL)
        },

        extract_tool_call_name = function(tool_call) {
            purrr::pluck(tool_call, "name")
        },

        extract_tool_call_args = function(tool_call) {
            args <- purrr::pluck(tool_call, "args")
            if (is.null(args) || purrr::is_empty(args)) {
                return(NULL)
            }
            purrr::possibly(jsonlite::fromJSON, otherwise = args)(args, simplifyDataFrame = FALSE)
        },

        extract_tool_results = function(root) {
            role <- private$extract_role(root)

            if (role %in% c("function")) {
                tool_results <- purrr::pluck(root, "parts") |> 
                    purrr::keep(\(part) !is.null(part$functionResponse)) |> 
                    purrr::map("functionResponse")
                if (purrr::is_empty(tool_results)) {
                    return(NULL)
                }
                return(tool_results)
            }
            return(NULL)
        },

        extract_tool_result_content = function(tool_result) {
            content <- purrr::pluck(tool_result, "response", "content")

            if (purrr::is_empty(content)) {
                return(NULL)
            }
            purrr::possibly(jsonlite::fromJSON, otherwise = content)(content)
        },

        extract_tool_result_name = function(tool_result) {
            return(purrr::pluck(tool_result, "name"))
        },

        extract_generated_code = function(root) {
            code_parts <- purrr::pluck(root, "parts") |>
                purrr::keep(\(part) !is.null(purrr::pluck(part, "executableCode", "code")))

            if (purrr::is_empty(code_parts)) {
                return(NULL)
            }

            # Normalize to provider-agnostic format
            purrr::map(code_parts, \(part) {
                lang <- tolower(part$executableCode$language %||% "plain")
                code <- purrr::pluck(part, "executableCode", "code")
                if (purrr::is_empty(code)) {
                    return(NULL)
                }
                return(list(language = lang, code = code))
            }) |> purrr::compact()
        },

        extract_generated_files = function(root) {
            file_parts <- purrr::pluck(root, "parts") |> 
                purrr::keep(\(part) !is.null(part$inlineData))

            if (is.null(file_parts) || purrr::is_empty(file_parts)) {
                return(NULL)
            }

            # Return list of files with mime_type and decoded data
            purrr::map(file_parts, \(part) {
                list(
                    mime_type = part$inlineData$mimeType,
                    data = jsonlite::base64_dec(part$inlineData$data)
                )
            })
        },

        download_generated_files = function(files, dest_path = "data", overwrite = TRUE) {
            is_file_path <- is_file(dest_path)
            if (length(files) > 1 && is_file_path) {
                cli::cli_abort(
                    "[{self$provider_name}] Multiple files to download, but 'dest_path' is a file path, not a dir."
                )
            }

            saved_paths <- purrr::map_chr(files, \(file) {
                ext <- find_ext_from_mime_type(file$mime_type)
                uuid <- uuid::UUIDgenerate()
                filename <- paste0("generated_file_", uuid, ".", ext)
                final_path <- resolve_download_path(dest_path, filename)

                if (is_file(final_path) && !overwrite) {
                    cli::cli_abort(c(
                        "[{self$provider_name}] File already exists: {.path {final_path}}.",
                        "i" = "Use {.code overwrite = TRUE} to replace it."
                    ))
                }

                tryCatch({
                    writeBin(file$data, final_path)
                    cli::cli_alert_success("File saved: {.path {final_path}}")
                    return(final_path)
                }, error = function(e) {
                    cli::cli_alert_danger("Failed to save file: {.path {final_path}}. Error: {e$message}")
                    return(NA_character_)
                })
            })

            invisible(stats::na.omit(saved_paths))
        },

        extract_total_token_count = function(api_resp) {
            purrr::pluck(api_resp, "usageMetadata", "totalTokenCount", .default = 0)
        },

        extract_input_token_count = function(api_resp) {
            prompt_tokens <- purrr::pluck(api_resp, "usageMetadata", "promptTokenCount", .default = 0)
            tool_use_prompt_tokens <- purrr::pluck(api_resp, "usageMetadata", "toolUsePromptTokenCount", .default = 0)
            return(prompt_tokens + tool_use_prompt_tokens)
        },

        extract_output_token_count = function(api_resp) {
            candidates <- purrr::pluck(api_resp, "usageMetadata", "candidatesTokenCount", .default = 0)
            thoughts <- purrr::pluck(api_resp, "usageMetadata", "thoughtsTokenCount", .default = 0)
            return(candidates + thoughts)
        },

        extract_tool_definitions = function(entry_data) {
            tool_list <- purrr::pluck(entry_data, "tools")
            if (purrr::is_empty(tool_list)) {
                return(NULL)
            }

            if (!is.null(tool_list$function_declarations)) {
                tool_list <- tool_list$function_declarations
            }

            normalized_tools <- purrr::imap(tool_list, \(tool, tool_name) {
                if (is_client_tool(tool)) {
                    return(list(
                        name = tool$name %||% "unknown",
                        description = tool$description,
                        type = "client",
                        parameters = names(purrr::pluck(tool, "parameters", "properties"))
                    ))
                } else if (is_server_tool(tool_name, self$server_tools)) {
                    return(list(
                        name = tool_name,
                        description = NULL,
                        type = "server",
                        parameters = character(0)
                    ))
                } else {
                    cli::cli_alert_danger("[{self$provider_name}] Invalid tool: {.field {tool}}")
                    return(NULL)
                }
            })

            if (purrr::is_empty(normalized_tools)) {
                return(NULL)
            }
            return(normalized_tools)
        },

        extract_output_schema = function(entry_data) {
            return(purrr::pluck(entry_data, "generationConfig", "responseSchema"))
        },

        extract_grounding_metadata = function(api_res) {
            metadata <- purrr::pluck(api_res, "candidates", 1, "groundingMetadata")
            if (purrr::is_empty(metadata)) {
                return(NULL)
            }

            grounding_metadata <- purrr::keep_at(
                metadata,
                c("searchEntryPoint", "groundingChunks", "groundingSupports", "webSearchQueries",
                  "googleMapsWidgetContextToken")
            )

            return(grounding_metadata)
        },

        extract_supplementary = function(api_res) {
            grounding_metadata <- private$extract_grounding_metadata(api_res)
            return(list3(grounding_metadata = grounding_metadata))
        },

        # ------🔺 HISTORY -----------------------------------------------------

        trim_response_for_chat_history = function(res) {
            root <- private$extract_root(res)
            
            if (!purrr::is_empty(root)) {
                # Remove executableCode, codeExecutionResult, or inlineData elements (from code execution tool)
                trimmed_parts <- keep(
                    root$parts, 
                    \(part) is.null(part$executableCode) && is.null(part$codeExecutionResult) && is.null(part$inlineData)
                )
                root$parts <- trimmed_parts
                # Note: grounding metadata (google_search, url_context, google_maps) are not part of 'root' -> not kept
                
                return(root)
            }
        },

        tool_results_to_chat_history = function(tool_results) {
            if (!is.null(tool_results) && length(tool_results) > 0) {
                private$append_to_chat_history(list(role = "function", parts = tool_results))
            }
        },

        extract_session_history_query_last_turn = function(input, index) {
            return(last(input))
        },

        # ------🔺 INPUTS ------------------------------------------------------

        text_input = function(input, ...) {
            return(list(text = input))
        },

        image_input = function(input, ...) {
            encoded <- if (is_url(input)) image_url_to_base64(input) else image_to_base64(input)
            return(list(inline_data = list(mime_type = encoded$mime_type, data = encoded$data)))
        },

        pdf_input = function(input, ...) {
            encoded <- if (is_url(input)) pdf_url_to_base64(input) else pdf_to_base64(input)
            return(list(inline_data = list(mime_type = encoded$mime_type, data = encoded$data)))
        },

        file_ref_input = function(input, ...) {
            if (is.character(input) && length(input) == 1) {
                # We're getting the file id (well, 'name' here), but we need the mime type and uri
                input <- self$get_file_metadata(input)
            }
            
            return(list(file_data = list(mime_type = input$mimeType, file_uri = input$uri)))
        },

        # ------🔺 REQUESTS ----------------------------------------------------

        add_auth = function(req) {
            httr2::req_url_query(req, key = private$api_key)
        },

        # ------🔺 TOOLS -------------------------------------------------------

        use_tool = function(tool_call) {
            fn_name <- private$extract_tool_call_name(tool_call)
            args <- private$extract_tool_call_args(tool_call)

            output <- super$use_tool(fn_name, args)

            return(list(
                functionResponse = list(
                    name = fn_name,
                    response = list(name = fn_name, content = as.list(output))
                )
            ))
        },

        # ------🔺 VALIDATION --------------------------------------------------

        # Validate and convert tool_choice to API format
        validate_tool_choice = function(tool_choice) {
            valid_modes <- c("AUTO", "ANY", "NONE", "VALIDATED")

            # Handle character input (mode only)
            if (is.character(tool_choice) && length(tool_choice) == 1) {
                if (!tool_choice %in% valid_modes) {
                    cli::cli_abort(
                        "[{self$provider_name}] Invalid tool_choice mode: {tool_choice}. Valid modes:
                        {paste(valid_modes, collapse = ', ')}"
                    )
                }
                return(list(mode = tool_choice))
            }

            # Handle list input
            if (is.list(tool_choice)) {
                if (is.null(tool_choice$mode)) {
                    cli::cli_abort("[{self$provider_name}] tool_choice list must contain a 'mode' field")
                }

                if (!tool_choice$mode %in% valid_modes) {
                    cli::cli_abort(
                        "[{self$provider_name}] Invalid tool_choice mode: {tool_choice$mode}. Valid modes:
                        {paste(valid_modes, collapse = ', ')}"
                    )
                }

                # Validate allowed_function_names if present
                if (!is.null(tool_choice$allowed_function_names)) {
                    if (!tool_choice$mode %in% c("ANY", "VALIDATED")) {
                        cli::cli_abort(
                            "[{self$provider_name}] allowed_function_names can only be used with mode 'ANY' or
                            'VALIDATED', not '{tool_choice$mode}'"
                        )
                    }

                    if (!is.character(tool_choice$allowed_function_names)) {
                        cli::cli_abort(
                            "[{self$provider_name}] allowed_function_names must be a character vector"
                        )
                    }
                }

                # Convert to API format (camelCase)
                api_config <- list(mode = tool_choice$mode)
                if (!is.null(tool_choice$allowed_function_names)) {
                    api_config$allowedFunctionNames <- as.list(tool_choice$allowed_function_names)
                }

                return(api_config)
            }

            cli::cli_abort("[{self$provider_name}] tool_choice must be either a character string (mode) or a list")
        },

        # ------🔺 HELPERS -----------------------------------------------------

        # Execute paginated list request with error handling
        list = function(endpoint, page_size, page_token = NULL) {
            req <- private$base_request(endpoint) |>
                httr2::req_url_query(pageSize = page_size)

            if (!is.null(page_token)) {
                req <- httr2::req_url_query(req, pageToken = page_token)
            }

            res <- req |>
                httr2::req_perform() |>
                httr2::resp_body_json()

            if ("error" %in% names(res)) {
                cli::cli_alert_danger("[{self$provider_name}] Error in API request:")
                cat(purrr::pluck(res, "error", "message", .default = "Unknown error"), "\n", sep = "")
                return(NULL)
            }

            return(res)
        },

        # Execute DELETE request with error handling
        delete = function(endpoint, force = FALSE) {
            req <- private$base_request(endpoint) |>
                httr2::req_method("DELETE")

            if (force) {
                req <- httr2::req_url_query(req, force = TRUE)
            }

            resp <- req |>
                httr2::req_perform() |>
                httr2::resp_body_json()

            if ("error" %in% names(resp)) {
                cli::cli_alert_danger("[{self$provider_name}] Error in API request:")
                cat(purrr::pluck(resp, "error", "message", .default = "Unknown error"), "\n", sep = "")
                return(NULL)
            }

            invisible(resp)
        },

        # Execute resumable file upload (2-step process)
        resumable_upload = function(init_endpoint, request_body, file_path, file_size, mime_type) {
            # Step 1: Initiate resumable upload
            init_req <- httr2::request(init_endpoint) |>
                httr2::req_url_query(key = private$api_key) |>
                httr2::req_headers(
                    "X-Goog-Upload-Protocol" = "resumable",
                    "X-Goog-Upload-Command" = "start",
                    "X-Goog-Upload-Header-Content-Length" = as.character(file_size),
                    "X-Goog-Upload-Header-Content-Type" = mime_type,
                    "Content-Type" = "application/json"
                ) |>
                httr2::req_body_json(request_body) |>
                httr2::req_error(is_error = \(resp) FALSE)

            init_resp <- httr2::req_perform(init_req)

            if (httr2::resp_is_error(init_resp)) {
                cli::cli_alert_danger("[{self$provider_name}] Failed to initiate upload")
                cli::cli_text("Full trace: {init_resp}")
                return(NULL)
            }

            upload_url <- httr2::resp_header(init_resp, "X-Goog-Upload-URL")

            if (is.null(upload_url)) {
                cli::cli_alert_danger("[{self$provider_name}] No upload URL returned")
                return(NULL)
            }

            # Step 2: Upload file content
            upload_req <- httr2::request(upload_url) |>
                httr2::req_headers(
                    "Content-Length" = as.character(file_size),
                    "X-Goog-Upload-Offset" = "0",
                    "X-Goog-Upload-Command" = "upload, finalize"
                ) |>
                httr2::req_body_file(file_path) |>
                httr2::req_error(is_error = \(resp) FALSE) |>
                httr2::req_timeout(300)

            upload_resp <- httr2::req_perform(upload_req)

            if (httr2::resp_is_error(upload_resp)) {
                status_code <- httr2::resp_status(upload_resp)
                error_body <- tryCatch(
                    httr2::resp_body_json(upload_resp),
                    error = function(e) list(error = list(message = "Unknown error"))
                )
                error_msg <- purrr::pluck(error_body, "error", "message", .default = "Unknown error")

                cli::cli_alert_danger("[{self$provider_name}] Failed to upload file (status {status_code})")
                cli::cli_alert_info("Error: {error_msg}")
                return(NULL)
            }

            result <- httr2::resp_body_json(upload_resp)

            if ("error" %in% names(result)) {
                cli::cli_alert_danger("[{self$provider_name}] Upload error: {result$error$message}")
                return(NULL)
            }

            return(result)
        },

        # Poll for long-running operation completion
        wait_for_operation = function(operation_name, operation_metadata, max_attempts = 30, sleep_duration = 2) {
            cli::cli_alert_info("[{self$provider_name}] Waiting for file processing...")

            attempt <- 0

            while (attempt < max_attempts) {
                operation_status <- self$get_operation(operation_name)

                if (!is.null(operation_status$done) && operation_status$done) {
                    if (!is.null(operation_status$error)) {
                        cli::cli_alert_danger(
                            "[{self$provider_name}] Operation failed: {operation_status$error$message}"
                        )
                        return(NULL)
                    }

                    return(operation_status$response)
                }

                Sys.sleep(sleep_duration)
                attempt <- attempt + 1
            }

            cli::cli_alert_warning("[{self$provider_name}] Operation timed out. Check status with get_operation()")
            invisible(operation_metadata)
        }
    )
)

# ------🔺 SCHEMAS -------------------------------------------------------------

#' Convert generic tool schema to Google format (internal)
#' @param tool_schema List. Generic tool schema from as_tool() function
#' @return List. Tool definition in Google format
#' @keywords internal
#' @noRd
as_tool_google <- function(tool_schema) {
    tool_args <- tool_schema$args_schema %||% tool_schema$parameters %||% tool_schema$input_schema %||% NULL
    list3(
        name = tool_schema$name,
        description = tool_schema$description,
        parameters = tool_args
    )
}

#' Convert schema to Google's native responseSchema format (internal)
#' @param output_schema List. Schema definition with args_schema/parameters/schema field
#' @return List. JSON Schema object for Google's responseSchema parameter
#' @keywords internal
#' @noRd
as_schema_google <- function(output_schema) {
    # Extract the actual JSON Schema from the wrapper
    if (!is.null(output_schema$args_schema)) {
        google_schema <- output_schema$args_schema
    } else if (!is.null(output_schema$parameters)) {
        google_schema <- output_schema$parameters
    } else if (!is.null(output_schema$schema)) {
        google_schema <- output_schema$schema
    } else {
        cli::cli_abort(
            "[{self$provider_name}] output_schema needs one of {.field {c('args_schema', 'parameters', 'schema')}}"
        )
    }
    google_schema$additionalProperties <- NULL # Google doesn't support this
    return(google_schema)
}
