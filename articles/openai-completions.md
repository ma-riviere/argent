# OpenAI - Chat Completions API

## Introduction

This article covers using OpenAI’s Chat Completions API with argent.
This is the standard OpenAI API that supports tool calling, structured
outputs, and reasoning with o1/GPT-5 models.

## Setup

``` r
openai_chat <- OpenAI_Chat$new(api_key = Sys.getenv("OPENAI_API_KEY"))
```

**Available Models**

``` r
openai_chat$list_models() |>
    dplyr::filter(stringr::str_detect(id, "-5-"))
```

## Basic Completion

``` r
openai_chat$chat(
    "What's the R programming language? Answer in three sentences.",
    model = "gpt-5-mini"
)
```

## Tool Calling + Structured Output + Reasoning

First, define some web-related tools (search, crawl, fetch, and a
general-use tool) bundled in a `web_tools` list:

Web Tools Implementation

**Search:**

``` r
web_search <- function(query) {
    #' @description Search the web for information using Tavily API. Returns a JSON array of search results with titles, URLs, and content snippets. Use this when you need current information, facts, news, or any data not in your training data.
    #' @param query:string* The search query string. Be specific and use keywords that will yield the most relevant results.
    
    return(web_search_tavily(query))
}

web_search_tavily <- function(query) {
    res <- httr2::request("https://api.tavily.com/search") |> 
        httr2::req_body_json(list(
            query = query,
            search_depth = "basic",
            include_answer = FALSE,
            max_results = 10,
            api_key = Sys.getenv("TAVILY_API_KEY")
        )) |> 
        httr2::req_error(is_error = \(resp) FALSE) |> 
        httr2::req_throttle(rate = 20/60, realm = "tavily") |> 
        httr2::req_perform() |> 
        httr2::resp_body_json() |> 
        purrr::discard_at(c("response_time", "follow_up_questions", "images"))

    results <- purrr::map(res$results, \(x) purrr::discard_at(x, "raw_content"))

    return(jsonlite::toJSON(results, pretty = FALSE, auto_unbox = TRUE))
}
```

**Fetch:**

``` r
web_fetch <- function(url) {
    #' @description Fetch and extract the main text content from a web page as clean markdown. Returns the page content with formatting preserved, stripped of navigation, ads, and boilerplate. Use this to read articles, documentation, blog posts, or any web page content. Automatically falls back to alternative methods if the primary fetch fails.
    #' @param url:string* The complete URL of the web page to fetch (e.g., "https://example.com/article"). Must be a valid HTTP/HTTPS URL.
    
    res <- web_fetch_trafilatura(url)

    could_not_fetch <- c(
        "Impossible to fetch the contents of this web page",
        "Please reload this page",
        "There was an error while loading",
        "404"
    )
    if (is.null(res) || is.na(res) || nchar(res) == 0 ||
        any(stringr::str_detect(res, stringr::fixed(could_not_fetch, ignore_case = TRUE)))) {
        res <- web_fetch_rvest(url)
    }
    return(res)
}

web_fetch_trafilatura <- function(url) {
    # pip install trafilatura
    tryCatch({
        res <- paste0("trafilatura -u ", url, " --markdown --no-comments --links ") |> 
            system(intern = TRUE) |> 
            purrr::keep(nzchar) |>
            paste0(collapse = "\n")
        
        return(res)
    },
    error = function(e) {
        return("Impossible to fetch the contents of this web page. It might not allow scraping")
    })
}

web_fetch_rvest <- function(url) {
    tags_to_ignore <- c(
        "a", "script", "code", "img", "svg", "footer", "g", "path", "polygon", "label", "button", "form", "input", "select", 
        "style", "link", "meta", "noscript", "iframe", "embed", "object", "param", "video", "audio", "track", "source", 
        "canvas", "map", "area", "math", "col", "colgroup", "dl", "dt", "dd", "hr", "pre", "address", "figure", "figcaption",
        "dfn", "em", "kbd", "samp", "var", "del", "ins", "mark", "circle"
    )

    remove_tags <- function(xml, tags) {
        purrr::walk(tags, \(tag) purrr::walk(xml2::xml_find_all(xml, paste0(".//", tag)), \(node) xml2::xml_remove(node)))
        return(xml)
    }

    cleaned_contents <- tryCatch(
        rvest::read_html(url)
        |> rvest::html_element("body")
        |> remove_tags(tags_to_ignore)
        |> rvest::html_children()
        |> rvest::html_text2()
        |> purrr::discard(\(x) x == "")
        |> paste0(collapse = "\n\n"),
        error = \(e) return("")
    )
    return(cleaned_contents)
}
```

