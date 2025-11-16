# -----🔺 PROMPTS --------------------------------------------------------------

#' Make a format prompt
#'
#' Makes a format prompt for a given format tool.
#' @param tool_name The name of the format tool to use
#' @return A prompt for the formatting instance
#' @keywords internal
#' @noRd
make_format_prompt <- function(tool_name = "json_formatting_tool") {
    stringr::str_glue(
        "Extract relevant information from the chat history (and only from those messages) to use the {tool_name} tool.",
        "Only generate the tool call. No other text, reasoning, or special formatting.",
        "Make the tool call no matter what, even with insufficient information.",
        "If the content provided lacks required information for the tool call, leave those arguments empty.",
        .sep = "\n"
    )
}

# -----🔺 IO -------------------------------------------------------------------

#' Read file content based on MIME type
#'
#' Automatically detects file type and reads content using appropriate parser.
#' Supports JSON, YAML, CSV, TSV, RDS, XML, HTML, and plain text files.
#'
#' @param path Character. Path to local file or URL
#' @return Parsed file content (type depends on file format)
#' @keywords internal
#' @noRd
read_file <- function(path) {
    mime_type <- guess_input_type(path)

    if (stringr::str_detect(mime_type, "json")) {
        return(jsonlite::read_json(path))
    } else if (stringr::str_detect(mime_type, "yaml")) {
        return(yaml::read_yaml(path))
    } else if (stringr::str_detect(mime_type, "csv|tab-separated-values|rds")) {
        return(read_data_file(path))
    } else if (stringr::str_detect(mime_type, "xml")) {
        return(as.character(xml2::read_xml(path)))
    } else if (stringr::str_detect(mime_type, "html")) {
        return(as.character(xml2::read_html(path)))
    } else if (stringr::str_detect(mime_type, "text")) {
        return(read_text_file(path))
    } else {
        cli::cli_abort("Unsupported file type: {mime_type}")
    }
}

#' Read text file content
#'
#' Reads a text file and returns its content as a single string
#' @param file_path Character. Path to local text file, or URL
#' @return Character. File content as a single string with newlines preserved
#' @keywords internal
#' @noRd
read_text_file <- function(file_path) {
    if (is_url(file_path)) {
        file_path <- download_temp_file(file_path)
        on.exit(unlink(file_path))
    }

    if (!is_file(file_path)) {
        cli::cli_abort("Text file not found: {.path {file_path}}")
    }

    contents <- readLines(file_path, warn = FALSE) |> paste(collapse = "\n")

    return(contents)
}

#' Read data file and format as text
#'
#' Reads CSV, TSV, or RDS files
#' @param file_path Character. Path to local data file, or URL
#' @return Character. Formatted text representation of the data
#' @keywords internal
#' @noRd
read_data_file <- function(file_path) {
    if (is_url(file_path)) {
        file_path <- download_temp_file(file_path)
        on.exit(unlink(file_path))
    }

    if (!is_file(file_path)) {
        cli::cli_abort("Data file not found: {.path {file_path}}")
    }

    ext <- tolower(tools::file_ext(file_path))

    if (stringr::str_detect(ext, stringr::fixed("csv", ignore_case = TRUE))) {
        return(utils::read.csv(file_path))
    } else if (stringr::str_detect(ext, stringr::fixed("tsv", ignore_case = TRUE))) {
        return(utils::read.table(file_path, sep = "\t"))
    } else if (stringr::str_detect(ext, stringr::fixed("rds", ignore_case = TRUE))) {
        return(readRDS(file_path))
    } else {
        cli::cli_abort("Unsupported data file extension: {ext}")
    }
}

# -----🔺 CONVERTERS -----------------------------------------------------------

