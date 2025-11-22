#' Provider Base Class: shared interface & common functionalities for all LLM providers
#'
#' @description
#' Base R6 class for all LLM provider clients. Provides shared infrastructure for:
#' - Chat history management (get, set, reset, append)
#' - Automatic history persistence to JSON (enabled by default, per-instance control)
#' - Rate limiting configuration
#' - Token usage tracking
#'
#' This class is inherited by all provider classes (Google, Anthropic, OpenAI_Base)
#' to ensure consistent interfaces and eliminate code duplication.
#'
#' @field base_url Character. Base URL for API endpoint
#' @field provider_name Character. Provider name
#' @field rate_limit Numeric. Rate limit in requests per second
#' @field history_file_path Character. Full file path for persistent history storage
#' @field chat_history List. Conversation history (provider-specific format)
#' @field session_history List. Ground truth: alternating query_data and API responses
#' @field server_tools Character vector. Server-side tools to use for API requests
#' @field default_model Character. Default model to use for chat requests
#'
#' @section History Auto-Save:
#' History auto-save is controlled per-instance and enabled by default. To control it:
#' - At initialization: Pass `auto_save_history = TRUE/FALSE` to `$new()` (default: TRUE)
#' - After creation: Use `$set_auto_save_history(TRUE/FALSE)` or `$get_auto_save_history()`
#'
#' Manual save/load available via `dump_history()` and `load_history()`.
#'
#' @keywords internal
Provider <- R6::R6Class( # nolint
    classname = "Provider",
    public = list(
        base_url = NULL,
        provider_name = NULL,
        rate_limit = NULL,
        server_tools = character(0),
        default_model = NULL,
        chat_history = list(),
        session_history = list(),
        history_file_path = NULL,

        # ------🔺 INIT --------------------------------------------------------

        #' @description
        #' Initialize a new Provider instance
        #' @param base_url Character. Base URL for API endpoint
        #' @param api_key Character. API key for the provider
        #' @param provider_name Character. Provider name
        #' @param rate_limit Numeric. Rate limit in requests per second
        #' @param server_tools Character vector. Server-side tools available
        #' @param default_model Character. Default model to use for chat requests
        #' @param auto_save_history Logical. Enable/disable automatic history sync (default: TRUE)
        initialize = function(
            base_url = NULL,
            api_key = NULL,
            provider_name = "Provider",
            rate_limit = NULL,
            server_tools = character(0),
            default_model = NULL,
            auto_save_history = TRUE
        ) {
            # Normalize base_url: remove trailing slash and /v1 suffix
            if (!is.null(base_url)) {
                base_url <- sub("/$", "", base_url)
                if (stringr::str_ends(base_url, "/v1")) {
                    base_url <- sub("/v1$", "", base_url)
                }
            }

            # Set common fields
            self$base_url <- base_url
            private$api_key <- api_key
            self$provider_name <- provider_name
            self$rate_limit <- rate_limit
            self$server_tools <- server_tools
            self$default_model <- default_model

            # Set instance-level auto_save_history setting (default TRUE)
            private$auto_save_history_setting <- auto_save_history
            self$history_file_path <- generate_history_path(self$provider_name)

            invisible(self)
        },

        # ------🔺 RATE LIMITING -----------------------------------------------

        #' @description
        #' Get the rate limit
        #' @return Numeric. Rate limit in requests per second
        get_rate_limit = function() {
            return(self$rate_limit)
        },

        #' @description
        #' Set the rate limit
        #' @param rate_limit Numeric. Rate limit in requests per second
        set_rate_limit = function(rate_limit) {
            if (!is.numeric(rate_limit) || rate_limit <= 0) {
                cli::cli_abort("rate_limit must be a positive numeric value")
            }
            self$rate_limit <- rate_limit
        },

        # ------🔺 HISTORY -----------------------------------------------------

        #' @description
        #' Get both chat and session history
        #' @return List. History containing both chat_history and session_history
        get_history = function() {
            history <- list(chat_history = self$chat_history, session_history = self$session_history)
            return(history)
        },

        #' @description
        #' Set both chat and session history
        #' @param history List. Chat and session history to set (list(chat_history = ..., session_history = ...))
        #' @return Self (invisibly) for method chaining
        set_history = function(history) {
            if (is.null(history) || !is.list(history)) {
                cli::cli_abort("{.arg history} must be a list, got: {.val {class(history)}}")
            }
            if (is.null(history$chat_history) || !is.list(history$chat_history)) {
                cli::cli_abort("{.arg history} must contain a non-null {.arg chat_history} list.")
            }
            if (is.null(history$session_history) || !is.list(history$session_history)) {
                cli::cli_abort("{.arg history} must contain a non-null {.arg session_history} list.")
            }
            private$set_chat_history(history$chat_history)
            private$set_session_history(history$session_history)
            invisible(self)
        },

        #' @description
        #' Get the chat history. The chat history is the history of messages exchanged between the user and the model.
        #' @return List. Chat history
        get_chat_history = function() {
            return(self$chat_history)
        },

        #' @description
        #' Get the session history
        #' @return List. Session history (alternating query_data and responses)
        get_session_history = function() {
            return(self$session_history)
        },

        #' @description
        #' Dump both chat and session history to JSON file
        #' @param dest_path Character. Optional custom file path. If NULL, uses history_file_path.
        #' @return Character. Path to saved file (invisibly)
        dump_history = function(dest_path = NULL) {
            target_path <- dest_path %||% self$history_file_path
            if (is.null(target_path)) {
                cli::cli_abort("No file path provided and history_file_path is not set")
            }
            private$save_history_to_file(target_path)
            invisible(target_path)
        },

        #' @description
        #' Reset both chat and session history
        #' @details Archives current history before resetting, then generates new history_file_path
        reset_history = function() {
            # Archive if non-empty
            if (
                (!purrr::is_empty(self$chat_history) || !purrr::is_empty(self$session_history)) &&
                    !is.null(self$history_file_path)
            ) {
                private$save_history_to_file(self$history_file_path)
            }

            # Reset both histories
            private$reset_chat_history()
            private$reset_session_history()

            # New JSON dump file path
            self$history_file_path <- generate_history_path(self$provider_name)

            invisible(self)
        },

        #' @description
        #' Get the history file path
        #' @return Character. History file path
        get_history_file_path = function() {
            return(self$history_file_path)
        },

        #' @description
        #' Load both chat and session history from JSON file
        #' @param file_path Character. Path to history file (absolute or relative to project root) or just filename
        #' @return Self (invisibly) for method chaining
        load_history = function(file_path) {
            # If it's just a filename (no path separators), construct full path
            if (!grepl("[/\\\\]", file_path)) {
                if (!stringr::str_ends(file_path, ".json")) {
                    file_path <- paste0(file_path, ".json")
                }
                dir_path <- dirname(generate_history_path(self$provider_name))
                file_path <- file.path(dir_path, file_path)
            } else {
                # It's a path, resolve it relative to project root
                file_path <- here::here(file_path)
            }
            
            if (!is_file(file_path)) {
                cli::cli_abort("File not found: {.path {file_path}}")
            }

            # Use the provided file path as the new history file path (so that the automatic sync will save to it)
            self$history_file_path <- file_path

            # Set session_history first
            session_history <- purrr::pluck(private$load_history_from_file(file_path), "session_history")
            if (purrr::is_empty(session_history)) {
                cli::cli_abort("[{self$provider_name}] No session history found in: {.path {file_path}}")
            }
            private$set_session_history(session_history)

            # Reconstruct chat_history from session_history
            chat_history <- private$reconstruct_chat_history()
            private$set_chat_history(chat_history)

            invisible(self)
        },

        #' @description
        #' Get the auto-save history setting
        #' @return Logical. Auto-save history setting
        get_auto_save_history = function() {
            return(private$auto_save_history_setting)
        },

        #' @description
        #' Set the auto-save history setting
        #' @param enabled Logical. Enable/disable automatic history sync
        set_auto_save_history = function(enabled) {
            if (!is.logical(enabled)) {
                cli::cli_abort("enabled must be TRUE or FALSE")
            }
            private$auto_save_history_setting <- enabled
            invisible(self)
        },

        #' @description
        #' Get the total tokens used from session_history
        #' @return Integer. Total tokens used at last API call
        get_session_last_token_count = function() {
            last_response <- self$get_last_response()
            if (purrr::is_empty(last_response)) {
                cli::cli_alert_info("No last response found")
                return(0)
            }
            return(private$extract_total_token_count(last_response))
        },

        #' @description
        #' Get the cumulative tokens used from session_history
        #' @param up_to_index Integer. Index up to which to calculate the cumulative tokens (default: NULL)
        #' @return Integer. Cumulative tokens used computed from session_history, up to the specified index
        get_session_cumulative_token_count = function(up_to_index = NULL) {
            session_history <- purrr::keep(self$session_history, \(x) x$type == "response")
            if (!is.null(up_to_index)) {
                session_history <- purrr::keep(session_history, \(x) x$index <= up_to_index)
            }
            return(sum(purrr::map_int(session_history, \(x) x$tokens %||% 0)))
        },

        # ------🔺 RESPONSE HELPERS --------------------------------------------

        #' @description
        #' Get the last API response
        #' @return List. Last API response object, or NULL if no response has been stored
        get_last_response = function() {
            if (purrr::is_empty(self$session_history)) {
                cli::cli_alert_info("No session history found")
                return(NULL)
            }
            last_response <- purrr::keep(self$session_history, \(x) x$type == "response") |>
                last() |>
                purrr::pluck("data")

            return(last_response)
        },

        #' @description
        #' Get the text content from an API response
        #' @param api_res List. API response object (defaults to last response)
        #' @return Character. Text content from response
        get_content_text = function(api_res = self$get_last_response()) {
            private$extract_root(api_res) |>
                private$extract_content_text()
        },

        #' @description
        #' Get the text content from reasoning in an API response
        #' @param api_res List. API response object (defaults to last response)
        #' @return Character or List. Text content from reasoning in response
        get_reasoning_text = function(api_res = self$get_last_response()) {
            reasoning_text <- private$extract_root(api_res) |>
                private$extract_reasoning_text()
            if (purrr::is_empty(reasoning_text) || reasoning_text %in% c("\n", "")) {
                return(NULL)
            }
            return(reasoning_text)
        },

        #' @description
        #' Get generated code from an API response (e.g. from code execution tools)
        #' @param api_res List. API response object (defaults to last response)
        #' @param langs Character vector. Languages to filter code parts by (default: NULL)
        #' @param as_chunks Logical. Whether to return the code as a list of chunks (default: FALSE)
        #' @return Character or List. Code content from response as list of chunks or as single string
        get_generated_code = function(api_res = self$get_last_response(), langs = NULL, as_chunks = FALSE) {
            code_parts <- private$extract_root(api_res) |>
                private$extract_generated_code()
            
            if (!is.null(langs)) {
                code_parts <- purrr::keep(code_parts, \(code_elt) code_elt$language %in% tolower(langs))
            }

            if (as_chunks) {
                code_chunks <- purrr::map_chr(
                    code_parts, 
                    \(code_elt) format_code_block(code_elt$code, language = code_elt$language)
                )
                return(paste(code_chunks, collapse = "\n\n"))
            }

            return(code_parts)
        },

        #' @description
        #' Get generated files from an API response (e.g. from code execution tools)
        #' @param api_res List. API response object (defaults to last response)
        #' @return List. Files from response (each with mime_type and data), or NULL if none found
        get_generated_files = function(api_res = self$get_last_response()) {
            private$extract_root(api_res) |> 
                private$extract_generated_files()
        },

        #' @description
        #' Download files generated by code execution from an API response (e.g. from code execution tools)
        #' @param api_res List. API response object (defaults to last response)
        #' @param dest_path Character. Destination path for downloaded files
        #' @param overwrite Logical. Whether to overwrite existing files
        #' @return Character vector. Paths to saved files (invisibly)
        download_generated_files = function(api_res = self$get_last_response(), dest_path = "data", overwrite = TRUE) {
            files <- self$get_generated_files(api_res)
            if (purrr::is_empty(files)) {
                cli::cli_alert_info("[{self$provider_name}] No files found in the response to download.")
                return(invisible(character(0)))
            }
            private$download_generated_files(files, dest_path, overwrite)
        },

        #' @description
        #' Get supplementary data from an API response (annotations, citations, grounding metadata, etc.)
        #' @param api_res List. API response object (defaults to last response)
        #' @return List. Supplementary data from response (provider-specific structure)
        get_supplementary = function(api_res = self$get_last_response()) {
            supplementary_data <- private$extract_supplementary(api_res)
            return(supplementary_data)
        },

        # ------🔺 PRINT -------------------------------------------------------

        #' @description
        #' Print chat history in a formatted view. Inspired by ellmer
        #' @param show_system Logical. Include system messages (default: TRUE)
        #' @param show_reasoning Logical. Include reasoning/thinking blocks (default: TRUE)
        #' @param show_code Logical. Include code blocks (default: FALSE)
        #' @param show_tools Logical. Include tool calls and results (default: FALSE)
        #' @param show_supplementary Logical. Include supplementary data like annotations, citations (default: FALSE)
        #' @param show_output_schema Logical. Include output schema in query display (default: TRUE)
        #' @param max_content_length Integer. Maximum content length before truncation (default: 999)
        #' @return Self (invisibly) for method chaining
        print = function(
            show_system = TRUE,
            show_reasoning = TRUE,
            show_code = FALSE,
            show_tools = FALSE,
            show_supplementary = FALSE,
            show_output_schema = TRUE,
            max_content_length = 999
        ) {
            if (purrr::is_empty(self$session_history)) {
                cli::cli_alert_info("No conversation history")
                return(invisible(self))
            }

            cumulative_tokens <- self$get_session_cumulative_token_count()
            current_tokens <- self$get_session_last_token_count()
            turn_count <- length(self$session_history)

            cli::cli_h1(c(
                "[ <{.emph {self$provider_name}}> turns: {.val {turn_count}} | ",
                "Current context: {.val {current_tokens}} | ",
                "Cumulated tokens: {.val {cumulative_tokens}} ]"
            ))

            for (entry in self$session_history) {
                private$format_session_entry(
                    entry,
                    show_system,
                    show_reasoning,
                    show_code,
                    show_tools,
                    show_supplementary,
                    show_output_schema,
                    max_content_length
                )
            }

            invisible(self)
        }
    ),
    private = list(
        api_key = NULL,
        auto_save_history_setting = TRUE,
        active_tools = list(mcp = list(), client = list()),

        # ------🔺 HISTORY MANAGEMENT ------------------------------------------

        # Session history -----

        set_session_history = function(history) {
            if (!is.list(history)) {
                cli::cli_abort("Session history must be a list, got: {class(history)}")
            }
            self$session_history <- history
            private$auto_save_history()
            invisible(self)
        },

        reset_session_history = function() {
            self$session_history <- list()
            invisible(self)
        },

        append_to_session_history = function(type, data, tokens = NULL) {
            if (purrr::is_empty(data)) {
                cli::cli_alert_info("[{self$provider_name}] Trying to add empty content to session history. Ignored.")
                return(invisible(self))
            }
            index <- private$get_session_history_last_index() + 1
            private$set_session_history(append(
                self$session_history,
                list(list(type = type, tokens = tokens, index = index, data = data))
            ))
            invisible(self)
        },

        get_session_history_entry_index = function(entry) {
            return(purrr::pluck(entry, "index"))
        },

        get_session_history_entry = function(index) {
            return(first(purrr::keep(self$session_history, \(x) x$index == index)))
        },

        get_session_history_last_index = function() {
            max(purrr::map_int(self$session_history, "index"), .default = 0)
        },

        get_session_history_last_query = function() {
            return(last(purrr::keep(self$session_history, \(x) x$type == "query")))
        },
        
        get_session_history_last_response = function() {
            return(last(purrr::keep(self$session_history, \(x) x$type == "response")))
        },

        reconstruct_chat_history = function() {
            last_query <- private$get_session_history_last_query()
            last_response <- private$get_session_history_last_response()
            if (purrr::is_empty(last_query) || purrr::is_empty(last_response)) {
                return(list())
            }

            messages <- private$extract_root(purrr::pluck(last_query, "data"))
            trimmed_response <- private$trim_response_for_chat_history(purrr::pluck(last_response, "data"))

            # Detect if trimmed_response is unnamed list (OpenAI Responses) or named object (standard)
            if (is.null(names(trimmed_response))) {
                # Unnamed list - append directly
                return(append(messages, trimmed_response))
            } else {
                # Named object - wrap in list
                return(append(messages, list(trimmed_response)))
            }
        },

        # Chat history -----

        set_chat_history = function(history) {
            if (!is.list(history)) {
                cli::cli_abort("Chat history must be a list, got: {class(history)}")
            }
            self$chat_history <- history
            private$auto_save_history()
            invisible(self)
        },

        reset_chat_history = function() {
            self$chat_history <- list()
            invisible(self)
        },

        append_to_chat_history = function(new) {
            if (purrr::is_empty(new)) {
                cli::cli_alert_info("[{self$provider_name}] Trying to add empty content to chat history. Ignored.")
                return(invisible(self))
            }

            # Detect if new is an unnamed list (OpenAI Responses) or a named object (standard providers)
            if (is.null(names(new))) {
                # Unnamed list of items - append each individually (OpenAI Responses)
                private$set_chat_history(append(self$chat_history, new))
            } else {
                # Named object - wrap in list() before appending (standard providers)
                private$set_chat_history(append(self$chat_history, list(new)))
            }

            invisible(self)
        },

        trim_response_for_chat_history = function(res) {
            private$abort_if_no_child_impl()
        },

        response_to_chat_history = function(res) {
            private$append_to_chat_history(private$trim_response_for_chat_history(res))
        },

        # History -----

        auto_save_history = function() {
            if (!isTRUE(private$auto_save_history_setting)) {
                return(invisible(NULL))
            }

            # Only save if history_file_path is set
            if (!is.null(self$history_file_path)) {
                private$save_history_to_file(self$history_file_path)
            }
        },

        save_history_to_file = function(file_path) {
            if (length(self$session_history) == 0) {
                return(invisible(NULL))
            }

            history_data <- list(
                provider = self$provider_name,
                session_history = self$session_history
            )

            dir_path <- dirname(file_path)
            if (!dir.exists(dir_path)) {
                dir.create(dir_path, recursive = TRUE)
            }

            jsonlite::write_json(history_data, file_path, auto_unbox = TRUE, pretty = TRUE)
            invisible(file_path)
        },

        load_history_from_file = function(file_path) {
            if (!is_file(file_path)) {
                cli::cli_abort("File not found: {.path {file_path}}")
            }

            data <- jsonlite::read_json(file_path, simplifyDataFrame = FALSE)

            return(list(
                session_history = data$session_history %||% data$payload_history %||% list(),
                chat_history = data$chat_history %||% list()
            ))
        },

        # Save the query and response to the session history
        save_to_session_history = function(query_data, api_resp) {
            input_tokens <- private$extract_input_token_count(api_resp) %|e|% 0
            output_tokens <- private$extract_output_token_count(api_resp) %|e|% 0
            current_output_tokens <- input_tokens + output_tokens
            
            private$append_to_session_history(
                type = "query",
                data = query_data,
                tokens = input_tokens
            )

            private$append_to_session_history(
                type = "response",
                data = api_resp,
                tokens = current_output_tokens
            )

            invisible(TRUE)
        },

        extract_session_history_query_last_turn = function(input, index) {
            private$abort_if_no_child_impl()
        },

        # ------🔺 INPUTS ------------------------------------------------------

        process_multipart_content = function(inputs) {
            # Inputs can be a list of quosures from rlang::enquos(...)

            # Detect if user passed a list of inputs to chat() instead of chat(!!!inputs)
            # This is not perfect and will miss some cases, thus we only warn instead of aborting
            if (length(inputs) == 1 && rlang::is_quosure(inputs[[1]])) {
                content <- rlang::eval_tidy(inputs[[1]])
                if (
                    is.list(content) && 
                        length(content) > 1 &&
                        purrr::some(purrr::list_flatten(content), \(x) !is.null(attr(x, "argent_input_type")))
                ) {
                    expr <- rlang::quo_get_expr(inputs[[1]])
                    cli::cli_bullets(c(
                        "!" = cli::col_red("It looks like you passed a list of inputs to {.fn chat}. "),
                        "!" = cli::col_red("This might create issues with the API request."),
                        "i" = cli::col_blue("Did you mean to use {.code !!!{as.character(expr)}} ? "),
                        "i" = cli::col_blue("Or pass the elements directly: {.code chat(prompt1, prompt2, ...)} ?")
                    ))
                }
            }
            
            # Step 1: Evaluate quosures that result in character strings, keep others as quosures
            inputs <- purrr::map(inputs, \(input) {
                if (rlang::is_quosure(input)) {
                    content <- rlang::eval_tidy(input)
                    if (is.character(content) || 
                            (is.list(content) && !is.null(attr(content[[1]], "argent_input_type")))
                    ) {
                        return(content)
                    }
                    # Return original quosure for non-character R objects
                    return(input)
                }
                # Keep non-quosures as-is
                return(input)
            })
            
            # Step 2: Flatten list structures (after removing no-longer-necessary quosures)
            inputs <- purrr::list_flatten(inputs)
            
            # Step 3: Process each item
            parts <- purrr::map(inputs, \(input) private$process_multipart_input(input))

            # Step 4: Ensure the list is unnamed to avoid JSON serialization issues
            return(unname(parts))
        },

        process_multipart_input = function(input) {            
            if (!is.null(attr(input, "argent_input_type"))) {
                return(private$process_argent_input(input))
            } else if ("character" %ni% class(input)) {
                return(private$process_r_object_input(input))
            } else if (is_file(input) || is_url(input)) {
                return(private$process_file_or_url_input(input))
            } else if (is.character(input)) {
                return(private$text_input(input))
            } else {
                cli::cli_abort("Unsupported input type: {class(input)}")
            }
        },

        process_argent_input = function(input) {
            input_type <- attr(input, "argent_input_type")
            provider_options <- attr(input, "argent_provider_options")

            if (input_type == "file_ref") {
                return(rlang::exec(private$file_ref_input, input, !!!provider_options))
            } else if (input_type == "image") {
                return(rlang::exec(private$image_input, input, !!!provider_options))
            } else if (input_type == "pdf") {
                return(rlang::exec(private$pdf_input, input, !!!provider_options))
            } else if (input_type == "text") {
                return(rlang::exec(private$text_input, input, !!!provider_options))
            } else {
                cli::cli_abort("Unsupported input type: {input_type}")
            }
        },

        process_r_object_input = function(input) {
            tryCatch({
                return(private$text_input(to_json_str(input)))
            },
            error = function(e) {
                # If JSON conversion fails, try to_str() as fallback
                tryCatch({
                    return(private$text_input(to_str(input)))
                }, error = function(e2) {
                    cli::cli_abort(
                        "Unsupported input object. Could not convert to JSON or str().",
                        "i" = "Use {.fn as_text_content} or {.fn as_json_content} to convert, or do it manually."
                    )
                })
            })
        },

        process_file_or_url_input = function(input) {
            mime_type <- guess_input_type(input)

            if (stringr::str_detect(mime_type, "image")) {
                return(private$image_input(input)) # We let the child class handle the URL or file path of images
            } else if (stringr::str_detect(mime_type, "pdf")) {
                return(private$pdf_input(input)) # We let the child class handle the URL or file path of PDFs
            } else {
                # We try our 'universal' read_file() function and convert to JSON if it's a structured file
                input <- read_file(input)
                if (stringr::str_detect(mime_type, "csv|tab-separated-values|rds|json|yaml|excel")) {
                    return(private$process_r_object_input(input))
                } else {
                    # html, xml, txt, ...
                    return(private$text_input(input))
                }
            }
        },

        text_input = function(input, ...) {
            private$abort_if_no_child_impl()
        },

        image_input = function(input, ...) {
            private$abort_if_no_child_impl()
        },

        pdf_input = function(input, ...) {
            private$abort_if_no_child_impl()
        },

        file_ref_input = function(input, ...) {
            private$abort_if_no_child_impl()
        },

        # ------🔺 TOOLS -------------------------------------------------------

        add_active_tool = function(type, tool) {
            if (type == "client") {
                private$active_tools$client[[tool$name]] <- tool
            } else if (type == "mcp") {
                private$active_tools$mcp[[tool$name]] <- tool
            } else {
                cli::cli_abort("Invalid tool type: {type}")
            }
            invisible(self)
        },

        reset_active_tools = function() {
            private$active_tools <- list(mcp = list(), client = list())
            invisible(self)
        },

        is_tool_call = function(input) {
            if (!private$is_root(input)) {
                input <- private$extract_root(input)
            }
            tool_calls <- private$extract_tool_calls(input)
            return(!purrr::is_empty(tool_calls))
        },

        is_tool_result = function(input) {
            if (!private$is_root(input)) {
                input <- private$extract_root(input)
            }
            tool_res <- private$extract_tool_results(input)
            return(!purrr::is_empty(tool_res))
        },

        use_tools = function(api_resp) {
            tool_calls <- private$extract_root(api_resp) |>
                private$extract_tool_calls()

            if (is.null(tool_calls) || purrr::is_empty(tool_calls)) {
                return(NULL)
            }

            purrr::map(tool_calls, \(tool_call) private$use_tool(tool_call))
        },

        # Execute a tool call (dispatcher)
        use_tool = function(fn_name, args) {
            if (is.null(fn_name)) {
                cli::cli_abort("Tool call has no function name")
            }

            mcp_tool_def <- purrr::pluck(private$active_tools, "mcp", fn_name)
            client_tool_def <- purrr::pluck(private$active_tools, "client", fn_name)

            if (is.null(mcp_tool_def) && is.null(client_tool_def)) {
                cli::cli_abort(c(
                    "Tool {.val {fn_name}} not found in active tools",
                    "i" = "Available tools: {.val {names(c(private$active_tools$mcp, private$active_tools$client))}}"
                ))
            }

            if (!is.null(mcp_tool_def)) {
                return(private$use_mcp_tool(mcp_tool_def, args))
            } else {
                return(private$use_client_tool(client_tool_def, args))
            }
        },

        # Execute a client tool (R function)
        use_client_tool = function(tool_def, arguments) {
            fn_name <- tool_def$name

            # Check if function is stored in tool definition (supports closures)
            fn <- tool_def$.fn
            if (!is.null(fn)) {
                if (!is.function(fn)) {
                    cli::cli_abort("Client tool {.val {fn_name}} has invalid .fn field (not a function)")
                }
            } else {
                # Fall back to global environment lookup
                if (!exists(fn_name) || !is.function(get(fn_name))) {
                    cli::cli_abort("Client tool {.val {fn_name}} is not a function in the global environment")
                }
                fn <- get(fn_name)
            }

            cli::cli_alert_info(
                "[{self$provider_name}] Calling: {.emph {cli::col_yellow(format_tool_call(fn_name, arguments))}}"
            )

            output <- rlang::exec(fn, !!!arguments)

            if (purrr::is_empty(output)) {
                output <- "The tool returned nothing."
            }

            output_tagged <- list(
                name = fn_name,
                arguments = arguments,
                result = output
            )

            return(output_tagged)
        },

        # Execute an MCP tool call
        use_mcp_tool = function(tool_def, arguments) {
            fn_name <- tool_def$name

            cli::cli_alert_info(
                "[{self$provider_name}] Calling MCP tool: {.emph {cli::col_blue(format_tool_call(fn_name, arguments))}}"
            )

            # Execute MCP tool via the helper function in R/tools-mcp.R
            # Note: execute_mcp_tool returns errors as results (isError = TRUE) instead of throwing
            output <- execute_mcp_tool(tool_def, arguments)

            # Check if MCP tool returned an error
            if (is.list(output) && isTRUE(output$isError)) {
                error_msg <- output$error$message %||% "Unknown MCP error"
                error_code <- output$error$code %||% "Unknown"

                cli::cli_alert_danger(
                    "[{self$provider_name}] MCP tool {.val {fn_name}} returned error {error_code}: {error_msg}"
                )

                # Format error as a result that the LLM can read and respond to
                output <- paste0(
                    "Error calling ", fn_name, " (code ", error_code, "): ", error_msg
                )
            }

            if (purrr::is_empty(output)) {
                output <- "The tool returned nothing."
            }

            # Return in same format as use_client_tool
            output_tagged <- list(
                name = fn_name,
                arguments = arguments,
                result = output
            )

            return(output_tagged)
        },

        # ------🔺 REQUESTS ----------------------------------------------------

        # Create base HTTP request
        base_request = function(endpoint, headers = list(`Content-Type` = "application/json")) {
            # Validate API key
            if (is.null(private$api_key) || private$api_key == "") {
                cli::cli_abort("[{self$provider_name}] API key not set")
            }

            req <- httr2::request(endpoint)

            # Add headers
            if (length(headers) > 0) {
                req <- httr2::req_headers(req, !!!headers)
            }

            # Add authentication (child classes override add_auth)
            req <- private$add_auth(req)

            # Common configuration
            req <- req |>
                httr2::req_error(is_error = \(resp) FALSE) |>
                httr2::req_timeout(getOption("argent.timeout", default = 60)) |>
                httr2::req_retry(
                    max_tries = 2,
                    retry_on_failure = TRUE,
                    is_transient = \(resp) is_transient_http_error(resp),
                    backoff = ~5
                )

            # Add rate limiting if rate_limit is set
            if (!is.null(self$rate_limit)) {
                req <- httr2::req_throttle(req, rate = self$rate_limit, realm = tolower(self$provider_name))
            }

            return(req)
        },

        # Add authentication to request (ABSTRACT - must override in child classes)
        add_auth = function(req) {
            private$abort_if_no_child_impl()
        },

        # Execute HTTP request with standardized error handling
        request = function(endpoint, query_data = NULL, headers = list(`Content-Type` = "application/json")) {
            req <- private$base_request(endpoint, headers = headers)

            # Add JSON body if provided
            if (!is.null(query_data)) {
                req <- httr2::req_body_json(req, query_data)
            }

            # Execute request with optional debug verbosity
            verbosity <- if (isTRUE(getOption("argent.debug", default = FALSE))) 3 else 0
            resp <- httr2::req_perform(req, verbosity = verbosity)

            # Check response has body
            if (!httr2::resp_has_body(resp)) {
                cli::cli_alert_danger("[{self$provider_name}] No response body")
                return(NULL)
            }

            # Check content type
            if (httr2::resp_content_type(resp) == "application/json") {
                resp <- httr2::resp_body_json(resp)

                if ("error" %in% names(resp) && !is.null(resp$error)) {
                    cli::cli_alert_danger("[{self$provider_name}] Error in API request:")
                    cat(purrr::pluck(resp, "error", "message", .default = "Unknown error"), "\n", sep = "")
                    return(NULL)
                }
            }

            return(resp)
        },

        list = function(endpoint) {
            private$abort_if_no_child_impl()
        },

        find = function(endpoint, ...) {
            silent_semi_join(private$list(endpoint), data.frame(...))
        },

        delete = function(endpoint, id) {
            private$abort_if_no_child_impl()
        },

        # ------🔺 EXTRACTION --------------------------------------------------
        # Abstract extraction methods (implemented by child classes)

        extract_root = function(input) {
            private$abort_if_no_child_impl()
        },

        extract_role = function(root) {
            private$abort_if_no_child_impl()
        },

        extract_content = function(root) {
            private$abort_if_no_child_impl()
        },

        extract_content_text = function(answer) {
            private$abort_if_no_child_impl()
        },

        extract_reasoning = function(root) {
            private$abort_if_no_child_impl()
        },

        extract_reasoning_text = function(reasoning) {
            private$abort_if_no_child_impl()
        },

        extract_tool_calls = function(root) {
            private$abort_if_no_child_impl()
        },

        extract_tool_call_name = function(tool_call) {
            private$abort_if_no_child_impl()
        },

        extract_tool_call_args = function(tool_call) {
            private$abort_if_no_child_impl()
        },

        extract_tool_results = function(root) {
            private$abort_if_no_child_impl()
        },

        extract_tool_result_content = function(tool_result) {
            private$abort_if_no_child_impl()
        },

        extract_tool_result_name = function(tool_result) {
            private$abort_if_no_child_impl()
        },

        extract_generated_code = function(root) {
            private$abort_if_no_child_impl()
        },

        extract_generated_files = function(input) {
            private$abort_if_no_child_impl()
        },

        extract_supplementary = function(api_res) {
            private$abort_if_no_child_impl()
        },

        is_root = function(input) {
            private$abort_if_no_child_impl()
        },

        extract_input_token_count = function(input) {
            private$abort_if_no_child_impl()
        },

        extract_output_token_count = function(output) {
            private$abort_if_no_child_impl()
        },

        extract_total_token_count = function(input) {
            private$abort_if_no_child_impl()
        },

        extract_tool_definitions = function(entry_data) {
            private$abort_if_no_child_impl()
        },

        extract_system_instructions = function(entry_data) {
            private$abort_if_no_child_impl()
        },

        extract_output_schema = function(entry_data) {
            private$abort_if_no_child_impl()
        },

        # ------🔺 PRINT -------------------------------------------------------

        format_session_entry = function(
            entry,
            show_system = TRUE,
            show_reasoning = TRUE,
            show_code = FALSE,
            show_tools = FALSE,
            show_supplementary = FALSE,
            show_output_schema = TRUE,
            max_content_length = NULL
        ) {
            index <- purrr::pluck(entry, "index", .default = 0)
            type <- purrr::pluck(entry, "type", .default = "unknown")
            turn_tokens <- purrr::pluck(entry, "tokens", .default = 0)
            cumulative_tokens <- self$get_session_cumulative_token_count(up_to_index = index + 1)
            entry_data <- purrr::pluck(entry, "data")
            
            turn_contents <- private$extract_root(entry_data)
            if (type == "query") {
                # Since queries/API calls keep a history of the turns, we only need the last input.
                # For the 'responses' API structure, this is more complex than just taking the last element.
                turn_contents <- private$extract_session_history_query_last_turn(turn_contents, index)
            }

            # Starting from here, turn_contents == root
            if (is.null(turn_contents)) {
                cli::cli_alert_info("No content available for this turn.")
                return(invisible(NULL))
            }

            role <- private$extract_role(turn_contents)
            if (role == "user") {
                is_tool_result <- private$is_tool_result(turn_contents)
                if (is_tool_result) {
                    role <- "tool"
                }
            }

            if (role == "user") cat("\n")
            cli::cli_h1("{color_role(role)} [{.val {turn_tokens}} / {.val {cumulative_tokens}}]")

            if (type == "query") {
                if (isTRUE(show_tools)) {
                    tool_results <- private$extract_tool_results(turn_contents)
                    if (!purrr::is_empty(tool_results)) {
                        private$display_tool_results(tool_results, max_content_length)
                    }
                }
            }

            if (type == "response") {
                if (isTRUE(show_reasoning)) {
                    reasoning_text <- private$extract_reasoning_text(turn_contents)
                    if (!purrr::is_empty(reasoning_text)) {
                        private$display_reasoning(reasoning_text, max_content_length)
                    }
                }
                if (isTRUE(show_code)) {
                    code_parts <- private$extract_generated_code(turn_contents)
                    if (!purrr::is_empty(code_parts)) {
                        private$display_generated_code(code_parts)
                    }
                }
                if (isTRUE(show_supplementary)) {
                    supplementary_data <- private$extract_supplementary(entry_data) # Not necessarily in root
                    if (!purrr::is_empty(supplementary_data)) {
                        private$display_supplementary(supplementary_data)
                    }
                }
            }

            # Display text content (skip for tool/function roles)
            if (role %ni% c("tool", "function")) {
                content <- private$extract_content_text(turn_contents)
                if (!purrr::is_empty(content)) {
                    private$display_content(content, max_content_length)
                }
            }

            if (type == "query") {
                if (role == "user") {
                    if (isTRUE(show_system)) {
                        system_instructions <- private$extract_system_instructions(entry_data) # Not necessarily in root
                        if (!purrr::is_empty(system_instructions)) {
                            private$display_system_instructions(system_instructions)
                        }
                    }
                    # Only show the tool definitions for the first user request (since they do not change)
                    if (isTRUE(show_tools)) {
                        tool_definitions <- private$extract_tool_definitions(entry_data) # Not in root
                        if (!purrr::is_empty(tool_definitions)) {
                            private$display_tool_definitions(tool_definitions)
                        }
                    }
                    if (isTRUE(show_output_schema)) {
                        output_schema <- private$extract_output_schema(entry_data) # Not in root
                        if (!purrr::is_empty(output_schema)) {
                            private$display_output_schema(output_schema)
                        }
                    }
                }
            }

            if (type == "response") {
                if (isTRUE(show_tools)) {
                    tool_calls <- private$extract_tool_calls(turn_contents)
                    if (!purrr::is_empty(tool_calls)) {
                        private$display_tool_calls(tool_calls)
                    }
                }
            }

            invisible(NULL)
        },

        display_system_instructions = function(system_instructions) {
            cli::cli_h2(cli::col_magenta("System"))
            cat(cli::col_magenta(system_instructions), "\n\n", sep = "")
        },

        display_tool_definitions = function(tool_definitions) {
            cli::cli_h2(cli::col_yellow("Tool Definitions"))
            formatted_tool_definitions <- purrr::map_chr(tool_definitions, \(tool) format_tool_definition(tool))
            purrr::walk(formatted_tool_definitions, \(tool) cli::cli_bullets(c("*" = cli::col_yellow(tool))))
        },

        display_reasoning = function(reasoning_text, max_content_length = NULL) {
            reasoning_text <- paste(reasoning_text, collapse = "\n")
            if (nzchar(reasoning_text) && !reasoning_text %in% c("\n", "")) {
                if (!is.null(max_content_length) && nchar(reasoning_text) > max_content_length) {
                    reasoning_text <- paste0(substr(reasoning_text, 1, max_content_length), "...")
                }
                cli::cli_h2(cli::col_grey("Thinking"))
                cat(cli::col_grey(cli::style_italic(reasoning_text)), "\n\n", sep = "")
            }
        },

        display_tool_calls = function(tool_calls) {
            cli::cli_h2(cli::col_yellow("Tool Calls"))
            formatted_calls <- purrr::map_chr(tool_calls, \(tc) {
                format_tool_call(
                    private$extract_tool_call_name(tc),
                    private$extract_tool_call_args(tc)
                )
            })
            purrr::walk(formatted_calls, \(tool) cli::cli_bullets_raw(c("*" = cli::col_yellow(tool))))
        },

        display_tool_results = function(tool_results, max_content_length = NULL) {
            formatted_results <- purrr::map(tool_results, \(tr) {
                format_tool_result(
                    private$extract_tool_result_name(tr),
                    private$extract_tool_result_content(tr)
                )
            })
            purrr::walk(formatted_results, \(result) {
                content <- result$content
                if (!is.null(max_content_length) && nchar(content) > max_content_length) {
                    content <- paste0(substr(content, 1, max_content_length), "...")
                }
                cat("\n")
                cli::cli_bullets(c("*" = cli::col_yellow(result$header)))
                cat("\n")
                cat(cli::col_yellow(content), sep = "")
                cat("\n")
            })
        },

        display_generated_code = function(code_parts) {
            cli::cli_h2(cli::col_red("Generated Code"))
            purrr::walk(code_parts, \(part) {
                code <- part$code
                if (is.null(code) || !nzchar(code)) {
                    return(NULL)
                }
                lang <- part$language %||% "plain"
                cat(cli::col_red(format_code_block(code, language = lang)), "\n", sep = "")
            })
        },

        display_supplementary = function(supplementary_data) {
            cli::cli_h2(cli::col_cyan("Supplementary Data"))
            cat(cli::col_cyan(yaml::as.yaml(supplementary_data)), "\n", sep = "")
        },

        display_output_schema = function(output_schema) {
            cli::cli_h2(cli::col_green("Output Schema"))
            cat(cli::col_green(yaml::as.yaml(output_schema)), "\n", sep = "")
        },

        display_content = function(content, max_content_length = NULL) {
            content <- paste(content, collapse = "\n")
            if (nzchar(content)) {
                if (!is.null(max_content_length) && nchar(content) > max_content_length) {
                    content <- paste0(substr(content, 1, max_content_length), "...")
                }
                cat("\n")
                cat(stringr::str_squish(content), "\n", sep = "")
            }
        },

        # ------🔺 UTILS -------------------------------------------------------

        # Abort if the current class is a the abstract Provider class
        abort_if_no_child_impl = function(method_name = NULL) {
            caller_expr <- deparse(sys.calls()[[sys.nframe() - 1]])
            caller_name <- sub("^([^$]+)\\$.*$", "\\1", caller_expr)
            if (caller_name == "self") {
                # Extract the method name from the calling expression if not provided
                if (is.null(method_name)) {
                    method_name <- sub("^.*\\$([^(]+)\\(.*$", "\\1", caller_expr)
                }
                first_class <- purrr::pluck(class(self), 1)
                cli::cli_abort("`{method_name}` must be implemented by child class `{first_class}`")
            }
        }
    )
)
