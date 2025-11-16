#' Client for OpenAI's Responses API
#'
#' @description
#' R6 class for interacting with OpenAI's Responses API (v1/responses).
#' Inherits file management and vector store methods from OpenAI_Base.
#' 
#' @section Features:
#' - Client-side conversation state management
#' - Server-side conversation state management via previous_response_id & response forking
#' - Client-side tools
#' - Server-side tools
#' - Multimodal inputs (files, images, PDFs, R objects)
#' - File uploads and management
#' - Server-side RAG with stores & `file_search` server tool
#' - Reasoning
#' - Structured outputs
#'
#' @section Useful links:
#' - API reference: https://platform.openai.com/docs/api-reference/responses/create
#' - API docs: https://platform.openai.com/docs/quickstart
#'
#' @section Main entrypoints:
#' - `chat()`: Multi-turn multimodal conversations with tool use and structured outputs.
#' - `embeddings()`: Vector embeddings for text inputs.
#'
#' @section Server-side tools:
#' - "web_search" for web search grounding via OpenAI's web plugin
#' - "file_search" for file search with vector stores
#' - "code_interpreter" for Python code execution in sandboxed containers
#'
#' @section Structured outputs:
#' Fully native structured outputs via JSON schema. No additional API calls required.
#'
#' @field provider_name Character. Provider name (OpenAI Responses)
#' @field server_tools Character vector. Server-side tools to use for API requests
#'
#' @export
#' @examples
#' \dontrun{
#' # Initialize
#' responses <- OpenAI_Responses$new()
#'
#' # Simple response
#' res <- responses$chat(
#'   prompt = "What is R programming?",
#'   model = "gpt-5-mini"
#' )
#'
#' # Continue conversation
#' res2 <- responses$chat(
#'   prompt = "Tell me more",
#'   previous_response_id = res$id
#' )
#'
#' # With web search
#' res <- responses$chat(
#'   prompt = "What are the latest AI developments?",
#'   tools = list(list(type = "web_search"))
#' )
#'
#' # With file search and vector stores
#' file_id <- responses$upload_file("document.pdf", purpose = "assistants")
#' store <- responses$create_store("docs", file_ids = list(file_id))
#' res <- responses$chat(
#'   prompt = "Summarize the document",
#'   tools = list(list(type = "file_search", store_ids = list(store$id)))
#' )
#' }
OpenAI_Responses <- R6::R6Class( # nolint
    classname = "OpenAI_Responses",
    inherit = OpenAI,
    public = list(
        provider_name = "OpenAI Responses",
        server_tools = c("web_search", "file_search", "code_interpreter"),

        # ------🔺 INIT --------------------------------------------------------
        
        #' @description
        #' Initialize a new OpenAI Responses client
        #' @param api_key Character. API key (default: from OPENAI_API_KEY env var)
        #' @param org Character. Organization ID (default: from OPENAI_ORG env var)
        #' @param base_url Character. Base URL for API (default: "https://api.openai.com")
        #' @param rate_limit Numeric. Rate limit in requests per second (default: 60/60)
        #' @param auto_save_history Logical. Enable/disable automatic history sync (default: TRUE)
        initialize = function(
            api_key = Sys.getenv("OPENAI_API_KEY"),
            org = Sys.getenv("OPENAI_ORG"),
            base_url = "https://api.openai.com",
            rate_limit = 60 / 60,
            auto_save_history = TRUE
        ) {
            super$initialize(api_key, org, base_url, rate_limit, auto_save_history)
        },

        # ------🔺 RESPONSE HELPERS --------------------------------------------

        #' @description
        #' Get the ID from the last response for conversation chaining
        #'
        #' This is a convenience wrapper around get_last_response()$id,
        #' useful for chaining responses via the previous_response_id parameter.
        #' @return Character. The ID of the last response, or NULL if no previous response exists
        #' @examples
        #' \dontrun{
        #' responses <- OpenAI_Responses$new()
        #' res1 <- responses$chat(prompt = "Tell me a joke", model = "gpt-5-mini")
        #' id <- responses$get_last_response_id()
        #' res2 <- responses$chat(
        #'   prompt = "Explain why it's funny",
        #'   previous_response_id = id
        #' )
        #' }
        get_last_response_id = function() {
            last_response <- self$get_last_response()
            if (is.null(last_response)) {
                return(NULL)
            }
            return(last_response$id)
        },

        # ------🔺 CONTAINER MANAGEMENT ----------------------------------------

        #' @description
        #' Create a new container for code execution
        #'
        #' Containers are sandboxed virtual machines where code_interpreter can execute Python code.
        #' Each container costs $0.03 and is active for 1 hour with 20 minute idle timeout.
        #' @param file_ids Character vector. Optional file IDs to initialize container with.
        #' @return List. Container object with id, created_at, status
        #' @examples
        #' \dontrun{
        #' responses <- OpenAI_Responses$new()
        #' container <- responses$create_container()
        #' container <- responses$create_container(file_ids = c("file-123", "file-456"))
        #' }
        create_container = function(file_ids = NULL) {
            query_data <- list()
            if (!is.null(file_ids)) {
                query_data$file_ids <- as.list(file_ids)
            }

            container <- private$request(paste0(self$base_url, "/v1/containers"), query_data)
            cli::cli_alert_success("[{self$provider_name}] Container created: {container$id}")
            invisible(container)
        },

        #' @description
        #' List all containers
        #' @return Data frame. Available containers with id, created_at, status
        #' @examples
        #' \dontrun{
        #' responses <- OpenAI_Responses$new()
        #' containers <- responses$list_containers()
        #' }
        list_containers = function() {
            private$list(paste0(self$base_url, "/v1/containers"))
        },

        #' @description
        #' Get information about a specific container
        #' @param container_id Character. Container ID to retrieve.
        #' @return List. Container metadata
        #' @examples
        #' \dontrun{
        #' responses <- OpenAI_Responses$new()
        #' container <- responses$get_container("container-123")
        #' }
        get_container = function(container_id) {
            private$request(paste0(self$base_url, "/v1/containers/", container_id))
        },

        #' @description
        #' Delete a container
        #' @param container_id Character. Container ID to delete.
        #' @return List. Deletion confirmation
        #' @examples
        #' \dontrun{
        #' responses <- OpenAI_Responses$new()
        #' responses$delete_container("container-123")
        #' }
        delete_container = function(container_id) {
            result <- private$delete(paste0(self$base_url, "/v1/containers/"), container_id)
            cli::cli_alert_success("[{self$provider_name}] Container deleted: {container_id}")
            invisible(result)
        },

        # Container Files ----

        #' @description
        #' List files in a container
        #' @param container_id Character. Container ID to list files from.
        #' @return Data frame. Files in container with paths
        #' @examples
        #' \dontrun{
        #' responses <- OpenAI_Responses$new()
        #' files <- responses$list_container_files("container-123")
        #' }
        list_container_files = function(container_id) {
            private$list(paste0(self$base_url, "/v1/containers/", container_id, "/files"))
        },

        #' @description
        #' Get metadata for a specific file in a container
        #' @param container_id Character. Container ID.
        #' @param file_id Character. Container file ID (e.g., "cfile_abc123xyz").
        #' @return List. File metadata.
        get_container_file_metadata = function(container_id, file_id) {
            private$request(paste0(self$base_url, "/v1/containers/", container_id, "/files/", file_id))
        },


        #' @description
        #' Get file content from container
        #' @param container_id Character. Container ID.
        #' @param file_id Character. Container file ID (e.g., "cfile_abc123xyz").
        #' @return Raw. File content as raw bytes
        #' @examples
        #' \dontrun{
        #' responses <- OpenAI_Responses$new()
        #' annotations <- responses$get_last_annotations()
        #' file_id <- annotations[[1]]$file_id
        #' content <- responses$get_container_file_content("container-123", file_id)
        #' }
        get_container_file_content = function(container_id, file_id) {
            url <- paste0(
                self$base_url,
                "/v1/containers/",
                container_id,
                "/files/",
                file_id,
                "/content"
            )
            private$base_request(url, headers = list()) |>
                httr2::req_perform() |>
                httr2::resp_body_raw()
        },

        #' @description
        #' Download file from container to local filesystem
        #'
        #' Downloads the file content and saves it to the specified path. If dest_path is a directory,
        #' the file is saved with its original filename. If dest_path is a file path, it is used as
        #' the complete destination path.
        #'
        #' @param container_id Character. Container ID.
        #' @param file_id Character. Container file ID (e.g., "cfile_abc123xyz").
        #' @param dest_path Character. Destination path (default: "data"). Can be either a directory
        #'   path or a complete file path. Created if it doesn't exist.
        #' @param filename Character. Optional filename to use when dest_path is a directory. If NULL,
        #'   fetches filename from container file list.
        #' @param overwrite Logical. Whether to overwrite existing files (default: TRUE).
        #' @return Character. Path to downloaded file (invisibly)
        #' @examples
        #' \dontrun{
        #' responses <- OpenAI_Responses$new()
        #' annotations <- responses$get_last_annotations()
        #' file_id <- annotations[[1]]$file_id
        #'
        #' # Download to a directory
        #' path <- responses$download_container_file("container-123", file_id, "downloads")
        #'
        #' # Download with specific filename
        #' path <- responses$download_container_file("container-123", file_id, "downloads/output.png")
        #'
        #' # Pass filename explicitly (from annotations)
        #' path <- responses$download_container_file(
        #'   "container-123",
        #'   file_id,
        #'   "downloads",
        #'   filename = annotations[[1]]$filename
        #' )
        #' }
        download_container_file = function(container_id, file_id, dest_path = "data", overwrite = TRUE) {
            is_file_path <- is_file(dest_path)

            filename <- if (!is_file_path) {
                # dest_path is a directory, so we need to fetch the filename
                file_info <- self$get_container_file_metadata(container_id, file_id)
                if (is.null(file_info)) {
                    cli::cli_abort("[{self$provider_name}] File {file_id} not found in container {container_id}")
                }
                basename(file_info$path)
            } else {
                # dest_path is a file path, resolve_download_path will use it.
                basename(dest_path)
            }

            final_path <- resolve_download_path(dest_path, filename)
            
            content <- self$get_container_file_content(container_id, file_id)

            if (is_file(final_path) && !overwrite) {
                cli::cli_abort(c(
                    "[{self$provider_name}] File already exists: {.path {final_path}}.",
                    "i" = "Use {.code overwrite = TRUE} to replace it."
                ))
            }

            writeBin(content, final_path)
            cli::cli_alert_success("[{self$provider_name}] Downloaded file to: {.path {final_path}}")

            invisible(final_path)
        },

        # ------🔺 CHAT --------------------------------------------------------

        #' @description
        #' Create a response from the Responses API
        #'
        #' See: \url{https://platform.openai.com/docs/api-reference/responses/create}
        #' @param ... One or more inputs for the prompt. Can be text strings, file paths, URLs, R objects,
        #'   or content wrapped with `as_*_content()` functions. R objects (but not plain strings) will
        #'   include their names and structure in the context sent to the model.
        #' @param model Character. Model to use (default: "gpt-5-mini")
        #' @param system Character. System prompt/instructions (default: .default_system_prompt)
        #' @param temperature Numeric. Sampling temperature 0-2 (default: 1)
        #' @param max_tokens Integer. Maximum output tokens to generate (default: 4096)
        #' @param top_p Numeric. Nucleus sampling parameter 0-1 (default: 1). Alternative to temperature.
        #'   We recommend altering this or temperature but not both.
        #' @param top_logprobs Integer. Number of most likely tokens (0-20) to return at each position with
        #'   associated log probabilities (default: NULL)
        #' @param input_truncation Character. Truncation strategy: "auto" or "disabled" (default: "disabled")
        #' @param previous_response_id Character. ID of previous response to chain from for server-side state
        #'   management. When provided, only the new prompt is sent (not full chat history). Cannot be used
        #'   with conversation parameter. (default: NULL)
        #' @param store Logical. Whether to store response server-side for later retrieval (default: TRUE)
        #' @param include Character vector. Additional output data to include in the model response. Supported values:
        #'   - "web_search_call.action.sources" - Include sources of web search tool calls
        #'   - "code_interpreter_call.outputs" - Include Python code execution outputs
        #'   - "computer_call_output.output.image_url" - Include image URLs from computer call output
        #'   - "file_search_call.results" - Include file search tool call results
        #'   - "message.input_image.image_url" - Include input message image URLs
        #'   - "message.output_text.logprobs" - Include logprobs with assistant messages
        #'   - "reasoning.encrypted_content" - Include encrypted reasoning tokens for multi-turn conversations
        #' @param tools List. Tool definitions (server-side or client-side functions). Server-side tools:
        #'   - list(type = "web_search") for web search
        #'   - list(type = "file_search", store_ids = list("vs_123")) for file search with vector stores
        #'   Client-side functions: use created with the `as_tool(fn)` or `tool()` helpers.
        #' @param tool_choice Character or List. Tool choice mode (default: "auto")
        #' @param max_tool_calls Integer. Maximum number of tool calls (default: NULL)
        #' @param parallel_tool_calls Logical. Allow parallel tool calls (default: TRUE)
        #' @param output_schema List. JSON schema for structured output via build_output_schema_openai() (optional)
        #' @param output_verbosity Character. Output verbosity: "low", "medium", or "high" (default: "medium")
        #' @param reasoning_effort Character. Reasoning effort for reasoning models: "minimal", "low", "medium",
        #'   or "high" (optional, only for o1/o3/gpt-5 models)
        #' @param reasoning_summary Character. Reasoning summary mode: "auto", "concise", or "detailed"
        #'   (optional, requires reasoning_effort to be set)
        #' @param return_full_response Logical. Return full API response (default: FALSE)
        #' @return Character (or List if return_full_response = TRUE). OpenAI Responses API's response object.
        chat = function(
            ...,
            model = "gpt-5-mini",
            system = .default_system_prompt,
            temperature = 1,
            max_tokens = 4096,
            top_p = 1,
            top_logprobs = NULL,
            input_truncation = "disabled", # auto, disabled (default)
            previous_response_id = NULL,
            store = TRUE,
            include = NULL,
            tools = NULL,
            tool_choice = "auto",
            max_tool_calls = NULL,
            parallel_tool_calls = TRUE,
            output_schema = NULL, # If NULL, response_format is "text" (default). If a JSON schema is provided, response_format is "json_schema".
            output_verbosity = "medium", # low, medium (default), and high
            reasoning_effort = NULL, # minimal, low, medium, or high
            reasoning_summary = NULL, # auto, concise, or detailed
            return_full_response = FALSE
        ) {

            # ---- Build input ----

            # Capture prompt inputs as quosures
            inputs <- rlang::enquos(...)

            # Dual-mode handling: server-side state vs manual history
            if (!is.null(previous_response_id)) {
                # SERVER-SIDE STATE MODE
                # When chaining from a previous response, the API maintains full conversation state
                # We only send the new user prompt, not the full history

                # Warn user if switching from manual history mode to server-side state mode
                if (length(self$chat_history) > 0) {
                    self$reset_history()
                }

                # Disable auto-save since server maintains conversation state
                if (self$get_auto_save_history()) {
                    cli::cli_alert_warning(
                        "[{self$provider_name}] Disabling auto-save since we rely on server-side state management."
                    )
                    self$set_auto_save_history(FALSE)
                }

                # Only send new user prompt (if provided)
                input_messages <- if (!purrr::is_empty(inputs)) {
                    content <- private$process_multipart_content(inputs)
                    list(list(role = "user", content = content, type = "message"))
                } else {
                    list()
                }

            } else {
                # MANUAL HISTORY MODE (default)
                # Client maintains full conversation state in chat_history

                # Add prompt to chat history
                if (length(inputs) > 0) {
                    content <- private$process_multipart_content(inputs)
                    private$append_to_chat_history(list(role = "user", content = content, type = "message"))
                }

                # Use chat history directly (already in Responses API format)
                input_messages <- self$chat_history
            }

            # ---- Process tools and inject into message ----

            tool_list <- NULL
            tool_choice_final <- NULL

            if (!is.null(tools)) {
                tool_list <- list()

                for (tool in tools) {
                    if (is_client_tool(tool)) {
                        # Convert custom function tools to OpenAI format
                        converted_tool <- as_tool_openai(tool)
                        tool_list <- append(tool_list, list(converted_tool))

                    } else if (is_server_tool(tool, self$server_tools)) {
                        tool_name <- get_server_tool_name(tool)

                        if (tool_name %in% c("code_interpreter")) {
                            # Handle list form with file_ids and/or container config
                            if (is.list(tool)) {
                                container_config <- tool$container %||% list(type = "auto")

                                file_ids <- purrr::pluck(tool, "file_ids")
                                if (!is.null(file_ids)) {
                                    container_config$file_ids <- as.list(file_ids)
                                }

                                tool_list <- append(
                                    tool_list,
                                    list(list(type = "code_interpreter", container = container_config))
                                )
                            } else {
                                # Handle string form
                                tool_list <- append(
                                    tool_list,
                                    list(list(type = "code_interpreter", container = list(type = "auto")))
                                )
                            }
                        } else if (tool_name %in% c("file_search")) {
                            # For file_search, include vector_store_ids directly in the tool definition
                            if (is.list(tool)) {
                                # Build the tool definition with all parameters
                                tool_def <- list3(
                                    type = "file_search",
                                    vector_store_ids = as.list(purrr::pluck(tool, "store_ids")),
                                    max_num_results = purrr::pluck(tool, "max_num_results"),
                                    filters = purrr::pluck(tool, "filters")
                                )
                                
                                tool_list <- append(tool_list, list(tool_def))
                            } else {
                                # For string-form, just add the tool
                                tool_list <- append(tool_list, list(list(type = "file_search")))
                            }
                        } else if (tool_name %in% c("web_search")) {
                            # For list-form server tools, return as-is
                            if (is.list(tool)) {
                                tool_list <- append(tool_list, list(tool))
                            } else {
                                # For string-form, wrap in list with type
                                tool_list <- append(tool_list, list(list(type = tool_name)))
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
                            cli::cli_abort("[{self$provider_name}] Invalid tool: {.field {tool}}.")
                        }
                    }
                }

                # Set tool_choice only if tools are present
                tool_choice_final <- tool_choice
            }

            # ---- Validate parameters ----

            # Check if model supports reasoning
            if (!is.null(reasoning_effort)) {
                is_reasoning_model <- stringr::str_detect(tolower(model), "o1|o3|o4|gpt-5")
                if (!is_reasoning_model) {
                    cli::cli_alert_warning(
                        c(
                            "[{self$provider_name}] {.arg reasoning_effort} is only applicable to reasoning models.",
                            "i" = "Removing {.arg reasoning_effort} parameter."
                        )
                    )
                    reasoning_effort <- NULL
                }
            }

            # Build reasoning config
            reasoning_config <- NULL
            if (!is.null(reasoning_effort)) {
                # Validate reasoning_effort parameter
                if (!reasoning_effort %in% c("minimal", "low", "medium", "high")) {
                    cli::cli_alert_warning(c(
                        "[{self$provider_name}] reasoning_effort must be one of: 'minimal', 'low', 'medium', 'high'.",
                        "i" = "Got: {reasoning_effort}. Defaulting to 'medium'."
                    ))
                    reasoning_effort <- "medium"
                }

                # Validate reasoning_summary parameter if provided
                if (!is.null(reasoning_summary)) {
                    if (!reasoning_summary %in% c("auto", "concise", "detailed")) {
                        cli::cli_alert_warning(c(
                            "[{self$provider_name}] reasoning_summary must be one of: 'auto', 'concise', 'detailed'.",
                            "i" = "Got: {reasoning_summary}. Defaulting to 'auto'."
                        ))
                        reasoning_summary <- "auto"
                    }
                }

                reasoning_config <- list3(effort = reasoning_effort, summary = reasoning_summary)
            }

            # ---- Output format ----

            # Build text configuration
            text_format <- list(type = "text")
            if (!purrr::is_empty(output_schema)) {
                if (is.list(output_schema) && "name" %in% names(output_schema)) {
                    output_schema_openai <- as_schema_openai(output_schema)
                    output_schema_openai$type <- "json_schema"
                    text_format <- output_schema_openai
                } else {
                    cli::cli_abort(c(
                        "[{self$provider_name}] Malformed output schema: {output_schema}.",
                        "i" = "Expected a list with a 'name' field."
                    ))
                }
            }

            text_config <- list(format = text_format, verbosity = output_verbosity)

            # ---- Build API request ----

            query_data <- list3(
                model = model,
                temperature = temperature,
                max_output_tokens = max_tokens,
                top_p = top_p,
                top_logprobs = top_logprobs,
                background = FALSE,
                truncation = input_truncation,
                store = store,
                include = as.list(include),
                previous_response_id = previous_response_id,
                input = input_messages,
                instructions = system,
                tools = tool_list,
                tool_choice = tool_choice_final,
                max_tool_calls = max_tool_calls,
                parallel_tool_calls = parallel_tool_calls,
                reasoning = reasoning_config,
                text = text_config
            )

            # ---- Make API request ----

            res <- private$request(paste0(self$base_url, "/v1/responses"), query_data)

            # ---- Handle response ----

            # Handle API errors
            if (purrr::is_empty(private$extract_root(res))) {
                cli::cli_abort("[{self$provider_name}] API request failed or returned no choices.")
            }

            # Save to session history and add response to chat history
            private$save_to_session_history(query_data, res)
            private$response_to_chat_history(res)

            # ---- Tool calls ----

            if (private$is_tool_call(res)) {

                private$tool_results_to_chat_history(private$use_tools(res))

                # Recursive call to continue conversation
                return(
                    self$chat(
                        model = model,
                        system = system,
                        temperature = temperature,
                        max_tokens = max_tokens,
                        top_p = top_p,
                        top_logprobs = top_logprobs,
                        input_truncation = input_truncation,
                        previous_response_id = previous_response_id,
                        store = store,
                        include = include,
                        tools = tools,
                        tool_choice = tool_choice,
                        max_tool_calls = max_tool_calls,
                        parallel_tool_calls = parallel_tool_calls,
                        output_schema = output_schema,
                        output_verbosity = output_verbosity,
                        reasoning_effort = reasoning_effort,
                        reasoning_summary = reasoning_summary,
                        return_full_response = return_full_response
                    )
                )
            }

            # ---- Final response (i.e. no more tool calls) ----         

            # Return based on preference
            if (!isTRUE(return_full_response)) {
                text_output <- self$get_content_text(res)
                if (!is.null(output_schema) && is.list(output_schema)) {
                    return(jsonlite::fromJSON(text_output, simplifyDataFrame = FALSE))
                } else {
                    return(text_output)
                }
            }
            return(res)
        }
    ),

    private = list(

        # ------🔺 EXTRACTION --------------------------------------------------

        is_root = function(input) {
            is.list(input) && (is.list(input[[1]]) || !is.null(input$role))
        },

        extract_root = function(input) {
            if (!is.null(purrr::pluck(input, "output"))) {
                # For API response && session_history -> <"response" turn> -> data
                root <- purrr::pluck(input, "output") |> purrr::compact()
            } else if (!is.null(purrr::pluck(input, "input"))) {
                # For session_history -> <"query" turn> -> data (in provider$format_session_entry())
                root <- purrr::pluck(input, "input") |> purrr::compact()
            } else {
                cli::cli_abort("[{self$provider_name}] Cannot extract root, from list({.field {input}}).")
            }
            
            if (purrr::is_empty(root)) {
                return(NULL)
            }
            return(root)
        },

        extract_role = function(root) {
            if (!is.null(purrr::pluck(root, "role"))) {
                return(purrr::pluck(root, "role", .default = "unknown"))
            } else {
                # root is an array of output items - extract role from the message item
                message_items <- purrr::keep(
                    root, 
                    \(item) purrr::pluck(item, "type", .default = "<unknown>") == "message"
                )
                if (!purrr::is_empty(message_items)) {
                    return(purrr::pluck(message_items, 1, "role", .default = "unknown"))
                }

                function_call_items <- purrr::keep(
                    root, 
                    \(item) purrr::pluck(item, "type", .default = "<unknown>") == "function_call"
                )
                if (!purrr::is_empty(function_call_items)) {
                    return("assistant")
                }

                function_output_items <- purrr::keep(
                    root, 
                    \(item) purrr::pluck(item, "type", .default = "<unknown>") == "function_call_output"
                )
                if (!purrr::is_empty(function_output_items)) {
                    return("tool")
                }

                cli::cli_alert_warning("Unknown role for root. This should not happen.")
                return("unknown")
            }
        },

        extract_content = function(root) {
            role <- private$extract_role(root)

            if (role %in% c("assistant", "user")) {
                message_item <- purrr::keep(root, \(item) purrr::pluck(item, "type") == "message")
                if (!purrr::is_empty(message_item)) {
                    contents <- purrr::pluck(message_item, 1, "content") |>
                        purrr::keep(\(item) purrr::pluck(item, "type") %in% c("input_text", "output_text"))
                    
                    if (purrr::is_empty(contents)) {
                        return(NULL)
                    }
                    return(contents)
                }
            }
            return(NULL)
        },

        extract_content_text = function(root) {
            contents <- private$extract_content(root)
            if (purrr::is_empty(contents)) return(NULL)

            contents_text <- purrr::map_chr(contents, "text")
            if (purrr::is_empty(contents_text)) return(NULL)

            return(paste0(contents_text, collapse = ""))
        },

        extract_system_instructions = function(entry_data) {
            purrr::pluck(entry_data, "instructions")
        },

        extract_reasoning = function(root) {
            role <- private$extract_role(root)

            if (role %in% c("assistant", "user")) {
                reasoning_items <- purrr::keep(root, \(item) purrr::pluck(item, "type") == "reasoning")
                if (!purrr::is_empty(reasoning_items)) {
                    reasoning <- purrr::pluck(reasoning_items, 1, "summary") |>
                        purrr::keep(\(item) purrr::pluck(item, "type") %in% c("summary_text"))
                    
                    if (purrr::is_empty(reasoning)) {
                        return(NULL)
                    }
                    return(reasoning)
                }
            }
            return(NULL)
        },

        extract_reasoning_text = function(root) {
            reasoning <- private$extract_reasoning(root)
            if (purrr::is_empty(reasoning)) return(NULL)

            reasoning_text <- purrr::map_chr(reasoning, "text")
            if (purrr::is_empty(reasoning_text)) return(NULL)

            return(paste0(reasoning_text, collapse = ""))
        },

        extract_tool_calls = function(root) {
            role <- private$extract_role(root)

            if (role != "assistant") {
                return(NULL)
            }

            tool_calls <- purrr::keep(
                root, 
                \(item) purrr::pluck(item, "type", .default = "<unknown>") == "function_call"
            )
            if (purrr::is_empty(tool_calls)) {
                return(NULL)
            }
            return(tool_calls)
        },

        extract_tool_call_name = function(tool_call) {
            purrr::pluck(tool_call, "name")
        },

        extract_tool_call_args = function(tool_call) {
            args <- purrr::pluck(tool_call, "arguments")
            if (is.null(args) || purrr::is_empty(args)) return(NULL)

            jsonlite::fromJSON(args, simplifyVector = FALSE)
        },

        extract_tool_results = function(root) {
            if (purrr::pluck(root, "type", .default = "<unknown>") == "function_call_output") {
                return(root)
            }

            purrr::keep(root, \(item) !is.null(purrr::pluck(item, "type")) && purrr::pluck(item, "type") == "function_call_output")
        },

        extract_tool_result_content = function(tool_result) {
            content <- purrr::pluck(tool_result, "output")
            if (is.null(content) || purrr::is_empty(content)) return(NULL)

            jsonlite::fromJSON(content, simplifyVector = FALSE)
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
            code_items <- purrr::keep(root, \(item) purrr::pluck(item, "type") == "code_interpreter_call")
            if (purrr::is_empty(code_items)) return(NULL)

            purrr::map(code_items, \(item) {
                list(
                    code = purrr::pluck(item, "code"),
                    language = "python"
                )
            })
        },

        extract_annotations = function(root) {
            text_items <- purrr::keep(root, \(item) purrr::pluck(item, "type") %in% c("text", "message"))

            if (purrr::is_empty(text_items)) {
                return(NULL)
            }

            # Extract all annotations from text items
            all_annotations <- list()
            for (item in text_items) {
                content <- purrr::pluck(item, "content")
                if (!is.null(content)) {
                    for (content_item in content) {
                        annotations <- purrr::pluck(content_item, "annotations")
                        if (!is.null(annotations) && length(annotations) > 0) {
                            all_annotations <- append(all_annotations, annotations)
                        }
                    }
                }
            }

            if (purrr::is_empty(all_annotations)) {
                return(NULL)
            }

            return(all_annotations)
        },

        extract_file_citations = function(root) {
            all_annotations <- private$extract_annotations(root)

            if (purrr::is_empty(all_annotations)) {
                return(NULL)
            }

            file_citations <- purrr::keep(all_annotations, \(x) purrr::pluck(x, "type") == "file_citation")
            if (purrr::is_empty(file_citations)) {
                return(NULL)
            }

            purrr::map(file_citations, \(citation) {
                list(
                    type = "file_citation",
                    index = purrr::pluck(citation, "index"),
                    file_id = purrr::pluck(citation, "file_id"),
                    filename = purrr::pluck(citation, "filename")
                )
            })
        },

        extract_web_sources = function(root) {
            web_search_items <- purrr::keep(root, \(item) purrr::pluck(item, "type") == "web_search_call")

            if (purrr::is_empty(web_search_items)) {
                return(NULL)
            }

            purrr::map(web_search_items, \(item) {
                list3(
                    type = purrr::pluck(item, "action", "type"),
                    query = purrr::pluck(item, "action", "query"),
                    status = purrr::pluck(item, "status")
                )
            })
        },

        extract_supplementary = function(api_res) {
            root <- private$extract_root(api_res)

            if (purrr::is_empty(root)) {
                return(NULL)
            }

            annotations <- private$extract_annotations(root)
            file_citations <- private$extract_file_citations(root)
            web_sources <- private$extract_web_sources(root)

            return(list3(
                annotations = annotations, 
                file_citations = file_citations,
                web_sources = web_sources
            ))
        },

        extract_generated_files = function(root) {
            all_annotations <- private$extract_annotations(root)

            if (purrr::is_empty(all_annotations)) {
                return(NULL)
            }

            file_annotations <- purrr::keep(all_annotations, \(x) purrr::pluck(x, "type") == "container_file_citation")
            if (purrr::is_empty(file_annotations)) {
                return(NULL)
            }

            purrr::map(file_annotations, \(annotation) {
                list(
                    container_id = purrr::pluck(annotation, "container_id"),
                    file_id = purrr::pluck(annotation, "file_id"),
                    filename = purrr::pluck(annotation, "filename")
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

            saved_paths <- purrr::map_chr(files, \(file_meta) {
                self$download_container_file(
                    file_meta$container_id,
                    file_meta$file_id,
                    dest_path,
                    overwrite
                )
            })

            invisible(saved_paths)
        },

        extract_input_token_count = function(input) {
            purrr::pluck(input, "usage", "input_tokens", .default = 0)
        },

        extract_output_token_count = function(output) {
            purrr::pluck(output, "usage", "output_tokens", .default = 0)
        },

        extract_total_token_count = function(input) {
            purrr::pluck(input, "usage", "total_tokens", .default = 0)
        },

        extract_tool_definitions = function(entry_data) {
            # entry_data is query_data from session_history
            tools <- purrr::pluck(entry_data, "tools")
            if (is.null(tools) || purrr::is_empty(tools)) return(NULL)

            normalized_tools <- purrr::map(tools, \(tool) {
                # Check client tools first (precedence over server-side tools)
                if (is_client_tool(tool)) {
                    param_props <- purrr::pluck(tool, "parameters", "properties", .default = list())
                    param_names <- names(param_props)

                    return(list(
                        name = purrr::pluck(tool, "name", .default = "unknown"),
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

            if (purrr::is_empty(normalized_tools)) return(NULL)

            return(normalized_tools)
        },

        # ------🔺 HISTORY -----------------------------------------------------

        trim_response_for_chat_history = function(res) {
            root <- private$extract_root(res)
            # Root is an unnamed list of output items
            # We keep everything
            return(root)
        },

        tool_results_to_chat_history = function(tool_results) {
            # tool_results are already formatted as function_call_output items
            if (!is.null(tool_results) && length(tool_results) > 0) {
                for (tool_result in tool_results) {
                    private$append_to_chat_history(tool_result)
                }
            }
        },

        extract_session_history_query_last_turn = function(input, index) {
            if (index < 3) {
                return(input)
            } else {
                previous_query <- private$get_session_history_entry(index - 2)
                previous_query_root <- private$extract_root(purrr::pluck(previous_query, "data"))
                previous_response <- private$get_session_history_entry(index - 1)
                previous_response_root <- private$extract_root(purrr::pluck(previous_response, "data"))

                start_idx <- length(previous_query_root) + length(previous_response_root) + 1
                return(input[seq(start_idx, length(input))])
            }
        },

        # ------🔺 INPUTS ------------------------------------------------------

        text_input = function(input, ...) {
            list(type = "input_text", text = input)
        },

        image_input = function(input, detail = NULL, ...) {
            # OpenAI supports: PNG (.png) - JPEG (.jpeg and .jpg) - WEBP (.webp) - Non-animated GIF (.gif)
            # See: https://platform.openai.com/docs/guides/images-vision?api-mode=responses#image-input-requirements
            supported_formats <- c("png", "jpeg", "jpg", "webp", "gif")
            ext <- tolower(tools::file_ext(input))

            if (!ext %in% supported_formats) {
                cli::cli_abort(c(
                    "[{self$provider_name}] Unsupported image format: {.val {ext}}",
                    "i" = "Supported formats: {.val {supported_formats}}"
                ))
            }

            url <- if (is_url(input)) input else image_to_base64(input)$data_uri

            result <- list(type = "input_image", image_url = url)

            # Add detail parameter if provided (low/high/auto)
            if (!is.null(detail)) {
                result$detail <- detail
            }

            return(result)
        },

        pdf_input = function(input, ...) {
            encoded <- if (is_url(input)) pdf_url_to_base64(input) else pdf_to_base64(input)
            list(type = "input_file", filename = basename(input), file_data = encoded$data_uri)
        },

        file_ref_input = function(input, ...) {
            file_id <- if (is.character(input)) input else purrr::pluck(input, "id")
            list(type = "input_file", file_id = file_id)
        },

        # ------🔺 TOOLS -------------------------------------------------------

        # Execute a single tool call
        use_tool = function(tool_call) {
            fn_name <- private$extract_tool_call_name(tool_call)
            args <- private$extract_tool_call_args(tool_call)

            output <- super$use_tool(fn_name, args)

            # Responses API expects function_call_output items in input for next request
            return(list(
                type = "function_call_output",
                call_id = tool_call$call_id,
                output = jsonlite::toJSON(output, auto_unbox = TRUE)
            ))
        }
    )
)
