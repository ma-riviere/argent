# Package initialization

.onLoad <- function(libname, pkgname) {
    # Enable source preservation for user-defined tool functions
    # This allows as_tool() to extract annotations from function bodies
    if (isFALSE(getOption("keep.source"))) {
        options(keep.source = TRUE)

        # Only show message in interactive sessions
        if (interactive()) {
            packageStartupMessage(
                "argent: Setting keep.source=TRUE to enable tool annotations"
            )
        }
    }
}
