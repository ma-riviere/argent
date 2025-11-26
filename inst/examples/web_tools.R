# ------🔺 WEB SEARCH ----------------------------------------------------------

web_search <- function(query) {
    #' @description Search the web for information using Tavily API. Returns a JSON array of search results with titles, URLs, and content snippets. Use this when you need current information, facts, news, or any data not in your training data.
    #' @param query:string* The search query string. Be specific and use keywords that will yield the most relevant results.

    return(web_search_tavily(query))
}

web_search_tavily <- function(query) {
    if (Sys.getenv("TAVILY_API_KEY") == "") {
        return("Error: TAVILY_API_KEY environment variable could not be found. Tell the user to set it.")
    }

    res <- httr2::request("https://api.tavily.com/search") |>
        httr2::req_body_json(list(
            query = query,
            search_depth = "basic",
            include_answer = FALSE,
            max_results = 10,
            api_key = Sys.getenv("TAVILY_API_KEY")
        )) |>
        httr2::req_error(is_error = \(resp) FALSE) |>
        httr2::req_throttle(rate = 20 / 60, realm = "tavily") |>
        httr2::req_perform() |>
        httr2::resp_body_json() |>
        purrr::discard_at(c("response_time", "follow_up_questions", "images"))

    results <- purrr::map(res$results, \(x) purrr::discard_at(x, "raw_content"))

    return(jsonlite::toJSON(results, pretty = FALSE, auto_unbox = TRUE))
}

# ------🔺 WEB FETCH -----------------------------------------------------------

web_fetch <- function(url) {
    #' @description Fetch and extract the main text content from a web page as clean markdown. Returns the page content with formatting preserved, stripped of navigation, ads, and boilerplate. Use this to read articles, documentation, blog posts, or any web page content.
    #' @param url:string* The complete URL of the web page to fetch (e.g., "https://example.com/article"). Must be a valid HTTP/HTTPS URL.

    trafilatura_installed <- tryCatch(
        {
            system("which trafilatura", intern = TRUE, ignore.stderr = TRUE)
            return(TRUE)
        },
        warning = function(e) {
            cli::cli_alert_warning("trafilatura is not installed. Install with: {.code pip install trafilatura}")
            return(FALSE)
        }
    )

    if (trafilatura_installed) {
        res <- web_fetch_trafilatura(url)

        could_not_fetch <- c(
            "Impossible to fetch the contents of this web page",
            "Please reload this page",
            "There was an error while loading",
            "404"
        )
        if (
            is.null(res) ||
                is.na(res) ||
                nchar(res) == 0 ||
                any(stringr::str_detect(res, stringr::fixed(could_not_fetch, ignore_case = TRUE)))
        ) {
            return(web_fetch_rvest(url))
        }
        return(res)
    }

    return(web_fetch_rvest(url))
}

web_fetch_trafilatura <- function(url) {
    tryCatch(
        {
            res <- paste0("trafilatura -u ", url, " --markdown --no-comments --links ") |>
                system(intern = TRUE) |>
                purrr::keep(nzchar) |>
                paste0(collapse = "\n")

            return(res)
        },
        error = function(e) {
            return("Impossible to fetch the contents of this web page. It might not allow scraping")
        }
    )
}

web_fetch_rvest <- function(url) {
    # We lose quite a bit of information with this approach, but properly extracting all this content would be a pain.
    tags_to_ignore <- c(
        "a",
        "script",
        "code",
        "img",
        "svg",
        "footer",
        "g",
        "path",
        "polygon",
        "label",
        "button",
        "form",
        "input",
        "select",
        "option",
        "optgroup",
        "datalist",
        "textarea",
        "fieldset",
        "legend",
        "output",
        "progress",
        "meter",
        "time",
        "details",
        "summary",
        "dialog",
        "menu",
        "menuitem",
        "command",
        "keygen",
        "embed",
        "object",
        "param",
        "video",
        "audio",
        "track",
        "source",
        "style",
        "link",
        "meta",
        "noscript",
        "iframe",
        "canvas",
        "map",
        "area",
        "math",
        "col",
        "colgroup",
        "dl",
        "dt",
        "dd",
        "hr",
        "pre",
        "address",
        "figure",
        "figcaption",
        "dfn",
        "em",
        "kbd",
        "samp",
        "var",
        "del",
        "ins",
        "mark",
        "circle"
    )

    remove_tags <- function(xml, tags) {
        purrr::walk(tags, \(tag) {
            purrr::walk(xml2::xml_find_all(xml, paste0(".//", tag)), \(node) xml2::xml_remove(node))
        })
        return(xml)
    }
    cleaned_contents <- tryCatch(
        rvest::read_html(url) |>
            rvest::html_element("body") |>
            remove_tags(tags_to_ignore) |>
            rvest::html_children() |>
            rvest::html_text2() |>
            purrr::discard(\(x) x == "") |>
            paste0(collapse = "\n\n"),
        error = \(e) return("")
    )
    return(cleaned_contents)
}

# ------🔺 WEB CRAWL -----------------------------------------------------------

web_crawl <- function(url) {
    #' @description Crawl a website/page to discover all available pages and their URLs. Returns a list of URLs found on the website by following sitemaps and internal links. Use this to explore the structure of a website or find specific pages before fetching their content. This method will only return internal links (matching the domain name of the base URL).
    #' @param url:string* The base URL of the website to crawl (e.g., "https://example.com"). Must be a valid HTTP/HTTPS URL. Clean it first if it's not a proper URL (e.g. 'https://github.com/tidyverse/ellmer/releases"}' -> https://github.com/tidyverse/ellmer/releases)

    trafilatura_installed <- tryCatch(
        {
            system("which trafilatura", intern = TRUE, ignore.stderr = TRUE)
            return(TRUE)
        },
        warning = function(e) {
            cli::cli_alert_warning("trafilatura is not installed. Install with: {.code pip install trafilatura}")
            return(FALSE)
        }
    )

    if (!trafilatura_installed) {
        return(
            "Impossible to crawl the website. trafilatura is not installed. Install with: {.code pip install trafilatura}"
        )
    }

    get_domain_name <- \(x) sub("^(?:https?://)?(?:www\\.)?([^/]+).*$", "\\1", x, perl = TRUE)

    tryCatch(
        {
            res <- paste0("trafilatura --sitemap '", url, "' --url-filter '", get_domain_name(url), "' --list") |>
                system(intern = TRUE) |>
                jsonlite::toJSON(pretty = FALSE, auto_unbox = TRUE)
            return(res)
        },
        error = function(e) {
            return("Impossible to fetch the contents of this web page. It might not allow scraping")
        }
    )
}
