# Convert inputs to PDF content for multimodal API requests

Marks PDF file paths or URLs as PDF content to be passed to LLM APIs.
Different providers handle PDFs differently:

- OpenAI Assistants API: PDFs are uploaded with purpose="assistants" and
  attached to messages

- Google Gemini: PDFs use the File API with vision models

- Other providers: May convert to base64 or other formats

## Usage

``` r
as_pdf_content(
  ...,
  .pdf_converter = default_pdf_converter,
  .provider_options = list()
)
```

## Arguments

- ...:

  One or more PDF inputs. Can be:

  - Local PDF file paths

  - PDF URLs (downloaded and uploaded for providers that don't support
    remote URLs)

- .pdf_converter:

  Function. Custom converter function with signature `function(input)`.
  Default is `default_pdf_converter`.

- .provider_options:

  List. Provider-specific options to attach as attributes. Default is an
  empty list. For OpenAI Assistants, can include 'tools' to specify
  which tools to use with the attachment (default: file_search).

## Value

Character vector with PDF references. Has attribute
`argent_input = TRUE` and each element has `argent_input_type = "pdf"`.
