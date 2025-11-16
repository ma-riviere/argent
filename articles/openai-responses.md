# OpenAI - Responses API

## Introduction

This article covers using OpenAI’s Responses API with `argent`. This is
OpenAI’s newest and most advanced API that combines the strengths of
Chat Completions and Assistants APIs into a single streamlined interface
for building agentic applications.

## Setup

``` r
openai_responses <- OpenAI_Responses$new(api_key = Sys.getenv("OPENAI_API_KEY"))
```

**Available Models**

``` r
openai_responses$list_models() |>
    dplyr::filter(stringr::str_detect(id, "-5|5.1-"))
```

## Basic Completion

``` r
openai_responses$chat(
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

Then, run the agent:

``` r
openai_responses$chat(
    "When was the first release of the R 'ellmer' package on GitHub?",
    model = "gpt-5-mini",
    reasoning_effort = "medium",
    tools = list(as_tool(web_search), as_tool(web_fetch)),
    output_schema = package_info_schema
)
```

``` default
$release_version
[1] "0.1.0"

$release_date
[1] "2025-01-09T18:06:27Z"
```

The model will keep calling tools until it has enough information to
answer the question.

### Extracting Reasoning

Unlike Chat Completions, the Responses API supports extracting reasoning
content:

``` r
cat(openai_responses$get_reasoning_text())
```

Alternatively, simply `print(openai_responses)` to see the reasoning and
answers’ text in the console, turn by turn.

> **Note**
>
> `get_reasoning_text()` and `get_content_text()` use the last API
> response (`get_last_response()`) by default.

> **Tip**
>
> To get the model’s reasoning with the responses API, you need to set
> both the `reasoning_effort` and `reasoning_summary` parameters.
>
> However, `reasoning_summary` requires to verify your identity of
> organization with OpenAI.

## Server-side Tools

Server-side tools are tools you can call without having to define them
yourself. They will be run on the provider’s server.

OpenAI Responses API supports three server-side tools:

- **web_search** - Web search/fetch capabilities (with citations)
- **file_search** - Search through uploaded files using vector stores
  (i.e. server-side RAG)
- **code_interpreter** - Execute Python code in sandboxed containers

### Server-side: Web Search

Docs:
https://platform.openai.com/docs/guides/tools-web-search?api-mode=responses

``` r
openai_responses$chat(
    "What's the latest version of the R 'ellmer' package?",
    model = "gpt-5-mini",
    tools = list("web_search"),
    output_schema = package_info_schema
)
```

> **Note**
>
> It can be used with any model, unlike its equivalent in the Chat
> Completions API.

We can check which searches were made with
`openai_responses$get_supplementary()` or
`print(openai_responses, show_supplementary = TRUE)`.

### Server-side: File Search

See the [RAG](#server-side-rag) section below for a complete example of
using the `file_search` tool.

### Server-side: Code Interpreter

The code_interpreter tool provides sandboxed Python execution in
containers.

Containers are sandboxed virtual machines where code_interpreter can
execute Python code.

- **Cost**: \$0.03 per container
- **Duration**: 1 hour active, 20 minute idle timeout
- **Auto-creation**: Containers are created automatically when using the
  tool

**Example: Analyzing the Penguins Dataset**

``` r
penguins_url <- "https://raw.githubusercontent.com/allisonhorst/palmerpenguins/refs/heads/main/inst/extdata/penguins.csv"
penguins_file_metadata <- openai_responses$upload_file(penguins_url, purpose = "assistants")

openai_responses$chat(
    "Create a summary table showing average body_mass grouped by species, sex, and year. Save as CSV.",
    model = "gpt-5-mini",
    tools = list(list(type = "code_interpreter", file_ids = list(penguins_file_metadata$id)))
)
```

Inspect the generated code:

``` r
cat(openai_responses$get_generated_code(langs = c("python"), as_chunks = TRUE))
```

Generated Code

``` python
# Read the uploaded CSV, compute average body_mass grouped by species, sex, and year,
# then save the result to a CSV file and display the first few rows.

import pandas as pd

input_path = "/mnt/data/file-KPrDs2i6sSr4afRoahCyyF-file541142818f949.csv"
output_path = "/mnt/data/summary_body_mass_by_species_sex_year.csv"

# Read CSV (infer encoding and separators)
df = pd.read_csv(input_path)

# Inspect columns
print("Columns in input file:", list(df.columns))

