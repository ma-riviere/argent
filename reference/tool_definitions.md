# Generate tools and schemas definitions from direct specification

### Direct specification approach

`tool()` creates a tool definition by directly specifying parameters, as
an alternative to using function annotations with
[`as_tool()`](https://ma-riviere.github.io/argent/reference/as_tool.md).
This approach is useful for complex nested structures or when defining
tools without corresponding R functions.

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
tool(name, description, ..., fn = NULL)

schema(name, description, ..., strict = TRUE, additional_properties = FALSE)
```

## Arguments

- name:

  Character. The tool or schema name

- description:

  Character. What the tool does or what the schema represents

- ...:

  Named parameter specifications. See Details.

- fn:

  Function. For `tool()` only. Optional function implementation to store
  with the tool definition. When provided, this function (with its
  closure) will be called when the LLM invokes the tool, supporting
  locally-defined functions with access to local variables. If NULL
  (default), the function is looked up by name in the global
  environment.

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

- `.fn`: Optional function implementation (if `fn` parameter provided)

For `schema()`: A list with:

- `name`: Schema name (character)

- `description`: Schema description (character)

- `args_schema`: JSON Schema object with `type`, `properties`, and
  `required` fields

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

**Nested objects (string syntax):** Use `{prop:type, ...}` inline:

    address = "{street:string*, city:string*, zip:string}* Mailing address"

**Nested objects (list syntax):** Use list with `type = "object"`:

    address = list(
      type = "object*",
      description = "Mailing address",
      street = "string* Street address",
      city = "string* City name"
    )

**Arrays of objects:** Use `[{...}]` or `type = "[object]"`:

    # String syntax
    items = "[{name:string*, qty:integer*}]* Order items"

    # List syntax
    items = list(
      type = "[object]*",
      description = "Order items",
      name = "string*",
      qty = "integer*"
    )

## Examples

``` r
if (FALSE) { # \dontrun{
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

# Nested object using string syntax (new!)
create_order <- tool(
  name = "create_order",
  description = "Create a new order",
  customer = "{name:string*, email:string*}* Customer information",
  items = "[{product:string*, quantity:integer*}]* Order items"
)

# Nested object using list syntax (original)
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
