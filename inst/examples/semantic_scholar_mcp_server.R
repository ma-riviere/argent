# Semantic Scholar MCP Server
#
# An HTTP MCP server for searching academic papers using the Semantic Scholar API.
# This server can be used with argent or other MCP clients.

# ------🔺 SETUP ---------------------------------------------------------------

suppressPackageStartupMessages(library(argent))

# Disable httr2 progress bars to avoid stderr noise
options(
    httr2_progress = FALSE,
    argent.debug = FALSE
)

# ------🔺 TOOLS ---------------------------------------------------------------
# Defining the tools that the server will expose

# Base request function for Semantic Scholar API
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

semantic_scholar_search_papers <- function(query, limit = 10L, fields = NULL) {
    if (is.null(query) || nchar(query) == 0) {
        return(argent:::mcp_error(
            message = "Query parameter is required",
            type = "validation",
            details = "The 'query' parameter cannot be empty",
            suggestion = "Provide keywords, author names, or paper titles to search for"
        ))
    }

    # Use default fields if not specified
    fields_param <- fields %||% default_fields

    params <- list(
        query = query,
        limit = as.integer(min(limit, 100)),
        fields = fields_param
    )

    result <- semantic_scholar_request("/paper/search", query = params)

    if (isTRUE(result$.error)) {
        return(result)
    }

    if (is.null(result) || purrr::is_empty(result$data)) {
        return(jsonlite::toJSON(list(), auto_unbox = TRUE))
    }

    # Extract and format papers
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

semantic_scholar_get_paper <- function(paper_id, fields = NULL) {
    if (is.null(paper_id) || nchar(paper_id) == 0) {
        return(argent:::mcp_error(
            message = "Paper ID is required",
            type = "validation",
            details = "The 'paper_id' parameter cannot be empty",
            suggestion = "Provide a Semantic Scholar paper ID or DOI"
        ))
    }

    # Use default fields if not specified
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
            suggestion = "Verify the paper ID using search_papers first, or try a different ID/DOI"
        ))
    }

    # Format authors
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

