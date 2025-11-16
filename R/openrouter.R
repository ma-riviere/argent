#' OpenRouter API Client
#'
#' @description
#' R6 class for interacting with OpenRouter's API. Provides access to multiple LLM providers
#' through a unified interface with support for chat completions, tool calling, and structured outputs.
#'
#' @section Useful links:
#' - API reference: https://openrouter.ai/docs/api-reference/overview
#' - API docs: https://openrouter.ai/docs/quickstart
#'
#' @field allowed_providers Character vector. Allowed provider slugs (default: NULL)
#' @field blocked_providers Character vector. Blocked provider slugs (default: NULL)
#'
#' @section Server-side tools:
#' - "web_search" for web search grounding via OpenRouter's web plugin
#' 
#' @export
#' @examples
#' \dontrun{
#' # Initialize with API key from environment
#' openrouter <- OpenRouter$new()
#'
#' # Or provide API key explicitly
#' openrouter <- OpenRouter$new(api_key = "your-api-key")
#'
#' # Simple chat completion
#' response <- openrouter$chat(
#'   prompt = "What is R programming?",
#'   model = "anthropic/claude-3.5-sonnet"
#' )
#'
#' # With web search (simple method)
#' response <- openrouter$chat(
#'   prompt = "What are the latest developments in quantum computing?",
#'   model = "anthropic/claude-3.5-sonnet",
#'   tools = list("web_search")
#' )
#'
#' # With web search using specific engine and custom settings
#' response <- openrouter$chat(
#'   prompt = "Recent news about R programming language",
#'   model = "openai/gpt-4o",
#'   tools = list(
#'     list(type = "web_search", engine = "exa", max_results = 3)
#'   )
#' )
#'
#' # With tools/function calling
#' response <- openrouter$chat(
#'   prompt = "What's the weather in Paris?",
#'   model = "anthropic/claude-3.5-sonnet",
#'   tools = list(get_weather_tool)
#' )
#' }
OpenRouter <- R6::R6Class( # nolint
    classname = "OpenRouter",
    inherit = Provider,
    public = list(
        allowed_providers = NULL,
        blocked_providers = NULL,

        # ------🔺 INIT --------------------------------------------------------
        
        #' @description
        #' Initialize a new OpenRouter client
        #' @param base_url Character. Base URL for API (default: "https://openrouter.ai/api")
        #' @param api_key Character. API key (default: from OPENROUTER_API_KEY env var)
        #' @param provider_name Character. Provider name (default: "OpenRouter")
        #' @param rate_limit Numeric. Rate limit in requests per second (default: 20/60)
        #' @param server_tools Character vector. Server-side tools available (default: c("web_search"))
        #' @param default_model Character. Default model to use for chat requests (default:
        #'   "openrouter/auto")
        #' @param allowed_providers Character vector. Allowed provider slugs (default: NULL)
        #' @param blocked_providers Character vector. Blocked provider slugs (default: NULL)
        #' @param auto_save_history Logical. Enable/disable automatic history sync (default: TRUE)
        initialize = function(
            base_url = "https://openrouter.ai/api",
            api_key = Sys.getenv("OPENROUTER_API_KEY"),
            provider_name = "OpenRouter",
            rate_limit = 20 / 60,
            server_tools = c("web_search"),
            default_model = "openrouter/auto",
            allowed_providers = NULL,
            blocked_providers = NULL,
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
            self$allowed_providers <- allowed_providers
            self$blocked_providers <- blocked_providers
        },

        # ------🔺 PROVIDERS ---------------------------------------------------
        
        #' @description
        #' Get the list of allowed providers
        #' @return Character vector. Allowed provider slugs, or NULL if none set
        get_allowed_providers = function() {
            return(self$allowed_providers)
        },

        #' @description
        #' Set the list of allowed providers for all requests
        #' @param providers Character vector. Provider slugs to allow (e.g., c("anthropic", "openai"))
        set_allowed_providers = function(providers) {
            if (!is.null(providers) && !is.character(providers)) {
                cli::cli_abort("[{self$provider_name}] Providers must be a character vector or NULL")
            }
            self$allowed_providers <- providers
        },

        #' @description
        #' Get the list of blocked providers
        #' @return Character vector. Blocked provider slugs, or NULL if none set
        get_blocked_providers = function() {
            return(self$blocked_providers)
        },

        #' @description
        #' Set the list of blocked providers for all requests
        #' @param providers Character vector. Provider slugs to block (e.g., c("deepinfra", "together"))
        set_blocked_providers = function(providers) {
            if (!is.null(providers) && !is.character(providers)) {
                cli::cli_abort("[{self$provider_name}] Providers must be a character vector or NULL")
            }
            self$blocked_providers <- providers
        },

        #' @description
        #' List all available providers from OpenRouter
        #' @return Data frame. Available providers with their specifications
        list_providers = function() {
            endpoint <- paste0(self$base_url, "/v1/providers")

            private$list(endpoint) |>
                dplyr::select(name, slug) |>
                dplyr::arrange(name)
        },

        # ------🔺 MODELS ------------------------------------------------------

        #' @description
        #' List all available models from OpenRouter
        #' @param supported_parameters Character vector. Supported parameters to filter models by. 
        #' Options include: "tools", "temperature", "top_p", "top_k", "min_p", "top_a", "frequency_penalty", 
        #' "presence_penalty", "repetition_penalty", "max_tokens", "logit_bias", "logprobs", "top_logprobs", "seed", 
        #' "response_format", "structured_outputs", "stop", "parallel_tool_calls", "include_reasoning", "reasoning", 
        #' "web_search_options", "verbosity".
        #' Example: c("tools", "response_format")
        #' @return Data frame. Available models with their specifications
        list_models = function(supported_parameters = NULL) {
            endpoint <- paste0(self$base_url, "/v1/models")

            req <- private$base_request(endpoint)
            
            if (!is.null(supported_parameters)) {
                req <- httr2::req_url_query(req, supported_parameters = paste(supported_parameters, collapse = ", "))
            }
            
            res <- httr2::req_perform(req) |>
                httr2::resp_body_json()

            if (purrr::is_empty(res$data)) {
                cli::cli_alert_danger("[{self$provider_name}] Error: Failed to retrieve model list")
                return(NULL)
            }

            # Convert list of models to data frame
            models_df <- purrr::map(res$data, \(model) {
                data.frame(
                    id = model$id %||% NA_character_,
                    slug = model$canonical_slug %||% NA_character_,
                    name = model$name %||% NA_character_,
                    created = model$created %||% NA_integer_,
                    context_length = model$context_length %||% NA_integer_,
                    architecture = model$architecture$modality %||% NA_character_,
                    input_modalities = paste(unlist(model$architecture$input_modalities), collapse = ", ") %||%
                        NA_character_,
                    output_modalities = paste(unlist(model$architecture$output_modalities), collapse = ", ") %||%
                        NA_character_,
                    pricing_prompt = model$pricing$prompt %||% NA_character_,
                    pricing_completion = model$pricing$completion %||% NA_character_,
                    pricing_request = model$pricing$request %||% NA_character_,
                    pricing_image = model$pricing$image %||% NA_character_,
                    pricing_web_search = model$pricing$web_search %||% NA_character_,
                    pricing_internal_reasoning = model$pricing$internal_reasoning %||% NA_character_,
                    supported_parameters = paste(unlist(model$supported_parameters), collapse = ", ") %||% NA_character_
                )
            }) |> purrr::list_rbind()

            if (!is.null(models_df$created)) {
                models_df <- models_df |>
                    dplyr::mutate(created = lubridate::as_datetime(created)) |>
                    dplyr::arrange(dplyr::desc(created), id)
            }

            return(models_df)
        },

        #' @description
        #' Get information about a specific model
        #' @param model_id Character. Model ID (e.g., "anthropic/claude-3.5-sonnet")
        #' @return List. Model information
        get_model_info = function(model_id) {
            models <- self$list_models()
            if (is.null(models)) return(NULL)

            model_info <- models |> dplyr::filter(id == model_id)

            if (nrow(model_info) == 0) {
                cli::cli_alert_warning("[{self$provider_name}] Model {model_id} not found")
                return(NULL)
            }

            return(as.list(model_info[1, ]))
        },

        # ------🔺 EMBEDDINGS --------------------------------------------------

        #' @description
        #' Generate embeddings for text input
        #' @param input Character vector. Text(s) to embed
        #' @param model Character. Model to use (e.g., "text-embedding-3-small", "text-embedding-3-large")
        #' @param encoding_format Character. Format of embeddings: "float" or "base64" (default: "float")
        #' @param dimensions Integer. Number of dimensions for output (only for embedding-3 models)
        #' @param provider Character. Specific provider to use (optional, enables provider routing)
        #' @param return_full_response Logical. Return full API response (default: FALSE)
        #' @return Numeric matrix (or List if return_full_response = TRUE). Embeddings with one row per input text
        #' @examples
        #' \dontrun{
        #' openrouter <- OpenRouter$new()
        #'
        #' # Generate embeddings
        #' embeddings <- openrouter$embeddings(
        #'   input = c("Hello world", "How are you?"),
        #'   model = "openai/text-embedding-3-small"
        #' )
        #'
        #' # With dimension reduction
        #' embeddings <- openrouter$embeddings(
        #'   input = "Sample text",
        #'   model = "openai/text-embedding-3-large",
        #'   dimensions = 256
        #' )
        #'
        #' # With provider routing
        #' embeddings <- openrouter$embeddings(
        #'   input = "Sample text",
        #'   model = "text-embedding-3-small",
        #'   provider = "openai"
        #' )
        #' }
        embeddings = function(
            input,
            model,
            encoding_format = "float",
            dimensions = NULL,
            provider = NULL,
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

            # Build API request (OpenAI-compatible format)
            query_data <- list3(
                input = input,
                model = model,
                encoding_format = encoding_format,
                dimensions = dimensions
            )

            # Add provider routing if specified
            if (!is.null(provider)) {
                query_data$provider <- list(order = list(provider))
            } else if (!is.null(self$allowed_providers)) {
                query_data$provider <- list(order = self$allowed_providers)
            }

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

            # Extract embeddings and return as matrix (OpenAI-compatible format)
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

        # ------🔺 RESPONSE HELPERS --------------------------------------------

        # ------🔺 CHAT --------------------------------------------------------

        #' @description
        #' Send a chat completion request to OpenRouter
        #' @param ... One or more inputs for the prompt. Can be text strings, file paths, URLs, R objects,
        #'   or content wrapped with `as_*_content()` functions. R objects (but not plain strings) will
        #'   include their names and structure in the context sent to the model.
        #' @param system Character. System instructions (optional)
        #' @param model Character. Model to use (e.g., "anthropic/claude-3.5-sonnet")
        #' @param temperature Numeric. Sampling temperature (default: 1)
        #' @param max_tokens Integer. Maximum tokens to generate (default: 4096)
        #' @param top_p Numeric. Nucleus sampling - restricts token selection to those whose cumulative
        #'   probability equals top_p. Range: 0.0-1.0 (optional)
        #' @param top_k Integer. Top-K sampling - limits token choices to top N selections. Set to 1 for
        #'   deterministic output (optional)
        #' @param frequency_penalty Numeric. Reduces reuse of tokens appearing frequently in input.
        #'   Range: -2.0 to 2.0 (optional)
        #' @param presence_penalty Numeric. Penalizes token reuse regardless of frequency.
        #'   Range: -2.0 to 2.0 (optional)
        #' @param repetition_penalty Numeric. Decreases token repetition from input.
        #'   Range: 0.0-2.0 (optional)
        #' @param min_p Numeric. Minimum relative probability threshold for token consideration.
        #'   Range: 0.0-1.0 (optional)
        #' @param top_a Numeric. Filters tokens based on sufficiently high probabilities relative to the
        #'   most likely token. Range: 0.0-1.0 (optional)
        #' @param seed Integer. Enables deterministic sampling when repeated with identical parameters
        #'   (optional)
        #' @param stop_sequences Character vector. Sequences that halt generation when encountered (optional)
        #' @param logit_bias Named list. Applies bias values (-100 to 100) to token logits before sampling
        #'   (optional)
        #' @param logprobs Logical. Returns log probabilities for output tokens when enabled (optional)
        #' @param top_logprobs Integer. Number of most probable tokens with log probabilities to return.
        #'   Range: 0-20. Requires logprobs = TRUE (optional)
        #' @param tools List. Function definitions for tool calling, or server tools (optional).
        #'   Server-side tools:
        #'   - "web_search" for web search grounding via OpenRouter's web plugin
        #'   - list(type = "web_search", engine = "exa", max_results = 3) for advanced configuration
        #'     - engine: "native" (provider's server-side search), "exa" (Exa API), or NULL (auto-select)
        #'     - max_results: Maximum results to include (default: 5, only for Exa)
        #'     - search_prompt: Custom prompt for results (optional)
        #'   Pricing: Exa charges $4/1000 results (~$0.02 per request with default 5 results).
        #'   Native search pricing varies by provider.
        #' @param tool_choice Character or List. Tool choice mode (default: "auto").
        #'   Note: Some models don't support "auto". If you get an error about "does not support auto tool", either:
        #'   - Use tool_choice = "none" to disable tools
        #'   - Use tool_choice = list(type = "function", function = list(name = "tool_name"))
        #'     to force a specific tool (model will always use it)
        #'   - Choose a different model that supports "auto"
        #' @param parallel_tool_calls Logical. Allow simultaneous tool execution (default: TRUE) (optional)
        #' @param cache_prompt Logical. Cache the user prompt (default: FALSE).
        #'   For Anthropic/Google models, adds cache_control breakpoint. Minimum 1024 tokens for Google 2.5 Flash,
        #'   2048 for Google 2.5 Pro, 4096 for Anthropic. Other providers cache automatically.
        #' @param cache_system Logical. Cache system instructions (default: FALSE).
        #'   For Anthropic/Google models only.
        #' @param thinking_budget Integer. Thinking budget in tokens: 0 (disabled) or any positive integer
        #'   (default: 0). Only for models that support reasoning tokens (e.g., o1, DeepSeek-R1).
        #' @param verbosity Character. Adjusts response length and detail level: "low", "medium", or "high"
        #'   (default: "medium") (optional)
        #' @param provider_options List. Provider routing options (optional). See
        #'   https://openrouter.ai/docs/features/provider-routing for details. Possible elements:
        #'   - order: Character vector. List of provider slugs to try in order
        #'   - allow_fallbacks: Logical. Allow backup providers when primary is unavailable (default: TRUE)
        #'   - require_parameters: Logical. Only use providers supporting all parameters (default: FALSE)
        #'   - data_collection: Character. "allow" or "deny" - control provider data storage
        #'   - zdr: Logical. Restrict routing to only ZDR (Zero Data Retention) endpoints
        #'   - enforce_distillable_text: Logical. Restrict routing to only models allowing text distillation
        #'   - only: Character vector. List of provider slugs to allow (overrides class-level allowed_providers)
        #'   - ignore: Character vector. List of provider slugs to skip (overrides class-level blocked_providers)
        #'   - quantizations: Character vector. List of quantization levels to filter by (e.g., c("int4", "int8"))
        #'   - sort: Character. Sort providers by "price" or "throughput"
        #'   - max_price: List. Maximum pricing (e.g., list(prompt = 0.001, completion = 0.002))
        #' @param output_schema List. JSON schema for structured output (optional)
        #' @param return_full_response Logical. Return full API response (default: FALSE)
        #' @return Character (or List if return_full_response = TRUE). OpenRouter API's response object.
        chat = function(
            ...,
            system = .default_system_prompt,
            model = "openrouter/auto",
            temperature = 1,
            max_tokens = 4096,
            top_p = NULL,
            top_k = NULL,
            frequency_penalty = NULL,
            presence_penalty = NULL,
            repetition_penalty = NULL,
            min_p = NULL,
            top_a = NULL,
            seed = NULL,
            stop_sequences = NULL,
            logit_bias = NULL,
            logprobs = NULL,
            top_logprobs = NULL,
            tools = NULL,
            tool_choice = "auto",
            parallel_tool_calls = NULL,
            cache_prompt = FALSE,
            cache_system = FALSE,
            thinking_budget = 0,
            verbosity = NULL,
            provider_options = NULL,
            output_schema = NULL,
            return_full_response = FALSE
        ) {

            # Capture prompt inputs as quosures
            inputs <- rlang::enquos(...)

            # ---- Models ----

            # Support for multiple models (fallback models)
            # See: https://openrouter.ai/docs/features/model-routing#the-models-parameter
            fallback_models <- NULL
            if (length(model) > 1) {
                fallback_models <- utils::tail(model, -1)
                model <- first(model)
            }

            # ---- System ----

            # Check if model requires explicit cache_control (Anthropic/Google)
            requires_cache_control <- stringr::str_detect(tolower(model), "anthropic|google")

            # First round (chat history is empty): add the system message as first message if it's not empty
            if (purrr::is_empty(self$chat_history) && !purrr::is_empty(system)) {
                if (cache_system && requires_cache_control) {
                    # For Anthropic/Google: use multipart content with cache_control
                    system_msg <- list(
                        role = "system",
                        content = list(
                            list(
                                type = "text",
                                text = system,
                                cache_control = list(type = "ephemeral")
                            )
                        )
                    )
                } else {
                    # Standard system message
                    system_msg <- list(role = "system", content = system)
                }
                private$append_to_chat_history(system_msg)
            }

            # ---- Inputs ----

            # Extract plugins if present (will be NULL for quosures)
            plugins <- list()

            # Add user prompt to chat history (unless it's empty)
            if (!purrr::is_empty(inputs)) {
                # Process multipart content (handles strings, multimodal inputs, etc.)
                content <- private$process_multipart_content(inputs)

                # Process provider options
                if (purrr::some(content, \(x) !is.null(attr(x, "provider_options")))) {
                    # Process PDF plugins
                    pdf_plugins <- purrr::map(content, \(x) purrr::pluck(attr(x, "provider_options"), "pdf_options")) |>
                        purrr::compact()
                    if (!purrr::is_empty(pdf_plugins)) {
                        plugins <- append(
                            plugins,
                            list(
                                list(
                                    id = "file-parser",
                                    pdf = list(engine = purrr::pluck(pdf_plugins, 1, "pdf_parser"))
                                )
                            )
                        )
                    }
                }                

                # Add cache_control if needed
                if (cache_prompt && requires_cache_control && !is.null(content[[1]]$type)) {
                    # Add cache_control to the last content item (typically text)
                    content[[length(content)]]$cache_control <- list(type = "ephemeral")
                }

                private$append_to_chat_history(list(role = "user", content = content))
            }

            # ---- Build provider preferences ----

            # Apply class-level defaults if not overridden in provider_options
            provider_options$only <- as.list(provider_options$only %||% self$allowed_providers)
            provider_options$ignore <- as.list(provider_options$ignore %||% self$blocked_providers)
            provider_options$order <- if (is.null(provider_options$order)) NULL else as.list(provider_options$order)
            provider_prefs <- list3(!!!provider_options)

            # ---- Process tools ----

            # Separate server tools from client function tools
            function_tools <- list()

            if (!is.null(tools)) {
                for (tool in tools) {
                    if (is_client_tool(tool)) {
                        converted_tool <- as_tool_openrouter(tool)
                        function_tools <- append(function_tools, list(converted_tool))

                    } else if (is_server_tool(tool, self$server_tools)) {
                        tool_name <- get_server_tool_name(tool)

                        if (tool_name == "web_search") {
                            # Handle web_search server tool
                            if (is.character(tool)) {
                                web_plugin <- list(id = "web") # Will try native then fallback to exa
                            } else {
                                # Advanced form: build plugin
                                web_plugin <- list3(
                                    id = "web",
                                    engine = tool$engine,
                                    max_results = tool$max_results,
                                    search_prompt = tool$search_prompt
                                )
                            }
                            plugins <- append(plugins, list(web_plugin))
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
            }

            # ---- Build API request ----

            # Convert tools to OpenAI format if needed
            converted_tools <- NULL
            if (length(function_tools) > 0) {
                converted_tools <- lapply(function_tools, \(tool) {
                    list(type = "function", `function` = as_tool_openrouter(tool))
                })
            }

            query_data <- list3(
                temperature = temperature,
                max_tokens = max_tokens,
                messages = self$chat_history,
                top_p = top_p,
                top_k = top_k,
                frequency_penalty = frequency_penalty,
                presence_penalty = presence_penalty,
                repetition_penalty = repetition_penalty,
                min_p = min_p,
                top_a = top_a,
                seed = seed,
                stop = stop_sequences,
                logit_bias = logit_bias,
                logprobs = logprobs,
                top_logprobs = top_logprobs,
                verbosity = verbosity,
                tools = converted_tools,
                tool_choice = if (length(function_tools) > 0) tool_choice else NULL,
                parallel_tool_calls = if (length(function_tools) > 0) parallel_tool_calls else NULL,
                provider = provider_prefs,
                reasoning = if (thinking_budget > 0) list(max_tokens = thinking_budget) else NULL,
                plugins = plugins
            )

            if (!purrr::is_empty(fallback_models)) {
                query_data$models <- fallback_models
            } else {
                query_data$model <- model
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

            res_status <- tolower(purrr::pluck(res, "choices", 1, "finish_reason", .default = "stop"))
            if (res_status == "length") {
                cli::cli_warn(
                    "[{self$provider_name}] The response was truncated because it exceeded the allowed token limit."
                )
            }

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
                        frequency_penalty = frequency_penalty,
                        presence_penalty = presence_penalty,
                        repetition_penalty = repetition_penalty,
                        min_p = min_p,
                        top_a = top_a,
                        seed = seed,
                        stop_sequences = stop_sequences,
                        logit_bias = logit_bias,
                        logprobs = logprobs,
                        top_logprobs = top_logprobs,
                        tools = tools,
                        tool_choice = tool_choice,
                        parallel_tool_calls = parallel_tool_calls,
                        cache_prompt = FALSE,
                        cache_system = FALSE,
                        thinking_budget = thinking_budget,
                        verbosity = verbosity,
                        provider_options = provider_options,
                        output_schema = output_schema,
                        return_full_response = return_full_response
                    )
                )

            }

            # ---- Final response ----

            # Handle structured output using the tool call trick
            if (is.list(output_schema)) {

                format_tool <- response_schema_to_tool_openrouter(output_schema)
                format_prompt <- make_format_prompt(format_tool$name)

                # Create a separate instance for JSON formatting
                format_instance <- OpenRouter$new(
                    api_key = private$api_key,
                    base_url = self$base_url,
                    rate_limit = self$rate_limit,
                    auto_save_history = FALSE
                )
                format_instance$set_history(self$get_history())

                # Use same provider preferences for structured output call
                # Use deterministic sampling for formatting task
                format_result <- format_instance$chat(
                    prompt = format_prompt,
                    model = model,
                    system = system,
                    max_tokens = max_tokens,
                    temperature = 0,
                    seed = seed,
                    logit_bias = logit_bias,
                    tools = list(format_tool),
                    tool_choice = "auto", # We can't use required/function because not all models/providers support it
                    parallel_tool_calls = parallel_tool_calls,
                    cache_prompt = FALSE,
                    cache_system = FALSE,
                    thinking_budget = thinking_budget,
                    provider_options = provider_options,
                    output_schema = TRUE,
                    return_full_response = return_full_response
                )
                rm(format_instance)

                return(format_result)
            }

            # No structured output: return the response content or the full response
            if (!isTRUE(return_full_response)) {
                return(self$get_content_text(res))
            }
            return(res)
        }
    ),
    private = list(
        api_key = NULL,

        # ------🔺 EXTRACTION --------------------------------------------------

        is_root = function(input) {
            is.list(input) && !is.null(input$role) && !is.null(input$content)
        },

        extract_root = function(input) {
            if (!is.null(purrr::pluck(input, "choices"))) {
                # For API response && session_history -> <"response" turn> -> data
                fields_to_keep <- c("role", "content", "reasoning", "tool_calls", "reasoning_details", "annotations")
                root <- purrr::pluck(input, "choices", 1, "message") |>
                    purrr::keep_at(fields_to_keep) |>
                    purrr::compact()
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
            role <- private$extract_role(root)

            if (role != "assistant") {
                return(NULL)
            }

            reasoning <- purrr::pluck(root, "reasoning")

            # Use reasoning_details as fallback if reasoning is empty
            has_no_reasoning <- purrr::is_empty(reasoning) || reasoning %in% c("\n", "")

            if (has_no_reasoning) {
                reasoning_details <- private$extract_reasoning_details(root)

                if (!is.null(reasoning_details)) {
                    reasoning_text_items <- purrr::keep(reasoning_details, \(x) {
                        purrr::pluck(x, "type", .default = "") == "reasoning.text"
                    })

                    if (length(reasoning_text_items) > 0) {
                        reasoning <- purrr::pluck(reasoning_text_items, 1, "text")
                    }
                }
            }

            if (purrr::is_empty(reasoning) || reasoning %in% c("\n", "")) {
                return(NULL)
            }

            # Return reasoning in the expected format
            return(list(reasoning = reasoning))
        },

        extract_reasoning_text = function(root) {
            reasoning_text <- private$extract_reasoning(root) |> 
                purrr::pluck("reasoning")
            if (purrr::is_empty(reasoning_text) || reasoning_text %in% c("\n", "")) {
                return(NULL)
            }
            if (length(reasoning_text) == 1) {
                return(first(reasoning_text))
            }
            return(paste0(reasoning_text, collapse = "\n"))
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

            # Apply JSON cleaning for malformed arguments
            tool_calls <- purrr::map(tool_calls, \(tool_call) {
                args_string <- purrr::pluck(tool_call, "function", "arguments")

                if (!is.null(args_string)) {
                    tool_call$`function`$arguments <- clean_malformed_json(args_string)
                }

                return(tool_call)
            })

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
            name <- purrr::pluck(tool_result, "name")
            if (purrr::is_empty(name)) {
                content <- private$extract_tool_result_content(tool_result)
                return(purrr::pluck(content, "name", .default = "unknown"))
            }
            return(name)
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
            
            if (!purrr::is_empty(entry_data$plugins)) {
                plugin_ids <- purrr::map_chr(entry_data$plugins, \(plugin) purrr::pluck(plugin, "id"))
                if (any(plugin_ids %in% c("web"))) {
                    tools <- append(tools, list("web_search"))
                }
            }

            if (is.null(tools) || purrr::is_empty(tools)) {
                return(NULL)
            }

            normalized_tools <- purrr::map(tools, \(tool) {
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

        extract_annotations = function(root) {
            annotations <- purrr::pluck(root, "annotations")

            if (purrr::is_empty(annotations)) {
                return(NULL)
            }

            return(annotations)
        },

        extract_reasoning_details = function(root) {
            reasoning_details <- purrr::pluck(root, "reasoning_details")

            if (purrr::is_empty(reasoning_details)) {
                return(NULL)
            }

            reasoning_details <- purrr::keep(reasoning_details, \(x) !x$text %in% c("\n", ""))

            return(reasoning_details)
        },

        extract_supplementary = function(api_res) {
            root <- private$extract_root(api_res)

            if (purrr::is_empty(root)) {
                return(NULL)
            }
            annotations <- private$extract_annotations(root)

            return(list3(annotations = annotations))
        },

        # ------🔺 HISTORY -----------------------------------------------------

        trim_response_for_chat_history = function(res) {
            root <- private$extract_root(res)

            if (!purrr::is_empty(root)) {
                # root$reasoning <- NULL # Keeping reasoning = more tokens, but better conversation awareness
                root$reasoning_details <- NULL
                
                # We keep annotations
                # See: https://openrouter.ai/docs/features/multimodal/pdfs
                # > When you send a PDF to the API, the response may include file annotations in the assistant's message
                # > These annotations contain structured information about the PDF document that was parsed. 
                # > By sending these annotations back in subsequent requests, you can avoid re-parsing the same PDF 
                # > document multiple times, which saves both processing time and costs.
            }
            return(root)
        },

        tool_results_to_chat_history = function(tool_results) {
            if (!is.null(tool_results) && length(tool_results) > 0) {
                # OpenRouter tool results are already formatted: list(role = "tool", tool_call_id, content)
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
            url <- if (is_url(input)) input else image_to_base64(input)$data_uri
            list(type = "image_url", image_url = list(url = url))
        },

        pdf_input = function(input, pdf_parser = "pdf-text", ...) {
            encoded <- if (is_url(input)) input else pdf_to_base64(input)$data_uri
            res <- list(type = "file", file = list(filename = basename(input), file_data = encoded))

            attr(res, "provider_options") <- list(pdf_options = list(pdf_parser = pdf_parser))
            return(res)
        },

        file_ref_input = function(input, ...) {
            cli::cli_abort(c(
                "[{self$provider_name}] Remote file references not supported.",
                "i" = "Provide files as local paths or URLs instead, for supported input types."
            ))
        },

        # ------🔺 REQUESTS ----------------------------------------------------

        # Add OpenRouter authentication (Bearer token)
        add_auth = function(req) {
            httr2::req_headers_redacted(req, Authorization = paste0("Bearer ", private$api_key))
        },


        # ------🔺 TOOLS -------------------------------------------------------

        # Execute a single tool call
        use_tool = function(tool_call) {
            fn_name <- private$extract_tool_call_name(tool_call)
            args <- private$extract_tool_call_args(tool_call)

            output <- super$use_tool(fn_name, args)

            # For OpenRouter, content should be a string representation, not JSON-encoded
            # If output is already a character string, use it directly
            # Otherwise, convert to JSON string without additional escaping
            if (is.character(output) && length(output) == 1) {
                content_str <- output
            } else {
                content_str <- jsonlite::toJSON(output, auto_unbox = TRUE)
            }

            # Clean malformed JSON in output (e.g., duplicate objects)
            content_str <- clean_malformed_json(content_str)

            return(list(
                role = "tool",
                tool_call_id = purrr::pluck(tool_call, "id"),
                content = content_str
            ))
        },

        # ------🔺 HELPERS -----------------------------------------------------

        list = function(endpoint) {
            private$request(endpoint) |> 
                purrr::pluck("data") |> 
                lol_to_df()
        },

        delete = function(endpoint, id) {
            private$base_request(endpoint) |>
                httr2::req_url_path_append(id) |> 
                httr2::req_method("DELETE") |> 
                httr2::req_perform() |>
                httr2::resp_body_json()
        }
    )
)

# ------🔺 SCHEMAS -------------------------------------------------------------

#' Convert generic tool schema to OpenRouter format (internal)
#' @param tool_schema List. Generic tool schema from as_tool() function
#' @return List. Tool definition in OpenRouter format
#' @keywords internal
#' @noRd
as_tool_openrouter <- function(tool_schema) {
    if (!is.null(tool_schema$parameters) && !is.null(tool_schema$type)) {
        return(tool_schema)
    }

    # OpenRouter requires a non-empty parameters even if it has no properties
    list3(
        name = tool_schema$name,
        description = tool_schema$description,
        parameters = if (is.null(tool_schema$args_schema)) list(type = "object") else tool_schema$args_schema
    )
}

#' Convert schema to structured output format for OpenRouter (internal)
#' @param output_schema List. Schema definition with name, description, and args_schema/schema
#' @return List. Structured output format for OpenRouter
#' @keywords internal
#' @noRd
as_schema_openrouter <- function(output_schema) {
    as_schema_openai(output_schema)
}

#' Convert response schema to tool format (internal)
#' @param response_schema List. Response schema definition
#' @return List. Tool definition in OpenRouter format
#' @keywords internal
#' @noRd
response_schema_to_tool_openrouter <- function(response_schema) {
    response_schema_to_tool_openai(response_schema)
}
