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
#' The argent package provides a unified interface for creating AI agents that can interact with
#' multiple Large Language Model (LLM) providers through R6 classes. It supports Google, Anthropic,
#' OpenAI, OpenRouter, and local LLM servers (e.g., llama.cpp, Ollama).
#'
#' argent is specialized for building AI agents with conversation history management, local function
#' and MCP tools, server-side tools, multimodal inputs, and universal structured outputs.
#'
#' @section Main Classes:
#' The package provides the following R6 classes:
#'
#' \describe{
#'   \item{\code{\link{Google}}}{Client for Google's API with support for chat completions,
#'     function calling, thinking mode, code execution, and web search}
#'   \item{\code{\link{Anthropic}}}{Client for Anthropic's API with prompt caching, tool calling,
#'     and extended thinking capabilities}
#'   \item{\code{\link{OpenAI_Chat}}}{Client for OpenAI's Chat Completions API}
#'   \item{\code{\link{OpenAI_Responses}}}{Client for OpenAI's Responses API with comprehensive file
#'     management, vector stores, code execution, and web search}
#'   \item{\code{\link{OpenAI_Assistant}}}{Client for OpenAI's Assistants API (Deprecated)}
#'   \item{\code{\link{OpenRouter}}}{Client for OpenRouter API providing access to multiple LLM
#'     providers through a unified interface}
#'   \item{\code{\link{LocalLLM}}}{Client for local LLM servers implementing OpenAI-compatible APIs}
#' }
#'
#' @section Features:
#' \itemize{
#'   \item Unified interface across multiple LLM providers: OpenAI, Anthropic, Google, OpenRouter, and Local LLM
#'   \item Support for all 3 of OpenAI's APIs: Chat Completions, Responses, and Assistants
#'   \item Function and MCP tool calling (http & stdio)
#'   \item Universal structured JSON outputs (works with any model supporting tool calling)
#'   \item Multimodal inputs (text, images, PDFs, data files, URLs, R objects), customizable and extensible
#'   \item Server-side (built-in) tools, like code execution, web search/fetch, file search, etc.
#'   \item Client-side conversation history management with automatic on-disk persistence
#'   \item Prompt caching (for providers supporting it)
#'   \item File upload and vector/file store management for server-side RAG
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
#' # OpenAI Responses API
#' openai <- OpenAI_Responses$new()
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
#'
#' get_weather <- function(location) {
#'   #' @description Get weather information for a location
#'   #' @param location:string* The location to get weather for
#'   paste("Weather in", location, "is sunny")
#' }
#'
#' google$chat(
#'   "What's the weather in Paris, London, and Tokyo?",
#'   tools = list(as_tool(get_weather)),
#'   model = "gemini-2.5-flash"
#' )
#' }
#'
#' @name argent-package
NULL
