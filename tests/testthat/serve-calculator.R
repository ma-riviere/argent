#!/usr/bin/env Rscript

# Standalone MCP STDIO server script for testing
# This script serves the calculator MCP server via STDIO

# Get the helper file path from command line args
args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 0) {
    helper_file <- args[1]
} else {
    # Default to finding it relative to this script
    helper_file <- file.path(dirname(sys.frame(1)$ofile), "helper-mcp-servers.R")
}

# Serve the calculator server
argent::mcp_serve_stdio(helper_file, name = "calculator")
