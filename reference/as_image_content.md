# Convert inputs to image content for multimodal API requests

Converts image inputs (file paths, URLs, or image data) into a format
suitable for LLM API requests. Supports automatic PDF-to-image
conversion and optional resizing.

## Usage

``` r
as_image_content(
  ...,
  .resize = "none",
  .image_converter = default_image_converter,
  .provider_options = list()
)
```

## Arguments

- ...:

  One or more image inputs to convert. Can be:

  - Local image file paths

  - Image URLs

  - PDF files (converted to images via magick)

- .resize:

  Character. Image resizing strategy:

  - `"none"`: No resizing (default)

  - `"low"`: Resize to fit within 512x512 (faster, cheaper processing)

  - `"high"`: Resize to fit within 2000x768 or 768x2000 based on
    orientation

  - Custom geometry string (e.g., "800x600", "50%", "200x200\>",
    "300x200\>!") following magick::image_resize() syntax. Append `>` to
    resize only if larger, `!` to ignore aspect ratio.

- .image_converter:

  Function. Custom converter function with signature `function(input)`.
  Default is `default_image_converter`.

- .provider_options:

  List. Provider-specific options to attach as attributes. For OpenAI
  providers, use `list(detail = "low")` to control image processing
  detail level. Options: `"low"` (85 tokens, 512px, faster), `"high"`
  (better understanding), `"auto"` (model decides). Default is an empty
  list.

## Value

Character vector with processed image paths. Has attribute
`argent_input = TRUE` and each element has
`argent_input_type = "image"`.

## Examples

``` r
if (FALSE) { # \dontrun{
# OpenAI low detail (faster, cheaper)
as_image_content("image.jpg", .provider_options = list(detail = "low"))

# OpenAI high detail (better understanding)
as_image_content("document.png", .provider_options = list(detail = "high"))

# Resize to low resolution
as_image_content("large_image.jpg", .resize = "low")

# Custom resize
as_image_content("image.jpg", .resize = "800x600>")
} # }
```
