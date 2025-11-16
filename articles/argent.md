# Getting Started with `argent`

## Getting Started

Here is a quick showcase of the various features of `argent` using the
Google (Gemini) provider.

> **Note**
>
> The examples shown would be mostly identical with any other provider.

``` r
gemini <- Google$new(api_key = Sys.getenv("GEMINI_API_KEY"))
```

You can customize the rate limit when initializing with the `rate_limit`
parameter.

### Basic Completion

``` r
gemini$chat(
    "What is the R programming language? Answer in two sentences.",
    model = "gemini-2.5-flash"
)
```

The chat history can be visualized by printing the provider object:

``` r
print(gemini)
```

### Tool Calling + Structured Output + Thinking

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

Then, let’s define the schema for the output using
[`schema()`](https://ma-riviere.github.io/argent/reference/tool_definitions.md):

``` r
package_info_schema <- schema(
    name = "package_info",
    description = "Information about an R package release",
    release_version = "string* The release version of the package",
    release_date = "string* The release date of the `release_version`"
)
```

> **Note**
>
> Tools and schemas are automatically converted to the provider’s
> specific format internally.

Run the agent:

``` r
gemini$chat(
    "When was the first release of the R 'ellmer' package on GitHub?",
    model = "gemini-2.5-flash",
    tools = list(as_tool(web_search), as_tool(web_fetch)),
    output_schema = package_info_schema
)
```

``` default
$release_version
[1] "ellmer_0.1.0"

$release_date
[1] "2025-01-09"
```

The model will use the tools provided (searching and fetching web pages)
repeatedly until it has enough information to answer the question, and
return structured JSON output.

#### Server-side Tools

Providers like Google, Anthropic, and OpenAI have server-side tools.
Those are tools you can call without having to define them yourself.
They will be run on the provider’s server.

For example, Google Gemini has a server-side `google_search` tool that
will offer similar capabilities as our client-side `web_search` tool.

``` r
gemini$chat(
    "When was the last version of the R 'ragnar' package released on GitHub?",
    model = "gemini-2.5-flash",
    tools = list("google_search"),
    output_schema = package_info_schema
)
```

``` default
$release_version
[1] "0.2.1"

$release_date
[1] "August 19, 2025"
```

#### Multimodal Input

All providers support multimodal inputs (to some degree). You can pass
text, images, PDFs, data files, URLs, remote files, and R objects to the
model in a single request.

##### Passing Files or URLs

Example with an URL to a PDF file:

``` r
gemini$chat(
    "What's my favorite programming language ?",
    "https://ma-riviere.com/res/cv.pdf",
    model = "gemini-2.5-flash"
)
```

``` default
Based on your resume, your favorite programming language appears to be **R**.
```

*Damn right!*

> **Note**
>
> Here, the URL was automatically detected, downloaded in a temporary
> file, and converted to base64, before being passed to the model.
>
> Other providers may have different behavior. For example, Anthropic
> supports passing PDF files URLs directly.
>
> You can use the `as_text_content(url)` helper to force the conversion
> to text content.

> **Tip**
>
> If you want to include an URL that you do not want to be parsed and
> converted (for example to be used by the `url_context` server tool),
> add it within a text block.

##### Passing R Objects

You can pass any R object to `chat()` as is:

``` r
lm_obj <- lm(body_mass ~ species + sex, data = datasets::penguins)

google_gemini$chat(
    "What can we deduct from this regression model ?",
    lm_obj,
    model = "gemini-2.5-flash"
)
```

``` default
From the provided regression model output, we can deduce the following three points:

1.  **Model Type and Purpose**: This is a linear regression model (`lm_obj`) attempting to explain or predict `body_mass` based on two categorical predictor variables: `species` and `sex`. The model was fitted using the `datasets::penguins` dataset.
2.  **Intercept and Reference Group Body Mass**: The estimated intercept is 3372.4. Given that `contr.treatment` was used for both categorical variables, this intercept represents the estimated average `body_mass` (likely in grams) for the baseline group: an **Adelie female penguin**.
3.  **Estimated Effects of Predictors**:
    *   **Species Effect**: Compared to Adelie penguins (the reference species), Chinstrap penguins are estimated to have an average `body_mass` that is 26.9 units higher, and Gentoo penguins are estimated to have an average `body_mass` that is 1377.9 units higher, assuming sex is held constant.
    *   **Sex Effect**: Compared to female penguins (the reference sex), male penguins are estimated to have an average `body_mass` that is 667.6 units higher, assuming species is held constant.
```

> **Note**
>
> The object will be captured automatically and converted to JSON (or
> text if JSON conversion fails), with some added information like the
> name of the object and its classes.

##### Passing Uploaded Files

Upload a file and reference it with
[`as_file_content()`](https://ma-riviere.github.io/argent/reference/as_file_content.md):

``` r
file_metadata <- gemini$upload_file("https://ma-riviere.com/res/cv.pdf")

multipart_prompt <- list(
    "What are my two favorite frameworks/tools ?",
    as_file_content(file_metadata$name)
)

gemini$chat(!!!multipart_prompt, model = "gemini-2.5-flash")

gemini$delete_file(file_metadata$name)
```

``` default
Based on the "Frameworks & Tools" section and the overall context of the resume, your two favorite frameworks/tools appear to be:

1.  **Shiny**
2.  **Quarto, R Markdown**
```

> **Note**
>
> Here, using
> [`as_file_content()`](https://ma-riviere.github.io/argent/reference/as_file_content.md)
> is necessary to signal to the model to use this as a remote file
> reference, rather than just some text content.

> **Tip**
>
> You can use `$list_files()` to list all uploaded files and their
> metadata.

### Documentation

#### Provider Guides

Detailed guides for each provider:

- [Google
  Gemini](https://ma-riviere.github.io/argent/articles/articles/google-gemini.md)
- [Anthropic
  Claude](https://ma-riviere.github.io/argent/articles/articles/anthropic.md)
- [OpenRouter](https://ma-riviere.github.io/argent/articles/articles/openrouter.md)
- [Local
  LLMs](https://ma-riviere.github.io/argent/articles/articles/local-llm.md)

##### OpenAI APIs

Guides for OpenAI’s three different APIs:

- [Chat Completions
  API](https://ma-riviere.github.io/argent/articles/articles/openai-completions.md) -
  Standard OpenAI chat interface
- [Responses
  API](https://ma-riviere.github.io/argent/articles/articles/openai-responses.md) -
  Newest API combining the functionalities of the Chat Completions and
  Assistants
- [Assistants
  API](https://ma-riviere.github.io/argent/articles/articles/openai-assistants.md) -
  Deprecated

##### Other Providers

- [Using Other Compatible
  APIs](https://ma-riviere.github.io/argent/articles/articles/other-providers.md) -
  Use argent classes with compatible services (e.g., Minimax instead of
  Claude)

### Other Topics

### Chat History Management

All providers (except OpenAI Assistants) support client-side chat
history management. The main methods to interact with the chat history
are:

- `get_chat_history()` - retrieve only the chat history (i.e. the
  cumulative inputs and answers from the LLM)
- `get_session_history()` - retrieve only the session history (i.e. the
  unprocessed API calls and responses)
- `reset_history()` - clear the object’s history
- `load_history()` - load history from a JSON file

The chat history maintains a list of messages exchanged between the user
and the model to be resent at each successive API call.

``` r
google_gemini <- Google$new()

google_gemini$chat(
    prompt = "My name is Alice",
    model = "gemini-2.5-flash"
)
#> [1] "Hello Alice! It's nice to meet you. How can I assist you today?"

google_gemini$chat(
    prompt = "What's my name?",
    model = "gemini-2.5-flash"
)
#> [1] "Your name is Alice."
```

Check the chat history:

``` r
cat(yaml::as.yaml(google_gemini$get_chat_history()))
```

``` json
[
  {
    "role": "user",
    "parts": [
      {
        "text": "My name is Alice"
      }
    ]
  },
  {
    "parts": [
      {
        "text": "Hello Alice! It's nice to meet you. How can I assist you today?"
      }
    ],
    "role": "model"
  },
  {
    "role": "user",
    "parts": [
      {
        "text": "What's my name?"
      }
    ]
  },
  {
    "parts": [
      {
        "text": "Your name is Alice."
      }
    ],
    "role": "model"
  }
]
```

See the total tokens used at last API call:

``` r
google_gemini$get_session_last_token_count() # Total (input + output) tokens used at last API call
google_gemini$get_session_cumulative_token_count() # Cumulative tokens used in this chat session
```

Reset the object’s history:

``` r
google_gemini$reset_history()
```

##### Automatic History Persistence

By default, history is automatically saved to timestamped JSON files in
`data/history/{provider}/`. You can:

- Change the directory via the `argent.history_dir` option
- Disable auto-save by setting `auto_save_history = FALSE` when
  initializing the provider object
- Toggle auto-save after initialization via
  `set_auto_save_history(TRUE/FALSE)`
- Check current setting via `get_auto_save_history()`

``` r
options(
    argent.history_dir = "data/history/"  # Default
)

google_gemini <- Google$new(
    auto_save_history = FALSE  # Disable automatic saving
)
```

> **Note**
>
> Resetting the history dumps the current history (if non-empty) into
> the current JSON history file in `{argent.history_dir}/{provider}/`.
> Subsequent chats will be saved to a new file.

##### Loading Previous Conversations

``` r
current_history_file_path <- google_gemini$get_history_file_path()

google_gemini <- Google$new() # Equivalent of resetting the provider object

google_gemini$load_history(current_history_file_path)
```

**A neater way to visualize the chat history is to print the provider
object:**

``` r
print(google_gemini)
```

#### Structured Outputs

`argent` supports structured outputs on **all providers**, even those
without native support, using a “forced tool call” mechanism:

``` r
# Define schema using direct specification
response_schema <- schema(
    name = "response_format",
    description = "Schema description",
    field1 = "string* Required string field",
    field2 = "number Optional numeric field"
)

result <- provider$chat(
    "Your question here",
    output_schema = response_schema
)
```

#### Tool Calling

Define tools using direct specification or annotations:

**Option 1:** Define the function and tool definition separately:

``` r
my_function <- function(arg1) {
    return(arg1)
}

my_tool <- tool(
    name = "my_function", # Has to match the actual R function to be called
    description = "What the function does",
    arg1 = "string* Required string argument description"
)
my_tool
```

**Option 2:** 2-in-1: Define the function and tool definition in one go
by adding plumber-style annotations:

``` r
my_function <- function(arg1) {
    #' @description What the function does
    #' @param arg1:string* Required string argument description

    return(arg1)
}
my_tool <- as_tool(my_function)
```

And then, use the tool within a chat:

``` r
gemini$chat(
    "Use the tool to answer this",
    tools = list(my_tool)
)
```
