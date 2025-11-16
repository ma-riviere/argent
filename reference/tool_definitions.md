# Tool Definitions

Functions for defining tools and schemas using either annotations or
direct specification.

### Annotation-based approach

`as_tool()` parses annotations from a function and converts it to a
generic tool definition with an `args_schema` field. This standardized
format can be converted to provider-specific formats internally.

Annotations use roxygen2-style `#'` comments inside the function body
(not outside like regular roxygen2 documentation). The annotation syntax
follows plumber2 conventions for type specifications.

The package automatically enables source preservation when loaded. If
you defined functions before loading the package, simply redefine them
after loading argent.

### Direct specification approach

`tool()` creates a tool definition by directly specifying parameters, as
an alternative to using function annotations with `as_tool()`. This
approach is useful for complex nested structures or when defining tools
without corresponding R functions.

`schema()` is similar to `tool()` but designed for structured output
schemas. It includes additional fields (`strict` and
`additionalProperties`) required by some LLM providers for structured
outputs.

Parameters are specified as named arguments. Each parameter value can
be:

- A string: `"type[*] [description]"` (e.g.,
  `"string* The user's name"`)

- A list: For nested objects with `type` field and nested properties

## Usage

``` r
as_tool(fn)

tool(name, description, ...)

schema(name, description, ..., strict = TRUE, additional_properties = FALSE)
```

## Arguments

- fn:

  A function with annotations in its body comments using `#'` prefix.
  Supported tags:

  - `@description`: Function description

  - `@param name:type* description`: Parameter specification

  Supported types: `string`, `integer`, `number`, `boolean`, `date`,
  `date-time`, and arrays using `[type]` syntax (e.g., `[integer]`).

  The `*` suffix marks a parameter as required. If a parameter has a
  default value in the function signature and no `*` suffix, it is
  optional. If it has a `*` suffix, it overrides the default and becomes
  required.

- name:

  Character. The tool or schema name

- description:

  Character. What the tool does or what the schema represents

- ...:

  Named parameter specifications. See Details.

- strict:

  Logical. For `schema()` only. Whether to use strict mode (defaults to
  TRUE). Added at root level of the schema definition.

- additional_properties:

  Logical. For `schema()` only. Whether to allow additional properties
  in the schema (defaults to FALSE). Added to `args_schema`.

## Value

For `tool()`: A list with:

- `name`: Tool name (character)

- `description`: Tool description (character)

- `args_schema`: JSON Schema object with `type`, `properties`, and
  `required` fields

For `schema()`: Same as `tool()` but with additional fields:

- `strict`: Logical (at root level)

- `args_schema$additionalProperties`: Logical (inside args_schema)

## Details

### Type Specifications (for `tool()`)

**Primitive types:** `string`, `integer`, `number`, `boolean`, `date`,
`date-time`

**Arrays:** Use `[type]` syntax (e.g., `"[string]"`, `"[integer]"`)

**Required marker:** Add `*` after type (e.g., `"string*"`)

**Descriptions:** Add text after type (e.g.,
`"string* The user's name"`)

**Nested objects:** Use list with `type = "object"` or
`type = "object*"`:

    address = list(
      type = "object*",
      description = "Mailing address",
      street = "string* Street address",
      city = "string* City name"
    )

**Arrays of objects:** Use `type = "[object]"`:

    users = list(
      type = "[object]*",
      description = "List of users",
      name = "string*",
      email = "string*"
    )

## Examples

``` r
if (FALSE) { # \dontrun{
# Annotation-based approach
options(keep.source = TRUE)

my_fn <- function(x, y = 3L) {
    #' @description Add two numbers
    #' @param x:number* First number
    #' @param y:integer Second number (optional, has default)
    x + y
}

as_tool(my_fn)

# Direct specification - tool()
search_tool <- tool(
  name = "search_db",
  description = "Search the database",
  query = "string* Search query",
  limit = "integer Maximum results to return"
)

# Direct specification - schema()
output_schema <- schema(
  name = "flight_search",
  description = "Flight search results",
  destination = "string* Destination city",
  departure_date = "string* Departure date",
  passengers = "integer* Number of passengers",
  strict = TRUE,
  additional_properties = FALSE
)

# Nested object
create_user_tool <- tool(
  name = "create_user",
  description = "Create a new user",
  name = "string* User's full name",
  address = list(
    type = "object*",
    description = "User's mailing address",
    street = "string* Street address",
    city = "string* City name",
    zip = "string Postal code"
  )
)
} # }
```