#' Convert inputs to content for multimodal API requests
#'
#' @description
#' These functions convert various input types into formats suitable for LLM API requests.
#' Each function handles specific content types with automatic detection and conversion
#' where applicable.
#'
#' @param ... One or more inputs to convert. Can be file paths, URLs, or R objects.
#' @param .vec_len Integer. For `as_text_content()` only. Maximum vector length to display
#'   when converting R objects. Default is 999.
#' @param .nchar_max Integer. For `as_text_content()` only. Maximum characters per element
#'   when converting R objects. Minimum value is 17. Default is 999.
#' @param .resize Character. For `as_image_content()` only. Image resizing strategy:
#'   - `"none"`: No resizing (default)
#'   - `"low"`: Resize to fit within 512x512 (faster, cheaper processing)
#'   - `"high"`: Resize to fit within 2000x768 or 768x2000 based on orientation
#'   - Custom geometry string (e.g., "800x600", "50%", "200x200>", "300x200>!")
#'     following magick::image_resize() syntax. Append `>` to resize only if larger,
#'     `!` to ignore aspect ratio.
#' @param .max_rows Integer. For `as_json_content()` only. Maximum number of rows to
#'   include when converting data frames. Default is 10.
#' @param .converter Function. Custom converter function. Signature varies by function:
#'   - `as_text_content()`: `function(input, vec_len, nchar_max)`
#'   - `as_image_content()`: `function(input)`
#'   - `as_pdf_content()`: `function(input)`
#'   - `as_json_content()`: `function(input, max_rows)`
#'   Default converters are provided for each function. Can be overridden by passing a custom function.
#' @param .provider_options List. Provider-specific options to attach as attributes.
#'   Default is an empty list. For OpenAI providers with images, use
#'   `list(detail = "low")` to control image processing detail level. Options:
#'   `"low"` (85 tokens, 512px, faster), `"high"` (better understanding), `"auto"`
#'   (model decides). For OpenAI Assistants with PDFs, can include 'tools' to specify
#'   which tools to use with the attachment (default: file_search).
#'
#' @return Character vector with processed content. Has attribute `argent_input = TRUE`
#'   and each element has `argent_input_type` set to the appropriate type ("text",
#'   "image", "file_ref", or "pdf").
#'
#' @details
#' ## Supported File Formats
#'
#' `as_text_content()` supports:
#' - JSON, YAML, CSV, TSV, RDS, XML, HTML, and plain text files
#' - PDF files (requires pdftools package)
#' - Image files (converted to base64 data URIs)
#'
#' `as_image_content()` supports:
#' - Common image formats (JPEG, PNG, GIF, etc.)
#' - PDF files (converted to images via magick)
#'
#' `as_pdf_content()` supports:
#' - PDF file paths or URLs
#' - Handling varies by provider (e.g., OpenAI Assistants API, Google Gemini File API)
#'
#' `as_json_content()` supports:
#' - R objects (converted via jsonlite::toJSON)
#' - JSON file paths
#' - JSON URLs
#'
#' @name content_converters
#' @examples
#' \dontrun{
#' # Text content
#' as_text_content("Hello, world!")
#' as_text_content(mtcars, .vec_len = 5)
#' as_text_content("path/to/file.txt")
#'
#' # Image content
#' as_image_content("image.jpg")
#' as_image_content("large_image.jpg", .resize = "low")
#' as_image_content("image.jpg", .provider_options = list(detail = "high"))
#'
#' # File references
#' as_file_content("file-abc123")
#'
#' # PDF content
#' as_pdf_content("document.pdf")
#'
#' # JSON content
#' as_json_content(mtcars, .max_rows = 5)
#' as_json_content(list(a = 1, b = 2))
#' }
#' @export
as_text_content <- function(
    ...,
    .vec_len = 999,
    .nchar_max = 999,
    .converter = default_text_converter,
    .provider_options = list()
) {
    inputs <- rlang::enquos(...)
    processed <- purrr::map(inputs, \(input) {
        converted <- .converter(input, vec_len = .vec_len, nchar_max = .nchar_max)
        return(structure(converted, argent_input_type = "text", argent_provider_options = .provider_options))
    })

    return(processed)
}

#' Default text converter for multimodal inputs
#'
#' Converts various input types to text by detecting file paths, URLs, or R objects
#' and processing them appropriately.
#'
#' @param input Input to convert (character path/URL, or R object)
#' @param vec_len Integer. Maximum vector length to display for R objects
#' @param nchar_max Integer. Maximum characters per element for R objects
#' @return Character. Processed text content
#' @keywords internal
#' @noRd
default_text_converter <- function(input, vec_len = 999, nchar_max = 999) {
    if (nchar_max < 17) {
        nchar_max <- 17
        cli::cli_alert_warning("{.arg nchar_max} cannot be less than 17, setting it to 17.")
    }
    input_val <- rlang::eval_tidy(input)
    # For files and URLs
    if (is_url(input_val) || is_file(input_val)) {
        mime_type <- guess_input_type(input_val)

        # Specific rule to convert PDF to text
        if (stringr::str_detect(mime_type, "pdf")) {
            if (!requireNamespace("pdftools", quietly = TRUE)) {
                cli::cli_abort("Package 'pdftools' is required to convert PDF to text.")
            }
            return(paste(pdftools::pdf_text(input_val), collapse = "\n\n"))
        } else if (stringr::str_detect(mime_type, "image")) {
            return(image_to_base64(input_val)$data_uri)
        } else {
            # Try the universal read_file() function
            return(to_str(read_file(input_val), vec_len = vec_len, nchar_max = nchar_max))
        }
    } else {
        # For R objects
        if (is.character(input_val)) {
            return(input_val)
        } else {
            # We pass the quosure to to_str() to get the object name & classes
            return(to_str(input, vec_len = vec_len, nchar_max = nchar_max))
        }
    }
}

