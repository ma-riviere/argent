#' Client for OpenAI's Chat Completions API
#'
#' @description
#' R6 class for interacting with OpenAI's Chat Completions API (v1/chat/completions).
#' Inherits file management and vector store methods from OpenAI_Base.
#'
#' @section Features:
#' - Client-side conversation state management
#' - Client-side tools
#' - Server-side tools
#' - Multimodal inputs (files, images, PDFs, R objects)
#' - File uploads and management
#' - Reasoning
#' - Structured outputs
#'
#' @section Useful links:
#' - API reference: https://platform.openai.com/docs/api-reference/chat
#' - API docs: https://platform.openai.com/docs/guides/completions/introduction
#'
#' @section Main entrypoints:
#' - `chat()`: Multi-turn multimodal conversations with tool use and structured outputs.
#' - `embeddings()`: Vector embeddings for text inputs.
#'
#' @section Server-side tools:
#' - "web_search" for web search grounding via OpenAI's web plugin
#'
#' @section Structured outputs:
#' Fully native structured outputs via JSON schema. No additional API calls required.
#'
#' @export
#' @examples
#' \dontrun{
#' # Initialize with API key from environment
#' openai <- OpenAI_Chat$new()
#'
#' # Or provide API key explicitly
#' openai <- OpenAI_Chat$new(api_key = "your-api-key")
#'
#' # Simple chat completion
#' response <- openai$chat(
#'   prompt = "What is R programming?",
#'   model = "gpt-5-chat-latest"
#' )
#'
#' # With tools/function calling
#' response <- openai$chat(
#'   prompt = "What's the weather in Paris?",
#'   tools = list(get_weather_tool)
#' )
#'
#' # Upload file and use in chat
#' file <- openai$upload_file("document.pdf", purpose = "user_data")
#' response <- openai$chat(
#'   prompt = openai$multimodal_input(
#'     "Summarize this document:",
#'     as_file_ref(file$id)
#'   )
#' )
#' }
OpenAI_Chat <- R6::R6Class( # nolint
    classname = "OpenAI_Chat",
    inherit = OpenAI,
    public = list(

        # ------🔺 INIT --------------------------------------------------------

        #' @description
        #' Initialize a new OpenAI Chat client
        #' @param base_url Character. Base URL for API (default: "https://api.openai.com")
        #' @param api_key Character. API key (default: from OPENAI_API_KEY env var)
        #' @param provider_name Character. Provider name (default: "OpenAI Chat")
        #' @param rate_limit Numeric. Rate limit in requests per second (default: 60/60)
        #' @param server_tools Character vector. Server-side tools available (default: c("web_search"))
        #' @param default_model Character. Default model to use for chat requests (default: "gpt-5-mini")
        #' @param org Character. Organization ID (default: from OPENAI_ORG env var)
        #' @param auto_save_history Logical. Enable/disable automatic history sync (default: TRUE)
        initialize = function(
            base_url = "https://api.openai.com",
            api_key = Sys.getenv("OPENAI_API_KEY"),
            provider_name = "OpenAI Chat",
            rate_limit = 60 / 60,
            server_tools = c("web_search"),
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
                org = org,
                auto_save_history = auto_save_history
            )
        },

        # ------🔺 CHAT --------------------------------------------------------

        #' @description
        #' Send a chat completion request to OpenAI
        #' @param ... One or more inputs for the prompt. Can be text strings, file paths, URLs, R objects,
        #'   or content wrapped with `as_*_content()` functions. R objects (but not plain strings) will
        #'   include their names and structure in the context sent to the model.
        #' @param system Character. System instructions (optional)
        #' @param model Character. Model to use (default: "gpt-5-mini")
        #' @param temperature Numeric. Sampling temperature (default: 1)
        #' @param max_completion_tokens Integer. Maximum tokens to generate (default: 4096)
        #' @param top_p Numeric. Nucleus sampling parameter 0-1 (default: 1). Alternative to temperature.
        #'   We recommend altering this or temperature but not both.
        #' @param frequency_penalty Numeric. Penalty for token frequency -2.0 to 2.0 (default: 0).
        #'   Positive values decrease likelihood of repeating the same line verbatim.
        #' @param presence_penalty Numeric. Penalty for token presence -2.0 to 2.0 (default: 0).
        #'   Positive values increase likelihood of talking about new topics.
        #' @param logprobs Logical. Whether to return log probabilities (default: FALSE)
        #' @param top_logprobs Integer. Number of most likely tokens (0-20) to return at each position (default: NULL).
        #'   Requires logprobs = TRUE.
        #' @param n Integer. Number of chat completion choices to generate (default: 1)
        #' @param logit_bias Named list. Modify likelihood of specified tokens by token ID (default: NULL).
        #'   Values from -100 to 100.
        #' @param tools List. Client-side function definitions for tool calling (optional). For web search with
        #'   search-enabled models (gpt-4o-mini-search-preview, gpt-4o-search-preview, gpt-5-search-api),
        #'   pass as: `list("web_search")` or with options:
        #'   `list(list(type = "web_search", user_location = list(...), search_context_size = "medium"))`.
        #'   Supported web_search options:
        #'   - `user_location`: list with `type = "approximate"` and `approximate` containing `country` (ISO 3166-1),
        #'     `city`, `region`, and/or `timezone` (IANA)
        #'   - `search_context_size`: "low", "medium" (default), or "high"
        #'
        #'   **Note**: Search models do not support standard sampling parameters (temperature, top_p,
        #'   frequency_penalty, presence_penalty, n). These are automatically omitted when using search models.
        #' @param tool_choice Character or List. Tool choice mode (default: "auto")
        #' @param output_schema List. JSON schema for structured output (optional)
        #' @param reasoning_effort Character. Reasoning effort level for reasoning models: "low", "medium", or "high"
        #'   (optional). Only applicable to reasoning models (o1, o3, o4, gpt-5). Default: NULL (uses model default)
        #' @param verbosity Character. Verbosity level for output: "low", "medium", or "high" (default: "medium")
        #' @param store Logical. Whether or not to store the output of this chat completion request in OpenAI servers (default: FALSE)
        #' @return Character. OpenAI Chat API's response object.
        chat = function(
            ...,
            system = .default_system_prompt,
            model = self$default_model,
            temperature = 1,
            max_completion_tokens = 4096,
            top_p = 1,
            frequency_penalty = 0,
            presence_penalty = 0,
            logprobs = FALSE,
            top_logprobs = NULL,
            n = 1,
            logit_bias = NULL,
            tools = NULL,
            tool_choice = "auto",
            output_schema = NULL,
            reasoning_effort = NULL,
            verbosity = "medium",
            store = FALSE
        ) {

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

            # ---- Prepare tools ----

            # Extract web_search options from tools if present
            # Note: We keep web_search in the tools list for persistence across recursive calls
            web_search_options <- NULL
            if (!is.null(tools)) {
                for (tool in tools) {
                    if (is_server_tool(tool, self$server_tools)) {
                        if (is.list(tool)) {
                            # Extract options (everything except 'type')
                            web_search_options <- purrr::discard_at(tool, "type")
                        } else {
                            # String form: "web_search"
                            web_search_options <- named_list()
                        }
                        break  # Only process first web_search found
                    }
                }
            }

            # ---- Validate parameters ----

            # Validate reasoning_effort parameter
            if (!is.null(reasoning_effort)) {
                if (!reasoning_effort %in% c("low", "medium", "high")) {
                    cli::cli_abort(
                        "[{self$provider_name}] {.arg reasoning_effort} must be one of: 'low', 'medium', 'high'."
                    )
                }

                # Check if model supports reasoning
                is_reasoning_model <- stringr::str_detect(tolower(model), "o1|o3|o4|gpt-5")
                if (!is_reasoning_model) {
                    cli::cli_alert_warning(c(
                        "[{self$provider_name}] {.arg reasoning_effort} is only applicable to reasoning models.",
                        "i" = "Model '{model}' may not support this parameter. Proceeding anyway."
                    ))
                }
            }

            # ---- Build API request ----

            # Check if this is a search model
            is_search_model <- stringr::str_detect(
                tolower(model),
                "search-(preview|api)|gpt-4o-mini-search|gpt-4o-search|gpt-5-search"
            )

            # Search models don't support standard sampling parameters
            query_data <- list3(
                model = model,
                messages = self$chat_history,
                verbosity = verbosity,
                store = store
            )

            # Only add sampling parameters for non-search models
            if (!is_search_model) {
                query_data$temperature <- temperature
                query_data$max_completion_tokens <- max_completion_tokens
                query_data$top_p <- top_p
                query_data$frequency_penalty <- frequency_penalty
                query_data$presence_penalty <- presence_penalty
                query_data$n <- n
            } else {
                # Search models use max_completion_tokens
                query_data$max_completion_tokens <- max_completion_tokens
            }

            # Add optional logprobs parameters
            if (isTRUE(logprobs)) {
                query_data$logprobs <- TRUE
                if (!is.null(top_logprobs)) {
                    query_data$top_logprobs <- top_logprobs
                }
            }

            # Add optional logit_bias
            if (!is.null(logit_bias)) {
                query_data$logit_bias <- logit_bias
            }

            # Add web_search_options for search-enabled models
            # Default to empty object {} if NULL for compatibility with search models
            if (!is.null(web_search_options)) {
                # Validate search_context_size if provided
                if (!is.null(web_search_options$search_context_size)) {
                    valid_sizes <- c("low", "medium", "high")
                    if (!web_search_options$search_context_size %in% valid_sizes) {
                        cli::cli_abort(
                            "[{self$provider_name}] {.arg search_context_size} must be one of: {.field {valid_sizes}}."
                        )
                    }
                }
                query_data$web_search_options <- web_search_options
            } else if (is_search_model) {
                # For search models, use empty object if no options provided
                query_data$web_search_options <- named_list()
            }

            private$reset_active_tools()

            if (!is.null(tools)) {
                # Filter out web_search (it's not a function tool, handled separately via web_search_options)
                # Keep client tools and MCP tools
                function_tools <- purrr::discard(tools, \(tool) is_server_tool(tool, self$server_tools))

                if (length(function_tools) > 0) {
                    # Convert tools to OpenAI format if needed
                    converted_tools <- list()
                    for (tool in function_tools) {
                        converted <- as_tool_openai(tool)

                        # Register client/MCP tools in active_tools
                        if (is_mcp_tool(tool)) {
                            # We add the original tool because the converted one no longer has the .mcp metadata
                            private$add_active_tool(type = "mcp", tool = tool)
                        } else if (is_client_tool(tool)) {
                            private$add_active_tool(type = "client", tool = tool)
                        }

                        # Convert returns {type, name, description, parameters}, wrap for API
                        converted_tools <- append(converted_tools, list(list(
                            type = "function",
                            `function` = list(
                                name = converted$name,
                                description = converted$description,
                                parameters = converted$parameters
                            )
                        )))
                    }
                    query_data$tools <- converted_tools
                    query_data$tool_choice <- tool_choice
                }
            }

            if (!is.null(output_schema)) {
                query_data$response_format <- list(
                    type = "json_schema", 
                    json_schema = as_schema_openai(output_schema)
                )
            }

            if (!is.null(reasoning_effort)) {
                query_data$reasoning_effort <- reasoning_effort
            }

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

            res_status <- purrr::pluck(res, "choices", 1, "finish_reason", .default = "stop")

            if (res_status == "length") {
                cli::cli_warn(
                    "[{self$provider_name}] The response was truncated because it exceeded the allowed token limit."
                )
            }

            if (private$is_tool_call(res)) {

                # Execute tools and add results to history
                private$tool_results_to_chat_history(private$use_tools(res))

                # Recursive call
                return(
                    self$chat(
                        system = NULL,
                        model = model,
                        temperature = temperature,
                        max_completion_tokens = max_completion_tokens,
                        top_p = top_p,
                        frequency_penalty = frequency_penalty,
                        presence_penalty = presence_penalty,
                        logprobs = logprobs,
                        top_logprobs = top_logprobs,
                        n = n,
                        logit_bias = logit_bias,
                        tools = tools,
                        tool_choice = tool_choice,
                        output_schema = output_schema,
                        reasoning_effort = reasoning_effort,
                        verbosity = verbosity,
                        store = store
                    )
                )
            }

            # ---- Final response ----

            res_text <- self$get_content_text(res)

            if (!is.null(output_schema) && is.list(output_schema)) {
                # Quick fix for OpenAI-4.1-mini weird JSON duplicated responses
                res_text <- clean_malformed_json(res_text)
                return(jsonlite::fromJSON(res_text, simplifyDataFrame = FALSE))
            } else {
                return(res_text)
            }
        }
    ),

    private = list(

        # ------🔺 EXTRACTION --------------------------------------------------

        is_root = function(input) {
            is.list(input) && !is.null(input$role) && !is.null(input$content)
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
            answer_content <- private$extract_content(root) |>
                purrr::pluck("content")

            if (purrr::is_empty(answer_content)) {
                return(NULL)
            }

            # Handle list content (multimodal)
            if (is.list(answer_content)) {
                text_content <- purrr::keep(answer_content, \(item) purrr::pluck(item, "type") == "text")
                if (!purrr::is_empty(text_content)) {
                    return(purrr::pluck(text_content, 1, "text"))
                }
                return(NULL)
            }

            # Handle string content
            if (is.character(answer_content) && nzchar(answer_content)) {
                return(answer_content)
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
            return(NULL)
        },

        extract_reasoning_text = function(root) {
            return(NULL)
        },

        extract_tool_definitions = function(entry_data) {
            tools <- purrr::pluck(entry_data, "tools")

            if (is.null(tools) || purrr::is_empty(tools)) {
                return(NULL)
            }

            normalized_tools <- purrr::map(tools, \(tool) {
                # Check client tools first (precedence over server-side tools)
                if (purrr::pluck(tool, "type") == "function" && is_client_tool(purrr::pluck(tool, "function"))) {
                    func_def <- purrr::pluck(tool, "function")
                    param_props <- purrr::pluck(func_def, "parameters", "properties", .default = list())
                    param_names <- names(param_props)

                    return(list(
                        name = purrr::pluck(func_def, "name", .default = "unknown"),
                        description = purrr::pluck(func_def, "description"),
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

        extract_output_schema = function(entry_data) {
            return(purrr::pluck(entry_data, "response_format", "json_schema"))
        },

        extract_annotations = function(root) {
            annotations <- purrr::pluck(root, "annotations")

            if (purrr::is_empty(annotations)) {
                return(NULL)
            }

            return(annotations)
        },

        extract_supplementary = function(api_res) {
            root <- private$extract_root(api_res)

            if (purrr::is_empty(root)) {
                return(NULL)
            }

            annotations <- private$extract_annotations(root)

            if (purrr::is_empty(annotations)) {
                return(NULL)
            }

            return(list3(annotations = annotations))
        },

        extract_total_token_count = function(api_resp) {
            purrr::pluck(api_resp, "usage", "total_tokens", .default = 0)
        },

        extract_input_token_count = function(api_resp) {
            purrr::pluck(api_resp, "usage", "prompt_tokens", .default = 0)
        },

        extract_output_token_count = function(api_resp) {
            purrr::pluck(api_resp, "usage", "completion_tokens", .default = 0)
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

            if (is.null(content) || purrr::is_empty(content)) {
                return(NULL)
            }

            # Try to parse JSON, fallback to raw content
            purrr::possibly(jsonlite::fromJSON, otherwise = content)(content)
        },

        extract_tool_result_name = function(tool_result) {
            return(purrr::pluck(tool_result, "name"))
        },

        extract_generated_code = function(root) {
            # Not supported for Chat Completions API
            return(NULL)
        },

        extract_generated_files = function(root) {
            # Not supported for Chat Completions API
            return(NULL)
        },

        download_generated_files = function(files, dest_path = "data", overwrite = TRUE) {
            # Not applicable for Chat Completions API
            cli::cli_alert_info("[{self$provider_name}] File generation not supported by Chat Completions API.")
            return(invisible(character(0)))
        },

        # ------🔺 HISTORY -----------------------------------------------------

        trim_response_for_chat_history = function(res) {
            root <- private$extract_root(res)

            if (!purrr::is_empty(root)) {
                # Remove annotations if present (not needed in chat history)
                root$annotations <- NULL
            }
            return(root)
        },

        tool_results_to_chat_history = function(tool_results) {
            if (!is.null(tool_results) && length(tool_results) > 0) {
                # OpenAI tool results are already formatted: list(role = "tool", tool_call_id, content)
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

        image_input = function(input, detail = NULL, ...) {
            # OpenAI supports: PNG (.png) - JPEG (.jpeg and .jpg) - WEBP (.webp) - Non-animated GIF (.gif)
            # See: https://platform.openai.com/docs/guides/images-vision?api-mode=chat#image-input-requirements
            supported_formats <- c("png", "jpeg", "jpg", "webp", "gif")
            ext <- tolower(tools::file_ext(input))

            if (!ext %in% supported_formats) {
                cli::cli_abort(c(
                    "[{self$provider_name}] Unsupported image format: {.val {ext}}",
                    "i" = "Supported formats: {.val {supported_formats}}"
                ))
            }

            url <- if (is_url(input)) input else image_to_base64(input)$data_uri

            result <- list(type = "image_url", image_url = list(url = url))

            # Add detail parameter if provided (low/high/auto)
            if (!is.null(detail)) {
                result$image_url$detail <- detail
            }

            return(result)
        },

        pdf_input = function(input, ...) {
            encoded <- if (is_url(input)) pdf_url_to_base64(input) else pdf_to_base64(input)
            list(type = "file", file = list(filename = basename(input), file_data = encoded$data_uri))
        },

        file_ref_input = function(input, ...) {
            file_id <- if (is.character(input)) input else purrr::pluck(input, "id")
            list(type = "file", file = list(file_id = file_id))
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
