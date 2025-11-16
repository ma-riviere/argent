

<!-- markdownlint-disable -->
<!-- README.md is generated from README.qmd. Please edit that file instead. -->

# argent: LLM Agents in R

<!-- badges: start -->

[![License:
MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lifecycle:
questioning](https://img.shields.io/badge/lifecycle-questioning-blue.svg)](https://lifecycle.r-lib.org/articles/stages.html#questioning)
<!-- badges: end -->

**argent** provides a unified R6-based interface for interacting with
Large Language Models (LLMs) from multiple providers, specialized for
creating AI agents with tool calling, multimodal inputs, and structured
outputs.

> **Important**
>
> Why **questioning** ? In most cases, you’d be better off using
> [ellmer](https://github.com/tidyverse/ellmer).
>
> I started working on this back in 2023 when none of the existing LLM
> packages supported tool calling or structured outputs, but I never
> took the time to put everything into a proper package until now.
> However, there are now several similar packages, including
> [ellmer](https://github.com/tidyverse/ellmer) by the Tidyverse team.
>
> I’m putting `argent` out there in case it supports some edge cases
> that other packages don’t, and because I didn’t want to let all that
> work go to waste. But I will be progressively migrating my projects to
> `ellmer`, and I am not sure how long I’ll maintain `argent`.

## In a Nutshell

`argent` provides a unified interface to build AI agents with
conversation history management, server or client-side tool calling,
multimodal inputs, and universal structured outputs.

It supports most **server-side tools** (code execution, web search, file
search, etc.) and allows to easily define **client-side tools** using
plumber2-style annotations within R functions. It allows sending
**multimodal inputs** (i.e. mixing text, images, PDFs, data files, URLs,
remote files, and R objects) in a single request, and it supports
**structured outputs** for ***any*** model supporting tool calling,
whatever other tools/functions are used.

## Supported Providers & Features

<table>
<colgroup>
<col style="width: 8%" />
<col style="width: 7%" />
<col style="width: 10%" />
<col style="width: 12%" />
<col style="width: 17%" />
<col style="width: 18%" />
<col style="width: 11%" />
<col style="width: 10%" />
</colgroup>
<thead>
<tr>
<th>Feature</th>
<th>Google</th>
<th>Anthropic</th>
<th>OpenAI Chat</th>
<th>OpenAI Responses</th>
<th>OpenAI Assistants</th>
<th>OpenRouter</th>
<th>Local LLM</th>
</tr>
</thead>
<tbody>
<tr>
<td><strong>Tool calling</strong></td>
<td>✅</td>
<td>✅</td>
<td>✅</td>
<td>✅</td>
<td>✅</td>
<td>⚠️<a href="#fn1" class="footnote-ref" id="fnref1"
role="doc-noteref"><sup>1</sup></a></td>
<td>⚠️<a href="#fn2" class="footnote-ref" id="fnref2"
role="doc-noteref"><sup>2</sup></a></td>
</tr>
<tr>
<td><strong>Structured outputs</strong></td>
<td>✅</td>
<td>✅</td>
<td>✅</td>
<td>✅</td>
<td>✅</td>
<td>✅<a href="#fn3" class="footnote-ref" id="fnref3"
role="doc-noteref"><sup>3</sup></a></td>
<td>✅<a href="#fn4" class="footnote-ref" id="fnref4"
role="doc-noteref"><sup>4</sup></a></td>
</tr>
<tr>
<td><strong>Multimodal inputs</strong></td>
<td>✅</td>
<td>✅</td>
<td>✅</td>
<td>✅</td>
<td>✅</td>
<td>✅</td>
<td>⚠️<a href="#fn5" class="footnote-ref" id="fnref5"
role="doc-noteref"><sup>5</sup></a></td>
</tr>
<tr>
<td><strong>Server-side tools</strong></td>
<td>✅<a href="#fn6" class="footnote-ref" id="fnref6"
role="doc-noteref"><sup>6</sup></a></td>
<td>✅<a href="#fn7" class="footnote-ref" id="fnref7"
role="doc-noteref"><sup>7</sup></a></td>
<td>⚠️<a href="#fn8" class="footnote-ref" id="fnref8"
role="doc-noteref"><sup>8</sup></a></td>
<td>✅<a href="#fn9" class="footnote-ref" id="fnref9"
role="doc-noteref"><sup>9</sup></a></td>
<td>✅<a href="#fn10" class="footnote-ref" id="fnref10"
role="doc-noteref"><sup>10</sup></a></td>
<td>⚠️<a href="#fn11" class="footnote-ref" id="fnref11"
role="doc-noteref"><sup>11</sup></a></td>
<td>❌</td>
</tr>
<tr>
<td><strong>Code execution</strong></td>
<td>✅</td>
<td>✅</td>
<td>❌</td>
<td>✅</td>
<td>✅</td>
<td>❌</td>
<td>❌</td>
</tr>
<tr>
<td><strong>File upload</strong></td>
<td>✅</td>
<td>✅</td>
<td>✅</td>
<td>✅</td>
<td>✅</td>
<td>❌</td>
<td>❌</td>
</tr>
<tr>
<td><strong>Server-side RAG</strong></td>
<td>✅</td>
<td>❌</td>
<td>❌</td>
<td>✅</td>
<td>✅</td>
<td>❌</td>
<td>❌</td>
</tr>
<tr>
<td><strong>Reasoning / thinking</strong></td>
<td>✅</td>
<td>✅</td>
<td>⚠️</td>
<td>✅</td>
<td>❌</td>
<td>⚠️<a href="#fn12" class="footnote-ref" id="fnref12"
role="doc-noteref"><sup>12</sup></a></td>
<td>⚠️<a href="#fn13" class="footnote-ref" id="fnref13"
role="doc-noteref"><sup>13</sup></a></td>
</tr>
<tr>
<td><strong>Server-side state</strong></td>
<td>❌</td>
<td>❌</td>
<td>❌</td>
<td>✅<a href="#fn14" class="footnote-ref" id="fnref14"
role="doc-noteref"><sup>14</sup></a></td>
<td>✅</td>
<td>❌</td>
<td>❌</td>
</tr>
<tr>
<td><strong>Prompt caching</strong></td>
<td>✅</td>
<td>✅</td>
<td>✅<a href="#fn15" class="footnote-ref" id="fnref15"
role="doc-noteref"><sup>15</sup></a></td>
<td>✅<a href="#fn16" class="footnote-ref" id="fnref16"
role="doc-noteref"><sup>16</sup></a></td>
<td>✅<a href="#fn17" class="footnote-ref" id="fnref17"
role="doc-noteref"><sup>17</sup></a></td>
<td>⚠️<a href="#fn18" class="footnote-ref" id="fnref18"
role="doc-noteref"><sup>18</sup></a></td>
<td>❌</td>
</tr>
<tr>
<td><strong>Status</strong></td>
<td>Active</td>
<td>Active</td>
<td>Active</td>
<td>Active</td>
<td><strong>Deprecated</strong><a href="#fn19" class="footnote-ref"
id="fnref19" role="doc-noteref"><sup>19</sup></a></td>
<td>Active</td>
<td>Active</td>
</tr>
</tbody>
</table>
<section id="footnotes" class="footnotes footnotes-end-of-document"
role="doc-endnotes">
<hr />
<ol>
<li id="fn1"><p>Depends on model capabilities. Not all models support
tool calling.<a href="#fnref1" class="footnote-back"
role="doc-backlink">↩︎</a></p></li>
<li id="fn2"><p>Depends on model capabilities. Not all models support
tool calling.<a href="#fnref2" class="footnote-back"
role="doc-backlink">↩︎</a></p></li>
<li id="fn3"><p>Works on any model supporting tool calling. Works even
if you provide other tools, client-side or server-side, to the model at
the same time.<a href="#fnref3" class="footnote-back"
role="doc-backlink">↩︎</a></p></li>
<li id="fn4"><p>Works on any model supporting tool calling. Works even
if you provide other tools, client-side or server-side, to the model at
the same time.<a href="#fnref4" class="footnote-back"
role="doc-backlink">↩︎</a></p></li>
<li id="fn5"><p>Depends on model capabilities<a href="#fnref5"
class="footnote-back" role="doc-backlink">↩︎</a></p></li>
<li id="fn6"><p>google_search, google_maps, url_context, code_execution,
file_search<a href="#fnref6" class="footnote-back"
role="doc-backlink">↩︎</a></p></li>
<li id="fn7"><p>web_search, web_fetch, code_execution<a href="#fnref7"
class="footnote-back" role="doc-backlink">↩︎</a></p></li>
<li id="fn8"><p>Only web search via specialized models
(gpt-4o-mini-search-preview)<a href="#fnref8" class="footnote-back"
role="doc-backlink">↩︎</a></p></li>
<li id="fn9"><p>web_search, file_search, code_interpreter<a
href="#fnref9" class="footnote-back" role="doc-backlink">↩︎</a></p></li>
<li id="fn10"><p>file_search, code_interpreter<a href="#fnref10"
class="footnote-back" role="doc-backlink">↩︎</a></p></li>
<li id="fn11"><p>web_search available on some models<a href="#fnref11"
class="footnote-back" role="doc-backlink">↩︎</a></p></li>
<li id="fn12"><p>Depends on model, and on server configuration (e.g.,
<code>--reasoning-format</code> for llama.cpp)<a href="#fnref12"
class="footnote-back" role="doc-backlink">↩︎</a></p></li>
<li id="fn13"><p>Depends on model, and on server configuration (e.g.,
<code>--reasoning-format</code> for llama.cpp)<a href="#fnref13"
class="footnote-back" role="doc-backlink">↩︎</a></p></li>
<li id="fn14"><p>Optional via <code>previous_response_id</code> (30-day
retention)<a href="#fnref14" class="footnote-back"
role="doc-backlink">↩︎</a></p></li>
<li id="fn15"><p>Automatic prompt caching by OpenAI<a href="#fnref15"
class="footnote-back" role="doc-backlink">↩︎</a></p></li>
<li id="fn16"><p>Automatic prompt caching by OpenAI<a href="#fnref16"
class="footnote-back" role="doc-backlink">↩︎</a></p></li>
<li id="fn17"><p>Automatic prompt caching by OpenAI<a href="#fnref17"
class="footnote-back" role="doc-backlink">↩︎</a></p></li>
<li id="fn18"><p>Depends on the underlying provider being used<a
href="#fnref18" class="footnote-back" role="doc-backlink">↩︎</a></p></li>
<li id="fn19"><p>Shuts down August 26, 2026. Use Responses API
instead.<a href="#fnref19" class="footnote-back"
role="doc-backlink">↩︎</a></p></li>
</ol>
</section>

## Installation

``` r
remotes::install_github("ma-riviere/argent")
```

## Setup

Set the API keys for the providers you want to use in your `.Renviron`:

``` r
GEMINI_API_KEY="your-google-gemini-key"
ANTHROPIC_API_KEY="your-anthropic-key"
OPENAI_API_KEY="your-openai-key"
```

## Quick Start

Here is a quick example using Google Gemini:

``` r
gemini <- Google$new(api_key = Sys.getenv("GEMINI_API_KEY"))
```

You can customize the rate limit when initializing with the `rate_limit`
parameter, and the default model with the `default_model` parameter
(‘gemini-2.5-flash’ for Google).

### Basic Completion

``` r
gemini$chat(
    "What is the R programming language? Answer in two sentences.",
    model = "gemini-2.5-flash" # Not necessary, it's the default model for Google
)
```

`argent` will maintain a conversation history in the provider object,
meaning that when using `$chat()` a second time, the model will have
access to the previous exchanges:

``` r
gemini$chat("Tell me more about its statistical modeling capabilities.")
```

The chat history can be visualized by printing the provider object:

``` r
print(gemini)
```

``` default
── [ <Google> turns: 4 | Current context: 419 | Cumulated tokens: 676 ] ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────


── user [159 / 257] ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

What is the R programming language? Answer in two sentences.

── System ──

You are a helpful AI assistant. Use your knowledge, the files you have access to, and the tools at your disposal to answer the user's query. You can use your tools multiple times, but use them sparingly. Make parallel tool calls if relevant to the user's query. Answer the user's query as soon as you have the information necessary to answer. Self-reflect and double-check your answer before responding. If you don't know the answer even after using your tools, say 'I don't know'. If you do not have all the information necessary to use a provided tool, use NA for required arguments. Today's date is 2025-11-15

── assistant [257 / 257] ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

R is a programming language and free software environment primarily used for statistical computing and graphics. It provides a wide variety of statistical (linear and nonlinear modeling, classical statistical tests, time-series analysis, classification, clustering, etc.) and graphical techniques, and is highly extensible.


── user [224 / 676] ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Tell me more about its statistical modeling capabilities.

── System ──

You are a helpful AI assistant. Use your knowledge, the files you have access to, and the tools at your disposal to answer the user's query. You can use your tools multiple times, but use them sparingly. Make parallel tool calls if relevant to the user's query. Answer the user's query as soon as you have the information necessary to answer. Self-reflect and double-check your answer before responding. If you don't know the answer even after using your tools, say 'I don't know'. If you do not have all the information necessary to use a provided tool, use NA for required arguments. Today's date is 2025-11-15

── assistant [419 / 676] ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

R offers extensive statistical modeling capabilities, encompassing a broad range of techniques. It supports linear and generalized linear models (GLMs) for various response types, as well as nonlinear regression. Users can perform classical statistical tests like t-tests, ANOVA, and chi-squared tests. Furthermore, R is widely used for time-series analysis, including ARIMA models and state-space models, classification algorithms such as logistic regression, decision trees, and support vector machines, and clustering methods like k-means and hierarchical clustering. Its package ecosystem continuously expands these capabilities with cutting-edge statistical methodologies.
```

> **Note**
>
> You can also check the JSON files containing the chat history that are
> created automatically in the `data/history/{provider}/` directory
> (default).

The chat history can be reset with `reset_history()`:

``` r
gemini$reset_history()
```

### Tool Calling + Structured Output

First, let’s define a mock function for the LLM:

``` r
get_user_info <- function(user_name) {
    #' @description Provides information about the user, like their favorite programming language
    #' @param user_name:string* The name of the user
    
    switch(
        user_name,
        "Marc" = list(favorite_language = "R", favorite_framework = "Shiny"),
        "Alice" = list(favorite_language = "Python", favorite_framework = "Flask"),
        "Bob" = list(favorite_language = "JavaScript", favorite_framework = "React"),
        .default = list(favorite_language = "unknown", favorite_framework = "unknown")
    )
}
```

We can then call `as_tool()` on the function to convert it to a tool
using the annotations added inside the function’s body (plumber2-style
annotations):

``` r
as_tool(get_user_info)
```

``` yaml
name: get_user_info
description: Provides information about the user, like their favorite programming
  language
args_schema:
  type: object
  properties:
    user_name:
      type: string
      description: The name of the user
  required:
  - user_name
```

Then, let’s define the schema for the structured output using
`schema()`:

``` r
user_info_schema <- schema(
    name = "user_info",
    description = "Information about the user",
    user_name = "string* The name of the user",
    favorite_language = "string* The user's favorite programming language",
    favorite_framework = "string* The user's favorite framework"
)
```

Run the agent:

``` r
gemini$chat(
    "The user's name is Marc. Give me the information about the user.",
    model = "gemini-2.5-flash",
    thinking_budget = 512,
    include_thoughts = TRUE, # Google-specific parameter
    tools = list(as_tool(get_user_info)),
    output_schema = user_info_schema
)
```

``` default
$user_name
[1] "Marc"

$favorite_language
[1] "R"

$favorite_framework
[1] "Shiny"
```

The model will use the tools provided repeatedly until it has enough
information to answer the question, and return structured JSON output.

> **Tip**
>
> By default, `argent` will print the tool calls the model makes in the
> console:
>
> ℹ \[Google\] Calling: get_user_info(user_name = “Marc”)

To see more, we can print the provider object with `show_tools = TRUE`
to show to tool definitions, calls, and results:

``` r
print(gemini, show_tools = TRUE)
```

``` default
── [ <Google> turns: 4 | Current context: 480 | Cumulated tokens: 773 ] ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────


── user [216 / 293] ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

The user's name is Marc. Give me the information about the user.

── System ──

You are a helpful AI assistant. Use your knowledge, the files you have access to, and the tools at your disposal to answer the user's query. You can use your tools multiple times, but use them sparingly. Make parallel tool calls if relevant to the user's query. Answer the user's query as soon as you have the information necessary to answer. Self-reflect and double-check your answer before responding. If you don't know the answer even after using your tools, say 'I don't know'. If you do not have all the information necessary to use a provided tool, use NA for required arguments. Today's date is 2025-11-15

── assistant [293 / 293] ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

── Thinking ──

**Accessing User Information: Marc**

Okay, so I need to find some information about a user named Marc.  The `get_user_info` tool looks like the perfect candidate for this. It's designed specifically for retrieving user details, and the `user_name` parameter is exactly what I need.  It's straightforward; I can just call the tool with `user_name='Marc'` and expect a detailed response. Simple and efficient, just the way I like it.


── tool [404 / 773] ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

── assistant [480 / 773] ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

── Thinking ──

**Understanding Marc's Preferences**

Okay, so the user wants to know about Marc. My first instinct, as always, is to leverage my tools. I employed the `get_user_info` function, specifically targeting 'Marc'. The response I received confirmed what I suspected: Marc's a fellow R enthusiast! Apparently, R is his favorite language. And beyond that, it looks like Shiny's the framework he gravitates towards. With this knowledge in hand, I can now craft a concise and informative response to the user's query, highlighting Marc's language and framework preferences, which are key elements to understand the landscape of skills.



Marc's favorite programming language is R and his favorite framework is Shiny.
```

### Server-side Tools

Providers like Google, Anthropic, and OpenAI have server-side tools.
Those are tools you can call without having to define them yourself.
They will be run on the provider’s server.

For example, Google Gemini has a server-side `google_search` which
combines searching & fetching web pages:

``` r
gemini$chat(
    "When was the first release of the R 'ellmer' package on GitHub?",
    model = "gemini-2.5-pro",
    tools = list("google_search"),
    thinking_budget = -1, # Unlimited thinking budget
    include_thoughts = TRUE, # Google-specific parameter
    output_schema = schema(
        name = "package_info",
        description = "Information about an R package release",
        release_version = "string* The release version of the package",
        release_date = "string* The release date of the `release_version`"
    )
)
```

``` default
$release_version
[1] "0.1.1"

$release_date
[1] "2025-02-25"
```

### Multimodal Input

All providers support multimodal inputs (to some degree). You can pass
text, images, PDFs, data files, URLs, remote files, and R objects to the
model in a single request.

#### Passing Files or URLs

Example with an URL to a PDF file:

``` r
bsg04_cast_image_url <- "https://upload.wikimedia.org/wikipedia/en/1/1a/Battlestar_Galactica_%282004%29_cast.jpg"

gemini$chat(
    "Who are the characters in this image, and what show is it from?",
    bsg04_cast_image_url,
    model = "gemini-2.5-flash"
)
```

``` default
This image features the cast of **Battlestar Galactica (2004 TV series)**.

The characters shown are:
*   **Edward James Olmos** as Admiral William Adama
*   **Mary McDonnell** as President Laura Roslin
*   **Jamie Bamber** as Captain Lee "Apollo" Adama
*   **Katee Sackhoff** as Captain Kara "Starbuck" Thrace
*   **Tricia Helfer** as Number Six
*   **James Callis** as Dr. Gaius Baltar
*   **Grace Park** as Lieutenant Sharon "Boomer" Valerii / Number Eight
```

*So say we all!*

> **Note**
>
> Here, the URL was automatically detected, downloaded in a temporary
> file, and converted to base64, before being passed to the model.
>
> Other providers may have different behavior. For example, Anthropic
> supports passing images & PDFs URLs directly.
>
> Helper functions like `as_text_content()` are available to force some
> behaviors (like extracting the contents of the PDF instead of passing
> base64).

> **Tip**
>
> We can also pass any R object to `chat()` as is. They will be captured
> automatically and converted to JSON (or text if JSON conversion
> fails), with some added information like the name of the object and
> its classes.

#### Passing Uploaded Files

Finally, major providers support uploading files to their servers, and
passing them as references to the model, to use them in the
conversation, either on their own, or as part of a vector store / RAG
system (see [server-side
RAG](./articles/google-gemini.html#server-side-rag)).

``` r
file_metadata <- gemini$upload_file("https://ma-riviere.com/res/cv.pdf")
#> ✔ [Google] File uploaded: files/7xulp36j9jq1
```

``` r
multipart_prompt <- list(
    "What is my favorite programming language?",
    as_file_content(file_metadata$name)
)

gemini$chat(!!!multipart_prompt, model = "gemini-2.5-flash")
```

``` default
Based on your resume, your favorite programming language appears to be **R**.
```

*Damn right!*

``` r
gemini$delete_file(file_metadata$name)
#> ✔ [Google] File deleted: files/7xulp36j9jq1
```

> **Note**
>
> Here, using `as_file_content()` signals to the model that this is a
> remote file reference, rather than just some text content.

> **Tip**
>
> You can use `$list_files()` to list all uploaded files and their
> metadata.

## Documentation

### Provider Guides

Detailed guides for each provider:

-   [Google Gemini](articles/google-gemini.html)
-   [Anthropic Claude](articles/anthropic.html)
-   [OpenRouter](articles/openrouter.html)
-   [Local LLMs](articles/local-llm.html)

#### OpenAI APIs

Guides for OpenAI’s three different APIs:

-   [Chat Completions API](articles/openai-completions.html) - Standard
    OpenAI chat interface
-   [Responses API](articles/openai-responses.html) - Newest API
    combining the functionalities of the Chat and Assistants
-   [Assistants API](articles/openai-assistants.html) - Deprecated

#### Other Providers

-   [Using Other Compatible APIs](articles/other-providers.html) - Use
    argent classes with compatible services (e.g., Minimax instead of
    Claude)

### Advanced Topics

-   [RAG Applications](articles/usecase-rag.html) - Retrieval-Augmented
    Generation patterns

## Contributing

You should probably contribute to
[ellmer](https://github.com/tidyverse/ellmer/) instead.

## License

MIT License