#' @rdname content_converters
#' @export
as_image_content <- function(
    ...,
    .resize = "none",
    .converter = default_image_converter,
    .provider_options = list()
) {
    inputs <- list(...)
    processed <- purrr::map(inputs, \(input) {
        if (is.character(input)) {
            input <- stringr::str_trim(input)
        }
        converted <- .converter(input)

        if (.resize != "none") {
            converted <- resize_image(converted, .resize)
        }

        return(structure(converted, argent_input_type = "image", argent_provider_options = .provider_options))
    })
    return(processed)
}

#' Resize image using magick
#'
#' Downloads and resizes images using the magick package. Supports preset sizes
#' ("low", "high") or custom geometry strings. Based on Ellmer's content_image_file.
#'
#' @param image_path Character. Path to local image file or URL
#' @param resize Character. Resizing strategy:
#'   - `"low"`: Resize to fit within 512x512
#'   - `"high"`: Resize to fit within 2000x768 or 768x2000 based on orientation
#'   - Custom geometry string (e.g., "800x600", "50%", "200x200>")
#' @return Character. Path to resized temporary image file
#' @keywords internal
#' @noRd
resize_image <- function(image_path, resize) {
    if (!requireNamespace("magick", quietly = TRUE)) {
        cli::cli_abort("Package 'magick' is required to resize images.")
    }

    ext <- tools::file_ext(image_path)

    if (is_url(image_path)) {
        image_path <- download_temp_file(image_path)
        on.exit(unlink(image_path))
    }

    img <- magick::image_read(image_path, strip = TRUE)

    if (resize == "low") {
        img <- magick::image_resize(img, "512x512>")
    } else if (resize == "high") {
        dims <- magick::image_info(img)
        width <- dims$width
        height <- dims$height

        if (width > height) {
            img <- magick::image_resize(img, "2000x768>")
        } else {
            img <- magick::image_resize(img, "768x2000>")
        }
    } else {
        img <- magick::image_resize(img, resize)
    }

    output_file_path <- tempfile(fileext = paste0(".", ext))
    magick::image_write(img, output_file_path)

    return(output_file_path)
}

#' Default image converter for multimodal inputs
#'
#' Converts various image input types by detecting file paths, URLs, or PDFs
#' and processing them appropriately. PDFs are converted to PNG images.
#'
#' @param input Input to convert (image path/URL, or PDF path/URL)
#' @return Character. Path to processed image file
#' @keywords internal
#' @noRd
default_image_converter <- function(input) {
    mime_type <- guess_input_type(input)
    
    if (stringr::str_detect(mime_type, "pdf")) {
        if (!requireNamespace("magick", quietly = TRUE)) {
            cli::cli_abort("Package 'magick' is required to convert PDF to image.")
        }
        output_file_path <- tempfile(fileext = ".png")

        output <- magick::image_read_pdf(input, density = 70) |> 
            magick::image_append(stack = TRUE)
        
        magick::image_write(output, output_file_path)

        if (is_url(input)) {
            unlink(input)
        }
        
        return(output_file_path)
    } else {
        return(input)
    }
}

#' @rdname content_converters
#' @export
as_file_content <- function(..., .provider_options = list()) {
    inputs <- list(...)
    processed <- purrr::map(inputs, \(input) {
        return(structure(input, argent_input_type = "file_ref", argent_provider_options = .provider_options))
    })
    return(processed)
}

#' @rdname content_converters
#' @export
as_pdf_content <- function(..., .converter = default_pdf_converter, .provider_options = list()) {
    inputs <- list(...)
    processed <- purrr::map(inputs, \(input) {
        if (is.character(input)) {
            input <- stringr::str_trim(input)
        }

        return(structure(input, argent_input_type = "pdf", argent_provider_options = .provider_options))
    })
    return(processed)
}

