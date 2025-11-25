test_that("process_multipart_input handles text inputs", {
    google <- Google$new()
    priv <- get_private(google)

    # Plain text string
    input <- "Hello world"
    inputs <- rlang::enquos(input)
    result <- priv$process_multipart_content(inputs)

    expect_type(result, "list")
    expect_equal(result[[1]]$text, "Hello world")
})

test_that("process_multipart_input handles as_text_content", {
    google <- Google$new()
    priv <- get_private(google)

    # Using as_text_content helper
    text_content <- as_text_content("Wrapped text")
    inputs <- rlang::enquos(text_content)
    result <- priv$process_multipart_content(inputs)

    expect_true("text" %in% names(result[[1]]))
    expect_match(as.character(result[[1]]$text), "Wrapped text")
})

test_that("process_multipart_input handles R objects as JSON", {
    google <- Google$new()
    priv <- get_private(google)

    # List object - should be converted to JSON
    test_list <- list(a = 1, b = "text", c = TRUE)
    inputs <- rlang::enquos(test_list)
    result <- priv$process_multipart_content(inputs)

    expect_type(result[[1]]$text, "character")
    expect_true(jsonlite::validate(result[[1]]$text))
})

test_that("process_multipart_input handles as_json_content", {
    google <- Google$new()
    priv <- get_private(google)

    # Using as_json_content helper
    test_data <- list(x = 1:3, y = letters[1:3])
    json_content <- as_json_content(test_data)
    inputs <- rlang::enquos(json_content)
    result <- priv$process_multipart_content(inputs)

    expect_type(result[[1]]$text, "character")
    expect_true(jsonlite::validate(result[[1]]$text))
})

test_that("process_multipart_input correctly identifies argent input types", {
    google <- Google$new()
    priv <- get_private(google)

    # Text with argent_input_type attribute
    text_input <- structure("Tagged text", argent_input_type = "text", argent_provider_options = list())
    inputs <- rlang::enquos(text_input)
    result <- priv$process_multipart_content(inputs)
    expect_type(result, "list")
    expect_match(as.character(result[[1]]$text), "Tagged text")

    # Plain character string
    plain_input <- "Plain string"
    inputs <- rlang::enquos(plain_input)
    result2 <- priv$process_multipart_content(inputs)
    expect_equal(result2[[1]]$text, "Plain string")

    # R object (non-character)
    obj_input <- data.frame(a = 1, b = 2)
    inputs <- rlang::enquos(obj_input)
    result3 <- priv$process_multipart_content(inputs)
    expect_type(result3[[1]]$text, "character")
    expect_true(jsonlite::validate(result3[[1]]$text))
})

test_that("text_input creates proper Google text format", {
    google <- Google$new()
    priv <- get_private(google)

    result <- priv$text_input("Test message")
    expect_type(result, "list")
    expect_equal(result$text, "Test message")
})

test_that("as_text_content creates properly tagged content", {
    content <- as_text_content("Sample text")

    expect_type(content, "list")
    expect_length(content, 1)
    expect_equal(attr(content[[1]], "argent_input_type"), "text")
})

test_that("as_json_content creates properly tagged JSON", {
    test_data <- list(key = "value")
    content <- as_json_content(test_data)

    expect_type(content, "list")
    expect_length(content, 1)
    expect_equal(attr(content[[1]], "argent_input_type"), "text")
    expect_true(jsonlite::validate(content[[1]]))
})

test_that("as_image_content creates properly tagged image content", {
    # Create a small test image data URI
    test_uri <- "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="

    content <- as_image_content(test_uri)

    expect_type(content, "list")
    expect_length(content, 1)
    expect_equal(attr(content[[1]], "argent_input_type"), "image")
})
