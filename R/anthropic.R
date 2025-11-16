#' Client for Anthropic's Claude API
#'
#' @description
#' R6 class for interacting with Anthropic's API. Provides methods for chat completions,
#' model information retrieval, files management, and tool calling capabilities.
#'
#' @section Useful links:
#' - API reference: https://docs.claude.com/en/api/overview
#' - API docs: https://docs.claude.com/en/docs/intro
#'
#' @field default_beta_features Character vector. Default beta features to use for API requests
#'
#' @section Server-side tools:
#' - "code_execution" for bash commands and file operations (pricing: $0.05/session-hour, 5-min min)
#' - "web_search" for web search capabilities. Can also be a list with `search_options`.
#' - "web_fetch" to fetch content from a URL provided in the prompt.
#' 
#' @export
#' @examples
#' \dontrun{
#' # Initialize with API key from environment
#' anthropic <- Anthropic$new()
#' 
#' # Or provide API key explicitly
#' anthropic <- Anthropic$new(api_key = "your-api-key")
#' 
#' # Simple chat completion
#' response <- anthropic$chat(
#'   prompt = "What is R programming?",
#'   model = "claude-sonnet-4-5-20250929"
#' )
#' 
#' # With prompt caching
#' response <- anthropic$chat(
#'   prompt = "Analyze this data",
#'   cache_prompt = TRUE,
#'   cache_system = TRUE
#' )
#' 
#' # With extended thinking (10k token budget)
#' response <- anthropic$chat(
#'   prompt = "Solve this complex math problem: ...",
#'   thinking_budget = 10000
#' )
#'
#' # With custom thinking budget
#' response <- anthropic$chat(
#'   prompt = "Analyze this complex scenario: ...",
#'   thinking_budget = 16000
#' )
#' }
Anthropic <- R6::R6Class( # nolint
    classname = "Anthropic",
    inherit = Provider,
    public = list(
        default_beta_features = c(
            "prompt-caching-2024-07-31",
            "token-efficient-tools-2025-02-19",
            "files-api-2025-04-14",
            "code-execution-2025-08-25",
            "web-fetch-2025-09-10",
            "structured-outputs-2025-11-13"
            # "context-management-2025-06-27" # Not implemented yet (see https://docs.anthropic.com/en/docs/build-with-anthropic/context-editing)
            # "context-1m-2025-08-07" # Tier 4 and up, extra costs above 200k tokens
        ),

        # ------🔺 INIT --------------------------------------------------------

        #' @description
        #' Initialize a new Anthropic client
        #' @param base_url Character. Base URL for API (default: "https://api.anthropic.com")
        #' @param api_key Character. API key (default: from ANTHROPIC_API_KEY env var)
        #' @param provider_name Character. Provider name (default: "Anthropic")
        #' @param rate_limit Numeric. Rate limit in requests per second (default: 50/60)
        #' @param server_tools Character vector. Server-side tools available (default: c("code_execution",
        #'   "web_search", "web_fetch"))
        #' @param default_model Character. Default model to use for chat requests (default:
        #'   "claude-haiku-4-5-20251001")
        #' @param auto_save_history Logical. Enable/disable automatic history sync (default: TRUE)
        initialize = function(
            base_url = "https://api.anthropic.com",
            api_key = Sys.getenv("ANTHROPIC_API_KEY"),
            provider_name = "Anthropic",
            rate_limit = 50 / 60,
            server_tools = c("code_execution", "web_search", "web_fetch"),
            default_model = "claude-haiku-4-5-20251001",
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
        #' List all available Anthropic models
        #' @return Data frame. Available models with their specifications
        list_models = function() {
            endpoint <- paste0(self$base_url, "/v1/models")
            
            resp <- private$request(endpoint)
            
            if (is.null(resp)) {
                return(NULL)
            }
            
            if (is.null(resp$data) || purrr::is_empty(resp$data)) {
                cli::cli_alert_danger("[{self$provider_name}] Error: Failed to retrieve model list")
                return(NULL)
            }
            
            # Convert list of models to data frame
            models_df <- purrr::map(resp$data, \(model) {
                data.frame(
                    id = model$id %||% NA_character_,
                    display_name = model$display_name %||% NA_character_,
                    created_at = model$created_at %||% NA_character_
                )
            }) |> purrr::list_rbind()
            
            return(models_df)
        },
        
        #' @description
        #' Get information about a specific Anthropic model
        #' @param model_id Character. Model ID (e.g., "claude-sonnet-4-5-20250929")
        #' @return List. Model information
        get_model_info = function(model_id) {
            endpoint <- paste0(self$base_url, "/v1/models/", model_id)

            return(private$request(endpoint))
        },

        # ------🔺 FILES -------------------------------------------------------

        #' @description
        #' Upload a file to Anthropic Files API
        #' @param file_path Character. Path to the file to upload, or URL to a remote file
        #' @param file_name Character. Optional custom name for the uploaded file. If NULL (default),
        #'   uses the basename of file_path.
        #' @return List. File metadata or NULL on error
        upload_file = function(file_path, file_name = NULL) {
            if (is_url(file_path)) {
                file_path <- download_temp_file(file_path)
                on.exit(unlink(file_path))
            }

            if (!is_file(file_path)) {
                cli::cli_abort("[{self$provider_name}] File not found: {.path {file_path}}")
            }

            file_name <- file_name %||% basename(file_path)
            file_size <- file.info(file_path)$size

            if (file_size > 5e8) {
                cli::cli_abort("[{self$provider_name}] File size exceeds 500MB limit")
            }

            endpoint <- paste0(self$base_url, "/v1/files")

            req <- private$base_request(
                endpoint, 
                headers = list(`Content-Type` = "multipart/form-data"),
                beta_features = "files-api-2025-04-14"
            ) |>
                httr2::req_body_multipart(file = curl::form_file(file_path, name = file_name))

            res <- httr2::req_perform(req) |> httr2::resp_body_json()

            if ("error" %in% names(res)) {
                cli::cli_abort("[{self$provider_name}] Failed to upload file: {res$error$message}")
            }

            cli::cli_alert_success("[{self$provider_name}] File uploaded: {res$id}")
            invisible(res)
        },

        #' @description
        #' Get metadata for an uploaded file
        #' @param file_id Character. File ID (e.g., "file-abc123")
        #' @return List. File metadata or NULL on error
        get_file_metadata = function(file_id) {
            endpoint <- paste0(self$base_url, "/v1/files/", file_id)

            req <- private$base_request(endpoint, beta_features = "files-api-2025-04-14")

            res <- httr2::req_perform(req) |> httr2::resp_body_json()

            if ("error" %in% names(res)) {
                cli::cli_abort("[{self$provider_name}] Failed to get file metadata: {res$error$message}")
            }

            return(res)
        },

        #' @description
        #' Download file content. Only files created by Anthropic's Code Execution tool can be downloaded.
        #'
        #' Downloads the file content and saves it to the specified path. If dest_path is a directory,
        #' the file is saved with its original filename. If dest_path is a file path, it is used as
        #' the complete destination path.
        #'
        #' @param file_id Character. File ID (e.g., "file-abc123")
        #' @param dest_path Character. Destination path (default: "data"). Can be either a directory
        #'   path or a complete file path. If NULL, returns content as raw bytes without saving.
        #'   Created if it doesn't exist.
        #' @param overwrite Logical. Whether to overwrite existing files (default: TRUE).
        #' @return Raw vector (if dest_path is NULL) or Character path to downloaded file (invisibly)
        #' @examples
        #' \dontrun{
        #' anthropic <- Anthropic$new()
        #'
        #' # Download to a directory
        #' path <- anthropic$download_file(file_id = "file-abc123", dest_path = "downloads")
        #'
        #' # Download with specific filename
        #' path <- anthropic$download_file(file_id = "file-abc123", dest_path = "downloads/myfile.txt")
        #'
        #' # Get raw bytes without saving
        #' raw_content <- anthropic$download_file(file_id = "file-abc123", dest_path = NULL)
        #' }
        download_file = function(file_id, dest_path = "data", overwrite = TRUE) {
            endpoint <- paste0(self$base_url, "/v1/files/", file_id, "/content")

            req <- private$base_request(endpoint, beta_features = "files-api-2025-04-14")

            res <- httr2::req_perform(req)

            if (httr2::resp_is_error(res)) {
                cli::cli_abort("[{self$provider_name}] Failed to download file")
            }

            content <- httr2::resp_body_raw(res)

            if (is.null(dest_path)) {
                return(content)
            }

            file_metadata <- self$get_file_metadata(file_id)
            final_path <- resolve_download_path(dest_path, file_metadata$filename)

            if (is_file(final_path) && !overwrite) {
                cli::cli_abort(c(
                    "[{self$provider_name}] File already exists: {.path {final_path}}.",
                    "i" = "Use {.code overwrite = TRUE} to replace it."
                ))
            }

            writeBin(content, final_path)
            cli::cli_alert_success("[{self$provider_name}] File downloaded to: {.path {final_path}}")

            invisible(final_path)
        },

        #' @description
        #' List all uploaded files
        #' @param limit Integer. Number of files per page (default: 20, max: 1000)
        #' @param before_id Character. ID for pagination (optional)
        #' @param after_id Character. ID for pagination (optional)
        #' @param as_df Logical. Whether to return files as a data frame (default: TRUE). If FALSE, returns raw list.
        #' @return Data frame (if as_df = TRUE) or list (if as_df = FALSE). Files metadata and pagination info.
        list_files = function(limit = 20, before_id = NULL, after_id = NULL, as_df = TRUE) {
            endpoint <- paste0(self$base_url, "/v1/files")

            req <- private$base_request(endpoint, beta_features = "files-api-2025-04-14") |>
                httr2::req_url_query(limit = limit)

            if (!is.null(before_id)) {
                req <- httr2::req_url_query(req, before_id = before_id)
            }

            if (!is.null(after_id)) {
                req <- httr2::req_url_query(req, after_id = after_id)
            }

            res <- req |>
                httr2::req_perform() |>
                httr2::resp_body_json()

            if ("error" %in% names(res)) {
                cli::cli_alert_danger("[{self$provider_name}] Failed to list files: {res$error$message}")
                return(NULL)
            }

            if (is.null(res$data) || purrr::is_empty(res$data)) {
                cli::cli_alert_info("[{self$provider_name}] No files found")
                if (as_df) {
                    return(data.frame())
                } else {
                    return(list(data = list(), has_more = FALSE))
                }
            }

            if (as_df) {
                return(lol_to_df(res$data))
            } else {
                return(res)
            }
        },

        #' @description
        #' Delete an uploaded file
        #' @param file_id Character. File ID (e.g., "file-abc123")
        #' @return Logical. TRUE if successful, FALSE otherwise
        delete_file = function(file_id) {
            endpoint <- paste0(self$base_url, "/v1/files/", file_id)

            req <- private$base_request(endpoint, beta_features = "files-api-2025-04-14") |>
                httr2::req_method("DELETE")

            res <- httr2::req_perform(req)

            if (httr2::resp_is_error(res)) {
                cli::cli_alert_danger("[{self$provider_name}] Failed to delete file")
                return(FALSE)
            }

            cli::cli_alert_success("[{self$provider_name}] File deleted: {file_id}")
            invisible(TRUE)
        },

        # ------🔺 EMBEDDINGS --------------------------------------------------

        #' @description
        #' Generate embeddings for text input
        #'
        #' Note: Anthropic does not provide a native embeddings API. For embeddings, consider using:
        #' - Voyage AI (recommended by Anthropic)
        #' - OpenAI (text-embedding-3-small, text-embedding-3-large)
        #' - Google (text-embedding-004)
        #' - Other embedding providers available through OpenRouter
        #'
        #' @param ... Arguments (not used, included for method signature consistency)
        #' @return This method always throws an error
        embeddings = function(...) {
            cli::cli_abort(
                "[{self$provider_name}] Anthropic does not provide a native embeddings API."
            )
        },

        # ------🔺 RESPONSE HELPERS --------------------------------------------

        # ------🔺 CHAT --------------------------------------------------------

        #' @description
        #' Send a chat completion request to Anthropic
        #' @param ... One or more inputs for the prompt. Can be text strings, file paths, URLs, R objects,
        #'   or content wrapped with `as_*_content()` functions. R objects (but not plain strings) will
        #'   include their names and structure in the context sent to the model.
        #' @param cache_prompt Logical. Cache the prompt for reuse (default: FALSE)
        #' @param model Character. Model to use (default: "claude-haiku-4-5-20251001")
        #' @param system Character. System instructions (optional)
        #' @param cache_system Logical. Cache system instructions (default: FALSE)
        #' @param max_tokens Integer. Maximum tokens to generate (default: 4096)
        #' @param temperature Numeric. Sampling temperature (default: 1). Range: 0.0-1.0
        #' @param top_p Numeric. Nucleus sampling - use cumulative probability distribution. Range: 0.0-1.0
        #'   (optional). Should be used instead of temperature for advanced use cases
        #' @param top_k Integer. Sample from top K options only. Minimum: 0 (optional). For advanced use cases
        #' @param tools List. Tool definitions (server-side or client-side functions). Server-side tools:
        #'   - "code_execution" for bash commands and file operations (pricing: $0.05/session-hour, 5-min min)
        #'   - list(type = "code_execution", container = container_id) to reuse an existing container
        #'   - "web_search" for web search capabilities. Can also be a list with `search_options`.
        #'   - "web_fetch" to fetch content from a URL provided in the prompt.
        #'   Client-side functions: created with the `as_tool(fn)` or `tool()` helpers.
        #'   Note: Code execution has no internet access, 5GB RAM/disk, 1 CPU.
        #'   Containers expire 30 days after creation.
        #' @param tool_choice List. Tool choice configuration: list(type = "auto"), list(type = "any"),
        #'   list(type = "tool", name = "tool_name"), or NULL for none (default: list(type = "auto"))
        #' @param cache_tools Logical. Cache tool definitions (default: FALSE)
        #' @param output_schema List. JSON schema for structured output (optional)
        #' @param thinking_budget Integer. Thinking budget in tokens: 0 (disabled), or 1024-max_tokens
        #'   (default: 0). Minimum is 1024 tokens.
        #' @param return_full_response Logical. Return full API response (default: FALSE)
        #' @return Character (or List if return_full_response = TRUE). Anthropic API's response object.
        chat = function(
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
        ) {

            # Count how many cache breakpoints are in the chat history already
            n_cache_breakpoints <- sum(
                purrr::map_lgl(
                    self$chat_history, 
                    \(msg) is.list(msg$content[[1]]) && "cache_control" %in% names(msg$content[[1]])
                )
            )

            # ---- Validate parameters ----

            # Validate thinking compatibility
            if (thinking_budget > 0) {
                # Check temperature compatibility
                if (!missing(temperature) && temperature != 1) {
                    cli::cli_alert_warning(c(
                        "[{self$provider_name}] Extended thinking is not compatible with temperature modifications. ",
                        "i" = "Setting temperature to 1."
                    ))
                    temperature <- 1
                }

                # Check tool_choice compatibility
                if (!is.null(tools) && !is.null(tool_choice)) {
                    if (tool_choice$type %in% c("any", "tool")) {
                        cli::cli_alert_warning(
                            c(
                                "[{self$provider_name}] Extended thinking is not compatible with forced tool use. ",
                                "i" = "Only tool_choice = list(type = 'auto') or NULL are supported with thinking. ",
                                "i" = "Setting tool_choice to list(type = 'auto')."
                            )
                        )
                        tool_choice <- list(type = "auto")
                    }
                }

                # Validate thinking_budget minimum
                if (thinking_budget < 1024) {
                    cli::cli_alert_warning(c(
                        "[{self$provider_name}] Extended thinking budget must be at least 1024 tokens. ",
                        "i" = "Setting to 1024."
                    ))
                    thinking_budget <- 1024
                }

                # Validate max_tokens is greater than thinking_budget
                if (max_tokens <= thinking_budget) {
                    new_max_tokens <- thinking_budget + 1024
                    cli::cli_alert_warning(c(
                        "[{self$provider_name}] max_tokens must be greater than thinking_budget. ",
                        "i" = "Setting max_tokens from {max_tokens} to {new_max_tokens}."
                    ))
                    max_tokens <- new_max_tokens
                }
            }

            # ---- Build input ----

            # Capture prompt inputs as quosures
            inputs <- rlang::enquos(...)
            
            prompt_length <- 0
            if (length(inputs) == 1) {
                # Check if single input is a tool_result (from previous tool use)
                first_input <- rlang::eval_tidy(inputs[[1]])
                if (is.list(first_input) &&
                        !is.null(purrr::pluck(first_input, 1, "type")) &&
                        purrr::pluck(first_input, 1, "type") == "tool_result"
                ) {
                    # Prompt is the result of a tool use - use as-is
                    new_message <- list(role = "user", content = first_input)
                    prompt_length <- ifelse(
                        is.null(purrr::pluck(first_input, 1, "content")),
                        0,
                        nchar(purrr::pluck(first_input, 1, "content"))
                    )
                } else {
                    # Process multipart content (handles strings, lists, multimodal inputs)
                    content <- private$process_multipart_content(inputs)
                    new_message <- list(role = "user", content = content)

                    # Estimate prompt length for caching
                    text_parts <- purrr::keep(content, \(x) !is.null(x$type) && x$type == "text")
                    if (length(text_parts) > 0) {
                        prompt_length <- sum(purrr::map_int(text_parts, \(x) nchar(x$text)))
                    }
                }
            } else if (length(inputs) > 0) {
                # Process multipart content (handles strings, lists, multimodal inputs)
                content <- private$process_multipart_content(inputs)
                new_message <- list(role = "user", content = content)

                # Estimate prompt length for caching
                text_parts <- purrr::keep(content, \(x) !is.null(x$type) && x$type == "text")
                if (length(text_parts) > 0) {
                    prompt_length <- sum(purrr::map_int(text_parts, \(x) nchar(x$text)))
                }
            } else {
                # Empty prompt (for tool result continuation)
                new_message <- NULL
            }

            prompt_length <- ifelse(purrr::is_empty(prompt_length), 0, prompt_length)

            if (cache_prompt && prompt_length >= 1024 * 4 && n_cache_breakpoints < 4) {
                new_message$content[[length(new_message$content)]]$cache_control <- list(type = "ephemeral")
                n_cache_breakpoints <- n_cache_breakpoints + 1
            }

            # ---- Process tools and inject into message ----

            tool_list <- list()
            container_id <- NULL

            if (!is.null(tools)) {
                tools_added <- c()

                for (tool in tools) {
                    if (is_client_tool(tool)) {
                        converted_tool <- as_tool_anthropic(tool)
                        tool_list <- append(tool_list, list(converted_tool))

                    } else if (is_server_tool(tool, self$server_tools)) {
                        tool_name <- get_server_tool_name(tool)

                        if (!tool_name %in% tools_added) {
                            if (tool_name %in% c("code_execution", "code_interpreter")) {
                                # Extract params and inject files into message if list form
                                if (is.list(tool)) {
                                    # Inject file uploads into message
                                    if (!is.null(tool$file_ids)) {
                                        for (file_id in tool$file_ids) {
                                            new_message$content <- append(
                                                new_message$content,
                                                list(list(type = "container_upload", file_id = file_id))
                                            )
                                        }
                                    }
                                    # Extract container for API request
                                    if (!is.null(tool$container)) {
                                        container_id <- tool$container
                                    }
                                }

                                tool_list <- append(
                                    tool_list,
                                    list(list(type = "code_execution_20250825", name = "code_execution"))
                                )
                                tools_added <- c(tools_added, "code_execution")
                            } else if (tool_name == "web_search") {
                                if (is.character(tool)) {
                                    tool_list <- append(
                                        tool_list,
                                        list(list(type = "web_search_20250305", name = "web_search"))
                                    )
                                } else {
                                    tool_list <- append(tool_list, list(tool))
                                }
                                tools_added <- c(tools_added, "web_search")
                            } else if (tool_name == "web_fetch") {
                                if (is.character(tool)) {
                                    tool_list <- append(
                                        tool_list,
                                        list(list(type = "web_fetch_20250910", name = "web_fetch"))
                                    )
                                } else {
                                    tool_list <- append(tool_list, list(tool))
                                }
                                tools_added <- c(tools_added, "web_fetch")
                            }
                        }
                    } else {
                        # Invalid tool - extract name if possible and provide helpful error
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

                # Apply cache control to last tool if enabled
                if (
                    cache_tools && length(tool_list) > 0 &&
                        "cache_control" %ni% names(tool_list[[length(tool_list)]]) &&
                        n_cache_breakpoints < 4
                ) {
                    tool_list[[length(tool_list)]]$cache_control <- list(type = "ephemeral")
                    n_cache_breakpoints <- n_cache_breakpoints + 1
                }
            }

            if (!is.null(new_message)) {
                private$append_to_chat_history(new_message)
            }

            # Check if code_execution server tool is present (incompatible with native structured output)
            code_execution_present <- !is.null(tool_list) && 
                purrr::some(tool_list, is_server_tool, names = "code_execution")

            # ---- Build API request ----

            # Build system message if provided
            system_content <- NULL
            if (!is.null(system) && nzchar(system)) {
                system_content <- list(list(type = "text", text = as.character(system)))
                if (cache_system && n_cache_breakpoints < 4) {
                    system_content[[1]]$cache_control <- list(type = "ephemeral")
                    n_cache_breakpoints <- n_cache_breakpoints + 1
                }
            }

            query_output_format <- NULL
            if (is.list(output_schema) && private$supports_native_structured_output(model) && !code_execution_present) {
                query_output_format <- list(type = "json_schema", schema = as_schema_anthropic(output_schema))
            }

            query_data <- list3(
                model = model,
                max_tokens = max_tokens,
                temperature = temperature,
                top_p = top_p,
                top_k = top_k,
                thinking = if (thinking_budget > 0) list(type = "enabled", budget_tokens = thinking_budget) else NULL,
                system = system_content,
                tools = tool_list,
                tool_choice = tool_choice,
                container = if (!is.null(tools) && !is.null(container_id)) container_id else NULL,
                output_format = query_output_format,
                messages = self$chat_history
            )

            # ---- Make API request ----

            endpoint <- paste0(self$base_url, "/v1/messages")

            res <- private$request(endpoint = endpoint, query_data = query_data)

            # ---- Handle response ----

            if (purrr::is_empty(private$extract_root(res))) {
                cli::cli_abort("[{self$provider_name}] Error: API request failed or returned no content")
            }

            # Save to session history and add response to chat history
            private$save_to_session_history(query_data, res)
            private$response_to_chat_history(res)

            # ---- Process response ----

            if (private$is_tool_call(res)) {

                # Final round of forced JSON output: return the tool call as is without executing it
                # See: https://docs.anthropic.com/en/docs/build-with-anthropic/tool-use#json-output
                if (isTRUE(output_schema)) {
                    if (!isTRUE(return_full_response)) {
                        first_tool_call <- private$extract_root(res) |>
                            private$extract_tool_calls() |>
                            purrr::pluck(1)
                        return(private$extract_tool_call_args(first_tool_call))
                    }
                    return(res)
                }

                # Execute tools and add results to history
                private$tool_results_to_chat_history(private$use_tools(res))

                # Recursive call
                return(
                    self$chat(
                        cache_prompt = cache_prompt,
                        model = model,
                        system = system,
                        cache_system = cache_system,
                        max_tokens = max_tokens,
                        temperature = temperature,
                        top_p = top_p,
                        top_k = top_k,
                        tools = tools,
                        tool_choice = list(type = "auto"),
                        cache_tools = cache_tools,
                        output_schema = output_schema,
                        thinking_budget = thinking_budget,
                        return_full_response = return_full_response
                    )
                )
            }

            # ---- Final response ----

            # Handle structured output
            if (is.list(output_schema)) {

                # Use native structured output if model supports it and code_execution is not present
                if (private$supports_native_structured_output(model) && !code_execution_present) {
                    if (!isTRUE(return_full_response)) {
                        text_output <- self$get_content_text(res)
                        return(jsonlite::fromJSON(text_output, simplifyDataFrame = FALSE))
                    }
                    return(res)
                }

                # Fall back to tool call trick for haiku, unknown models, or when code_execution is present
                format_tool <- response_schema_to_tool_anthropic(output_schema)
                format_prompt <- make_format_prompt(format_tool$name)

                # Create a separate instance for JSON formatting
                format_instance <- Anthropic$new(
                    api_key = private$api_key,
                    base_url = self$base_url,
                    rate_limit = self$rate_limit,
                    auto_save_history = FALSE
                )
                format_instance$set_history(self$get_history())

                # Use deterministic sampling for formatting task
                format_result <- format_instance$chat(
                    prompt = format_prompt,
                    cache_prompt = FALSE,
                    model = model,
                    system = system,
                    cache_system = FALSE,
                    max_tokens = max_tokens,
                    temperature = 0,
                    tools = list(format_tool),
                    tool_choice = list(type = "tool", name = format_tool$name),
                    cache_tools = FALSE,
                    thinking_budget = 0,
                    output_schema = TRUE,
                    return_full_response = return_full_response
                )
                rm(format_instance)

                return(format_result)
            }

            # No output schema: return the response content or the full response
            if (!isTRUE(return_full_response)) {
                return(self$get_content_text(res))
            }
            return(res)
        }
    ),
    private = list(
        api_key = NULL,

        # ------🔺 MODEL SUPPORT -----------------------------------------------

        supports_native_structured_output = function(model) {
            model_lower <- tolower(model)
            if (grepl("haiku", model_lower)) return(FALSE)
            if (grepl("sonnet", model_lower) || grepl("opus", model_lower)) return(TRUE)
            return(FALSE)
        },

        # ------🔺 EXTRACTION --------------------------------------------------

        is_root = function(input) {
            is.list(input) && !is.null(input$role) && !is.null(input$content)
        },

        extract_root = function(input) {
            if (!is.null(purrr::pluck(input, "content"))) {
                # For API response: only keep role and content (NOT type - Anthropic rejects it in messages array)
                root <- purrr::keep_at(input, c("role", "content")) |> purrr::compact()
            } else if (!is.null(purrr::pluck(input, "messages"))) {
                # For session_history -> <"query" turn> -> data (in provider$format_session_entry())
                root <- purrr::pluck(input, "messages") |> purrr::compact()
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

            if (role %in% c("user", "assistant", "system")) {
                contents <- purrr::pluck(root, "content") |>
                    purrr::keep(\(content) purrr::pluck(content, "type") == "text")

                if (purrr::is_empty(contents)) {
                    return(NULL)
                }
                return(contents)
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

        extract_system_instructions = function(entry_data) {
            system_content <- purrr::pluck(entry_data, "system")
            if (purrr::is_empty(system_content)) {
                return(NULL)
            }

            # Handle both string and list(type="text", text="...") formats
            if (is.character(system_content)) {
                return(system_content)
            }

            if (is.list(system_content)) {
                text_blocks <- purrr::keep(system_content, \(x) purrr::pluck(x, "type") == "text")
                if (!purrr::is_empty(text_blocks)) {
                    system_text <- purrr::map_chr(text_blocks, "text")
                    return(paste0(system_text, collapse = "\n"))
                }
            }

            return(NULL)
        },

        extract_reasoning = function(root) {
            role <- private$extract_role(root)

            if (role %in% c("assistant")) {
                thinking_contents <- purrr::pluck(root, "content") |>
                    purrr::keep(\(content) purrr::pluck(content, "type") %in% c("thinking", "redacted_thinking"))

                if (purrr::is_empty(thinking_contents)) {
                    return(NULL)
                }
                return(thinking_contents)
            }
            return(NULL)
        },

        extract_reasoning_text = function(root) {
            reasoning_blocks <- private$extract_reasoning(root)
            if (is.null(reasoning_blocks) || purrr::is_empty(reasoning_blocks)) {
                return(NULL)
            }

            reasoning_text <- purrr::map_chr(reasoning_blocks, \(x) {
                c(purrr::pluck(x, "thinking"), purrr::pluck(x, "redacted_thinking"))
            })
            if (is.null(reasoning_text) || purrr::is_empty(reasoning_text)) {
                return(NULL)
            }
            return(paste0(reasoning_text, collapse = "\n"))
        },

        extract_tool_calls = function(root) {
            role <- private$extract_role(root)

            if (role %in% c("assistant")) {
                tool_use_contents <- purrr::pluck(root, "content") |>
                    purrr::keep(\(content) purrr::pluck(content, "type") == "tool_use")

                if (purrr::is_empty(tool_use_contents)) {
                    return(NULL)
                }
                return(tool_use_contents)
            }
            return(NULL)
        },

        extract_tool_call_name = function(tool_call) {
            purrr::pluck(tool_call, "name")
        },

        extract_tool_call_args = function(tool_call) {
            args <- purrr::pluck(tool_call, "input")
            if (is.null(args) || purrr::is_empty(args)) {
                return(NULL)
            }
            # Anthropic already returns object format, not JSON string
            purrr::possibly(jsonlite::fromJSON, otherwise = args)(args)
        },

        extract_tool_results = function(root) {
            role <- private$extract_role(root)

            if (role %in% c("user")) {
                tool_result_contents <- purrr::pluck(root, "content") |>
                    purrr::keep(\(content) purrr::pluck(content, "type") == "tool_result")
                if (purrr::is_empty(tool_result_contents)) {
                    return(NULL)
                }
                return(tool_result_contents)
            }
            return(NULL)
        },

        extract_tool_result_content = function(tool_result) {
            content <- purrr::pluck(tool_result, "content")
            if (is.null(content) || purrr::is_empty(content)) {
                return(NULL)
            }

            # Handle nested structure (content may be string or list with type="text")
            if (is.list(content) && length(content) > 0 && purrr::pluck(content, 1, "type") == "text") {
                content <- purrr::pluck(content, 1, "text")
            }

            purrr::possibly(jsonlite::fromJSON, otherwise = content)(content)
        },

        extract_tool_result_name = function(tool_result) {
            name <- purrr::pluck(tool_result, "name")
            if (purrr::is_empty(name)) {
                content <- private$extract_tool_result_content(tool_result)
                return(purrr::pluck(content, "name", .default = "unknown"))
            }
            return(name)
        },

        extract_generated_code = function(root) {
            code_parts <- purrr::pluck(root, "content") |>
                purrr::keep(\(part) {
                    purrr::pluck(part, "type") == "server_tool_use" &&
                        purrr::pluck(part, "name") %in% c("bash_code_execution", "text_editor_code_execution")
                })

            if (purrr::is_empty(code_parts)) {
                return(NULL)
            }

            # Normalize to provider-agnostic format
            purrr::map(code_parts, \(part) {
                if (purrr::pluck(part, "name") == "bash_code_execution") {
                    command <- purrr::pluck(part, "input", "command")
                    if (purrr::is_empty(command)) {
                        return(NULL)
                    }
                    return(list(language = "bash", code = command))
                } else {
                    contents <- purrr::pluck(part, "input", "file_text")
                    if (purrr::is_empty(contents)) {
                        return(NULL)
                    }
                    return(list(language = "python", code = contents))
                }
            }) |> purrr::compact()
        },

        extract_generated_files = function(root) {
            exec_results <- purrr::pluck(root, "content") |>
                purrr::keep(\(x) purrr::pluck(x, "type") == "bash_code_execution_tool_result")

            if (purrr::is_empty(exec_results)) {
                return(NULL)
            }

            file_ids <- purrr::map(exec_results, \(result) {
                content_blocks <- purrr::pluck(result, "content", "content")
                if (!is.null(content_blocks)) {
                    output_blocks <- purrr::keep(content_blocks, \(x) purrr::pluck(x, "type") == "bash_code_execution_output")
                    purrr::map_chr(output_blocks, "file_id")
                }
            }) |> 
                purrr::compact() |>
                unlist()

            if (purrr::is_empty(file_ids)) {
                return(NULL)
            }

            return(as.list(file_ids))
        },

        download_generated_files = function(files, dest_path = "data", overwrite = TRUE) {
            if (is.null(files)) {
                cli::cli_alert_info("[{self$provider_name}] No files found in the response to download.")
                return(invisible(character(0)))
            }

            is_file_path <- is_file(dest_path)
            if (length(files) > 1 && is_file_path) {
                cli::cli_abort(
                    "[{self$provider_name}] Multiple files to download, but 'dest_path' is a file path, not a dir."
                )
            }

            saved_paths <- purrr::map_chr(files, \(file_id) {
                self$download_file(file_id, dest_path, overwrite)
            })

            invisible(saved_paths)
        },

        extract_total_token_count = function(api_resp) {
            input_tokens <- purrr::pluck(api_resp, "usage", "input_tokens", .default = 0)
            output_tokens <- purrr::pluck(api_resp, "usage", "output_tokens", .default = 0)
            return(input_tokens + output_tokens)
        },

        extract_input_token_count = function(api_resp) {
            purrr::pluck(api_resp, "usage", "input_tokens", .default = 0)
        },

        extract_output_token_count = function(api_resp) {
            purrr::pluck(api_resp, "usage", "output_tokens", .default = 0)
        },

        extract_tool_definitions = function(entry_data) {
            tools <- purrr::pluck(entry_data, "tools")

            if (is.null(tools) || purrr::is_empty(tools)) {
                return(NULL)
            }

            normalized_tools <- purrr::map(tools, \(tool) {
                if (is_client_tool(tool)) {
                    param_props <- purrr::pluck(tool, "input_schema", "properties", .default = list())
                    param_names <- names(param_props)

                    return(list(
                        name = purrr::pluck(tool, "name"),
                        description = purrr::pluck(tool, "description"),
                        type = "client",
                        parameters = param_names
                    ))
                } else if (is_server_tool(tool, self$server_tools)) {
                    tool_name <- get_server_tool_name(tool)
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
            }) |> purrr::compact()

            if (purrr::is_empty(normalized_tools)) {
                return(NULL)
            }

            return(normalized_tools)
        },

        extract_citations = function(root) {
            role <- private$extract_role(root)

            if (role %in% c("assistant")) {
                content_blocks <- purrr::pluck(root, "content")
                if (purrr::is_empty(content_blocks)) {
                    return(NULL)
                }

                # Extract citations from text blocks that have them
                citations <- purrr::map(content_blocks, \(block) {
                    if (purrr::pluck(block, "type") == "text" && !is.null(purrr::pluck(block, "citations"))) {
                        block_contents <- purrr::pluck(block, "citations")
                        block_contents <- purrr::map(block_contents, \(citation) {
                            citation$encrypted_index <- NULL
                            return(citation)
                        })
                        list(
                            text = purrr::pluck(block, "text"),
                            citations = block_contents
                        )
                    }
                }) |> purrr::compact()

                if (purrr::is_empty(citations)) {
                    return(NULL)
                }
                return(citations)
            }
            return(NULL)
        },

        extract_server_tool_calls = function(root) {
            role <- private$extract_role(root)

            if (role %in% c("assistant")) {
                content_blocks <- purrr::pluck(root, "content")
                if (purrr::is_empty(content_blocks)) {
                    return(NULL)
                }

                # Extract server tool use blocks (web_search, web_fetch)
                server_tools <- purrr::map(content_blocks, \(block) {
                    if (purrr::pluck(block, "type") == "server_tool_use") {
                        list(
                            id = purrr::pluck(block, "id"),
                            name = purrr::pluck(block, "name"),
                            input = purrr::pluck(block, "input")
                        )
                    }
                }) |> purrr::compact()

                if (purrr::is_empty(server_tools)) {
                    return(NULL)
                }
                return(server_tools)
            }
            return(NULL)
        },

        extract_server_tool_results = function(root) {
            role <- private$extract_role(root)

            if (role %in% c("assistant")) {
                content_blocks <- purrr::pluck(root, "content")
                if (purrr::is_empty(content_blocks)) {
                    return(NULL)
                }

                # Extract server tool result blocks
                server_results <- purrr::map(content_blocks, \(block) {
                    block_type <- purrr::pluck(block, "type")
                    if (block_type %in% c("web_search_tool_result", "web_fetch_tool_result")) {
                        result <- list(
                            tool_use_id = purrr::pluck(block, "tool_use_id"),
                            type = block_type,
                            content = purrr::pluck(block, "content")
                        )
                        
                        # For web_fetch, simplify the nested structure
                        if (block_type == "web_fetch_tool_result") {
                            result$url <- purrr::pluck(block, "content", "url")
                            result$retrieved_at <- purrr::pluck(block, "content", "retrieved_at")
                        }
                        
                        return(result)
                    }
                }) |> purrr::compact()

                if (purrr::is_empty(server_results)) {
                    return(NULL)
                }
                return(server_results)
            }
            return(NULL)
        },

        extract_supplementary = function(api_res) {
            root <- private$extract_root(api_res)
            if (purrr::is_empty(root)) {
                return(NULL)
            }

            citations <- private$extract_citations(root)
            server_tool_calls <- private$extract_server_tool_calls(root)
            server_tool_results <- private$extract_server_tool_results(root)

            res <- list3(
                citations = citations,
                server_tool_calls = server_tool_calls,
                server_tool_results = server_tool_results
            )
            if (purrr::is_empty(res)) {
                return(NULL)
            }
            return(res)
        },

        # ------🔺 HISTORY -----------------------------------------------------

        trim_response_for_chat_history = function(res) {
            # Anthropic preserves full content including thinking blocks
            return(private$extract_root(res))
        },

        tool_results_to_chat_history = function(tool_results) {
            if (!is.null(tool_results) && length(tool_results) > 0) {
                private$append_to_chat_history(list(role = "user", content = tool_results))
            }
        },

        extract_session_history_query_last_turn = function(input, index) {
            return(last(input))
        },

        # ------🔺 INPUTS ------------------------------------------------------

        text_input = function(input, ...) {
            return(list(type = "text", text = input))
        },

        image_input = function(input, ...) {
            if (is_url(input)) {
                return(list(type = "image", source = list(type = "url", url = input)))
            } else {
                encoded <- image_to_base64(input)
                return(list(
                    type = "image",
                    source = list(type = "base64", media_type = encoded$mime_type, data = encoded$data)
                ))
            }
        },

        pdf_input = function(input, ...) {
            if (is_url(input)) {
                return(list(type = "document", source = list(type = "url", url = input)))
            } else {
                encoded <- pdf_to_base64(input)
                return(list(
                    type = "document",
                    source = list(type = "base64", media_type = encoded$mime_type, data = encoded$data)
                ))
            }
        },

        file_ref_input = function(input, title = NULL, context = NULL, citations = FALSE, ...) {
            file_id <- if (is.character(input)) input else purrr::pluck(input, "id")
            file_block <- list3(type = "document", source = list(type = "file", file_id = file_id))

            file_block$title <- title
            file_block$context <- context
            file_block$citations <- list(enabled = citations)

            return(file_block)
        },

        # ------🔺 REQUESTS ----------------------------------------------------

        # Add Anthropic authentication (x-api-key header)
        add_auth = function(req) {
            httr2::req_headers_redacted(req, `x-api-key` = private$api_key)
        },

        # Override base_request to add Anthropic-specific headers
        base_request = function(
            endpoint,
            headers = list(),
            beta_features = self$default_beta_features
        ) {
            # Merge Anthropic-specific headers with passed headers
            # Passed headers come last so they can override defaults
            anthropic_headers <- list(
                `Content-Type` = "application/json",
                `anthropic-version` = "2023-06-01",
                `anthropic-beta` = paste(beta_features, collapse = ",")
            )
            headers <- purrr::list_modify(anthropic_headers, !!!headers)
            super$base_request(endpoint, headers = headers)
        },

        # Override request to accept beta_features parameter
        request = function(
            endpoint,
            query_data = NULL,
            headers = list(),
            beta_features = self$default_beta_features
        ) {
            anthropic_headers <- list(
                `Content-Type` = "application/json",
                `anthropic-version` = "2023-06-01",
                `anthropic-beta` = paste(beta_features, collapse = ",")
            )
            headers <- purrr::list_modify(anthropic_headers, !!!headers)
            super$request(endpoint, query_data, headers)
        },

        # ------🔺 TOOLS -------------------------------------------------------

        # Execute a single tool call
        use_tool = function(tool_call) {
            fn_name <- private$extract_tool_call_name(tool_call)
            args <- private$extract_tool_call_args(tool_call)

            output <- super$use_tool(fn_name, args)

            res <- list(type = "tool_result", tool_use_id = tool_call$id)
            if (!is.null(output)) {
                # With token-efficient-tools-2025-02-19, content must be a string, not an array
                if (is.list(output) || (is.vector(output) && length(output) > 1)) {
                    # Convert to JSON string if it's a list or vector
                    res$content <- jsonlite::toJSON(output, auto_unbox = TRUE)
                } else {
                    # Single value, ensure it's a scalar
                    res$content <- as.character(output)
                }
            }

            return(res)
        }
    )
)

# ------🔺 SCHEMAS -------------------------------------------------------------

#' Convert generic tool schema to Anthropic format (internal)
#' @param tool_schema List. Generic tool schema from as_tool() function
#' @return List. Tool definition in Anthropic format
#' @keywords internal
#' @noRd
as_tool_anthropic <- function(tool_schema) {
    if (!is.null(tool_schema$input_schema)) {
        return(tool_schema)
    }

    # Anthropic requires a non-empty input_schema even if it has no properties
    list3(
        name = tool_schema$name,
        description = tool_schema$description,
        input_schema = if (is.null(tool_schema$args_schema)) list(type = "object") else tool_schema$args_schema
    )
}

#' Convert schema to native output_format parameter for Anthropic (internal)
#' @param output_schema List. Schema definition with input_schema/args_schema/schema field
#' @return List. JSON Schema object for Anthropic's output_format parameter
#' @keywords internal
#' @noRd
as_schema_anthropic <- function(output_schema) {
    # Extract the actual JSON Schema from the wrapper
    if (!is.null(output_schema$input_schema)) {
        return(output_schema$input_schema)
    } else if (!is.null(output_schema$args_schema)) {
        return(output_schema$args_schema)
    } else if (!is.null(output_schema$schema)) {
        return(output_schema$schema)
    } else {
        cli::cli_abort(
            "[{self$provider_name}] output_schema needs one of {.field {c('input_schema', 'args_schema', 'schema')}}"
        )
    }
}

#' Convert response schema to tool format (internal)
#' @param response_schema List. Response schema definition
#' @return List. Tool definition in Anthropic format
#' @keywords internal
#' @noRd
response_schema_to_tool_anthropic <- function(response_schema) {
    schema_to_use <- if (!is.null(response_schema$input_schema)) {
        response_schema$input_schema
    } else if (!is.null(response_schema$args_schema)) {
        response_schema$args_schema
    } else {
        cli::cli_abort(
            "[{self$provider_name}] Response schema must have either {.field input_schema} or {.field args_schema}"
        )
    }

    tool_def <- list(
        name = "json_formatting_tool",
        description = response_schema$description %||%
            "This tool is used to reformat the response to the user into a well-structured JSON object.",
        input_schema = schema_to_use
    )
    return(tool_def)
}