# Normalize column names to lower for matching common names
cols_lower = [c.lower() for c in df.columns]
col_map = dict(zip(df.columns, cols_lower))

# Determine likely column names for species, sex, year, body_mass
def find_col(possible_names):
    for name in possible_names:
        for col in df.columns:
            if col.lower() == name.lower():
                return col
    return None

species_col = find_col(["species", "species_name", "speciesid"])
sex_col = find_col(["sex", "gender"])
year_col = find_col(["year", "time", "year_observed"])
body_col = find_col(["body_mass", "bodymass", "mass", "weight", "body_weight"])

# If any not found, try fuzzy match by substring
if not species_col:
    for col in df.columns:
        if "species" in col.lower():
            species_col = col
if not sex_col:
    for col in df.columns:
        if "sex" in col.lower():
            sex_col = col
if not year_col:
    for col in df.columns:
        if "year" in col.lower():
            year_col = col
if not body_col:
    for col in df.columns:
        if "body" in col.lower() and "mass" in col.lower():
            body_col = col

# If still not found, raise an informative error
missing = []
if not species_col: missing.append("species")
if not sex_col: missing.append("sex")
if not year_col: missing.append("year")
if not body_col: missing.append("body_mass")

if missing:
    raise ValueError(f"Could not find columns for: {', '.join(missing)}. Columns present: {list(df.columns)}")

# Create a working DataFrame with selected columns
work = df[[species_col, sex_col, year_col, body_col]].copy()
work.columns = ["species", "sex", "year", "body_mass"]

# Convert body_mass to numeric (coerce errors), drop NA body_mass
work["body_mass"] = pd.to_numeric(work["body_mass"], errors="coerce")
before_drop = len(work)
work = work.dropna(subset=["body_mass"])
dropped = before_drop - len(work)

# Group and compute mean
summary = (
    work.groupby(["species", "sex", "year"], dropna=False)
    .agg(avg_body_mass=("body_mass", "mean"), count=("body_mass","size"))
    .reset_index()
)

# Round average body mass to 3 decimal places
summary["avg_body_mass"] = summary["avg_body_mass"].round(3)

# Save to CSV
summary.to_csv(output_path, index=False)

# Display info and first rows
print(f"Dropped {dropped} rows with missing/non-numeric body_mass.")
print(f"Saved summary to: {output_path}")
summary.head(20)
```

Download the generated files:

``` r
downloaded_path <- openai_responses$download_generated_files(dest_path = "data")
#> ✔ [OpenAI Responses] Downloaded file to: data/summary_body_mass_by_species_sex_year.csv
```

``` r
read.csv(downloaded_path, na.strings = c("", "NA"))
```

``` default
     species    sex year avg_body_mass count
1     Adelie female 2007      3389.773    22
2     Adelie female 2008      3386.000    25
3     Adelie female 2009      3334.615    26
4     Adelie   male 2007      4038.636    22
5     Adelie   male 2008      4098.000    25
6     Adelie   male 2009      3995.192    26
7     Adelie   <NA> 2007      3540.000     5
8  Chinstrap female 2007      3569.231    13
9  Chinstrap female 2008      3472.222     9
10 Chinstrap female 2009      3522.917    12
11 Chinstrap   male 2007      3819.231    13
12 Chinstrap   male 2008      4127.778     9
13 Chinstrap   male 2009      3927.083    12
14    Gentoo female 2007      4618.750    16
15    Gentoo female 2008      4627.273    22
16    Gentoo female 2009      4786.250    20
17    Gentoo   male 2007      5552.941    17
18    Gentoo   male 2008      5410.870    23
19    Gentoo   male 2009      5510.714    21
20    Gentoo   <NA> 2007      4100.000     1
21    Gentoo   <NA> 2008      4650.000     1
22    Gentoo   <NA> 2009      4800.000     2
```

Continue asking questions in the same context:

``` r
penguin_output_schema <- schema(
    name = "penguin_output",
    description = "Schema for the penguin output",
    average_body_mass = "number* The average body_mass",
    species = "string* The species",
    sex = "string* The sex",
    year = "integer* The year"
)

openai_responses$chat(
    "What's the average body_mass for the Adelie females in 2009?",
    tools = list("code_interpreter"), # We need to specify the tool again to continue in the same context
    output_schema = penguin_output_schema
)
```

``` default
$average_body_mass
[1] 3334.615

$species
[1] "Adelie"

$sex
[1] "female"

