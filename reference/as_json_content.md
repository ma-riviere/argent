# Convert inputs to JSON content for multimodal API requests

Converts various input types into JSON-formatted text content suitable
for LLM API requests. Particularly useful for passing structured data
(data frames, lists) to models.

## Usage

``` r
as_json_content(
  ...,
  .max_rows = 10,
  .json_converter = default_json_converter,
  .provider_options = list()
)
```

## Arguments

- ...:

  One or more inputs to convert. Can be:

  - R objects (converted to JSON via jsonlite)

  - JSON file paths (parsed and re-serialized)

  - JSON URLs (downloaded, parsed, and re-serialized)

- .max_rows:

  Integer. Maximum number of rows to include when converting data
  frames. Default is 10.

- .json_converter:

  Function. Custom converter function with signature
  `function(input, max_rows)`. Default is `default_json_converter`.

- .provider_options:

  List. Provider-specific options to attach as attributes. Default is an
  empty list.

## Value

Character vector with JSON-formatted content. Has attribute
`argent_input = TRUE` and each element has `argent_input_type = "text"`.
