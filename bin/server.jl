#!/usr/bin/env julia

"""
TestPicker MCP Server Entry Point

This script starts the TestPicker MCP server.
It should be run from within a Julia package directory.

Configuration via environment variables:
- TESTPICKER_MCP_TRANSPORT: "stdio" (default) or "http"
- TESTPICKER_MCP_HOST: HTTP host (default: "127.0.0.1")
- TESTPICKER_MCP_PORT: HTTP port (default: 3000)

Usage:
    julia --project bin/server.jl

Or for HTTP mode:
    TESTPICKER_MCP_TRANSPORT=http julia --project bin/server.jl
"""

using TestPickerMCPServer

# Start the server (blocks until stopped)
start_server()