$year
[1] 2009
```

#### Container Management

List containers:

``` r
openai_responses$list_containers()
```

Get container information:

``` r
container <- openai_responses$get_container("cntr_690fb998d170819089fc6176eaa19ab90f300882b8d201ca")
```

List files in a container:

``` r
openai_responses$list_container_files("cntr_690fb998d170819089fc6176eaa19ab90f300882b8d201ca")
```

Download a specific file from a container:

``` r
openai_responses$download_container_file(
    container_id = "cntr_690fb998d170819089fc6176eaa19ab90f300882b8d201ca",
    file_id = "cfile_690fb9b692d88191b77427d736671fcd",
    dest_path = "data/output.csv"
)
```

Delete a container:

``` r
openai_responses$delete_container("cntr_690fb998d170819089fc6176eaa19ab90f300882b8d201ca")
#> ✔ [OpenAI Responses] Container deleted: cntr_690fb998d170819089fc6176eaa19ab90f300882b8d201ca
```

## Multimodal Inputs

OpenAI Responses API supports sending:

- Images: URLs (as-is, or base64), files (base64)
- PDFs: URLs (as-is, base64, or text content), files (base64, or text
  content)
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
openai_responses$chat(
    "Who are the characters in this image, and what show is it from?",
    bsg04_cast_image_path,
    model = "gpt-5-mini"
)
```

``` default
This is a promotional image for the reimagined TV series Battlestar Galactica (the 2004–2009 series). Left-to-right the characters are:

- Admiral William Adama (commander of the Battlestar Galactica)  
- Laura Roslin (the President of the surviving human fleet)  
- Lee "Apollo" Adama (Viper pilot, Adama’s son)  
- Kara "Starbuck" Thrace (lead Viper pilot)  
- Number Six (a Cylon model often appearing in human form)  
- Sharon Valerii / "Boomer" (a Cylon who serves aboard Galactica)
```

*So say we all!*

**Sending an image URL:**

OpenAI supports sending image URLs directly:

``` r
openai_responses$chat(
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
> OpenAI Responses API also supports sending a file_id (i.e. the image
> `as_file_content(file_id)` after uploading it with
> `openai_responses$upload_file()`).

### PDF Comprehension

Downloading an example PDF (my CV)

``` r
my_cv_url <- "https://ma-riviere.com/res/cv.pdf"
my_cv_pdf_path <- download_temp_file(my_cv_url)
```

**Sending a local PDF:**

``` r
openai_responses$chat(
    "What's my favorite programming language?",
    my_cv_pdf_path,
    model = "gpt-5-mini"
)
```

``` default
Probably R.

Evidence from your CV:
- Header: "R Programming | Data Science | Neuroscience" and "with a focus on R & Shiny."
- R is listed first in Programming Skills and Shiny/Quarto/R Markdown appear under Frameworks & Tools.
- Many projects and publications reference R, Shiny apps, and scientific publishing workflows.
```

*Probably ?!?*

**Sending PDF URLs:**

For OpenAI Responses, by default, PDF URLs are sent as base64 to the
server.

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

openai_responses$chat(!!!multimodal_prompt, model = "gpt-5-mini")
```

``` default
S7 is a formal OO system with first-class generics and methods (including limited multiple dispatch) and built‑in interoperability with S3 and S4, whereas R6 is primarily an encapsulated, environment‑based reference class system without that formal method dispatch. S7 provides declarative properties, constructors, validators, unions, dynamic getters/setters and convert()/super() semantics, giving stronger type safety, automatic validation and controlled up/down‑casting compared with R6’s looser, manual field management. S7 also includes package-friendly method registration, external‑generic support and dispatch introspection, making it better suited as a successor for formal, package‑level OO design while R6 stays simpler and lighter for straightforward reference semantics.

Current versions — S7: 0.2.0; R6: 2.6.1.
```

### Passing R Objects

You can pass any R object to `chat()` as is:

``` r
lm_obj <- lm(body_mass ~ species + sex, data = datasets::penguins)

openai_responses$chat(
    "What can we deduct from this regression model?",
    lm_obj,
    model = "gpt-5-mini"
)
```

