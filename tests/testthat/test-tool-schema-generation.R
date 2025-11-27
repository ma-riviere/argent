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
    expect_error(tool(name = "", description = "Test"), "must be a non-empty string")

    expect_error(tool(name = "test", description = ""), "must be a non-empty string")

    expect_error(tool(name = "test", description = "Test", fn = "not_a_function"), "must be a function or NULL")
})

test_that("tool() supports closure functions", {
    my_fn <- function(x) x * 2

    result <- tool(name = "multiply", description = "Multiply by 2", x = "number* Input number", fn = my_fn)

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
    result <- tool(name = "simple_tool", description = "Simple tool", param1 = "string* Parameter")

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

# -----🔺 as_tool() with inline nested type annotations ------------------------

test_that("as_tool() parses inline object type annotations", {
    create_user <- function(user) {
        #' @description Create a new user with nested object
        #' @param user:{name:string*, email:string*, age:integer}* User information
        user
    }

    result <- as_tool(create_user)

    expect_equal(result$name, "create_user")
    expect_equal(result$description, "Create a new user with nested object")

    props <- result$args_schema$properties

    # Check user is required and is an object
    expect_contains(result$args_schema$required, "user")
    expect_equal(props$user$type, "object")
    expect_equal(props$user$description, "User information")

    # Check nested properties
    expect_equal(props$user$properties$name$type, "string")
    expect_equal(props$user$properties$email$type, "string")
    expect_equal(props$user$properties$age$type, "integer")

    # Check nested required fields
    expect_contains(props$user$required, "name")
    expect_contains(props$user$required, "email")
    expect_false("age" %in% props$user$required)
})

test_that("as_tool() parses inline array of objects annotations", {
    process_items <- function(items) {
        #' @description Process a list of items
        #' @param items:[{id:string*, quantity:number*, price:number}]* List of items
        items
    }

    result <- as_tool(process_items)

    expect_equal(result$name, "process_items")
    props <- result$args_schema$properties

    # Check items is required and is an array
    expect_contains(result$args_schema$required, "items")
    expect_equal(props$items$type, "array")
    expect_equal(props$items$description, "List of items")

    # Check items schema (array of objects)
    items_schema <- props$items$items
    expect_equal(items_schema$type, "object")

    # Check object properties within array
    expect_equal(items_schema$properties$id$type, "string")
    expect_equal(items_schema$properties$quantity$type, "number")
    expect_equal(items_schema$properties$price$type, "number")

    # Check required fields in nested object
    expect_contains(items_schema$required, "id")
    expect_contains(items_schema$required, "quantity")
    expect_false("price" %in% items_schema$required)
})

test_that("as_tool() parses deeply nested object structures", {
    configure_app <- function(config) {
        #' @description Configure application with nested settings
        #' @param config:{db:{host:string*, port:integer*, ssl:boolean}, cache:{enabled:boolean*, ttl:integer}}* App configuration
        config
    }

    result <- as_tool(configure_app)

    props <- result$args_schema$properties

    # Check top-level config object
    expect_contains(result$args_schema$required, "config")
    expect_equal(props$config$type, "object")

    # Check db nested object
    db <- props$config$properties$db
    expect_equal(db$type, "object")
    expect_equal(db$properties$host$type, "string")
    expect_equal(db$properties$port$type, "integer")
    expect_equal(db$properties$ssl$type, "boolean")
    expect_contains(db$required, "host")
    expect_contains(db$required, "port")
    expect_false("ssl" %in% db$required)

    # Check cache nested object
    cache <- props$config$properties$cache
    expect_equal(cache$type, "object")
    expect_equal(cache$properties$enabled$type, "boolean")
    expect_equal(cache$properties$ttl$type, "integer")
    expect_contains(cache$required, "enabled")
    expect_false("ttl" %in% cache$required)
})

test_that("as_tool() parses mixed simple and complex parameters", {
    search_products <- function(query, filters = NULL, pagination = NULL) {
        #' @description Search for products with filters
        #' @param query:string* Search query string
        #' @param filters:{category:string, minPrice:number, maxPrice:number, tags:[string]} Optional filters
        #' @param pagination:{page:integer, limit:integer} Pagination options
        list(query = query, filters = filters, pagination = pagination)
    }

    result <- as_tool(search_products)

    props <- result$args_schema$properties

    # Check simple required parameter
    expect_contains(result$args_schema$required, "query")
    expect_equal(props$query$type, "string")
    expect_equal(props$query$description, "Search query string")

    # Check filters is NOT required (has default NULL)
    expect_false("filters" %in% result$args_schema$required)
    expect_equal(props$filters$type, "object")

    # Check filters nested properties
    expect_equal(props$filters$properties$category$type, "string")
    expect_equal(props$filters$properties$minPrice$type, "number")
    expect_equal(props$filters$properties$maxPrice$type, "number")
    expect_equal(props$filters$properties$tags$type, "array")
    expect_equal(props$filters$properties$tags$items$type, "string")

    # Check pagination is NOT required (has default NULL)
    expect_false("pagination" %in% result$args_schema$required)
    expect_equal(props$pagination$type, "object")
})

test_that("as_tool() parses array of objects with nested arrays", {
    create_orders <- function(orders) {
        #' @description Create multiple orders
        #' @param orders:[{customer:string*, items:[{sku:string*, qty:integer*}]*}]* Orders to create
        orders
    }

    result <- as_tool(create_orders)

    props <- result$args_schema$properties

    # Check orders is required array
    expect_contains(result$args_schema$required, "orders")
    expect_equal(props$orders$type, "array")

    # Check order object structure
    order_schema <- props$orders$items
    expect_equal(order_schema$type, "object")
    expect_equal(order_schema$properties$customer$type, "string")
    expect_contains(order_schema$required, "customer")
    expect_contains(order_schema$required, "items")

    # Check nested items array within each order
    items_schema <- order_schema$properties$items
    expect_equal(items_schema$type, "array")

    # Check item object within items array
    item_schema <- items_schema$items
    expect_equal(item_schema$type, "object")
    expect_equal(item_schema$properties$sku$type, "string")
    expect_equal(item_schema$properties$qty$type, "integer")
    expect_contains(item_schema$required, "sku")
    expect_contains(item_schema$required, "qty")
})

test_that("as_tool() handles optional nested objects correctly", {
    update_profile <- function(user_id, profile = NULL) {
        #' @description Update user profile
        #' @param user_id:string* User ID
        #' @param profile:{bio:string, avatar:string, social:{twitter:string, github:string}} Optional profile data
        list(user_id = user_id, profile = profile)
    }

    result <- as_tool(update_profile)

    props <- result$args_schema$properties

    # Check user_id is required
    expect_contains(result$args_schema$required, "user_id")
    expect_equal(props$user_id$type, "string")

    # Check profile is NOT required (has default)
    expect_false("profile" %in% result$args_schema$required)
    expect_equal(props$profile$type, "object")

    # Check deeply nested social object
    social <- props$profile$properties$social
    expect_equal(social$type, "object")
    expect_equal(social$properties$twitter$type, "string")
    expect_equal(social$properties$github$type, "string")
})

test_that("as_tool() validates MCP JSON Schema compliance for complex types", {
    # This test ensures the output structure matches MCP JSON Schema expectations
    complex_fn <- function(data) {
        #' @description Complex data processing
        #' @param data:{items:[{name:string*, value:number*}]*, metadata:{version:integer*}}* Input data
        data
    }

    result <- as_tool(complex_fn)

    # Verify top-level schema structure
    expect_equal(result$args_schema$type, "object")
    expect_type(result$args_schema$properties, "list")
    expect_type(result$args_schema$required, "list")

    props <- result$args_schema$properties

    # Verify data object schema
    expect_equal(props$data$type, "object")
    expect_type(props$data$properties, "list")
    expect_type(props$data$required, "list")

    # Verify items array schema
    expect_equal(props$data$properties$items$type, "array")
    expect_type(props$data$properties$items$items, "list")
    expect_equal(props$data$properties$items$items$type, "object")

    # Verify metadata object schema
    expect_equal(props$data$properties$metadata$type, "object")
    expect_type(props$data$properties$metadata$properties, "list")
    expect_contains(props$data$properties$metadata$required, "version")
})
