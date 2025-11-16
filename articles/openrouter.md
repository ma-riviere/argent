# OpenRouter

## Introduction

This article covers using the OpenRouter provider with argent.
OpenRouter aggregates multiple LLM providers, offering routing
capabilities, fallback options, and access to a wide variety of models.

## Setup

``` r
openrouter <- OpenRouter$new(api_key = Sys.getenv("OPENROUTER_API_KEY"))
```

## Discovering Models and Providers

**Available Models**

OpenRouter provides access to hundreds of models from various providers:

``` r
openrouter$list_models(supported_parameters = c("tools")) |>
    dplyr::filter(
        stringr::str_detect(name, "free") & context_length > 100000 & stringr::str_detect(input_modalities, "image")
    ) |>
    dplyr::select(id, context_length, architecture)
```

**Available Providers**

``` r
openrouter$list_providers() |> 
    head(10)
```

## Basic Completion

``` r
openrouter$chat(
    "What's the R programming language? Answer in three sentences.",
    model = "z-ai/glm-4.5-air:free",
    provider_options = list(only = "z-ai")
)
```

## Tool Calling + Structured Output + Thinking

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

Then, run the agent:

``` r
openrouter$chat(
    "When was the first release of the R 'ellmer' package on GitHub?",
    model = "z-ai/glm-4.5-air:free",
    provider_options = list(only = "z-ai"),
    thinking_budget = 512,
    tools = list(as_tool(web_search), as_tool(web_fetch)),
    output_schema = package_info_schema
)
```

``` default
$release_version
[1] "0.1.0"

$release_date
[1] "January 9, 2025"
```

> **Note**
>
> Structured output works on ANY model that supports tool calling, even
> if they don’t support structured outputs or response formats natively.
> `argent` handles this through a “forced tool call” mechanism.

### Extracting Reasoning

``` r
cat(openrouter$get_reasoning_text())
```

Alternatively, simply `print(openrouter)` to see the reasoning and
answers’ text in the console, turn by turn.

> **Note**
>
> `get_reasoning_text()` and `get_content_text()` use the last API
> response (`openrouter$get_last_response()`) by default.

## Server-side Tools

Server-side tools are tools you can call without having to define them
yourself. They will be run on the provider’s server.

OpenRouter only supports one server-side tool:

- **web_search** - Web search capabilities

### Web Search

``` r
openrouter$chat(
    "When was the last version of the R 'ragnar' package released on GitHub?",
    model = "minimax/minimax-m2:free",
    provider_options = list(only = "minimax"),
    tools = list(list(type = "web_search", engine = "exa", max_results = 3)),
    output_schema = package_info_schema
)
```

Supported search engines: - `"exa"` - High-quality semantic search -
`"tavily"` - Fast general search - `"searchapi"` - Google-powered search

> **Note**
>
> You can simply use `tools = list("web_search")`, which will set the
> engine to the default (`native` with fallback to `exa`), and the max
> results to 5.

## Multimodal Inputs

OpenRouter supports sending:

- Images (files or URLs) as base64
- PDF files as base64, and URLs as-is (with configurable server-side
  parser engines:
  `as_pdf_content("pdf_url", .provider_options = list(pdf_parser = c("pdf-text", "mistral-ocr", "native"))))`)
- Text/code files
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
openrouter$chat(
    "Who are the characters in this image, and what show is it from?",
    bsg04_cast_image_path,
    model = "mistralai/mistral-small-3.2-24b-instruct:free"
)
```

``` default
The image you provided is from the TV show "Battlestar Galactica". The characters in the image are:

1. Edward James Olmos as William Adama
2. Mary McDonnell as Laura Roslin
3. Jamie Bamber as Lee "Apollo" Adama
4. Katee Sackhoff as Kara "Starbuck" Thrace
5. Tricia Helfer as Number Six
6. James Callis as Gaius Baltar
7. Grace Park as Sharon "Boomer" Valerii
```

*So say we all!*

**Sending an image URL:**

OpenRouter supports sending image URLs directly:

``` r
openrouter$chat(
    "Who are the characters in this image, and what show is it from?",
    bsg04_cast_image_url,
    model = "mistralai/mistral-small-3.2-24b-instruct:free"
)
```

> **Tip**
>
> Using
> [`as_image_content()`](https://ma-riviere.github.io/argent/reference/as_image_content.md)
> or
> [`as_text_content()`](https://ma-riviere.github.io/argent/reference/as_text_content.md)
> will force the URL to be downloaded and the image to be converted to
> base64. Furthermore,
> [`as_image_content()`](https://ma-riviere.github.io/argent/reference/as_image_content.md)
> has a `.resize` parameter to control the image size.

### PDF Comprehension

Downloading an example PDF (my CV)

``` r
my_cv_url <- "https://ma-riviere.com/res/cv.pdf"
my_cv_pdf_path <- download_temp_file(my_cv_url)
```

**Sending a local PDF:**

``` r
openrouter$chat(
    "What's my favorite programming language?",
    my_cv_pdf_path,
    model = "z-ai/glm-4.5-air:free",
    provider_options = list(only = "z-ai")
)
```

``` default
Based on the document you provided, it appears that R is your favorite programming language.
```

*Damn right!*

> **Note**
>
> When sending a PDF (local or URL) to OpenRouter, you can optionally
> specify the parser engine the server will use to parse the PDF’s
> contents via the `.provider_options` parameter of
> [`as_pdf_content()`](https://ma-riviere.github.io/argent/reference/as_pdf_content.md).
> If not specidfied (or if not using
> [`as_pdf_content()`](https://ma-riviere.github.io/argent/reference/as_pdf_content.md)),
> it will be set to `"pdf-text"` by default, which is free. The possible
> values are: `"pdf-text"`, `"mistral-ocr"`, `"native"`. See OpenRouter
> [documentation](https://openrouter.ai/docs/features/multimodal/pdfs)
> for more details.
>
> ``` r
> openrouter$chat(
>     "What's my favorite programming language?",
>     as_pdf_content(my_cv_url, .provider_options = list(pdf_parser = "mistral-ocr")),
>     model = "anthropic/claude-sonnet-4"
> )
> ```
>
> Of course, we could parse the PDF’s contents before sending them as
> text.
> [`as_text_content()`](https://ma-riviere.github.io/argent/reference/as_text_content.md)
> does this using
> [`pdftools::pdf_convert()`](https://docs.ropensci.org/pdftools//reference/pdf_render_page.html).
> Or we could have implemented our own OCR solution, e.g. using a
> `local_llm` instance with a VL model like *Qwen3-8B-VL-instruct*.

**Sending PDF URLs:**

For OpenRouter, by default, PDF URLs are sent as-is to the server.

However, we can use the
[`as_text_content()`](https://ma-riviere.github.io/argent/reference/as_text_content.md)
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
    "And give me the current versions of both packages" # To make sure you actually read the PDFs
)

openrouter$chat(!!!multimodal_prompt, model = "z-ai/glm-4.5-air:free", provider_options = list(only = "z-ai"))
```