``` default
1. The intercept (≈ 3372.4) is the modelled mean body mass for the reference group: Adelie females (baseline species = Adelie, baseline sex = female).

2. Species effects: Gentoo penguins are much heavier than Adelies (coefficient ≈ +1377.9 g), while Chinstraps differ very little from Adelies (≈ +26.9 g). Thus species — especially being Gentoo — has a large effect on body mass.

3. Sex effect: Males weigh about 667.6 g more than females, holding species constant. (Model used 333 observations with df.residual = 329; p‑values/SEs are not shown here, so significance cannot be asserted from the printed coefficients alone.)
```

> **Note**
>
> Any R object passed to `chat()` will be automatically converted to
> JSON (or text if JSON conversion fails), with some added information
> like the name of the object and its classes.

### Sending files

e can also send files directly to the model.

**Uploading Files**

``` r
file_metadata <- openai_responses$upload_file(my_cv_url)
```

**Listing Files**

``` r
openai_responses$list_files()
```

``` default
# A tibble: 1 × 9
   object id                          purpose    filename                bytes created_at          expires_at status    status_details
   <chr>  <chr>                       <chr>      <chr>                   <int> <dttm>              <lgl>      <chr>     <lgl>         
 1 file   file-C6FSoAhHoAkyxV61djbB6D user_data  file92917bdad4ff.pdf   431965 2025-11-14 11:52:18 NA         processed NA            
```

**Using Uploaded Files**

