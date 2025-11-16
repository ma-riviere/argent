#' Client for OpenAI's Assistants API
#'
#' @description
#' R6 class for interacting with OpenAI's Assistants API. Provides methods for creating and
#' managing assistants and threads.
#'
#' @section Deprecation Notice:
#' **DEPRECATED:** OpenAI has deprecated the Assistants API in favor of the Responses API. It will shut down on August 26, 2026.
#'
#' Users should migrate to the [Responses API](responses-api.html) instead.
#'
#' For more information, see: https://platform.openai.com/docs/assistants/migration
#'
#' @section History Management:
#' The Assistants API uses server-side thread state for conversation history. However,
#' this class maintains client-side `session_history` for tracking conversations with token counts.
#' - `chat_history` methods are overridden and not applicable (server-side threads)
#' - `session_history` is maintained for use with `print()` and token tracking
#' - Use `get_thread_msgs()` to retrieve server-side conversation history
#' - Use `get_history()` or `get_session_history()` for client-side tracking 
#'
#' @section Features:
#' - Server-side state management with threads
#' - File search with vector stores
#' - Code execution in sandboxed containers
#'
#' @section Useful links:
#' - API reference: https://platform.openai.com/docs/api-reference/assistants
#' - API docs: https://platform.openai.com/docs/assistants/deep-dive
#'
#' @field assistant List. Current assistant object
#' @field thread List. Current thread object
#' @field provider_name Character. Provider name (OpenAI Assistant)
#' @field server_tools Character vector. Server-side tools to use for API requests
#'
#' @section Server-side tools:
#' - "file_search" for file search with vector stores
#' - "code_interpreter" for Python code execution in sandboxed containers
#'
#' @export
#' @examples
#' \dontrun{
#' # Initialize client
#' assistant <- OpenAI_Assistant$new()
#'
#' # Create a new assistant
#' assistant$create_assistant(
#'   name = "My Assistant",
#'   model = "gpt-4o",
#'   instructions = "You are a helpful assistant"
#' )
#'
#' # Or load an existing assistant
#' assistant$load_assistant(id = "asst_...")
#'
#' # Send a message
#' response <- assistant$chat("Hello!")
#'
#' # Create assistant with tools
#' assistant <- OpenAI_Assistant$new()
#' assistant$create_assistant(
#'   name = "Research Assistant",
#'   model = "gpt-4o",
#'   instructions = "Research assistant with web access",
#'   tools = list(
#'     list(type = "file_search", store_ids = list(store_id)),
#'     list(
#'       name = "web_search",
#'       description = "Search the web",
#'       parameters = list(
#'         type = "object",
#'         properties = list(query = list(type = "string", description = "The search query"))
#'       )
#'     )
#'   )
#' )
#'
#' # Code execution with embedded file resources
#' assistant <- OpenAI_Assistant$new()
#' assistant$create_assistant(
#'   name = "Data Analyst",
#'   model = "gpt-4o",
#'   tools = list(list(type = "code_interpreter", file_ids = list(file_id)))
#' )
#'
#' # Using PDFs and files in messages
#' # PDFs are automatically uploaded and attached to messages
#' assistant <- OpenAI_Assistant$new()
#' assistant$create_assistant(
#'   name = "Document Analyst",
#'   model = "gpt-4o",
#'   tools = list(list(type = "file_search"))
#' )
#' response <- assistant$chat("Summarize this document", "path/to/document.pdf")
#' }
OpenAI_Assistant <- R6::R6Class( # nolint
    classname = "OpenAIAssistant",
    inherit = OpenAI,
    # DEPRECATION: This class implements OpenAI's deprecated Assistants API.
    # OpenAI announced deprecation in favor of the Responses API, with shutdown on August 26, 2026.
    # The Assistants API uses threads and runs, requiring polling for completion status.
    # The newer Responses API offers a simpler input/output model with better performance.
    # Users should migrate to OpenAI_Responses (see R/openai_responses.R) for new projects.
    public = list(
        provider_name = "OpenAI Assistant",
        server_tools = c("file_search", "code_interpreter"),
        assistant = NULL,
        thread = NULL,

        # ------🔺 INIT --------------------------------------------------------
        
        #' @description
        #' Initialize a new OpenAI Assistant client
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
            cli::cli_alert_warning(c(
                "!" = "The Assistants API is deprecated and will shut down on August 26, 2026.\n",
                "i" = "Migrate to the OpenAI_Responses class (see R/openai_responses.R).\n",
                "i" = "See: https://platform.openai.com/docs/assistants/migration"
            ))

            super$initialize(api_key, org, base_url, rate_limit, auto_save_history)
        },

        # ------🔺 MODELS ------------------------------------------------------

        #' @description
        #' Override list_models to warn about gpt-5 incompatibility
        #' @return Data frame. Available models
        list_models = function() {
            cli::cli_alert_warning(
                "[{self$provider_name}] Note: gpt-5-* models are not supported for Assistants API."
            )
            super$list_models()
        },

        # ------🔺 CHAT HISTORY OVERRIDES (server-side state) ------------------
        # OpenAI_Assistant uses server-side thread state, so client-side history
        # methods are not applicable. Override to prevent misuse.

        #' @description
        #' Get chat history from the current thread (server-side state).
        #' Returns the content array from the thread messages.
        #' @return List. The content array from thread messages, or NULL if no thread exists.
        get_chat_history = function() {
            if (is.null(self$thread)) {
                cli::cli_alert_info("No active thread. Chat history is empty.")
                return(NULL)
            }

            msgs <- private$get_thread_msgs(self$thread$id)
            return(purrr::pluck(msgs, "data", 1, "content", .default = NULL))
        },

        #' @description
        #' Dump chat history (not applicable - server-side state)
        #' @param file_path Character. File path
        dump_chat_history = function(file_path = NULL) {
            cli::cli_abort("Chat history is managed server-side. Use get_thread_msgs().")
        },

        #' @description
        #' Load chat history (not applicable - server-side state)
        #' @param file_path Character. File path
        load_chat_history = function(file_path) {
            cli::cli_abort("Chat history is managed server-side. Use add_msg_to_thread().")
        },

        #' @description
        #' Get total tokens (not applicable - per-run tracking)
        get_total_tokens = function() {
            cli::cli_abort("Token usage is tracked per-run. Check run.usage after run_thread().")
        },

        # ------🔺 ASSISTANTS --------------------------------------------------

        #' @description
        #' Get the current assistant.
        #' @return The current assistant.
        get_assistant = function() {
            return(self$assistant)
        },

        #' @description
        #' Get the ID of the current assistant.
        #' @return The ID of the current assistant.
        get_assistant_id = function() {
            return(self$assistant$id)
        },

        #' @description
        #' Set the current assistant by ID.
        #' @param assistant_id The ID of the assistant to set.
        set_assistant_id = function(assistant_id) {
            self$assistant <- self$read_assistant(assistant_id)
        },

        #' @description
        #' Create a new assistant
        #' @param name Character. Name of the assistant
        #' @param model Character. Model to use (default: "gpt-4o")
        #' @param system Character. System instructions (default: .default_system_prompt)
        #' @param temperature Numeric. Sampling temperature 0-2 (default: 1)
        #' @param top_p Numeric. Nucleus sampling parameter 0-1 (default: 1). Alternative to temperature.
        #'   We recommend altering this or temperature but not both.
        #' @param tools List. Tool definitions (optional). Supports three formats:
        #'   - String form: "file_search", "code_interpreter"
        #'   - List form with resources: list(type = "file_search", store_ids = list("vs_123"))
        #'     or list(type = "code_interpreter", file_ids = list("file-123"))
        #'   - Client-side functions: created with the `as_tool(fn)` or `tool()` helpers
        #' @param response_format Character. Response format: "auto" (default), or list for JSON schema
        #' @return The assistant object (invisibly)
        #' @examples
        #' \dontrun{
        #' assistant <- OpenAI_Assistant$new()
        #' assistant$create_assistant(
        #'   name = "My Assistant",
        #'   model = "gpt-4o",
        #'   system = "You are a helpful assistant"
        #' )
        #' }
        create_assistant = function(
            name,
            model = "gpt-4o",
            system = .default_system_prompt,
            temperature = 1,
            top_p = 1,
            tools = NULL,
            response_format = "auto"
        ) {

            if (!is.null(self$assistant)) {
                cli::cli_abort("An assistant already exists. Delete it first or create a new client.")
            }

            assistant_params <- list(
                name = name,
                model = model,
                instructions = system,
                temperature = temperature,
                top_p = top_p,
                response_format = response_format
            )

            tool_resources <- NULL

            if (!is.null(tools)) {
                extracted_code_exec_file_ids <- list()
                extracted_file_search_config <- NULL

                assistant_params$tools <- purrr::map(tools, \(tool) {
                    if (is_server_tool(tool, c("code_interpreter", "code_execution"))) {
                        if (is.list(tool) && !is.null(tool$file_ids)) {
                            extracted_code_exec_file_ids <<- c(
                                extracted_code_exec_file_ids,
                                as.list(tool$file_ids)
                            )
                        }
                        return(list(type = "code_interpreter"))
                    } else if (is_server_tool(tool, "file_search")) {
                        if (is.character(tool)) {
                            return(list(type = "file_search"))
                        }
                        # Extract resources from list-form file_search tool
                        if (is.list(tool)) {
                            # Extract store_ids and map to vector_store_ids
                            if (!is.null(tool$store_ids)) {
                                store_ids <- as.list(tool$store_ids)
                                if (is.null(extracted_file_search_config)) {
                                    extracted_file_search_config <<- list()
                                }
                                existing_stores <- extracted_file_search_config$vector_store_ids %||% list()
                                extracted_file_search_config$vector_store_ids <<- c(existing_stores, store_ids)
                            }
                        }
                        return(list(type = "file_search"))
                    } else if (is.character(tool)) {
                        cli::cli_abort(c(
                            "[{self$provider_name}] Invalid server tool: {tool}.",
                            "i" = "Valid tools: {.field {list('file_search', 'code_interpreter', 'code_execution')}}."
                        ))
                    }

                    tool <- as_tool_openai(tool)

                    if ("name" %in% names(tool) && "parameters" %in% names(tool)) {
                        tool$type <- NULL
                        return(list(type = "function", `function` = tool))
                    }
                    return(tool)
                })

                # Merge extracted code_interpreter resources
                if (length(extracted_code_exec_file_ids) > 0) {
                    if (is.null(tool_resources)) {
                        tool_resources <- list()
                    }
                    if (is.null(tool_resources$code_interpreter)) {
                        tool_resources$code_interpreter <- list()
                    }
                    existing_ids <- tool_resources$code_interpreter$file_ids %||% list()
                    tool_resources$code_interpreter$file_ids <- c(existing_ids, extracted_code_exec_file_ids)
                }

                # Merge extracted file_search resources
                if (!is.null(extracted_file_search_config)) {
                    if (is.null(tool_resources)) {
                        tool_resources <- list()
                    }
                    if (is.null(tool_resources$file_search)) {
                        tool_resources$file_search <- list()
                    }
                    # Merge vector_store_ids
                    if (!is.null(extracted_file_search_config$vector_store_ids)) {
                        existing_stores <- tool_resources$file_search$vector_store_ids %||% list()
                        tool_resources$file_search$vector_store_ids <-
                            c(existing_stores, extracted_file_search_config$vector_store_ids)
                    }
                }
            }

            if (!is.null(tool_resources)) {
                if (!is.null(tool_resources$file_search) &&
                        !is.null(tool_resources$file_search$vector_store_ids)) {
                    if (!is.list(tool_resources$file_search$vector_store_ids)) {
                        tool_resources$file_search$vector_store_ids <-
                            as.list(tool_resources$file_search$vector_store_ids)
                    }
                }
                if (!is.null(tool_resources$code_interpreter) &&
                        !is.null(tool_resources$code_interpreter$file_ids)) {
                    if (!is.list(tool_resources$code_interpreter$file_ids)) {
                        tool_resources$code_interpreter$file_ids <-
                            as.list(tool_resources$code_interpreter$file_ids)
                    }
                }
                assistant_params$tool_resources <- tool_resources
            }

            private$validate_api_call(assistant_params)

            res <- private$request(paste0(self$base_url, "/v1/assistants"), assistant_params)

            if (purrr::is_empty(res)) {
                cli::cli_abort("Assistant creation failed")
            }

            self$assistant <- res

            if (getOption("argent.verbose", TRUE)) {
                cli::cli_alert_success("[{self$provider_name}] Assistant created: {self$assistant$id}")
                private$display_assistant_info()
            }

            invisible(self)
        },

        #' @description
        #' Load an existing assistant by ID
        #' @param id Character. Assistant ID to load
        #' @return The assistant object (invisibly)
        #' @examples
        #' \dontrun{
        #' assistant <- OpenAI_Assistant$new()
        #' assistant$load_assistant(id = "asst_...")
        #' }
        load_assistant = function(id) {
            if (!is.null(self$assistant)) {
                cli::cli_abort("An assistant is already loaded. Create a new client to load a different assistant.")
            }

            if (getOption("argent.verbose", TRUE)) {
                cli::cli_text("[{self$provider_name}] Loading assistant: {id}")
            }

            self$assistant <- self$read_assistant(id)

            if (getOption("argent.verbose", TRUE)) {
                private$display_assistant_info()
            }

            invisible(self$assistant)
        },

        #' @description
        #' Read an assistant.
        #' @param assistant_id The ID of the assistant to read.
        #' @return The assistant object.
        read_assistant = function(assistant_id = self$assistant$id) {
            res <- private$request(paste0(self$base_url, "/v1/assistants/", assistant_id))
            res$created_at <- lubridate::as_datetime(res$created_at)
            return(res)
        },

        #' @description
        #' Delete an assistant.
        #' @param assistant_id The ID of the assistant to delete.
        #' @return The deletion status.
        delete_assistant = function(assistant_id = self$assistant$id) {
            if (is.null(assistant_id)) {
                cli::cli_alert_warning("No assistant to delete")
                return(NULL)
            }

            if (!is.null(self$thread)) {
                private$delete_thread(self$thread$id)
                self$thread <- NULL
            }

            res <- private$delete(paste0(self$base_url, "/v1/assistants/"), assistant_id)
            cli::cli_alert_success("[{self$provider_name}] Assistant deleted: {assistant_id}")

            self$assistant <- NULL

            invisible(res)
        },

        #' @description
        #' Delete an assistant and its contents.
        #' @param assistant_id The ID of the assistant to delete.
        #' @return A list with the deletion status for the assistant and its contents.
        delete_assistant_and_contents = function(assistant_id = self$assistant$id) {
            assistant_info <- self$read_assistant(assistant_id = assistant_id)

            # Delete stores and their files (now using inherited methods from OpenAI)
            store_ids <- purrr::list_c(assistant_info$tool_resources$file_search$vector_store_ids %||% list())
            store_deletion_res <- purrr::map(store_ids, self$delete_store_and_files)

            # Delete assistant
            assistant_deletion_res <- self$delete_assistant(assistant_id = assistant_id)

            cli::cli_alert_success("[{self$provider_name}] Assistant and contents deleted: {assistant_id}")

            invisible(list(
                stores = purrr::list_c(store_deletion_res),
                assistant = assistant_deletion_res
            ))
        },

        # ------🔺 CHAT --------------------------------------------------------

        #' @description
        #' Send a chat message to the assistant.
        #'
        #' Note: Unlike OpenAI$chat(), assistant configuration (model, temperature, tools, system)
        #' is set during initialization and cannot be changed per-chat.
        #'
        #' After sending a message, you can use base class methods like `get_content_text()`,
        #' `get_supplementary()`, or `download_generated_files()` to extract information from responses.
        #'
        #' @param ... One or more inputs for the prompt. Can be text strings, file paths, URLs, R objects,
        #'   or content wrapped with `as_*_content()` functions. R objects (but not plain strings) will
        #'   include their names and structure in the context sent to the model.
        #' @param in_new_thread Logical. Start new thread (default: FALSE).
        #'   Assistant-specific: Controls thread management. Set TRUE to start a fresh conversation.
        #' @param output_schema List. JSON schema for structured output (optional).
        #'   When assistant uses server tools, forces a second call with only the schema to ensure structured output.
        #' @param remove_citations Logical. Remove file_search citation markers (default: TRUE).
        #'   When TRUE, removes citation markers like 【35†source】 and \[3:0†source\] from responses.
        #'   Only applies when return_full_response = FALSE.
        #' @param return_full_response Logical. Return full message object (default: FALSE).
        #'   If FALSE, returns only the text content via cat(). If TRUE, returns complete message object.
        #' @return Character (or List if return_full_response = TRUE). OpenAI Assistant API's response object.
        chat = function(
            ...,
            in_new_thread = FALSE,
            output_schema = NULL,
            remove_citations = TRUE,
            return_full_response = FALSE
        ) {

            # Ensure assistant is loaded
            if (is.null(self$assistant)) {
                cli::cli_abort(c(
                    "No assistant loaded",
                    "Use {.fun create_assistant} to create a new one, or {.fun load_assistant} to load an existing one."
                ))
            }

            # ---- Setup thread ----

            # Capture prompt inputs as quosures
            inputs <- rlang::enquos(...)
            
            # Process multipart content
            processed_prompt <- private$process_multipart_content(inputs)
            if (is.null(processed_prompt)) {
                cli::cli_abort("No prompt provided")
            }

            # Determine if we need to create a new thread
            create_new <- is.null(self$thread) ||  # No thread exists
                (!is.null(self$thread) && purrr::is_empty(private$read_thread(self$thread$id))) ||  # Thread is dead
                in_new_thread  # User explicitly requested new thread

            if (create_new) {
                # Reset history when starting a new thread (similar to previous_response_id in Responses API)
                self$reset_history()
                self$thread <- private$create_thread()
            }

            # ---- Make API request ----

            # Separate content from attachments
            separated <- private$separate_attachments(processed_prompt)

            # Always add message to thread (whether new or existing)
            init_msg <- private$add_msg_to_thread(
                query = separated$content,
                attachments = separated$attachments
            )

            # Determine if we can pass response_format directly (no server tools + schema provided)
            use_direct_schema <- is.list(output_schema) && !private$has_server_tools()

            # Run the thread with optional response_format
            if (use_direct_schema) {
                init_run <- private$run_thread(
                    response_format = list(
                        type = "json_schema",
                        json_schema = as_schema_openai(output_schema)
                    )
                )
            } else {
                init_run <- private$run_thread()
            }

            init_run <- private$get_thread_run_info(run_id = init_run$id)

            # ---- Saving to session history ----
            
            query_data <- init_run
            query_data$role <- init_msg$role
            query_data$content <- init_msg$content
            private$append_to_session_history(
                type = "query",
                data = query_data,
                tokens = private$extract_total_token_count(init_run)
            )

            # ---- Handle response ----

            run_id <- init_run$id
            run_status <- init_run$status

            while (run_status != "completed") {

                if (run_status == "failed") {
                    cli::cli_abort("Assistant run failed (server-side error). Please try again.")
                    cli::cli_text("Run data: \n {jsonlite::toJSON(run, pretty = TRUE, auto_unbox = TRUE)}")
                }

                run <- private$get_thread_run_info(run_id = run_id)
                run_status <- run$status

                # ---- Tool calls ----

                if (run_status == "requires_action") {

                    res_data <- run
                    res_data$tools <- NULL
                    res_data$role <- "assistant"
                    private$append_to_session_history(
                        type = "response",
                        data = res_data,
                        tokens = private$extract_total_token_count(run)
                    )

                    if (run$required_action$type == "submit_tool_outputs") {

                        tool_res <- private$use_tools(run)
                        submit_output_res <- private$submit_tool_outputs(run_id = run_id, tool_outputs = tool_res)

                        # WARN: We should save the API call that submit_tool_outputs() is sending as the query here ...
                        private$append_to_session_history(
                            type = "query",
                            data = list(role = "tool", content = tool_res),
                            tokens = 0
                        )
                    } else {
                        cli::cli_alert_warning(
                            "[{self$provider_name}] Unsupported required action type: {run$required_action$type}"
                        )
                    }
                }

                Sys.sleep(1)

                # ---- Completed run ----

                if (run_status == "completed") {

                    # Force a JSON response when schema provided AND server tools exist (two-call approach)
                    if (is.list(output_schema) && private$has_server_tools()) {

                        private$append_to_session_history(
                            type = "response",
                            data = private$get_thread_last_msg(),
                            tokens = private$extract_total_token_count(run)
                        )

                        run <- private$create_and_run_thread(
                            query = "Use the provided JSON schema to format the response to the last user query.",
                            tools = list(),
                            tool_resources = NULL,
                            response_format = list(
                                type = "json_schema",
                                json_schema = as_schema_openai(output_schema)
                            )
                        )

                        self$thread <- private$read_thread(run$thread_id)
                        run_id <- run$id
                        run_status <- run$status

                        output_schema <- TRUE

                    } else {
                        assistant_msg <- private$get_thread_last_msg()

                        if (use_direct_schema || purrr::is_empty(output_schema)) {
                            private$append_to_session_history(
                                type = "response",
                                data = assistant_msg,
                                tokens = private$extract_total_token_count(run)
                            )
                        }

                        if (!isTRUE(return_full_response)) {
                            res_text <- self$get_content_text(assistant_msg)

                            # Remove citations if requested
                            if (remove_citations) {
                                res_text <- gsub("\u3010[0-9]+\u2020source\u3011", "", res_text)
                                res_text <- gsub("\\[[0-9]+:[0-9]+\u2020source\\]", "", res_text)
                            }

                            # Return parsed JSON if schema was used (either direct or two-call)
                            if (use_direct_schema || isTRUE(output_schema)) {
                                return(jsonlite::fromJSON(res_text, simplifyDataFrame = FALSE))
                            } else {
                                return(res_text)
                            }
                        }
                        return(assistant_msg)
                    }
                }
            }
        }
    ),
    private = list(

        # ------🔺 CHAT HISTORY OVERRIDES (server-side state) ------------------
        # These methods are private in Provider, so they must be private here too

        reset_chat_history = function() {
            # Chat history is managed server-side.
        },

        set_chat_history = function(history) {
            # Chat history is managed server-side.
        },

        append_to_chat_history = function(new) {
            # Chat history is managed server-side. Use add_msg_to_thread().
        },

        # ------🔺 INPUTS ------------------------------------------------------

        text_input = function(input, ...) {
            list(type = "text", text = input)
        },

        image_input = function(input, detail = NULL, ...) {
            # OpenAI supports: PNG (.png) - JPEG (.jpeg and .jpg) - WEBP (.webp) - Non-animated GIF (.gif)
            supported_formats <- c("png", "jpeg", "jpg", "webp", "gif")
            ext <- tolower(tools::file_ext(input))

            if (!ext %in% supported_formats) {
                cli::cli_abort(c(
                    "[{self$provider_name}] Unsupported image format: {.val {ext}}",
                    "i" = "Supported formats: {.val {supported_formats}}"
                ))
            }

            # For URLs, use image_url format
            if (is_url(input)) {
                result <- list(type = "image_url", image_url = list(url = input))
                if (!is.null(detail)) {
                    result$image_url$detail <- detail
                }
                return(result)
            }

            # For local files, upload with purpose="vision" and use image_file format
            uploaded_file <- self$upload_file(input, purpose = "vision")

            result <- list(type = "image_file", image_file = list(file_id = uploaded_file$id))

            # Add detail parameter if provided (low/high/auto)
            if (!is.null(detail)) {
                result$image_file$detail <- detail
            }

            return(result)
        },

        pdf_input = function(input, tools = list(list(type = "file_search")), ...) {
            # Upload the PDF file with purpose="assistants" (URLs are handled by upload_file)
            file_obj <- self$upload_file(input, purpose = "assistants")

            # Return attachment format (distinguished from content by having file_id at root)
            return(list(
                file_id = file_obj$id,
                tools = tools
            ))
        },

        file_ref_input = function(input, tools = list(list(type = "file_search")), ...) {

            if (is.list(input)) {
                file_id <- input$id
            } else {
                file_id <- input
            }

            # File references become attachments in Assistants API
            return(list(
                file_id = file_id,
                tools = tools
            ))
        },

        # Separate attachments from content in processed multipart input
        separate_attachments = function(parts) {
            if (is.null(parts) || purrr::is_empty(parts)) {
                return(list(content = NULL, attachments = NULL))
            }

            # Attachments have file_id at root level, content has type field
            attachments <- purrr::keep(parts, \(x) !is.null(x$file_id) && is.null(x$type))
            content <- purrr::discard(parts, \(x) !is.null(x$file_id) && is.null(x$type))

            return(list(
                content = if (purrr::is_empty(content)) NULL else content,
                attachments = if (purrr::is_empty(attachments)) NULL else attachments
            ))
        },

        # ------🔺 THREADS & RUNS ----------------------------------------------

        create_thread = function(query = NULL, attachments = NULL) {
            payload <- list()

            if (!is.null(query)) {
                msg <- list(role = "user", content = query)
                if (!is.null(attachments)) {
                    msg$attachments <- attachments
                }
                payload$messages <- list(msg)
            }

            thread <- private$request(paste0(self$base_url, "/v1/threads"), payload)
            cli::cli_alert_success("[{self$provider_name}] Thread created: {thread$id}")
            invisible(thread)
        },

        read_thread = function(thread_id = self$thread$id) {
            private$request(paste0(self$base_url, "/v1/threads/", thread_id))
        },

        delete_thread = function(thread_id = self$thread$id) {
            result <- private$delete(paste0(self$base_url, "/v1/threads/"), thread_id)
            cli::cli_alert_success("[{self$provider_name}] Thread deleted: {thread_id}")
            invisible(result)
        },

        run_thread = function(assistant_id = self$assistant$id, thread_id = self$thread$id, ...) {
            private$request(
                paste0(self$base_url, "/v1/threads/", thread_id, "/runs"),
                list(assistant_id = assistant_id, parallel_tool_calls = TRUE, ...)
            )
        },

        create_and_run_thread = function(assistant_id = self$assistant$id, query, attachments = NULL, ...) {
            msg <- list(role = "user", content = query)
            if (!is.null(attachments)) {
                msg$attachments <- attachments
            }

            payload <- list(
                assistant_id = assistant_id,
                thread = list(messages = list(msg)),
                parallel_tool_calls = TRUE,
                ...
            )

            private$request(paste0(self$base_url, "/v1/threads/runs"), payload)
        },

        add_msg_to_thread = function(thread_id = self$thread$id, query, attachments = NULL) {
            payload <- list(role = "user", content = query)

            # Add attachments if provided
            if (!is.null(attachments)) {
                payload$attachments <- attachments
            }

            private$request(
                paste0(self$base_url, "/v1/threads/", thread_id, "/messages"),
                payload
            )
        },

        get_thread_run_info = function(thread_id = self$thread$id, run_id) {
            private$request(paste0(self$base_url, "/v1/threads/", thread_id, "/runs/", run_id))
        },

        update_thread_run = function(thread_id = self$thread$id, run_id, ...) {
            private$request(
                paste0(self$base_url, "/v1/threads/", thread_id, "/runs/", run_id),
                list(...)
            )
        },

        get_thread_msgs = function(thread_id = self$thread$id) {
            private$request(paste0(self$base_url, "/v1/threads/", thread_id, "/messages"))
        },

        get_thread_msg = function(thread_id = self$thread$id, msg_id) {
            private$request(paste0(self$base_url, "/v1/threads/", thread_id, "/messages/", msg_id))
        },

        get_thread_first_msg = function(thread_id = self$thread$id) {
            msgs <- private$get_thread_msgs(thread_id)
            if ("last_id" %in% names(msgs)) {
                return(private$get_thread_msg(thread_id, msgs$last_id))
            } else {
                cli::cli_alert_warning(c("!" = "No messages found"))
                return(NULL)
            }
        },

        get_thread_last_msg = function(thread_id = self$thread$id) {
            msgs <- private$get_thread_msgs(thread_id)

            if ("first_id" %in% names(msgs)) {
                return(private$get_thread_msg(thread_id, msgs$first_id))
            } else {
                cli::cli_alert_warning(c("!" = "No messages found"))
                return(NULL)
            }
        },

        submit_tool_outputs = function(thread_id = self$thread$id, run_id, tool_outputs) {
            private$request(
                paste0(self$base_url, "/v1/threads/", thread_id, "/runs/", run_id, "/submit_tool_outputs"),
                list(tool_outputs = tool_outputs)
            )
        },

        # ------🔺 ASSISTANT INFO ----------------------------------------------

        display_assistant_info = function() {

            cli::cli_text("[{self$provider_name}] Current assistant's information:")

            purrr::iwalk(
                self$assistant,
                \(x, idx) cli::cli_bullets(c("*" = "{.field {idx}}: {.val {x}}"))
            )
        },

        # ------🔺 REQUESTS ----------------------------------------------------

        validate_api_call = function(query_data) {
            
            query_names <- get_all_names(query_data)
            
            # If the response type is json_object, we need to check that the model was properly instructed to
            # answer in JSON in the system instructions or in the Query. The API call will fail if not.
            if ("content" %in% query_names) {
                if (
                    "type" %in% names(self$assistant$response_format) 
                    && self$assistant$response_format$type == "json_object"
                ) {
                    json_check <- stringr::str_detect(self$assistant$instructions, stringr::fixed("JSON", TRUE)) || 
                        stringr::str_detect(find_in_list(query_data, "content"), stringr::fixed("JSON", TRUE))
                    
                    if (!json_check) {
                        cli::cli_abort(
                            c("!" = "{.var response_format} is 'json_object' but the query or instructions do 
                          not explicitely ask for JSON output.")
                        )
                    }
                }
            }
        },

        # ------🔺 TOOLS -------------------------------------------------------

        # Extract tool calls from run or message object
        extract_tool_calls = function(root) {
            # For run object with pending tool calls
            tool_calls <- purrr::pluck(root, "required_action", "submit_tool_outputs", "tool_calls")
            if (!is.null(tool_calls) && !purrr::is_empty(tool_calls)) {
                return(tool_calls)
            }

            # Message objects don't contain tool calls in Assistants API
            return(NULL)
        },

        # Extract arguments from tool call
        extract_tool_call_args = function(tool_call) {
            jsonlite::fromJSON(tool_call$`function`$arguments)
        },

        # Extract name from tool call
        extract_tool_call_name = function(tool_call) {
            tool_call$`function`$name
        },

        extract_tool_results = function(root) {
            # For Assistants API, tool results are stored with role="tool" and content array
            role <- purrr::pluck(root, "role", .default = NULL)
            if (!is.null(role) && role == "tool") {
                return(purrr::pluck(root, "content", .default = NULL))
            }
            return(NULL)
        },

        extract_tool_result_content = function(tool_result) {
            # The output field contains the tool execution result
            return(purrr::pluck(tool_result, "output", .default = NULL))
        },

        extract_tool_result_name = function(tool_result) {
            # Assistants API uses tool_call_id as the identifier
            # There's no separate name field
            return(purrr::pluck(tool_result, "tool_call_id", .default = NULL))
        },

        # Execute a single tool call
        use_tool = function(tool_call) {
            fn_name <- private$extract_tool_call_name(tool_call)
            args <- private$extract_tool_call_args(tool_call)

            output <- super$use_tool(fn_name, args)

            # Assistants API format for tool outputs
            return(list(
                tool_call_id = tool_call$id,
                output = jsonlite::toJSON(output, auto_unbox = TRUE)
            ))
        },

        # Override use_tools to handle run objects
        use_tools = function(run) {
            tool_calls <- private$extract_tool_calls(run)
            if (is.null(tool_calls) || purrr::is_empty(tool_calls)) return(NULL)

            return(purrr::map(tool_calls, \(tc) private$use_tool(tc)))
        },

        has_server_tools = function() {
            if (is.null(self$assistant$tools) || purrr::is_empty(self$assistant$tools)) {
                return(FALSE)
            }

            purrr::some(self$assistant$tools, \(tool) {
                is_server_tool(tool, c("file_search", "code_interpreter"))
            })
        },

        # ------🔺 HISTORY -----------------------------------------------------

        # Private method for downloading generated files (called by base class public method)
        download_generated_files = function(files, dest_path = "data", overwrite = TRUE) {
            is_file_path <- is_file(dest_path)
            if (length(files) > 1 && is_file_path) {
                cli::cli_abort(
                    "[{self$provider_name}] Multiple files to download, but 'dest_path' is a file path, not a dir."
                )
            }

            saved_paths <- purrr::map_chr(files, \(file_meta) {
                self$download_file(file_meta$file_id, dest_path, overwrite)
            })

            invisible(saved_paths)
        },

        # ------🔺 EXTRACTION --------------------------------------------------

        extract_root = function(input) {
            # For thread message object (API response or from session_history)
            if (!is.null(purrr::pluck(input, "role")) && !is.null(purrr::pluck(input, "content"))) {
                return(purrr::keep_at(input, c("role", "content", "created_at")))
            }
            # For run object (when checking tool calls)
            if (!is.null(purrr::pluck(input, "required_action"))) {
                return(purrr::keep_at(input, c("required_action", "status", "usage", "role")))
            }
            # Default: return as-is
            return(input)
        },

        extract_role = function(root) {
            purrr::pluck(root, "role", .default = "unknown")
        },

        extract_content = function(root) {
            contents <- purrr::pluck(root, "content")
            if (is.null(contents)) return(NULL)

            purrr::keep(contents, \(item) purrr::pluck(item, "type") == "text")
        },

        extract_content_text = function(root) {
            contents <- private$extract_content(root)
            if (purrr::is_empty(contents)) return(NULL)

            text_parts <- purrr::map_chr(contents, \(item) {
                purrr::pluck(item, "text", "value", .default = "")
            })

            return(paste0(text_parts, collapse = "\n"))
        },

        extract_system_instructions = function(input) {
            # Assistants have instructions in assistant object, not in messages
            if (!is.null(self$assistant)) {
                return(purrr::pluck(self$assistant, "instructions"))
            }
            return(NULL)
        },

        extract_reasoning = function(root) {
            return(NULL)  # Assistants API doesn't support reasoning
        },

        extract_reasoning_text = function(root) {
            return(NULL)
        },

        extract_generated_code = function(root) {
            return(NULL)  # Code from code_interpreter is in annotations, not as separate items
        },

        extract_generated_files = function(root) {
            citations <- private$extract_citations(root)
            if (is.null(citations) || purrr::is_empty(citations)) return(NULL)

            file_annotations <- purrr::keep(citations, \(x) purrr::pluck(x, "type") == "file_path")
            if (purrr::is_empty(file_annotations)) return(NULL)

            return(purrr::map(file_annotations, \(annotation) {
                list(
                    file_id = purrr::pluck(annotation, "file_path", "file_id"),
                    filename = basename(purrr::pluck(annotation, "text"))
                )
            }))
        },

        extract_citations = function(root) {
            if (is.null(root$content) || length(root$content) == 0) {
                return(NULL)
            }

            all_annotations <- list()
            for (content_item in root$content) {
                if (!is.null(content_item$text) && !is.null(content_item$text$annotations)) {
                    annotations <- content_item$text$annotations
                    if (length(annotations) > 0) {
                        all_annotations <- append(all_annotations, annotations)
                    }
                }
            }

            if (purrr::is_empty(all_annotations)) {
                return(NULL)
            }

            return(all_annotations)
        },

        extract_supplementary = function(api_res) {
            root <- api_res

            citations <- private$extract_citations(root)

            if (is.null(citations)) {
                return(NULL)
            }

            return(list3(citations = citations))
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
                } else if (is_server_tool(tool, c("file_search", "code_interpreter", "code_execution"))) {
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

        is_root = function(input) {
            is.list(input)
        },

        extract_input_token_count = function(input) {
            purrr::pluck(input, "usage", "prompt_tokens", .default = 0)
        },

        extract_output_token_count = function(output) {
            purrr::pluck(output, "usage", "completion_tokens", .default = 0)
        },

        extract_total_token_count = function(input) {
            purrr::pluck(input, "usage", "total_tokens", .default = 0)
        },

        extract_session_history_query_last_turn = function(input, index) {
            # Assistants don't accumulate query history like other APIs
            return(input)
        }
    )
)
