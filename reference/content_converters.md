# Convert file paths, URLs or R objects to the specified content format before passing it to the LLM API

These functions convert various input types into formats suitable for
LLM API requests. Each function handles specific content types with
automatic detection and conversion where applicable.

## Usage

``` r
as_text_content(
  ...,
  .vec_len = 999,
  .nchar_max = 999,
  .converter = default_text_converter,
  .provider_options = list()
)

as_image_content(
  ...,
  .resize = "none",
  .converter = default_image_converter,
  .provider_options = list()
)

as_file_content(..., .provider_options = list())

as_pdf_content(
  ...,
  .converter = default_pdf_converter,
  .provider_options = list()
)

as_json_content(
  ...,
  .max_rows = 10,
  .converter = default_json_converter,
  .provider_options = list()
)
```

## Arguments

- ...:

  One or more inputs to convert. Can be file paths, URLs, or R objects.

- .vec_len:

  Integer. For `as_text_content()` only. Maximum vector length to
  display when converting R objects. Default is 999.

- .nchar_max:

  Integer. For `as_text_content()` only. Maximum characters per element
  when converting R objects. Minimum value is 17. Default is 999.

- .converter:

  Function. Custom converter function. Signature varies by function:

  - `as_text_content()`: `function(input, vec_len, nchar_max)`

  - `as_image_content()`: `function(input)`

  - `as_pdf_content()`: `function(input)`

  - `as_json_content()`: `function(input, max_rows)` Default converters
    are provided for each function. Can be overridden by passing a
    custom function.

- .provider_options:

  List. Provider-specific options to attach as attributes. Default is an
  empty list. For OpenAI providers with images, use
  `list(detail = "low")` to control image processing detail level.
  Options: `"low"` (85 tokens, 512px, faster), `"high"` (better
  understanding), `"auto"` (model decides). For OpenAI Assistants with
  PDFs, can include 'tools' to specify which tools to use with the
  attachment (default: file_search).

- .resize:

  Character. For `as_image_content()` only. Image resizing strategy:

  - `"none"`: No resizing (default)

  - `"low"`: Resize to fit within 512x512 (faster, cheaper processing)

  - `"high"`: Resize to fit within 2000x768 or 768x2000 based on
    orientation

  - Custom geometry string (e.g., "800x600", "50%", "200x200\>",
    "300x200\>!") following magick::image_resize() syntax. Append `>` to
    resize only if larger, `!` to ignore aspect ratio.

- .max_rows:

  Integer. For `as_json_content()` only. Maximum number of rows to
  include when converting data frames. Default is 10.

## Value

Character vector with processed content. Has attribute
`argent_input = TRUE` and each element has `argent_input_type` set to
the appropriate type ("text", "image", "file_ref", or "pdf").

## Details

### Supported File Formats

`as_text_content()` supports:

- JSON, YAML, CSV, TSV, RDS, XML, HTML, and plain text files

- PDF files (requires pdftools package)

- Image files (converted to base64 data URIs)

`as_image_content()` supports:

- Common image formats (JPEG, PNG, GIF, etc.)

- PDF files (converted to images via magick)

`as_pdf_content()` supports:

- PDF file paths or URLs

- Handling varies by provider (e.g., OpenAI Assistants API, Google
  Gemini File API)

`as_json_content()` supports:

- R objects (converted via jsonlite::toJSON)

- JSON file paths

- JSON URLs

## Examples

``` r
if (FALSE) { # \dontrun{
# Text content
as_text_content("Hello, world!")
as_text_content(mtcars, .vec_len = 5)
as_text_content("path/to/file.txt")

# Image content
as_image_content("image.jpg")
as_image_content("large_image.jpg", .resize = "low")
as_image_content("image.jpg", .provider_options = list(detail = "high"))

# File references
as_file_content("file-abc123")

# PDF content
as_pdf_content("document.pdf")

# JSON content
as_json_content(mtcars, .max_rows = 5)
as_json_content(list(a = 1, b = 2))
} # }
```
