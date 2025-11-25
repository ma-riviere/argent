test_that("tool() creates valid tool definition", {
    result <- tool(
        name = "get_weather",
        description = "Get weather for a location",
        location = "string* The city name",
        units = "string Temperature units"
    )

    expect_type(result, "list")
    expect_equal(result$name, "get_weather")
    expect_equal(result$description, "Get weather for a location")
    expect_type(result$args_schema, "list")
    expect_equal(result$args_schema$type, "object")
    expect_type(result$args_schema$properties, "list")
    expect_length(result$args_schema$properties, 2)

    # Check required parameters
    expect_contains(result$args_schema$required, "location")
    expect_false("units" %in% result$args_schema$required)

    # Check property types
    expect_equal(result$args_schema$properties$location$type, "string")
    expect_equal(result$args_schema$properties$units$type, "string")
})

test_that("tool() validates input parameters", {
    expect_error(
        tool(name = "", description = "Test"),
        "must be a non-empty string"
    )

    expect_error(
        tool(name = "test", description = ""),
        "must be a non-empty string"
    )

    expect_error(
        tool(name = "test", description = "Test", fn = "not_a_function"),
        "must be a function or NULL"
    )
})

test_that("tool() supports closure functions", {
    my_fn <- function(x) x * 2

    result <- tool(
        name = "multiply",
        description = "Multiply by 2",
        x = "number* Input number",
        fn = my_fn
    )

    expect_equal(result$.fn, my_fn)
    expect_true(is.function(result$.fn))
})

test_that("schema() creates valid schema definition", {
    result <- schema(
        name = "User",
        description = "A user object",
        username = "string* User name",
        age = "integer User age",
        email = "string* Email address"
    )

    expect_type(result, "list")
    expect_equal(result$name, "User")
    expect_equal(result$description, "A user object")
    expect_type(result$args_schema, "list")
    expect_equal(result$args_schema$type, "object")

    # Check required fields
    expect_contains(result$args_schema$required, "username")
    expect_contains(result$args_schema$required, "email")
    expect_false("age" %in% result$args_schema$required)

    # Check property types
    expect_equal(result$args_schema$properties$username$type, "string")
    expect_equal(result$args_schema$properties$age$type, "integer")
    expect_equal(result$args_schema$properties$email$type, "string")
})

test_that("schema() handles strict and additional_properties", {
    schema1 <- schema(
        name = "StrictSchema",
        description = "A strict schema",
        field = "string* A field",
        strict = TRUE,
        additional_properties = FALSE
    )

    expect_true(schema1$strict)
    expect_false(schema1$args_schema$additionalProperties)

    schema2 <- schema(
        name = "FlexibleSchema",
        description = "A flexible schema",
        field = "string A field",
        strict = FALSE,
        additional_properties = TRUE
    )

    expect_false(schema2$strict)
    expect_true(schema2$args_schema$additionalProperties)
})

test_that("tool definitions support various parameter types", {
    result <- tool(
        name = "complex_tool",
        description = "Tool with various types",
        str_param = "string* String parameter",
        int_param = "integer Integer parameter",
        num_param = "number* Number parameter",
        bool_param = "boolean Boolean parameter",
        arr_param = "[string] Array of strings",
        date_param = "date Date parameter"
    )

    props <- result$args_schema$properties

    expect_equal(props$str_param$type, "string")
    expect_equal(props$int_param$type, "integer")
    expect_equal(props$num_param$type, "number")
    expect_equal(props$bool_param$type, "boolean")
    expect_equal(props$arr_param$type, "array")
    expect_equal(props$arr_param$items$type, "string")
    expect_equal(props$date_param$type, "string")
    expect_equal(props$date_param$format, "date")
})

test_that("tool definitions have no .fn field by default", {
    result <- tool(
        name = "simple_tool",
        description = "Simple tool",
        param1 = "string* Parameter"
    )

    expect_null(result$.fn)
})

test_that("nested array types are supported", {
    tool1 <- tool(
        name = "nested_arrays",
        description = "Test nested arrays",
        matrix_param = "[[number]] 2D array of numbers"
    )

    props <- tool1$args_schema$properties
    expect_equal(props$matrix_param$type, "array")
    expect_equal(props$matrix_param$items$type, "array")
    expect_equal(props$matrix_param$items$items$type, "number")
})

test_that("nested object types are supported", {
    tool1 <- tool(
        name = "create_user",
        description = "Create a new user",
        user_name = "string* User's full name",
        address = list(
            type = "object*",
            description = "User's mailing address",
            street = "string* Street address",
            city = "string* City name",
            zip = "string Postal code"
        )
    )

    props <- tool1$args_schema$properties

    # Check top-level properties
    expect_equal(props$user_name$type, "string")
    expect_contains(tool1$args_schema$required, "user_name")
    expect_contains(tool1$args_schema$required, "address")

    # Check nested object structure
    expect_equal(props$address$type, "object")
    expect_equal(props$address$description, "User's mailing address")
    expect_type(props$address$properties, "list")

    # Check nested object properties
    expect_equal(props$address$properties$street$type, "string")
    expect_equal(props$address$properties$city$type, "string")
    expect_equal(props$address$properties$zip$type, "string")

    # Check nested required fields
    expect_contains(props$address$required, "street")
    expect_contains(props$address$required, "city")
    expect_false("zip" %in% props$address$required)
})

test_that("arrays of objects are supported", {
    tool1 <- tool(
        name = "process_users",
        description = "Process a list of users",
        users = list(
            type = "[object]*",
            description = "List of users to process",
            name = "string* User name",
            email = "string* Email address",
            age = "integer User's age"
        )
    )

    props <- tool1$args_schema$properties

    # Check array structure
    expect_equal(props$users$type, "array")
    expect_equal(props$users$description, "List of users to process")
    expect_contains(tool1$args_schema$required, "users")

    # Check items schema (the object type)
    items <- props$users$items
    expect_equal(items$type, "object")
    expect_type(items$properties, "list")

    # Check object properties within array
    expect_equal(items$properties$name$type, "string")
    expect_equal(items$properties$email$type, "string")
    expect_equal(items$properties$age$type, "integer")

    # Check required fields in nested object
    expect_contains(items$required, "name")
    expect_contains(items$required, "email")
    expect_false("age" %in% items$required)
})