semantic_scholar_get_paper_citations <- function(paper_id, limit = 10, fields = NULL) {
    if (is.null(paper_id) || nchar(paper_id) == 0) {
        return(argent:::mcp_error(
            message = "Paper ID is required",
            type = "validation",
            details = "The 'paper_id' parameter cannot be empty",
            suggestion = "Provide a Semantic Scholar paper ID or DOI"
        ))
    }

    # Use default fields if not specified
    fields_param <- fields %||% default_fields

    endpoint <- paste0("/paper/", paper_id, "/citations")
    params <- list(
        limit = as.integer(min(limit, 1000)),
        fields = fields_param
    )

    result <- semantic_scholar_request(endpoint, query = params)

    if (isTRUE(result$.error)) {
        return(result)
    }

    if (is.null(result) || purrr::is_empty(result$data)) {
        return(jsonlite::toJSON(list(), auto_unbox = TRUE))
    }

    # Extract citing papers
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

semantic_scholar_get_paper_references <- function(paper_id, limit = 10, fields = NULL) {
    if (is.null(paper_id) || nchar(paper_id) == 0) {
        return(argent:::mcp_error(
            message = "Paper ID is required",
            type = "validation",
            details = "The 'paper_id' parameter cannot be empty",
            suggestion = "Provide a Semantic Scholar paper ID or DOI"
        ))
    }

    # Use default fields if not specified
    fields_param <- fields %||% default_fields

    endpoint <- paste0("/paper/", paper_id, "/references")
    params <- list(
        limit = as.integer(min(limit, 1000)),
        fields = fields_param
    )

    result <- semantic_scholar_request(endpoint, query = params)

    if (isTRUE(result$.error)) {
        return(result)
    }

    if (is.null(result) || purrr::is_empty(result$data)) {
        return(jsonlite::toJSON(list(), auto_unbox = TRUE))
    }

    # Extract referenced papers
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

# ------🔺 MCP SERVER ----------------------------------------------------------

semantic_scholar_mcp_server <- function(port = 8080, host = "127.0.0.1") {
    server <- argent:::McpServer$new(
        name = "semantic-scholar",
        version = "1.0.0"
    )

    # Define tools
    search_papers_tool <- argent::tool(
        name = "search_papers",
        description = paste(
            "Search for academic papers by keywords, authors, or topics using the Semantic Scholar API.",
            "Returns a list of papers with metadata including title, authors, year, abstract, citation count, and URL.",
            "IMPORTANT:",
            "- Use broad search terms for better results",
            "- Search is case-insensitive",
            "- Returns up to 100 results per query"
        ),
        query = paste(
            "string* Search query (keywords, author names, paper titles, etc.).",
            "Examples: 'neural networks', 'attention mechanisms', 'Geoffrey Hinton'"
        ),
        limit = "integer Maximum number of results to return (default: 10, max: 100)",
        fields = paste(
            "string Comma-separated list of fields to return.",
            "Default: 'title,authors,year,abstract,citationCount,url,venue,publicationDate'.",
            "Other available fields: 'referenceCount', 'influentialCitationCount', 'fieldsOfStudy'"
        ),
        fn = semantic_scholar_search_papers
    )

    get_paper_tool <- argent::tool(
        name = "get_paper",
        description = paste(
            "Get detailed metadata for a specific paper by its Semantic Scholar ID or DOI.",
            "Returns comprehensive information including title, authors, abstract, year, citation count, and more.",
            "Use this after search_papers to get full details for specific papers."
        ),
        paper_id = paste(
            "string* Paper ID (Semantic Scholar ID or DOI).",
            "Examples: '649def34f8be52c8b66281af98ae884c09aef38b' (S2 ID), '10.1038/nature14539' (DOI)"
        ),
        fields = paste(
            "string Comma-separated list of fields to return.",
            "Default: 'title,authors,year,abstract,citationCount,url,venue,publicationDate'"
        ),
        fn = semantic_scholar_get_paper
    )

    get_paper_citations_tool <- argent::tool(
        name = "get_paper_citations",
        description = paste(
            "Get papers that cite a given paper.",
            "Returns a list of citing papers with their metadata.",
            "Useful for finding related work and tracking research impact."
        ),
        paper_id = "string* Paper ID (Semantic Scholar ID or DOI)",
        limit = "integer Maximum number of citations to return (default: 10, max: 1000)",
        fields = paste(
            "string Comma-separated list of fields to return for each citing paper.",
            "Default: 'title,authors,year,abstract,citationCount,url,venue,publicationDate'"
        ),
        fn = semantic_scholar_get_paper_citations
    )

    get_paper_references_tool <- argent::tool(
        name = "get_paper_references",
        description = paste(
            "Get papers referenced by a given paper (its bibliography).",
            "Returns a list of referenced papers with their metadata.",
            "Useful for finding foundational work and related research."
        ),
        paper_id = "string* Paper ID (Semantic Scholar ID or DOI)",
        limit = "integer Maximum number of references to return (default: 10, max: 1000)",
        fields = paste(
            "string Comma-separated list of fields to return for each referenced paper.",
            "Default: 'title,authors,year,abstract,citationCount,url,venue,publicationDate'"
        ),
        fn = semantic_scholar_get_paper_references
    )

    # Add tools to server
    server$add_tool(search_papers_tool)
    server$add_tool(get_paper_tool)
    server$add_tool(get_paper_citations_tool)
    server$add_tool(get_paper_references_tool)

    # Start HTTP server
    server$serve_http(host = host, port = port, block = TRUE)
}

# Run server with command line args or defaults
args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args) > 0) as.integer(args[1]) else 8080
semantic_scholar_mcp_server(port = port)