#' Default PDF converter for multimodal inputs
#'
#' Converts PDF file paths or URLs to PDF content to be passed to LLM APIs.
#'
#' @param input Input to convert (PDF path/URL)
#' @return Character. PDF content
#' @keywords internal
#' @noRd
default_pdf_converter <- function(input) {
    return(input)
}

#' @rdname content_converters
#' @export
as_json_content <- function(
    ...,
    .max_rows = 10,
    .converter = default_json_converter,
    .provider_options = list()
) {
    inputs <- rlang::enquos(...)
    processed <- purrr::map(inputs, \(input) {
        converted <- .converter(input, max_rows = .max_rows)
        return(structure(converted, argent_input_type = "text", argent_provider_options = .provider_options))
    })
    return(processed)
}

#' Default JSON converter for multimodal inputs
#'
#' Converts R objects or files to JSON-formatted text. Data frames are limited to
#' a specified number of rows.
#'
#' @param input Input to convert (R object, file path, or URL)
#' @param max_rows Integer. Maximum number of rows for data frames
#' @return Character. JSON-formatted string
#' @keywords internal
#' @noRd
default_json_converter <- function(input, max_rows = 10) {
    input_val <- rlang::eval_tidy(input)
    if (is_url(input_val) || is_file(input_val)) {
        input_val <- read_file(input_val)        
    } else {
        if (is.data.frame(input_val)) {
            input_val <- utils::head(input_val, max_rows)
        }
    }
    # Update the quosure with the new value
    input <- rlang::new_quosure(input_val, rlang::quo_get_env(input))

    tryCatch({
        return(to_json_str(input))
    }, error = function(e) {
        cli::cli_abort(
            "{.fn default_json_converter} failed to convert object to JSON: {e$message}",
            "i" = "Please provide a custom JSON converter to the `.json_converter` argument of {.fn as_json_content}."
        )
    })  
}

#' Convert PDF to base64 data
#'
#' Reads a local PDF file and encodes it as base64 for embedding in API requests
#' @param pdf_path Character. Path to local PDF file (must exist)
#' @return Named list with three elements:
#'   \describe{
#'     \item{data}{Character. Base64-encoded PDF data (no data URI prefix)}
#'     \item{mime_type}{Character. Always "application/pdf"}
#'     \item{data_uri}{Character. Complete data URI string (data:application/pdf;base64,...)}
#'   }
#' @keywords internal
#' @noRd
pdf_to_base64 <- function(pdf_path) {
    if (!is_file(pdf_path)) {
        cli::cli_abort("PDF file not found: {.path {pdf_path}}")
    }

    pdf_bytes <- readBin(pdf_path, "raw", file.info(pdf_path)$size)
    encoded_pdf <- base64enc::base64encode(pdf_bytes)
    data_uri <- paste0("data:application/pdf;base64,", encoded_pdf)

    return(list(
        data = encoded_pdf,
        mime_type = "application/pdf",
        data_uri = data_uri
    ))
}

#' Convert PDF URL to base64 data
#'
#' Downloads a PDF from a URL and encodes it as base64 for embedding in API requests
#' @param pdf_url Character. URL to PDF file (must be accessible)
#' @return Named list with three elements:
#'   \describe{
#'     \item{data}{Character. Base64-encoded PDF data}
#'     \item{mime_type}{Character. Always "application/pdf"}
#'     \item{data_uri}{Character. Complete data URI string}
#'   }
#' @keywords internal
#' @noRd
pdf_url_to_base64 <- function(pdf_url) {
    temp_file <- download_temp_file(pdf_url, ext = "pdf")
    on.exit(unlink(temp_file))
    return(pdf_to_base64(temp_file))
}

#' Convert local image path to base64 data
#'
#' Reads a local image file and encodes it as base64 for embedding in API requests
#' @param image_path Character. Path to local image file (must exist)
#' @return Named list with three elements:
#'   \describe{
#'     \item{data}{Character. Base64-encoded image data}
#'     \item{mime_type}{Character. MIME type of the image (e.g., "image/jpeg")}
#'     \item{data_uri}{Character. Complete data URI string}
#'   }
#' @keywords internal
#' @noRd
image_to_base64 <- function(image_path) {
    if (!is_file(image_path)) {
        cli::cli_abort("Image file not found: {.path {image_path}}")
    }

    # Read and encode image
    mime_type <- mime::guess_type(image_path, unknown = "application/octet-stream")
    image_bytes <- readBin(image_path, "raw", file.info(image_path)$size)
    encoded_image <- base64enc::base64encode(image_bytes)
    data_uri <- paste0("data:", mime_type, ";base64,", encoded_image)

    return(list(
        data = encoded_image,
        mime_type = mime_type,
        data_uri = data_uri
    ))
}

