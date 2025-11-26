# Semantic Scholar MCP Server Tools
#
# Tool definitions for searching academic papers using the Semantic Scholar API.
# Use with: argent::mcp_serve_http(file = "semantic_scholar_mcp_server.R", name = "semantic-scholar")

# ------🔺 HELPER FUNCTIONS ----------------------------------------------------

# Base request function for Semantic Scholar API (not an MCP tool)
semantic_scholar_request <- function(endpoint, query = list()) {
    base_url <- "https://api.semanticscholar.org/graph/v1"
    url <- paste0(base_url, endpoint)

    resp <- httr2::request(url) |>
        httr2::req_url_query(!!!query) |>
        httr2::req_error(is_error = \(resp) FALSE) |>
        httr2::req_throttle(rate = 20 / 60, realm = "semantic-scholar") |>
        httr2::req_perform()

    status <- httr2::resp_status(resp)

    if (status == 429) {
        return(argent:::mcp_error(
            message = "Rate limit exceeded",
            type = "api_error",
            details = "Too many requests to Semantic Scholar API",
            suggestion = "Wait a few seconds before retrying"
        ))
    }

    if (status == 404) {
        return(NULL)
    }

    if (status != 200) {
        return(argent:::mcp_error(
            message = paste0("Semantic Scholar API request failed with status ", status),
            type = "api_error",
            details = paste0("Unexpected HTTP status code from endpoint: ", endpoint)
        ))
    }

    httr2::resp_body_json(resp)
}

# Default fields to return for papers
default_fields <- "title,authors,year,abstract,citationCount,url,venue,publicationDate"

# ------🔺 MCP TOOLS -----------------------------------------------------------

search_papers <- function(query, limit = 10L, fields = NULL) {
    #' @description Search for academic papers by keywords, authors, or topics
    #'   using the Semantic Scholar API. Returns papers with metadata including
    #'   title, authors, year, abstract, citation count, and URL. Use broad
    #'   search terms for better results. Returns up to 100 results per query.
    #' @mcp tool
    #' @param query:string* Search query (keywords, author names, paper titles)
    #' @param limit:integer Maximum results to return (default 10, max 100)
    #' @param fields:string Comma-separated fields to return

    if (is.null(query) || nchar(query) == 0) {
        return(argent:::mcp_error(
            message = "Query parameter is required",
            type = "validation",
            details = "The 'query' parameter cannot be empty",
            suggestion = "Provide keywords, author names, or paper titles to search for"
        ))
    }

    fields_param <- fields %||% default_fields

    params <- list(query = query, limit = as.integer(min(limit, 100)), fields = fields_param)

    result <- semantic_scholar_request("/paper/search", query = params)

    if (isTRUE(result$.error)) {
        return(result)
    }

    if (is.null(result) || purrr::is_empty(result$data)) {
        return(jsonlite::toJSON(list(), auto_unbox = TRUE))
    }

    papers <- lapply(result$data, function(paper) {
        authors <- "No authors"
        if (!purrr::is_empty(paper$authors)) {
            authors <- paste(purrr::map_chr(paper$authors, \(a) a$name), collapse = "; ")
        }

        list(
            paperId = paper$paperId,
            title = paper$title %||% "Untitled",
            authors = authors,
            year = paper$year %||% "Unknown year",
            abstract = paper$abstract %||% "No abstract available",
            citationCount = paper$citationCount %||% 0,
            url = paper$url,
            venue = paper$venue %||% "Unknown venue",
            publicationDate = paper$publicationDate %||% "Unknown date"
        )
    })

    jsonlite::toJSON(papers, auto_unbox = TRUE)
}

get_paper <- function(paper_id, fields = NULL) {
    #' @description Get detailed metadata for a specific paper by its Semantic
    #'   Scholar ID or DOI. Returns title, authors, abstract, year, citation
    #'   count, and more. Use after search_papers to get full details.
    #' @mcp tool
    #' @param paper_id:string* Paper ID (Semantic Scholar ID or DOI)
    #' @param fields:string Comma-separated fields to return

    if (is.null(paper_id) || nchar(paper_id) == 0) {
        return(argent:::mcp_error(
            message = "Paper ID is required",
            type = "validation",
            details = "The 'paper_id' parameter cannot be empty",
            suggestion = "Provide a Semantic Scholar paper ID or DOI"
        ))
    }

    fields_param <- fields %||% default_fields

    endpoint <- paste0("/paper/", paper_id)
    params <- list(fields = fields_param)

    result <- semantic_scholar_request(endpoint, query = params)

    if (isTRUE(result$.error)) {
        return(result)
    }

    if (is.null(result)) {
        return(argent:::mcp_error(
            message = "Paper not found",
            type = "not_found",
            details = paste0("No paper with ID '", paper_id, "' exists"),
            suggestion = "Verify the paper ID using search_papers first"
        ))
    }

    authors <- "No authors"
    if (!purrr::is_empty(result$authors)) {
        authors <- paste(purrr::map_chr(result$authors, \(a) a$name), collapse = "; ")
    }

    paper <- list(
        paperId = result$paperId,
        title = result$title %||% "Untitled",
        authors = authors,
        year = result$year %||% "Unknown year",
        abstract = result$abstract %||% "No abstract available",
        citationCount = result$citationCount %||% 0,
        url = result$url,
        venue = result$venue %||% "Unknown venue",
        publicationDate = result$publicationDate %||% "Unknown date"
    )

    jsonlite::toJSON(paper, auto_unbox = TRUE)
}