Then, let’s define a JSON schema for the structured output using
[`schema()`](https://ma-riviere.github.io/argent/reference/tool_definitions.md):

``` r
package_info_schema <- schema(
    name = "package_info",
    description = "Information about an R package release",
    release_version = "string* The release version of the package",
    release_date = "string* The release date of the `release_version`"
)
```

``` r
openai_chat$chat(
    "When was the first release of the R 'ellmer' package on GitHub?",
    model = "gpt-5-mini",
    reasoning_effort = "low",
    tools = list(as_tool(web_search), as_tool(web_fetch)),
    output_schema = package_info_schema
)
```

``` default
$release_version
[1] "v0.1.0"

$release_date
[1] "2025-01-09T18:06:27Z"
```

> **Note**
>
> The Chat Completions API does not support extracting reasoning
> content.

## Server-side Tools

Server-side tools are tools you can call without having to define them
yourself. They will be run on the provider’s server.

OpenAI Chat Completions API only supports one server-side tool:
**web_search**

### Server-side: Web Search

OpenAI provides specialized search models with web search capabilities
for the Chat Completions API:

- `gpt-5-search-api`
- `gpt-4o-search-preview`
- `gpt-4o-mini-search-preview`

**Basic usage:** `search-preview` models automatically use web search

``` r
openai_chat$chat(
    "What's the latest version of the R 'ellmer' package?",
    model = "gpt-4o-mini-search-preview"
)
```

**Advanced usage:** we can pass additional options to the web search
tool

``` r
openai_chat$chat(
    "What are the best restaurants near me?",
    model = "gpt-4o-mini-search-preview",
    tools = list(list(
        type = "web_search",
        user_location = list(
            type = "approximate",
            approximate = list(
                country = "NO",
                city = "Trondheim",
                timezone = "Europe/Oslo"
            )
        ),
        search_context_size = "medium"  # "low", "medium", or "high"
    ))
)
```

**Cost**: Web searches incur \$25.00/1k calls plus token costs.

> **Note**
>
> Search models do not support standard sampling parameters
> (temperature, top_p, frequency_penalty, presence_penalty, n). These
> are automatically omitted when using search models.

**Extracting the annotations:** we can extract the annotations with
`openai_chat$get_supplementary()` or
`print(openai_chat, show_supplementary = TRUE)`.

``` r
cat(yaml::as.yaml(openai_chat$get_supplementary()))
```

Web search annotations

``` yaml
annotations:
- type: url_citation
  url_citation:
    end_index: 284
    start_index: 196
    title: Fagn
    url: https://www.google.com/maps/search/Fagn%2C+Trondheim%2C+Norway?utm_source=openai
- type: url_citation
  url_citation:
    end_index: 584
    start_index: 484
    title: Speilsalen
    url: https://www.google.com/maps/search/Speilsalen%2C+Trondheim%2C+Norway?utm_source=openai
- type: url_citation
  url_citation:
    end_index: 909
    start_index: 819
    title: Credo
    url: https://www.google.com/maps/search/Credo%2C+Trondheim%2C+Norway?utm_source=openai
- type: url_citation
  url_citation:
    end_index: 1241
    start_index: 1122
    title: To Rom og Kjøkken
    url: https://www.google.com/maps/search/To+Rom+og+Kj%C3%B8kken%2C+Trondheim%2C+Norway?utm_source=openai
- type: url_citation
  url_citation:
    end_index: 1562
    start_index: 1427
    title: Havfruen Sjømatrestaurant
    url: https://www.google.com/maps/search/Havfruen+Sj%C3%B8matrestaurant%2C+Trondheim%2C+Norway?utm_source=openai
- type: url_citation
  url_citation:
    end_index: 1837
    start_index: 1729
    title: Bula Neobistro
    url: https://www.google.com/maps/search/Bula+Neobistro%2C+Trondheim%2C+Norway?utm_source=openai
- type: url_citation
  url_citation:
    end_index: 2111
    start_index: 1989
    title: Vertshuset Grenaderen
    url: https://www.google.com/maps/search/Vertshuset+Grenaderen%2C+Trondheim%2C+Norway?utm_source=openai
- type: url_citation
  url_citation:
    end_index: 2805
    start_index: 2686
    title: Top 10 Best Restaurants to Visit in Trondheim | Norway
    url: https://www.youtube.com/watch?v=0J6xfdlb3I4&utm_source=openai
```

For more flexible server-side tools, use the [Responses
API](https://ma-riviere.github.io/argent/articles/responses-api.md)
instead.

## Multimodal Inputs

OpenAI Responses API supports sending:

- Images: URLs (as-is, or base64), files (base64)
- PDFs: URLs and files (base64, or text content)
- Remote files (through
  [`as_file_content()`](https://ma-riviere.github.io/argent/reference/content_converters.md))
- Plain text & code files
- Text-based data files (csv, tsv, json, ..)
- R objects

### Image Comprehension

Downloading an example image

``` r
bsg04_cast_image_url <- "https://upload.wikimedia.org/wikipedia/en/1/1a/Battlestar_Galactica_%282004%29_cast.jpg"
bsg04_cast_image_path <- download_temp_file(bsg04_cast_image_url)
```

**Sending a local image:**

When providing a path to a local image, it will automatically be
converted to base64 before being sent to the server.

``` r
openai_chat$chat(
    "Who are the characters in this image, and what show is it from?",
    bsg04_cast_image_path,
    model = "gpt-5-mini"
)
```

``` default
This is a promotional shot of the main characters from the reimagined TV series Battlestar Galactica (2004). From left to right the characters are:

- Admiral William Adama (commander of the battlestar)
- President Laura Roslin
- Captain Lee "Apollo" Adama
- Kara "Starbuck" Thrace
- Number Six (the Cylon model)
- Dr. Gaius Baltar (with Number Six)
- Sharon "Boomer" Valerii (a Cylon sleeper/Raptor pilot)

(If you want, I can point out who plays each character.)
```

*So say we all!*

**Sending an image URL:**

``` r
openai_chat$chat(
    "Who are the characters in this image, and what show is it from?",
    bsg04_cast_image_url,
    model = "gpt-5-mini"
)
```

> **Note**
>
> OpenAI supports an optional `detail` parameter (low/high/auto) to
> control the image processing detail level when the image is sent as a
> URL. The default value is `"auto"`.
>
> To specify this parameter, we need to pass the image URL to
> `as_image_content(url, .provider_options = list(detail = "low"))`.
>
> We could have used the
> [`as_image_content()`](https://ma-riviere.github.io/argent/reference/content_converters.md)
> to resize the image before sending it with the `.resize` argument.
>
> OpenAI Chat Completions API also supports sending a file_id (i.e. the
> image `as_file_content(file_id)` after uploading it with
> `openai_chat$upload_file()`).

### PDF Comprehension

Downloading an example PDF (my CV)

``` r
my_cv_url <- "https://ma-riviere.com/res/cv.pdf"
my_cv_pdf_path <- download_temp_file(my_cv_url)
```

**Sending a local PDF:**

``` r
openai_chat$chat(
    "What's my favorite programming language?",
    my_cv_pdf_path,
    model = "gpt-5-mini"
)
```

``` default
Based on the resume you provided (page 1), your favorite programming language appears to be R — the header says "R Programming | Data Science | Neuroscience," you list R first under Programming Skills, and you have a strong focus on R & Shiny in your work experience. If that’s not right, tell me which source I should check or confirm your actual preference.
```

*Damn right!*

**Sending PDF URLs:**

For OpenAI Chat Completions, by default, PDF URLs are sent as base64 to
the server.

However, we can use the
[`as_text_content()`](https://ma-riviere.github.io/argent/reference/content_converters.md)
helper to have
[`pdftools::pdf_convert()`](https://docs.ropensci.org/pdftools//reference/pdf_render_page.html)
parse the PDFs and pass their text contents to the model instead.

``` r
r6_pdf_url <- "https://cran.r-project.org/web/packages/R6/R6.pdf"
s7_pdf_url <- "https://cran.r-project.org/web/packages/S7/S7.pdf"

multimodal_prompt <- list(
    "Give a 3 sentences summary of the advantages of S7 over R6",
    as_text_content(r6_pdf_url),
    as_text_content(s7_pdf_url),
    "And give me the current versions of both packages" # To make sure it actually reads the PDFs
)

openai_chat$chat(!!!multimodal_prompt, model = "gpt-5-mini")
```

### Passing R Objects

You can pass any R object to `chat()` as is:

``` r
lm_obj <- lm(body_mass ~ species + sex, data = datasets::penguins)

openai_chat$chat(
    "What can we deduct from this regression model?",
    lm_obj,
    model = "gpt-5-mini"
)
```

``` default
1) Estimated effects (relative to the reference group Adelie & female):  
   - Intercept = 3372.4 g → predicted body mass for an Adelie female ≈ 3372 g.  
   - speciesChinstrap = +26.9 g → Chinstrap females ≈ 27 g heavier than Adelie females (practically negligible).  
   - speciesGentoo = +1377.9 g → Gentoo females ≈ 1378 g heavier than Adelie females (large difference).  
   - sexmale = +667.6 g → males ≈ 668 g heavier than females (same additive effect across species).

2) Predicted group means (by combination):  
   - Adelie female ≈ 3372 g; Adelie male ≈ 3372.4 + 667.6 ≈ 4040 g.  
   - Chinstrap female ≈ 3372.4 + 26.9 ≈ 3399 g; Chinstrap male ≈ 3399 + 667.6 ≈ 4067 g.  
   - Gentoo female ≈ 3372.4 + 1377.9 ≈ 4750 g; Gentoo male ≈ 4750 + 667.6 ≈ 5418 g.

3) Model structure and caveats:  
   - This is an additive linear model (body_mass ~ species + sex) using treatment contrasts (Adelie & female as baselines); sex effect is assumed equal across species (no interaction included).  
   - There are 333 observations (11 rows omitted), rank = 4, df.residual = 329.  
   - The output quoted does not show standard errors, p-values, R² or diagnostic statistics, so you cannot formally assess statistical significance or overall fit from what’s shown — run summary(lm_obj) and diagnostic plots to check significance and model assumptions.
```

### Sending files

We can also send files directly to the model.

**Uploading Files**

``` r
file_metadata <- openai_chat$upload_file(my_cv_url)
```

**Listing Files**

``` r
openai_chat$list_files()
```

``` default
# A tibble: 1 × 9
  object id                          purpose   filename               bytes created_at          expires_at status    status_details
  <chr>  <chr>                       <chr>     <chr>                  <int> <dttm>              <lgl>      <chr>     <lgl>         
1 file   file-5LtQyoh6ZdtK71TpZdTxSn user_data file1cc931188f797.pdf 431965 2025-11-11 21:49:14 NA         processed NA 
```

**Using Uploaded Files**

Use
[`as_file_content()`](https://ma-riviere.github.io/argent/reference/content_converters.md)
to reference uploaded files:

``` r
openai_chat$chat(
    "What are my two favorite frameworks/tools ?",
    as_file_content(file_metadata$id),
    model = "gpt-5-mini"
)
```

``` default
On your CV (Frameworks & Tools section, right column on page 1) the top two listed are:
- Shiny
- Scientific publishing tools — Quarto / R Markdown

So your two favorite frameworks/tools appear to be Shiny and Quarto (R Markdown).
```

**Downloading Files**

``` r
openai_chat$download_file(file_metadata$id, dest_path = "data")  # Downloads to data/ by default
#> ✔ [OpenAI] File downloaded to: data/file1cc931188f797.pdf
```

**Deleting Files**

``` r
openai_chat$delete_file(file_metadata$id)
#> ✔ [OpenAI] File deleted: file-5LtQyoh6ZdtK71TpZdTxSn
```