#' Convert image URL to base64 data
#'
#' Downloads an image from a URL and encodes it as base64 for embedding in API requests
#' @param image_url Character. URL to image file (must be accessible)
#' @return Named list with three elements:
#'   \describe{
#'     \item{data}{Character. Base64-encoded image data}
#'     \item{mime_type}{Character. MIME type of the image}
#'     \item{data_uri}{Character. Complete data URI string}
#'   }
#' @keywords internal
#' @noRd
image_url_to_base64 <- function(image_url) {
    temp_file <- download_temp_file(image_url)
    on.exit(unlink(temp_file))
    return(image_to_base64(temp_file))
}

# -----🔺 HELPERS --------------------------------------------------------------

#' Format output to JSON or YAML
#'
#' Formats an output to JSON or YAML.
#' @param x Any R object
#' @param format Character. Output format: "json", "yaml", or NULL for list (default: NULL)
#' @return Character. Formatted output
#' @keywords internal
#' @noRd
format_output <- function(x, format) {
    if (is.null(format)) {
        return(x)
    }
    format <- match.arg(format, c("json", "yaml"))
    switch(
        format,
        "json" = jsonlite::toJSON(x, pretty = TRUE, auto_unbox = TRUE),
        "yaml" = yaml::as.yaml(x),
        x
    )
}

#' Guess MIME type of input
#'
#' Determines the MIME type of a file path or URL using mime package with custom
#' extensions for R-specific files.
#'
#' @param input Character. File path or URL
#' @return Character. Lowercase MIME type string
#' @keywords internal
#' @noRd
guess_input_type <- function(input) {
    mime_extra <- c(
        "qmd" = "text/x-markdown",
        "rds" = "data/rds",
        "lintr" = "text/plain",
        "Rprofile" = "text/plain"
    )

    mime_type <- mime::guess_type(input, mime_extra = mime_extra)
    return(tolower(mime_type))
}

#' Check if input is a URL
#'
#' Tests whether a string matches URL patterns (http, https, ftp).
#'
#' @param x Character scalar. Input to test
#' @return Logical. TRUE if input is a valid URL, FALSE otherwise
#' @keywords internal
#' @noRd
is_url <- function(x) {
    if (is.list(x) || length(x) > 1) {
        return(FALSE)
    }
    stringr::str_detect(x, "^(https?|ftp)://[^\\s/$.?#].[^\\s]*$")
}

#' Check if input is a file path
#'
#' Tests whether a string is an existing file path by checking for path separators
#' or file extensions and verifying file existence.
#'
#' @param x Character scalar. Input to test
#' @return Logical. TRUE if input is an existing file, FALSE otherwise
#' @keywords internal
#' @noRd
is_file <- function(x) {
    if (is.list(x) || length(x) > 1) {
        return(FALSE)
    }
    # Check if it looks like a file path (contains path separators or file extension)
    looks_like_path <- stringr::str_detect(x, "^.*([/\\\\]|\\.[a-zA-Z0-9]+)$")
    if (!looks_like_path) {
        return(FALSE)
    }
    return(fs::is_file(x))
}

#' Find file extension from MIME type
#'
#' Looks up the file extension corresponding to a MIME type using mime package.
#'
#' @param mime_type Character. MIME type string (e.g., "image/jpeg")
#' @return Character. File extension without dot (e.g., "jpg"), or "bin" if not found
#' @keywords internal
#' @noRd
find_ext_from_mime_type <- function(mime_type) {
    names(mime::mimemap[which(mime::mimemap == mime_type)])[1] %||% "bin"
}

#' Download file from URL to temporary location
#'
#' Downloads a file from a URL and saves it to a temporary file with the specified
#' or inferred extension.
#'
#' @param url Character. URL to download from
#' @param ext Character. File extension to use (without dot). If NULL, extracted from URL
#' @param quiet Logical. If TRUE, suppress download progress messages
#' @return Character. Path to temporary file
#' @keywords internal
#' @noRd
download_temp_file <- function(url, ext = NULL, quiet = TRUE) {
    if (is.null(ext)) {
        ext <- tools::file_ext(url)
    }
    temp_file <- tempfile(fileext = paste0(".", ext))
    utils::download.file(url, temp_file, mode = "wb", quiet = quiet)
    return(temp_file)
}