get_paper_citations <- function(paper_id, limit = 10L, fields = NULL) {
    #' @description Get papers that cite a given paper. Returns citing papers
    #'   with their metadata. Useful for finding related work and tracking
    #'   research impact.
    #' @mcp tool
    #' @param paper_id:string* Paper ID (Semantic Scholar ID or DOI)
    #' @param limit:integer Maximum citations to return (default 10, max 1000)
    #' @param fields:string Comma-separated fields to return

    if (is.null(paper_id) || nchar(paper_id) == 0) {
        return(argent:::mcp_error(
            message = "Paper ID is required",
            type = "validation",
            details = "The 'paper_id' parameter cannot be empty",
            suggestion = "Provide a Semantic Scholar paper ID or DOI"
        ))
    }

    fields_param <- fields %||% default_fields

    endpoint <- paste0("/paper/", paper_id, "/citations")
    params <- list(limit = as.integer(min(limit, 1000)), fields = fields_param)

    result <- semantic_scholar_request(endpoint, query = params)

    if (isTRUE(result$.error)) {
        return(result)
    }

    if (is.null(result) || purrr::is_empty(result$data)) {
        return(jsonlite::toJSON(list(), auto_unbox = TRUE))
    }

    citations <- lapply(result$data, function(citation) {
        paper <- citation$citingPaper

        authors <- "No authors"
        if (!purrr::is_empty(paper$authors)) {
            authors <- paste(purrr::map_chr(paper$authors, \(a) a$name), collapse = "; ")
        }

        list(
            paperId = paper$paperId,
            title = paper$title %||% "Untitled",
            authors = authors,
            year = paper$year %||% "Unknown year",
            abstract = paper$abstract %||% "No abstract available",
            citationCount = paper$citationCount %||% 0,
            url = paper$url,
            venue = paper$venue %||% "Unknown venue",
            publicationDate = paper$publicationDate %||% "Unknown date"
        )
    })

    jsonlite::toJSON(citations, auto_unbox = TRUE)
}

get_paper_references <- function(paper_id, limit = 10L, fields = NULL) {
    #' @description Get papers referenced by a given paper (its bibliography).
    #'   Returns referenced papers with metadata. Useful for finding foundational
    #'   work and related research.
    #' @mcp tool
    #' @param paper_id:string* Paper ID (Semantic Scholar ID or DOI)
    #' @param limit:integer Maximum references to return (default 10, max 1000)
    #' @param fields:string Comma-separated fields to return

    if (is.null(paper_id) || nchar(paper_id) == 0) {
        return(argent:::mcp_error(
            message = "Paper ID is required",
            type = "validation",
            details = "The 'paper_id' parameter cannot be empty",
            suggestion = "Provide a Semantic Scholar paper ID or DOI"
        ))
    }

    fields_param <- fields %||% default_fields

    endpoint <- paste0("/paper/", paper_id, "/references")
    params <- list(limit = as.integer(min(limit, 1000)), fields = fields_param)

    result <- semantic_scholar_request(endpoint, query = params)

    if (isTRUE(result$.error)) {
        return(result)
    }

    if (is.null(result) || purrr::is_empty(result$data)) {
        return(jsonlite::toJSON(list(), auto_unbox = TRUE))
    }

    references <- lapply(result$data, function(reference) {
        paper <- reference$citedPaper

        authors <- "No authors"
        if (!purrr::is_empty(paper$authors)) {
            authors <- paste(purrr::map_chr(paper$authors, \(a) a$name), collapse = "; ")
        }

        list(
            paperId = paper$paperId,
            title = paper$title %||% "Untitled",
            authors = authors,
            year = paper$year %||% "Unknown year",
            abstract = paper$abstract %||% "No abstract available",
            citationCount = paper$citationCount %||% 0,
            url = paper$url,
            venue = paper$venue %||% "Unknown venue",
            publicationDate = paper$publicationDate %||% "Unknown date"
        )
    })

    jsonlite::toJSON(references, auto_unbox = TRUE)
}
