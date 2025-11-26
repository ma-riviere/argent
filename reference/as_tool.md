# Generate tools and schemas definitions from functions annotations

`as_tool()` parses annotations from a function and converts it to a
generic tool definition with an `args_schema` field. This standardized
format can be converted to provider-specific formats internally.

Annotations use roxygen2-style `#'` comments inside the function body
(not outside like regular roxygen2 documentation). The annotation syntax
follows plumber2 conventions for type specifications.

The package automatically enables source preservation when loaded. If
you defined functions before loading the package, simply redefine them
after loading argent.

## Usage

``` r
as_tool(fn)
```

## Arguments

- fn:

  A function with annotations in its body comments using `#'` prefix.
  Supported tags:

  - `@description`: Function description

  - `@param name:type* description`: Parameter specification

  Supported types: `string`, `integer`, `number`, `boolean`, `date`,
  `date-time`, and arrays using `[type]` syntax (e.g., `[integer]`).
  Enhanced support for nested objects: `{prop:Type, prop2:Type2}` and
  arrays of objects: `[{prop:Type}]`.

  The `*` suffix marks a parameter as required. If a parameter has a
  default value in the function signature and no `*` suffix, it is
  optional. If it has a `*` suffix, it overrides the default and becomes
  required.

## Value

A list with:

- `name`: Tool name (character)

- `description`: Tool description (character)

- `args_schema`: JSON Schema object with `type`, `properties`, and
  `required` fields

- `.fn`: The original function (with closure) for execution

## Examples

``` r
if (FALSE) { # \dontrun{
options(keep.source = TRUE)

# Simple function with primitive types
my_fn <- function(x, y = 3L) {
    #' @description Add two numbers
    #' @param x:number* First number
    #' @param y:integer Second number (optional, has default)
    x + y
}

as_tool(my_fn)

# Function with nested objects
create_user <- function(user, settings = NULL) {
    #' @description Create a new user account
    #' @param user:{name:string*, email:string*, age:integer} User information
    #' @param settings:{theme:string, notifications:boolean} Optional settings
    list(user = user, settings = settings)
}

as_tool(create_user)

# Function with arrays
search_items <- function(tags, filters = NULL) {
    #' @description Search for items
    #' @param tags:[string]* List of tags to search
    #' @param filters:{category:string, minPrice:number} Optional filters
    list(tags = tags, filters = filters)
}

as_tool(search_items)
} # }
```