#' Convert R object to string representation
#'
#' Captures the output of str() as a character string for text-based representation
#' of R objects.
#'
#' @param input Any R object
#' @param vec_len Integer. Maximum vector length to display
#' @param nchar_max Integer. Maximum characters per element
#' @return Character. String representation of the object
#' @keywords internal
#' @noRd
to_str <- function(input, vec_len = 999, nchar_max = 999) {
    input <- add_object_metadata(input)
    utils::str(input, give.attr = FALSE, vec.len = vec_len, nchar.max = nchar_max, list.len = 999) |>
        utils::capture.output() |>
        paste(collapse = "\n")
}

#' Convert R object to JSON string
#'
#' Converts an R object to a JSON string using jsonlite::toJSON().
#' @param input Any R object
#' @return Character. JSON string
#' @keywords internal
#' @noRd
to_json_str <- function(input) {
    input <- add_object_metadata(input)
    return(as.character(jsonlite::toJSON(input, pretty = FALSE, auto_unbox = TRUE)))
}

#' Add object metadata to input
#'
#' Adds metadata to an input object to be used in the JSON string.
#' @param input Any R object
#' @return R object with metadata
#' @keywords internal
#' @noRd
add_object_metadata <- function(input) {
    if (rlang::is_quosure(input)) {
        content <- rlang::eval_tidy(input)
        # If evaluated content is a character string, return it as-is (no name wrapping)
        if (is.character(content)) {
            return(content)
        }
        # Only wrap with metadata if the quosure is a symbol (variable name)
        if (rlang::is_symbol(rlang::quo_get_expr(input))) {
            return(list(
                object_name = rlang::as_label(input),
                object_classes = class(content),
                content = content
            ))
        } else {
            # For inline expressions, use the content directly
            return(content)
        }
    }
}

#' Convert list of lists to data frame
#' @param lol List of lists where each element will become a row
#' @return Data frame with combined rows, or empty data frame if input is NULL or empty
#' @keywords internal
#' @noRd
lol_to_df <- function(lol) {
    
    if (purrr::is_empty(lol)) return(data.frame())
    
    process_element <- function(elt) {
        elt |> 
            purrr::map(\(x) if (is.list(x) && purrr::is_empty(x)) NA else x) |>
            purrr::map(\(x) if (is.list(x) && length(x) == 1) x[[1]] else x) |>
            rectangularize() |>
            dplyr::mutate(dplyr::across(tidyselect::everything(), as.character))
    }
    process_elements <- \(x) purrr::map(x, process_element)
    
    quiet_process_element <- purrr::quietly(process_elements)
    
    output <- quiet_process_element(lol) |> 
        purrr::pluck("result") |>
        purrr::reduce(dplyr::bind_rows) |>
        utils::type.convert(as.is = TRUE)
    
    return(output)
}

#' Silent semi join
#'
#' Performs a semi join between two data frames without printing warnings
#' @param x First data frame (left side of join)
#' @param y Second data frame (right side of join)
#' @return Filtered data frame containing rows from x that have matching values in y
#' @keywords internal
#' @noRd
silent_semi_join <- function(x, y) {
    common_cols <- intersect(names(x), names(y))
    if (length(common_cols) == 0) {
        return(x[0, ])
    }
    purrr::quietly(dplyr::semi_join)(x, y, by = common_cols)$result
}

#' Get all names recursively from a list
#'
#' Extracts all names from a list recursively, including nested list names
#' @param x List to extract names from
#' @return Character vector of all unique names found at all levels
#' @keywords internal
#' @noRd
get_all_names <- function(x) {
    if (!is.list(x)) return(character(0))
    
    current_names <- names(x)
    nested_names <- unlist(lapply(x, get_all_names))
    
    unique(c(current_names, nested_names))
}

#' Find element in nested list by name
#'
#' Searches recursively through a nested list structure for an element with a specific name
#' @param x List to search through
#' @param name Character. Name of the element to find
#' @return The found element or NULL if not found
#' @keywords internal
#' @noRd
find_in_list <- function(x, name) {
    if (!is.list(x)) return(NULL)
    
    if (name %in% names(x)) {
        return(x[[name]])
    }
    
    for (elem in x) {
        if (is.list(elem)) {
            result <- find_in_list(elem, name)
            if (!is.null(result)) return(result)
        }
    }
    
    return(NULL)
}

