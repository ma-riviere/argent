# Standalone file: do not edit by hand
# Source: https://github.com/thieled/fleece
# ----------------------------------------------------------------------
#
# This file provides a standalone implementation of fleece::rectangularize()
#
# nocov start

#' Bind JSON data parsed as an R list to a data frame and unnest nested columns
#'
#' This function takes JSON data parsed as an R list, binds it to a tibble,
#' and then recursively applies the "unnest_recursively" function to unnest any
#' nested list columns in the data frame. The input data can contain either a
#' single observation (a list representing a row) or multiple observations (a
#' list of lists representing multiple rows).
#'
#' @param content A list containing JSON data parsed into R format.
#' @return A data frame with JSON data bound and all nested list columns unnested
#'   to achieve a tidy format.
#' @keywords internal
#' @noRd
rectangularize <- function(content) {
    # Stop if content is not a list
    if (!is.list(content)) {
        stop("Error: Please provide content in list format.")
    }

    # Check if content contains 1 observation (=> simple rbind; 1 row df)
    if (all(sapply(content, is.list))) {
        con <- do.call(rbind, content) |> tibble::as_tibble()
        con <- unnest_recursively(con)
        return(con)

    } else {
        # ...or more (=> do.call(rbind, l); multiple rows df)
        con <- rbind(content) |> tibble::as_tibble()
        con <- unnest_recursively(con)

        if (any(sapply(con, is.list))) {
            con <- unnest_recursively(con)
        }

        return(con)
    }
}

#' Recursively unnest a nested data frame until every column is unnested
#'
#' This function takes a nested data frame and recursively applies the
#' "unnest_wider" function from the tidyr package to unnest list columns until
#' all columns are in a tidy format. The function separates list columns from
#' non-list columns, checks if there is anything to unnest, and then applies
#' the unnesting process recursively to deeply nested list columns.
#'
#' @param df A nested data frame (data.table or data.frame) containing list columns.
#' @return A data frame with all nested list columns unnested and merged with
#'   other columns. The resulting data frame will have a tidy format.
#' @keywords internal
#' @noRd
unnest_recursively <- function(df) {
    # Separate list columns from non-list columns
    df_l <- df |> dplyr::select_if(is.list)
    df_nl <- df |> dplyr::select_if(~!is.list(.x))

    # Check if there is something to unnest
    if (ncol(df_l) == 0) {
        return(df)
    } else {
        # Check which list columns are deeper nested
        max_lengths <- function(x) max(lengths(x))
        v <- sapply(df_l, max_lengths)
        cols <- v[v > 1] |> names()

        if (length(cols) == 0) {
            # "list" columns, but not deeper nested
            df_unnested <- df_l |>
                dplyr::select(-tidyselect::all_of(cols)) |>
                tidyr::unnest(
                    cols = tidyselect::everything(),
                    keep_empty = TRUE,
                    names_repair = "minimal",
                    names_sep = "_"
                )
            # Bind with regular columns if any
            if (ncol(df_nl > 0)) {
                df_unnested <- dplyr::bind_cols(df_nl, df_unnested)
            }
            return(df_unnested)

        } else {
            df_unnested <- df_l |>
                dplyr::select(-tidyselect::all_of(cols)) |>
                tidyr::unnest(
                    cols = tidyselect::everything(),
                    keep_empty = TRUE,
                    names_repair = "minimal",
                    names_sep = "_"
                )
            # Bind with regular columns if any
            if (ncol(df_nl > 0)) {
                df_unnested <- dplyr::bind_cols(df_nl, df_unnested)
            }
            df_remaining <- df |> dplyr::select(tidyselect::all_of(cols))
            df_remaining_unnested <- df_remaining |>
                tidyr::unnest_wider(
                    tidyselect::all_of(cols),
                    strict = FALSE,
                    names_repair = "minimal",
                    names_sep = "_"
                )

            # Recur on the remaining nested columns
            df_unnested <- dplyr::bind_cols(
                df_unnested,
                unnest_recursively(df_remaining_unnested)
            )
            return(df_unnested)
        }
    }
}

# nocov end
