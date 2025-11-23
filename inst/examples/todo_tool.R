# Create a TODO-list
create_todo_list <- function(name = "todos") {
    env <- new.env(parent = emptyenv())
    env$name <- name
    env$todos <- list()
    class(env) <- c("todo_list", class(env))
    return(env)
}

# Get the current TODOs from a given TODO-list
get_todos <- function(todo_mgr) {
    todo_mgr$todos
}

# Set the TODOs of a given TODO-list
set_todos <- function(todo_mgr, todos) {
    # Validate input structure
    if (!is.list(todos)) {
        return("Error: todos must be a list")
    }

    errors <- character()
    for (i in seq_along(todos)) {
        todo <- todos[[i]]

        # Check required fields
        if (!all(c("content", "status") %in% names(todo))) {
            errors <- c(errors, sprintf("Todo %d missing required fields (content, status)", i))
        }

        # Validate status
        valid_statuses <- c("pending", "in_progress", "completed")
        if (!todo$status %in% valid_statuses) {
            errors <- c(errors, sprintf(
                "Todo %d has invalid status '%s'. Must be one of: %s",
                i, todo$status, paste(valid_statuses, collapse = ", ")
            ))
        }
    }

    if (length(errors) > 0) {
        return(paste(c("Errors found:", errors), collapse = "\\n- "))
    }

    todo_mgr$todos <- todos
    return(sprintf("Successfully updated %d TODO(s)", length(todos)))
}

# Print method for TODO lists
print.todo_list <- function(x, ...) {
    name <- x$name
    todos <- x$todos
    
    if (length(todos) == 0) {
        cat(sprintf("%s: []\n", name))
        return(invisible(x))
    }
    
    cat(sprintf("%s:\n", name))
    for (i in seq_along(todos)) {
        todo <- todos[[i]]
        
        # Determine checkbox symbol based on status
        checkbox <- switch(
            todo$status,
            "pending" = "[ ]",
            "in_progress" = "[-]",
            "completed" = "[x]",
            "[ ]"  # default fallback
        )
        
        cat(sprintf("- %s %s\n", checkbox, todo$content))
    }
    
    invisible(x)
}