#' Flatten single-element lists
#'
#' Recursively flattens single-element lists to their contents throughout a nested structure
#' @param x List or other object to flatten
#' @return List with single-element sublists flattened to their contents, or original object if not a list
#' @keywords internal
#' @noRd
flatten_singles <- function(x) {
    if (!is.list(x)) {
        return(x)
    }
    purrr::modify_tree(x, post = \(node) purrr::map_if(node, \(x) is.list(x) && length(x) == 1, \(y) y[[1]]))
}

#' Check if HTTP error is transient
#'
#' Determines whether an HTTP error should trigger a retry based on status code
#' @param resp httr2 response object to check
#' @return Logical. TRUE if the error is transient (408, 429, 500-504), FALSE otherwise
#' @keywords internal
#' @noRd
is_transient_http_error <- function(resp) {
    if (!httr2::resp_has_body(resp)) return(TRUE)
    
    status <- httr2::resp_status(resp)
    # Retry on 429 (rate limit), 500+ (server errors), and some 400s
    status %in% c(408, 429, 500, 502, 503, 504)
}

#' Clean malformed JSON in content
#'
#' Cleans malformed JSON in content by removing duplicate objects.
#' @param content Character. Content to clean
#' @return Character. Cleaned content
#' @keywords internal
#' @noRd
clean_malformed_json <- function(content) {
    if (purrr::is_empty(content)) return(content)
    
    if (stringr::str_detect(content, "\\}\\{")) {
        content <- stringr::str_split_1(content, "\\}\\{") |>
            dplyr::first() |>
            paste0("}")
    }
    return(content)
}

#' Resolve download destination path
#'
#' Determines the final path for downloading a file, handling both directory and file paths.
#' All paths are resolved relative to the project root using here::here(). If dest_path is
#' a directory (or doesn't exist and has no file extension), the filename is appended.
#' If dest_path is a file path, it's used as-is.
#'
#' @param dest_path Character. Destination path - can be directory or complete file path.
#'   Relative paths are resolved from project root.
#' @param filename Character. Filename to use when dest_path is a directory
#' @return Character. Resolved absolute path for the download
#' @keywords internal
#' @noRd
resolve_download_path <- function(dest_path, filename) {

    # Resolve dest_path relative to project root
    dest_path <- here::here(dest_path)

    if (fs::is_dir(dest_path)) {
        # dest_path is an existing directory
        final_path <- file.path(dest_path, filename)
    } else if (is_file(dest_path)) {
        # dest_path is an existing file
        final_path <- dest_path
    } else {
        # dest_path doesn't exist - check if it looks like a file or directory
        if (grepl("\\.[a-zA-Z0-9]+$", basename(dest_path))) {
            # Has file extension, treat as file path
            final_path <- dest_path
            parent_dir <- dirname(dest_path)
            if (!dir.exists(parent_dir)) {
                dir.create(parent_dir, recursive = TRUE)
            }
        } else {
            # No extension, treat as directory
            if (!dir.exists(dest_path)) {
                dir.create(dest_path, recursive = TRUE)
            }
            final_path <- file.path(dest_path, filename)
        }
    }

    return(final_path)
}


# -----🔺 CHAT HISTORY ---------------------------------------------------------

#' Generate history file path
#'
#' Creates a unique file path for storing chat history based on a base name and timestamp.
#' @param base_name Character. Base name for the instance (e.g., "openai_chat")
#' @return Character. Full file path (e.g., "data/history/google/20251017_215407.json")
#' @keywords internal
#' @noRd
generate_history_path <- function(base_name = "provider") {
    history_dir <- getOption("argent.history_dir", "data/history/") |> 
        stringr::str_remove("^/")
    
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    formatted_base_name <- tolower(base_name) |> 
        stringr::str_replace_all("\\s+", "_")
    path <- here::here(history_dir, formatted_base_name, paste0(timestamp, ".json"))
    
    # Normalize to remove double slashes
    fs::path_norm(path)
}

# -----🔺 PRINT ----------------------------------------------------------------

#' Format tool call for display
#'
#' Formats a tool call as an R function call with named arguments.
#' Handles JSON parsing, defaults, and formatting internally.
#'
#' @param fn_name Character or NULL. Function name (defaults to "unknown" if NULL)
#' @param args Character (JSON string), list, or NULL. Function arguments (defaults to empty list if NULL)
#' @return Character. Formatted tool call string suitable for cli_bullets
#' @keywords internal
#' @noRd
format_tool_call <- function(fn_name, args) {
    fn_name <- fn_name %||% "unknown"

    # Parse JSON string to list if needed (OpenAI/OpenRouter/LocalLLM return JSON strings)
    if (is.character(args)) {
        args <- purrr::possibly(jsonlite::fromJSON, otherwise = list())(args)
    }

    # Format arguments as name = value pairs
    if (is.list(args) && length(args) > 0) {
        # Format each argument as a proper R expression
        args_formatted <- purrr::imap_chr(args, \(value, name) {
            # Use deparse to convert value to R code string
            value_str <- paste(deparse(value, width.cutoff = 500L), collapse = "")
            paste0(name, " = ", value_str)
        })
        args_str <- paste(args_formatted, collapse = ", ")
    } else {
        args_str <- ""
    }

    # Build the function call string and apply cyan color
    return(paste0(fn_name, "(", args_str, ")"))
}

