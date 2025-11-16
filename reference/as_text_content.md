# Convert inputs to text content for multimodal API requests

Converts various input types (text strings, files, URLs, R objects) into
text content suitable for LLM API requests. Handles automatic detection
and conversion of different file formats including JSON, YAML, CSV, XML,
HTML, and plain text.

## Usage

``` r
as_text_content(
  ...,
  .vec_len = 999,
  .nchar_max = 999,
  .text_converter = default_text_converter,
  .provider_options = list()
)
```

## Arguments

- ...:

  One or more inputs to convert. Can be:

  - Character strings (used as-is)

  - File paths (local files)

  - URLs (downloaded and processed)

  - R objects (converted to text representation via
    [`str()`](https://rdrr.io/r/utils/str.html))

- .vec_len:

  Integer. Maximum vector length to display when converting R objects.
  Default is 999.

- .nchar_max:

  Integer. Maximum characters per element when converting R objects.
  Minimum value is 17. Default is 999.

- .text_converter:

  Function. Custom converter function with signature
  `function(input, vec_len, nchar_max)`. Default is
  `default_text_converter`.

- .provider_options:

  List. Provider-specific options to attach as attributes. Default is an
  empty list.

## Value

Character vector with processed text content. Has attribute
`argent_input = TRUE` and each element has `argent_input_type = "text"`.
