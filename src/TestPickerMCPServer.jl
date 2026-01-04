"""
TestPickerMCPServer

MCP (Model Context Protocol) server for TestPicker.jl.

Exposes Julia testing functionality via MCP, enabling LLMs to discover,
run, and inspect tests programmatically.

# Environment Variables
- `TESTPICKER_MCP_TRANSPORT`: Transport type ("stdio" or "http", default: "stdio")
- `TESTPICKER_MCP_HOST`: HTTP server host (default: "127.0.0.1")
- `TESTPICKER_MCP_PORT`: HTTP server port (default: "3000")

# Usage
```julia
using TestPickerMCPServer
start_server()  # Blocks and runs the MCP server
```

Or via command line:
```bash
julia --project -e 'using TestPickerMCPServer; start_server()'
```
"""
module TestPickerMCPServer

# Dependencies
using ModelContextProtocol
using TestPicker
using Pkg: PackageSpec
using JSON3
using Preferences

# Module state: package and TestPicker interfaces
const SERVER_PKG = Ref{Union{Nothing,PackageSpec}}(nothing)
const INTERFACES = TestPicker.INTERFACES

# Include source files
include("utils.jl")
include("handlers.jl")
include("tools.jl")

"""
    get_config(key::String, default)

Get configuration value with precedence: Preferences.jl > ENV > default.
"""
function get_config(key::String, default)
    # 1. Check Preferences.jl first
    pref = @load_preference(key, nothing)
    pref !== nothing && return pref

    # 2. Fall back to environment variable
    env_key = "TESTPICKER_MCP_$(uppercase(key))"
    haskey(ENV, env_key) && return ENV[env_key]

    # 3. Use default
    return default
end

"""
    start_server()

Start the TestPicker MCP server.

Configuration is read with the following precedence:
1. **Preferences.jl** (persistent, set via `set_preferences!`)
2. **Environment variables** (TESTPICKER_MCP_TRANSPORT, etc.)
3. **Default values**

Available settings:
- `transport`: "stdio" (default) or "http"
- `host`: HTTP host (default: "127.0.0.1")
- `port`: HTTP port (default: 3000)

# Examples

Using environment variables:
```bash
TESTPICKER_MCP_TRANSPORT=http julia --project -e 'using TestPickerMCPServer; start_server()'
```

Using Preferences.jl (persistent):
```julia
using TestPickerMCPServer
using Preferences
set_preferences!(TestPickerMCPServer, "transport" => "http", "port" => 3000)
start_server()
```

This function blocks until the server is stopped.
"""
function start_server()
    # Detect and cache package
    SERVER_PKG[] = detect_package()

    # Create server
    server = mcp_server(
        name = "testpicker",
        version = "0.1.0",
        description = "MCP interface for TestPicker.jl",
        tools = ALL_TOOLS
    )

    # Get configuration with Preferences > ENV > defaults
    transport_type = lowercase(string(get_config("transport", "stdio")))

    # Transport selection
    if transport_type == "http"
        host = string(get_config("host", "127.0.0.1"))
        port = parse(Int, string(get_config("port", "3000")))

        transport = HttpTransport(host = host, port = port)
        server.transport = transport
        connect(transport)
        start!(server; transport = transport)
    else
        start!(server)  # Stdio is default
    end
end

export start_server

end # module
