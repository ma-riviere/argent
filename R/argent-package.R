## usethis namespace: start
#' @importFrom R6 R6Class
#' @importFrom base64enc base64encode
#' @importFrom cli cli_abort cli_alert_danger cli_alert_info cli_alert_success cli_alert_warning cli_bullets
#' @importFrom cli cli_bullets_raw cli_h1 cli_h2 cli_h3 cli_text cli_warn col_blue col_cyan col_green col_grey
#' @importFrom cli col_magenta col_red col_silver col_yellow style_italic
#' @importFrom curl form_file
#' @importFrom dplyr arrange bind_cols bind_rows desc filter first mutate select select_if semi_join
#' @importFrom fs dir_create dir_exists file_exists is_dir is_file path path_norm
#' @importFrom here here
#' @importFrom httr2 req_body_file req_body_json req_body_multipart req_error req_headers req_headers_redacted
#' @importFrom httr2 req_method req_perform req_retry req_throttle req_timeout req_url_path_append req_url_query
#' @importFrom httr2 request resp_body_json resp_body_raw resp_body_string resp_content_type resp_has_body
#' @importFrom httr2 resp_header resp_is_error resp_status
#' @importFrom jsonlite fromJSON toJSON
#' @importFrom lubridate as_datetime today ymd_hms
#' @importFrom mime guess_type mimemap
#' @importFrom purrr compact detect discard discard_at imap imap_chr is_empty iwalk keep list_c
#' @importFrom purrr list_flatten list_modify list_rbind map map_chr map_dfr map_if map_int map_lgl modify_at
#' @importFrom purrr modify_tree pluck possibly quietly reduce some walk
#' @importFrom rlang as_label enquos eval_tidy exec is_quosure is_symbol list2 new_quosure quo_get_env
#' @importFrom rlang quo_get_expr
#' @importFrom stats setNames
#' @importFrom stringr fixed str_c str_detect str_ends str_extract str_glue str_match str_remove
#' @importFrom stringr str_replace_all str_split_1 str_starts str_trim
#' @importFrom tibble as_tibble
#' @importFrom tidyr unnest unnest_wider
#' @importFrom tidyselect all_of everything
#' @importFrom tools file_ext
#' @importFrom utils type.convert
#' @importFrom xml2 read_html read_xml
#' @importFrom yaml as.yaml read_yaml
## usethis namespace: end
NULL

#' @keywords internal
"_PACKAGE"

#' argent: An R Agent-based Interface
#'
#' @description
#' The argent package provides a unified interface for creating AI agents that can interact with multiple Large Language Model
#' (LLM) providers through R6 classes. It supports Google, Anthropic, OpenAI,
#' OpenRouter, and local LLM servers (e.g., llama.cpp, Ollama).
#'
#' @section Main Classes:
#' The package provides the following R6 classes:
#'
#' \describe{
#'   \item{\code{\link{Google}}}{Client for Google's API with support for chat completions,
#'     function calling, and thinking mode}
#'   \item{\code{\link{Anthropic}}}{Client for Anthropic's API with prompt caching and
#'     tool calling capabilities}
#'   \item{\code{\link{OpenAI}}}{Client for OpenAI's API with comprehensive file management,
#'     vector stores, and chat completions}
#'   \item{\code{\link{OpenAIAssistant}}}{Client for OpenAI's Assistants API with thread management
#'     and persistent conversations}
#'   \item{\code{\link{OpenRouter}}}{Client for OpenRouter API providing access to multiple LLM
#'     providers through a unified interface}
#'   \item{\code{\link{LocalLLM}}}{Client for local LLM servers implementing OpenAI-compatible APIs}
#' }
#'
#' @section Features:
#' \itemize{
#'   \item Unified interface across multiple LLM providers
#'   \item Support for function/tool calling
#'   \item Structured JSON outputs
#'   \item Conversation history management
#'   \item Prompt caching (Anthropic)
#'   \item File and vector store management (OpenAI)
#'   \item Local LLM support
#' }
#'
#' @section Getting Started:
#' Set up API keys as environment variables:
#' \itemize{
#'   \item \code{GEMINI_API_KEY} for Google
#'   \item \code{ANTHROPIC_API_KEY} for Anthropic
#'   \item \code{OPENAI_API_KEY} for OpenAI
#'   \item \code{OPENAI_ORG} for OpenAI organization (optional)
#'   \item \code{OPENROUTER_API_KEY} for OpenRouter
#' }
#'
#' @examples
#' \dontrun{
#' # Google
#' google <- Google$new()
#' response <- google$chat("What is R programming?")
#'
#' # Anthropic
#' anthropic <- Anthropic$new()
#' response <- anthropic$chat(
#'   prompt = "Explain quantum computing",
#'   model = "claude-sonnet-4-5-20250929"
#' )
#'
#' # OpenAI
#' openai <- OpenAI$new()
#' response <- openai$chat(
#'   prompt = "Write a haiku about R",
#'   model = "gpt-5-chat-latest"
#' )
#'
#' # OpenRouter
#' openrouter <- OpenRouter$new()
#' response <- openrouter$chat(
#'   prompt = "Explain machine learning",
#'   model = "anthropic/claude-sonnet-4"
#' )
#'
#' # Local LLM
#' llm <- LocalLLM$new(base_url = "http://localhost:5000")
#' response <- llm$chat(prompt = "Hello!")
#' }
#'
#' @name argent-package
NULL
