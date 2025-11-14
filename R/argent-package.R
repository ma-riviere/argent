## usethis namespace: start
#' @importFrom R6 R6Class
#' @importFrom base64enc base64encode
#' @importFrom cli cli_abort cli_alert_danger cli_alert_info cli_alert_success cli_alert_warning cli_text
#' @importFrom curl form_file
#' @importFrom dplyr arrange desc filter mutate semi_join
#' @importFrom httr2 req_body_json req_body_multipart req_error req_headers req_headers_redacted req_method
#' @importFrom httr2 req_perform req_retry req_throttle req_timeout req_url_query request
#' @importFrom httr2 resp_body_json resp_body_raw resp_content_type resp_has_body resp_is_error resp_status
#' @importFrom jsonlite fromJSON toJSON
#' @importFrom lubridate as_datetime today
#' @importFrom mime guess_type
#' @importFrom purrr compact detect is_empty keep list_c list_rbind map map_dfr map_if modify_at modify_tree pluck quietly
#' @importFrom rlang exec
#' @importFrom stringr str_detect str_ends str_glue
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