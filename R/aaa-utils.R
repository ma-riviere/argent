#' Default system prompt for all models
#' @keywords internal
#' @noRd
.default_system_prompt <- stringr::str_glue(
    "You are a helpful AI assistant.",
    "Use your knowledge, the files you have access to, and the tools at your disposal to answer the user's query.",
    "You can use your tools multiple times, but use them sparingly.",
    "Make parallel tool calls if relevant to the user's query.",
    "Answer the user's query as soon as you have the information necessary to answer.",
    "Self-reflect and double-check your answer before responding.",
    "If you don't know the answer even after using your tools, say 'I don't know'.",
    "If you do not have all the information necessary to use a provided tool, use NA for required arguments.",
    "Today's date is {lubridate::today()}",
    .sep = " "
)

#' Negated in operator
#' @param x Vector of values to be matched
#' @param table Vector of values to be matched against
#' @return Logical vector indicating if elements of x are not in table
#' @keywords internal
#' @noRd
`%ni%` <- function(x, table) {
    !(x %in% table)
}

#' Default value for NULL
#' @param x Object to test
#' @param y Default value if x is NULL
#' @return Returns x if not NULL, otherwise y
#' @keywords internal
#' @noRd
`%||%` <- function(x, y) {
    if (is.null(x)) y else x
}

#' Default value for empty vector
#' @param x Vector to test
#' @param y Default value if x is empty or NULL
#' @return Returns x if not empty or NULL, otherwise y
#' @keywords internal
#' @noRd
`%|e|%` <- function(x, y) if (purrr::is_empty(x) || is.na(x)) y else x


#' Wrapper around rlang::list2() that removes NULLs and empty elements.
#' @param ... One or more elements.
#' @return List with NULLs removed.
#' @keywords internal
#' @noRd
list3 <- function(...) {
    purrr::discard(rlang::list2(...), \(x) is.null(x) || (is.list(x) && length(x) == 0 && is.null(names(x))))
}

#' Wrapper around list3() that returns a named empty list if no elements are provided.
#' @param ... One or more elements.
#' @return Named empty list if no elements are provided, otherwise the list with NULLs removed.
#' @keywords internal
#' @noRd
named_list <- function(...) {
    dots <- list3(...)
    if (purrr::is_empty(dots)) {
        return(structure(list(), names = character(0)))
    }
    return(dots)
}

first <- function(x) if (is.null(x) || purrr::is_empty(x)) NULL else x[[1L]]
last <- function(x) if (is.null(x) || purrr::is_empty(x)) NULL else x[[length(x)]]