#' Format tool result for display
#'
#' Formats a tool result using cli inline markup for better styling.
#' Handles content conversion and defaults internally.
#'
#' @param identifier Character or NULL. Tool identifier (name or ID, defaults to "unknown" if NULL)
#' @param content Character, list, or NULL. Result content (defaults to empty string if NULL)
#' @return List with two elements: header (for cli_bullets) and content (for cat)
#' @keywords internal
#' @noRd
format_tool_result <- function(identifier, content) {
    identifier <- identifier %||% "unknown"

    content_str <- if (is.null(content)) {
        ""
    } else if (is.list(content)) {
        # If it's already a list, check if it's a single-element list containing a JSON string
        if (length(content) == 1 && is.character(content[[1]])) {
            # Try to parse the string inside the list
            parsed <- purrr::possibly(jsonlite::fromJSON, otherwise = NULL)(content[[1]])
            if (!is.null(parsed)) {
                yaml::as.yaml(parsed)
            } else {
                content[[1]]  # Return the string as-is if not JSON
            }
        } else {
            # Regular list object
            yaml::as.yaml(content)
        }
    } else {
        content_char <- as.character(content)
        # Try to parse and prettify if it looks like JSON
        parsed <- purrr::possibly(jsonlite::fromJSON, otherwise = NULL)(content_char)
        if (!is.null(parsed)) {
            yaml::as.yaml(parsed)
        } else {
            content_char
        }
    }

    list(
        header = sprintf("Result from {.strong %s}:", identifier),
        content = content_str
    )
}

#' Format code block for display
#'
#' Formats a code block as a markdown code fence with language syntax highlighting hint.
#'
#' @param code Character. The code content
#' @param language Character or NULL. Programming language (defaults to "" if NULL)
#' @param label Character or NULL. Optional label/description to prepend (e.g., "File: path/to/file")
#' @return Character. Formatted code block string
#' @keywords internal
#' @noRd
format_code_block <- function(code, language = NULL, label = NULL) {
    language <- language %||% ""

    result <- paste0("```{", tolower(language), "}\n", code, "\n```")

    if (!is.null(label)) {
        result <- paste0(label, "\n", result)
    }

    return(result)
}

#' Color-code role names for display
#'
#' Applies CLI color formatting to role names for better visual distinction.
#'
#' @param role Character. Role name (system, user, assistant, model, tool, function)
#' @return Character. Colored role name
#' @keywords internal
#' @noRd
color_role <- function(role) {
    switch(
        role,
        "system" = cli::col_silver(role),
        "user" = cli::col_blue(role),
        "assistant" = cli::col_green(role),
        "model" = cli::col_green("assistant"),
        "tool" = cli::col_yellow(role),
        "function" = cli::col_yellow("tool"),
        role
    )
}

#' Format tool definition for display
#'
#' Formats a normalized tool definition for display in the chat history.
#' Expects tool to have name, description, type, and parameters fields.
#'
#' @param tool List. Normalized tool definition with name, description, type, and parameters fields
#' @return NULL (invisibly). Prints formatted tool definition as side effect
#' @keywords internal
#' @noRd
format_tool_definition <- function(tool) {
    name <- tool$name %||% "unknown"
    type <- tool$type %||% "tool"
    desc <- tool$description %||% ""
    params <- tool$parameters %||% character(0)

    # Build function signature
    param_str <- paste(params, collapse = ", ")
    signature <- paste0(name, "(", param_str, ")")

    if (type == "server") {
        formatted <- sprintf("{.strong {.emph [Server]} %s}", signature)
    } else {
        # Custom functions: **function_name(params)**: description
        if (nzchar(desc)) {
            formatted <- sprintf("{.strong %s}: %s", signature, desc)
        } else {
            formatted <- sprintf("{.strong %s}", signature)
        }
    }

    return(formatted)
}