``` default
Based on the documentation provided, here's a 3-sentence summary of the advantages of S7 over R6:

S7 provides a more formal and comprehensive object-oriented system with complete class, generic, and method specification capabilities, including multiple dispatch, which is more limited in R6. Unlike R6, S7 is designed as a successor to S3 and S4 systems with better integration into R's existing object-oriented framework and offers superior tools for method introspection through functions like method_explain(). The S7 system has been collaboratively developed by the R Consortium's Object-Oriented Programming Working Group, representing a more standardized future direction for object-oriented programming in R.

The current versions of both packages are:
- R6: Version 2.6.1 (published 2025-02-15)
- S7: Version 0.2.0 (published 2024-11-07)
```

### Passing R Objects

You can pass any R object to `chat()` as is:

``` r
lm_obj <- lm(body_mass ~ species + sex, data = datasets::penguins)

openrouter$chat(
    "What can we deduct from this regression model?",
    lm_obj,
    model = "z-ai/glm-4.5-air:free",
    provider_options = list(only = "z-ai")
)
```

``` default
From analyzing this regression model, I can deduct the following 3 key points:

1. **Species significantly affects body mass**: The coefficients show that Gentoo penguins have substantially higher body mass (+1377.9 units) compared to Adelie penguins (the reference category), while Chinstrap penguins have only slightly higher body mass (+26.9 units) compared to Adelie penguins. This suggests a large biological difference in body mass between species, with Gentoo penguins being the heaviest.

2. **Sex has a notable impact on body mass**: The coefficient for sexmale (+667.6 units) indicates that male penguins have significantly higher body mass than female penguins, regardless of species. This difference is substantial but smaller than the difference between the heaviest (Gentoo) and lightest (Adelie) species.

3. **The model uses data from 333 penguins** with measurements on body mass grouped by 3 species (Adelie, Chinstrap, Gentoo) and 2 sexes (female, male). The model has 4 parameters total (intercept + species contrasts + sex contrast) and 329 degrees of freedom for residuals, suggesting this is a reasonably sized dataset for these predictors.
```

> **Note**
>
> Any R object passed to `chat()` will be automatically converted to
> JSON (or text if JSON conversion fails), with some added information
> like the name of the object and its classes.

### File References

> **Warning**
>
> Remote file references via
> [`as_file_content()`](https://ma-riviere.github.io/argent/reference/as_file_content.md)
> are not supported with OpenRouter. Use local file paths or URLs
> instead.

## Routing

### Automatic Routing

If no model is specified, `argent` will automatically use the
`"openrouter/auto"` model router, which will route the request to the
best provider for the given request.

### Fallback Models

You can specify multiple models to use, and the first one that succeeds
will be used.

``` r
openrouter$chat(
    "What's the R programming language? Answer in three sentences.",
    model = list("deepseek/deepseek-chat-v3-0324:free", "minimax/minimax-m2:free"),
)
```

### Provider Routing

OpenRouter provides powerful provider routing capabilities through the
`provider_options` parameter. See the [OpenRouter
documentation](https://openrouter.ai/docs/features/provider-routing) for
full details.

#### Basic Provider Control

Control which providers are used and in what order:

``` r
openrouter$chat(
    prompt = "Your question here",
    model = "z-ai/glm-4.5-air:free",
    provider_options = list(
        only = c("z-ai", "atlas-cloud/fp8"),    # Only use these providers
        ignore = "chutes/bf16",                 # Never use this provider
        order = c("z-ai", "atlas-cloud/fp8")    # Try in this order
    )
)
```

#### Advanced Routing Options

``` r
openrouter$chat(
    prompt = "Your question here",
    model = "anthropic/claude-3.5-sonnet",
    provider_options = list(
        allow_fallbacks = TRUE,                 # Allow backup providers
        require_parameters = TRUE,              # Only use providers supporting all parameters
        data_collection = "deny",               # Prevent provider data storage
        zdr = TRUE,                             # Only use Zero Data Retention endpoints
        quantizations = c("int4", "int8"),      # Filter by quantization levels
        sort = "price",                         # Sort providers by price or throughput
        max_price = list(                       # Set maximum pricing
            prompt = 0.001,
            completion = 0.002
        )
    )
)
```