Use
[`as_file_content()`](https://ma-riviere.github.io/argent/reference/content_converters.md)
to reference uploaded files:

``` r
openai_responses$chat(
    "What are my two favorite frameworks/tools ?",
    as_file_content(file_metadata$id),
    model = "gpt-5-mini"
)
```

``` default
Likely Shiny and Quarto (R Markdown).

Reason: your résumé explicitly highlights a focus on R & Shiny and lists Shiny first under Frameworks & Tools, and Quarto / R Markdown appear under Scientific Publishing as your main authoring tools.
```

*Likely ?!?*

**Downloading Files**

``` r
openai_responses$download_file(file_metadata$id, dest_path = "data")  # Downloads to data/ by default
#> ✔ [OpenAI] File downloaded to: data/file92917bdad4ff.pdf
```

**Deleting Files**

``` r
openai_responses$delete_file(file_metadata$id)
#> ✔ [OpenAI] File deleted: file-C6FSoAhHoAkyxV61djbB6D
```

## Server-Side RAG

Instead of just passing single files to the Assistant, we can also add
them to a vector store (where the files are chunked and indexed) and use
the `file_search` tool to search through the store and retrieve the
relevant chunks, effectively turning it into a server-side RAG
application. This is useful when your files are too large to pass
directly to the model.

### Vector Store Management

First, a quick overview of available methods to manage vector stores:

**Creating a Vector Store**

``` r
store <- openai_responses$create_store(
    name = "my_docs",
    file_ids = list("file-123", "file-456")
)
```

**Listing Vector Stores**

``` r
openai_responses$list_stores()
```

**Adding Files to a Vector Store**

``` r
openai_responses$add_file_to_store(store$id, "file-789")
```

**Listing Files in a Vector Store**

``` r
openai_responses$list_files_in_store(store$id)
```

**Deleting a Vector Store**

``` r
openai_responses$delete_store(store$id)
```

> **Note**
>
> Files and vector stores are shared across all OpenAI APIs (Chat
> Completions, Responses, and Assistants). A file uploaded via one API
> can be used in another.

### Basic Server-Side RAG example

First, let’s upload the files we want to search through and create a
vector store with them:

``` r
r6_file_metadata <- openai_responses$upload_file(r6_pdf_url)
s7_file_metadata <- openai_responses$upload_file(s7_pdf_url)

r_oop_store <- openai_responses$create_store(
    name = "r_oop_store",
    file_ids = list(r6_file_metadata$id, s7_file_metadata$id)
)
#> ✔ [OpenAI] Store created: vs_6911cb2e5150819183672288d3018478
```

Then, let’s make an output schema for the response:

``` r
oop_output_schema <- schema(
    name = "oop_output",
    description = "Explanation of the R6 and S7 active bindings mechanism",
    short_answer = "string* The short answer to the question, in plain text. One sentence.",
    r6_code_example = "string* R6 active bindings code example. Formatted as code block (```{r} ... ```).",
    s7_code_example = "string* S7 active bindings 'equivalent' code example. Formatted as code block (```{r} ... ```)."
)
```

Use file_search with the vector store:

``` r
openai_file_search_tool <- list(type = "file_search", store_ids = list(r_oop_store$id))

openai_responses$chat(
    "What's the active bindings' R6 mechanism equivalent in S7?",
    "Important: use both the file_search and web_search & web_fetch tools to find the information.",
    model = "gpt-5-mini",
    tools = list(
        openai_file_search_tool,
        as_tool(web_search), # In case it needs to search the web for more information
        as_tool(web_fetch) # In case it needs to search the web for more information
    ),
    output_schema = oop_output_schema
)
```

Response

``` r
jsonlite::fromJSON(openai_responses$get_content_text()) |> 
    purrr::walk(\(x) cat(x, "\n\n", sep = ""))
```

R6 “active bindings” are equivalent to S7 “dynamic properties”: use S7
properties created with new_property() supplying a getter and optionally
a setter (accessed with @). R6 active bindings docs: S7 properties/docs:
(also see S7 new_property reference
https://rconsortium.github.io/S7/reference/new_property.html).

``` r
# R6 example: active bindings (reads call function with no arg; writes pass value)
library(R6)
Numbers <- R6Class("Numbers",
  public = list(
    x = 100
  ),
  active = list(
    x2 = function(value) {
      if (missing(value)) return(self$x * 2)
      else self$x <- value / 2
    },
    rand = function() rnorm(1)
  )
)

n <- Numbers$new()
n$x2        # -> 200 (calls function)
n$x2 <- 1000  # -> sets x to 500 via setter
```

``` r
# S7 equivalent: dynamic properties via new_property(getter=, setter=)
# getter receives self and should return the value; setter receives self and value and must return modified self
library(S7)

# read-only dynamic property (computed on access)
Clock <- new_class("Clock", properties = list(
  now = new_property(getter = function(self) Sys.time())
))

my_clock <- Clock()
my_clock@now   # computed each access (read-only because no setter)

# read-write property example
Counter <- new_class("Counter", properties = list(
  count = new_property(
    getter = function(self) self@.data$count,
    setter = function(self, value) { self@.data$count <- value; self }
  )
))

c <- Counter(count = 0)
c@count        # read
c@count <- 5   # write (setter must return modified object)
```

We can check the annotations `openai_responses$get_supplementary()` or
`print(openai_responses, show_supplementary = TRUE)`:

``` r
print(openai_responses, show_tools = TRUE, show_supplementary = TRUE) # Also show tool calls for the client tools
```

> **Note**
>
> You can also specify additional options like `max_num_results` and
> `filters` for the `file_search` tool. See the
> [documentation](https://platform.openai.com/docs/guides/tools-file-search)
> for details.

**Cleaning:**

``` r
openai_responses$delete_store(r_oop_store$id)
openai_responses$delete_file(r6_file_metadata$id)
openai_responses$delete_file(s7_file_metadata$id)
```

> **Tip**
>
> We could have deleted everything (vector store, files, and assistant)
> with:
>
> ``` r
> openai_responses$delete_store_and_files(r_oop_store$id)
> ```

## Server-Side State Management

The Responses API supports server-side state management via
`previous_response_id`.

``` r
res1 <- openai_responses$chat(
    "Tell me a joke about R programming",
    model = "gpt-5-mini",
    return_full_response = TRUE
)
cat(openai_responses$get_content_text(res1), "\n")
```

``` default
Why did the R programmer break up with his girlfriend?  
There were too many NAs — he just couldn't find her complete.cases().
```

``` r
openai_responses$chat(
    "Explain why it's funny",
    previous_response_id = res1$id,
    model = "gpt-5-mini"
)
```

``` default
Sure — here's why that joke lands for R users:

- NA in R means a missing value (Not Available). Saying “there were too many NAs” is like saying the partner had too many missing/unavailable traits.
- complete.cases() is an R function that returns TRUE for rows that have no NAs (i.e., “complete” observations) and FALSE for rows with any missing values.
- The punchline “he just couldn't find her complete.cases()” is a pun: it mixes code (calling complete.cases()) with ordinary language (“find her complete self” / “find someone who’s complete”). So it’s funny because it treats a romantic relationship as if it were a data frame, and the solution to the problem is literally a function that checks for completeness.
- Extra nerdy twist: programmers often get frustrated debugging missing data, so the idea of breaking up over NAs is a relatable exaggeration for people who work with R.
```

*You gotta work on your jokes, man.*

> **Warning**
>
> When using `previous_response_id`:
>
> - The API maintains full conversation state server-side (30-day
>   retention)
> - Local chat history is reset and no longer synchronized with the JSON
>   history file
