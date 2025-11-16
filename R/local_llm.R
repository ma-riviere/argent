#' Local LLM API Client
#'
#' @description
#' R6 class for interacting with local LLM servers (e.g., llama.cpp, Ollama) that implement
#' OpenAI-compatible APIs. Provides methods for chat completions with tool calling support.
#'
#' @export
#' @examples
#' \dontrun{
#' # Connect to local llama.cpp server
#' llm <- LocalLLM$new(base_url = "http://localhost:8080")
#' 
#' # With specific model
#' llm <- LocalLLM$new(
#'   base_url = "http://localhost:8080",
#'   model = "llama-3-8b"
#' )
#' 
#' # Simple chat completion
#' response <- llm$chat(
#'   prompt = "What is R programming?",
#'   temperature = 0.7
#' )
#' 
#' # With additional sampling parameters
#' response <- llm$chat(
#'   prompt = "Explain quantum computing",
#'   temperature = 0.8,
#'   top_p = 0.9,
#'   top_k = 40,
#'   min_p = 0.05,
#'   repeat_penalty = 1.1
#' )
#' }
LocalLLM <- R6::R6Class( # nolint
    classname = "LocalLLM",
    inherit = Provider,
    public = list(

        # ------🔺 INIT --------------------------------------------------------
        
        #' @description
        #' Initialize a new Local LLM client
        #' @param base_url Character. Base URL of the local server (default: "http://localhost:5000")
        #' @param api_key Character. API key (default: "not-needed")
        #' @param provider_name Character. Provider name (default: "LocalLLM")
        #' @param rate_limit Numeric. Rate limit in requests per second (default: 999999)
        #' @param server_tools Character vector. Server-side tools available (default: character(0))
        #' @param default_model Character. Default model name (auto-detected if NULL)
        #' @param auto_save_history Logical. Enable/disable automatic history sync (default: TRUE)
        initialize = function(
            base_url = "http://localhost:5000",
            api_key = "not-needed",
            provider_name = "LocalLLM",
            rate_limit = 999999,
            server_tools = character(0),
            default_model = NULL,
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

            # Auto-detect model if not provided
            if (is.null(self$default_model)) {
                models <- tryCatch(
                    self$list_models(),
                    error = function(e) NULL
                )

                if (!is.null(models) && nrow(models) > 0) {
                    self$default_model <- models$id[1]
                    cli::cli_alert_success("[{self$provider_name}] Auto-detected model: {basename(self$default_model)}")
                } else {
                    cli::cli_alert_warning(
                        "[{self$provider_name}] Could not auto-detect model. Specify with default_model parameter."
                    )
                }
            }
        },
        
        # ------🔺 MODELS ------------------------------------------------------

        #' @description
        #' Get the current model
        #' @return Character. Model name
        get_default_model_id = function() {
            return(self$default_model)
        },

        #' @description
        #' Set the model to use
        #' @param model Character. Model name
        set_default_model_id = function(model) {
            self$default_model <- model
        },

        #' @description
        #' Get the model name (basename)
        #' @return Character. Model basename
        get_model_name = function() {
            return(basename(self$default_model))
        },

        #' @description
        #' List all available models from the local server
        #' @return Data frame. Available models
        list_models = function() {
            private$list(paste0(self$base_url, "/v1/models")) |>
                dplyr::mutate(created = lubridate::as_datetime(created)) |>
                dplyr::arrange(dplyr::desc(created), id)
        },

        # ------🔺 RESPONSE HELPERS --------------------------------------------

        # ------🔺 CHAT --------------------------------------------------------
        
        #' @description
        #' Send a chat completion request to the local LLM
        #' @param ... One or more inputs for the prompt. Can be text strings, file paths, URLs, R objects,
        #'   or content wrapped with `as_*_content()` functions. R objects (but not plain strings) will
        #'   include their names and structure in the context sent to the model.
        #' @param system Character. System instructions (optional)
        #' @param model Character. Model to use (default: current model)
        #' @param temperature Numeric. Sampling temperature (default: 1)
        #' @param max_tokens Integer. Maximum tokens to generate (default: 4096)
        #' @param top_p Numeric. Top-p (nucleus) sampling (default: 0.9, 1.0 = disabled)
        #' @param top_k Integer. Top-k sampling (default: 40, 0 = disabled)
        #' @param min_p Numeric. Min-p sampling (default: 0.1, 0.0 = disabled)
        #' @param repeat_penalty Numeric. Penalize repeat sequence of tokens (default: 1.0, 1.0 = disabled)
        #' @param presence_penalty Numeric. Repeat alpha presence penalty (default: 0.0, 0.0 = disabled)
        #' @param frequency_penalty Numeric. Repeat alpha frequency penalty (default: 0.0, 0.0 = disabled)
        #' @param mirostat Integer. Use Mirostat sampling (default: 0, 0 = disabled, 1 = Mirostat, 
        #'   2 = Mirostat 2.0)
        #' @param mirostat_tau Numeric. Mirostat target entropy, parameter tau (default: 5.0)
        #' @param mirostat_eta Numeric. Mirostat learning rate, parameter eta (default: 0.1)
        #' @param seed Integer. RNG seed (default: -1, use random seed for -1)
        #' @param tools List. Function definitions for tool calling (optional)
        #' @param tool_choice Character or List. Tool choice mode (default: "auto")
        #' @param output_schema List. JSON schema for structured output (optional)
        #' @param return_full_response Logical. Return full API response (default: FALSE)
        #' @return Character (or List if return_full_response = TRUE). Local LLM API's response object.
        chat = function(
            ...,
            system = .default_system_prompt,
            model = NULL,
            temperature = 1,
            max_tokens = 4096,
            top_p = NULL,
            top_k = NULL,
            min_p = NULL,
            repeat_penalty = NULL,
            presence_penalty = NULL,
            frequency_penalty = NULL,
            mirostat = NULL,
            mirostat_tau = NULL,
            mirostat_eta = NULL,
            seed = NULL,
            tools = NULL,
            tool_choice = "auto",
            output_schema = NULL,
            return_full_response = FALSE
        ) {

            # ---- Validate parameters ----

            # Use default_model if model is not specified
            if (is.null(model)) {
                model <- self$default_model
                if (is.null(model)) {
                    cli::cli_abort("[{self$provider_name}] No model specified and no default model available.")
                }
            }

            # ---- Build input ----

            # Add system message if provided and not already in history
            if (!is.null(system) && (length(self$chat_history) == 0 || self$chat_history[[1]]$role != "system")) {
                private$append_to_chat_history(list(role = "system", content = system))
            }

            # Capture prompt inputs as quosures
            inputs <- rlang::enquos(...)
            
            # Add user message
            if (length(inputs) > 0) {
                content <- private$process_multipart_content(inputs)
                private$append_to_chat_history(list(role = "user", content = content))
            }

            # ---- Build API request ----

            # Prepare tools if provided
            converted_tools <- NULL
            if (!is.null(tools)) {
                converted_tools <- lapply(tools, \(tool) {
                    converted <- as_tool_local(tool)
                    list(type = "function", `function` = list(
                        name = converted$name,
                        description = converted$description,
                        parameters = converted$parameters
                    ))
                })
            }

            query_data <- list3(
                model = model,
                messages = self$chat_history,
                temperature = temperature,
                max_tokens = max_tokens,
                top_p = top_p,
                top_k = top_k,
                min_p = min_p,
                repeat_penalty = repeat_penalty,
                presence_penalty = presence_penalty,
                frequency_penalty = frequency_penalty,
                mirostat = mirostat,
                mirostat_tau = mirostat_tau,
                mirostat_eta = mirostat_eta,
                seed = seed,
                tools = converted_tools,
                tool_choice = if (!is.null(tools)) tool_choice else NULL
            )

            # Note: thinking/reasoning is controlled at the server level, not via API parameters.
            # The server automatically includes reasoning_content in responses when configured
            # with --reasoning-format flag (e.g., --reasoning-format qwen or deepseek).

            # ---- Make API request ----

            res <- private$request(paste0(self$base_url, "/v1/chat/completions"), query_data)

            # ---- Handle response ----

            # Handle API errors
            if (purrr::is_empty(private$extract_root(res))) {
                cli::cli_abort("[{self$provider_name}] Error: API request failed or returned no choices")
            }

            # Save to session history and add response to chat history
            private$save_to_session_history(query_data, res)
            private$response_to_chat_history(res)

            # ---- Process response ----

            res_status <- tolower(purrr::pluck(res, "choices", 1, "finish_reason", .default = "stop"))

            # ---- Handle tool calls ----
            if (private$is_tool_call(res)) {

                # Final round of forced JSON output: return the tool call as is without executing it
                if (isTRUE(output_schema)) {
                    if (!isTRUE(return_full_response)) {
                        return(
                            private$extract_root(res) |>
                                private$extract_tool_calls() |>
                                purrr::pluck(1) |>
                                private$extract_tool_call_args()
                        )
                    }
                    return(res)
                }

                # Execute tools and add results to history
                private$tool_results_to_chat_history(private$use_tools(res))

                # Recursive call
                return(
                    self$chat(
                        system = system,
                        model = model,
                        temperature = temperature,
                        max_tokens = max_tokens,
                        top_p = top_p,
                        top_k = top_k,
                        min_p = min_p,
                        repeat_penalty = repeat_penalty,
                        presence_penalty = presence_penalty,
                        frequency_penalty = frequency_penalty,
                        mirostat = mirostat,
                        mirostat_tau = mirostat_tau,
                        mirostat_eta = mirostat_eta,
                        seed = seed,
                        tools = tools,
                        tool_choice = tool_choice,
                        output_schema = output_schema,
                        return_full_response = return_full_response
                    )
                )
            }

            # Handle case where reasoning model puts tool call in reasoning_content
            if (res_status == "stop" && isTRUE(output_schema)) {
                # This happens with tool_choice="required" on some reasoning models
                cli::cli_warn(c(
                    "[{self$provider_name}] Structured output with reasoning models may not work as expected.",
                    "i" = "The model returned finish_reason='stop' instead of 'tool_calls'.",
                    "i" = "Check if reasoning_content contains the tool call output."
                ))
                
                # Return empty result or the response as-is
                if (!isTRUE(return_full_response)) {
                    return(list())
                }
                return(res)
            }

            # ---- Final response ----

            # Truncated response: warn the user but continue (e.g. if an output_schema is given)
            if (res_status == "length") {
                cli::cli_warn(
                    "[{self$provider_name}] The response was truncated because it exceeded the allowed token limit."
                )
            }

            # Handle JSON response format with forced tool call
            if (is.list(output_schema)) {

                format_tool <- response_schema_to_tool_local(output_schema)
                format_prompt <- make_format_prompt(format_tool$name)

                # Create a separate instance for JSON formatting
                format_instance <- LocalLLM$new(
                    base_url = self$base_url,
                    api_key = private$api_key,
                    model = model,
                    auto_save_history = FALSE
                )
                format_instance$set_history(self$get_history())

                # Use deterministic sampling for formatting task
                format_result <- format_instance$chat(
                    prompt = format_prompt,
                    model = model,
                    system = system,
                    max_tokens = max_tokens,
                    temperature = 0,
                    tools = list(format_tool),
                    tool_choice = "auto",
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
        },

        # ------🔺 EMBEDDINGS --------------------------------------------------

        #' @description
        #' Generate embeddings for text input
        #' @param input Character vector. Text(s) to embed
        #' @param model Character. Model to use (default: current model)
        #' @param return_full_response Logical. Return full API response (default: FALSE)
        #' @return Numeric matrix (or List if return_full_response = TRUE). Embeddings with one row per input text
        embeddings = function(
            input,
            model = NULL,
            return_full_response = FALSE
        ) {
            # Use default_model if model is not specified
            if (is.null(model)) {
                model <- self$default_model
                if (is.null(model)) {
                    cli::cli_abort(
                        "[{self$provider_name}] No model specified and no default model available."
                    )
                }
            }

            # Validate input
            if (!is.character(input) || length(input) == 0) {
                cli::cli_abort("[{self$provider_name}] Input must be a non-empty character vector.")
            }

            # Build API request
            query_data <- list(
                input = input,
                model = model
            )

            # Make API request
            res <- private$request(paste0(self$base_url, "/v1/embeddings"), query_data)

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
        }
    ),
    private = list(
        api_key = NULL,

        # ------🔺 EXTRACTION --------------------------------------------------

        is_root = function(input) {
            is.list(input) && 
                !is.null(input$role) && 
                (!is.null(input$content) || !is.null(input$reasoning_content) || !is.null(input$tool_calls))
        },

        extract_root = function(input) {
            if (!is.null(purrr::pluck(input, "choices"))) {
                # For API response && session_history -> <"response" turn> -> data
                root <- purrr::pluck(input, "choices", 1, "message") |> purrr::compact()
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

            if (!role %in% c("assistant", "user", "system")) {
                return(NULL)
            }

            contents <- purrr::keep_at(root, c("role", "content"))
            if (purrr::is_empty(contents)) {
                return(NULL)
            }

            return(contents)
        },

        extract_content_text = function(root) {
            role <- private$extract_role(root)

            if (!role %in% c("assistant", "user", "system")) {
                return(NULL)
            }

            content <- purrr::pluck(root, "content")

            if (purrr::is_empty(content)) {
                return(NULL)
            }

            # Handle list content (multimodal)
            if (is.list(content)) {
                text_content <- purrr::keep(content, \(item) purrr::pluck(item, "type") == "text")
                if (!purrr::is_empty(text_content)) {
                    return(purrr::pluck(text_content, 1, "text"))
                }
                return(NULL)
            }

            # Handle string content
            if (is.character(content) && nzchar(content)) {
                return(content)
            }

            return(NULL)
        },

        extract_system_instructions = function(entry_data) {
            root <- private$extract_root(entry_data)
            system_instructions <- purrr::keep(root, \(msg) purrr::pluck(msg, "role") == "system") |> 
                purrr::map_chr("content")
            if (purrr::is_empty(system_instructions)) {
                return(NULL)
            }
            return(paste0(system_instructions, collapse = "\n"))
        },

        extract_reasoning = function(root) {
            role <- private$extract_role(root)

            if (role != "assistant") {
                return(NULL)
            }

            reasoning_data <- purrr::keep_at(root, "reasoning_content")

            if (purrr::is_empty(reasoning_data)) {
                return(NULL)
            }

            return(reasoning_data)
        },

        extract_reasoning_text = function(root) {
            role <- private$extract_role(root)

            if (role != "assistant") {
                return(NULL)
            }

            reasoning <- purrr::pluck(root, "reasoning_content")

            if (purrr::is_empty(reasoning) || reasoning %in% c("\n", "")) {
                return(NULL)
            }

            # Handle list content (if reasoning_content is structured)
            if (is.list(reasoning)) {
                text_reasoning <- purrr::keep(reasoning, \(item) purrr::pluck(item, "type") == "text")
                if (!purrr::is_empty(text_reasoning)) {
                    return(purrr::pluck(text_reasoning, 1, "text"))
                }
            }

            # Handle string content
            if (is.character(reasoning)) {
                if (length(reasoning) == 1) {
                    return(first(reasoning))
                }
                return(paste0(reasoning, collapse = "\n"))
            }

            return(reasoning)
        },

        extract_tool_calls = function(root) {
            role <- private$extract_role(root)

            if (role != "assistant") {
                return(NULL)
            }

            tool_calls <- purrr::pluck(root, "tool_calls")

            if (is.null(tool_calls) || purrr::is_empty(tool_calls)) {
                return(NULL)
            }

            # Keep only relevant fields
            return(
                purrr::map(tool_calls, \(tool_call) {
                    purrr::keep_at(tool_call, c("id", "type", "function"))
                })
            )
        },

        extract_tool_call_name = function(tool_call) {
            purrr::pluck(tool_call, "function", "name")
        },

        extract_tool_call_args = function(tool_call) {
            args <- purrr::pluck(tool_call, "function", "arguments")

            if (is.null(args) || purrr::is_empty(args)) {
                return(NULL)
            }

            # Try to parse JSON, fallback to raw string
            purrr::possibly(jsonlite::fromJSON, otherwise = args)(args)
        },

        extract_tool_results = function(root) {
            role <- private$extract_role(root)

            if (role != "tool") {
                return(NULL)
            }

            # Wrap root in list to use purrr::keep pattern
            tool_results <- purrr::keep(list(root), \(item) {
                purrr::pluck(item, "role") == "tool"
            })

            if (purrr::is_empty(tool_results)) {
                return(NULL)
            }

            return(tool_results)
        },

        extract_tool_result_content = function(tool_result) {
            content <- purrr::pluck(tool_result, "content")

            if (purrr::is_empty(content)) {
                return(NULL)
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
            # Not supported for local LLM
            return(NULL)
        },

        extract_generated_files = function(root) {
            # Not supported for local LLM
            return(NULL)
        },

        download_generated_files = function(files, dest_path = "data", overwrite = TRUE) {
            # Not applicable for LocalLLM
            cli::cli_alert_info("[{self$provider_name}] File generation not supported by local servers.")
            return(invisible(character(0)))
        },

        extract_total_token_count = function(api_res) {
            purrr::pluck(api_res, "usage", "total_tokens", .default = 0)
        },

        extract_input_token_count = function(api_res) {
            purrr::pluck(api_res, "usage", "prompt_tokens", .default = 0)
        },

        extract_output_token_count = function(api_res) {
            purrr::pluck(api_res, "usage", "completion_tokens", .default = 0)
        },

        extract_tool_definitions = function(entry_data) {
            tools <- purrr::pluck(entry_data, "tools")

            if (is.null(tools) || purrr::is_empty(tools)) {
                return(NULL)
            }

            normalized_tools <- purrr::map(tools, \(tool) {
                # LocalLLM only supports client function tools (no server tools)
                if (purrr::pluck(tool, "type") == "function") {
                    func_def <- purrr::pluck(tool, "function")
                    param_props <- purrr::pluck(func_def, "parameters", "properties", .default = list())
                    param_names <- names(param_props)

                    return(list(
                        name = purrr::pluck(func_def, "name", .default = "unknown"),
                        description = purrr::pluck(func_def, "description"),
                        type = "client",
                        parameters = param_names
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

        extract_supplementary = function(api_res) {
            return(NULL)
        },

        # ------🔺 HISTORY -----------------------------------------------------

        trim_response_for_chat_history = function(res) {
            root <- private$extract_root(res)

            if (!purrr::is_empty(root)) {
                # Remove reasoning_content from the message (must be NULL, not empty string)
                root$reasoning_content <- NULL

                # Ensure content is never null/empty after processing
                if (purrr::is_empty(root$content)) {
                    root$content <- ""
                }
            }
            return(root)
        },

        tool_results_to_chat_history = function(tool_results) {
            if (!is.null(tool_results) && length(tool_results) > 0) {
                # LocalLLM tool results are already formatted: list(role = "tool", tool_call_id, content)
                for (tool_result in tool_results) {
                    private$append_to_chat_history(tool_result)
                }
            }
        },

        extract_session_history_query_last_turn = function(input, index) {
            return(last(input))
        },

        # ------🔺 INPUTS ------------------------------------------------------

        text_input = function(input, ...) {
            list(type = "text", text = input)
        },

        image_input = function(input, ...) {
            encoded <- if (is_url(input)) image_url_to_base64(input) else image_to_base64(input)
            list(type = "image_url", image_url = list(url = encoded$data_uri))
        },

        pdf_input = function(input, ...) {
            encoded <- if (is_url(input)) pdf_url_to_base64(input) else pdf_to_base64(input)
            list(type = "file", file = list(filename = basename(input), file_data = encoded$data_uri))
        },

        file_ref_input = function(input, ...) {
            cli::cli_abort(c("[{self$provider_name}] Remote file references not supported.",
                             "i" = "Local servers have no file storage APIs."))
        },

        # Add LocalLLM authentication (Bearer token)
        add_auth = function(req) {
            httr2::req_headers_redacted(req, Authorization = paste0("Bearer ", private$api_key))
        },

        # ------🔺 REQUESTS ----------------------------------------------------

        list = function(endpoint, as_df = TRUE) {
            res <- private$request(endpoint) |> purrr::pluck("data")

            if (as_df) res <- lol_to_df(res)

            return(res)
        },

        # ------🔺 TOOLS -------------------------------------------------------

        # Execute a single tool call
        use_tool = function(tool_call) {
            fn_name <- private$extract_tool_call_name(tool_call)
            args <- private$extract_tool_call_args(tool_call)

            output <- super$use_tool(fn_name, args)

            return(list(
                role = "tool",
                tool_call_id = tool_call$id,
                content = jsonlite::toJSON(output, auto_unbox = TRUE)
            ))
        }
    )
)

# ------🔺 SCHEMAS -------------------------------------------------------------

#' Convert generic tool schema to local LLM format (internal)
#' @param tool_schema List. Generic tool schema from as_tool() function
#' @return List. Tool definition in local LLM format
#' @keywords internal
#' @noRd
as_tool_local <- function(tool_schema) {
    if (!is.null(tool_schema$parameters) && !is.null(tool_schema$type)) {
        return(tool_schema)
    }

    list3(
        name = tool_schema$name,
        description = tool_schema$description,
        parameters = tool_schema$args_schema
    )
}

#' Convert schema to structured output format for local LLM (internal)
#' @param output_schema List. Schema definition with name, description, and args_schema/schema
#' @return List. Structured output format for local LLM
#' @keywords internal
#' @noRd
as_schema_local <- function(output_schema) {
    as_schema_openai(output_schema)
}

#' Convert response schema to tool format (internal)
#' @param response_schema List. Response schema definition
#' @return List. Tool definition in local LLM format
#' @keywords internal
#' @noRd
response_schema_to_tool_local <- function(response_schema) {
    response_schema_to_tool_openai(response_schema)
}
