# Convert inputs to file references for multimodal API requests

Marks file paths or file IDs as file references to be passed to LLM
APIs. This is used for providers that support file uploads (e.g.,
Google, Anthropic, OpenAI). The files should already be uploaded to the
provider's file store.

## Usage

``` r
as_file_content(..., .provider_options = list())
```

## Arguments

- ...:

  One or more file references. Can be:

  - File IDs from uploaded files (e.g., from `upload_file()`)

  - File paths (interpretation depends on provider)

- .provider_options:

  List. Provider-specific options to attach as attributes. Default is an
  empty list.

## Value

Character vector with file references. Has attribute
`argent_input = TRUE` and each element has
`argent_input_type = "file_ref"`.
