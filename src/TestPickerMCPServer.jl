"""
TestPickerMCPServer

MCP (Model Context Protocol) server for TestPicker.jl.

Exposes Julia testing functionality via MCP, enabling LLMs to discover,
run, and inspect tests programmatically.

# Usage
```julia
using TestPickerMCPServer
TestPickerMCPServer.start_server()  # Blocks and runs the MCP server
```

Or via command line:
```bash
julia --project -e 'using TestPickerMCPServer; TestPickerMCPServer.start_server()'
```

See docs for the type of transports and other config parameters.
"""
module TestPickerMCPServer

# Dependencies
using ModelContextProtocol
using TestPicker
using TestPicker: INTERFACES, TestBlockInfo
using Pkg
using JSON
using Preferences

"Cache the current package in use."
const SERVER_PKG = Ref{Union{Nothing,PackageSpec}}(nothing)

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

    # 2. Fall back to environment variable or default
    env_key = "TESTPICKER_MCP_$(uppercase(key))"
    get(ENV, env_key, default)
end

"""
    start_server(pkg_dir::String=pwd())

Start the TestPicker MCP server for the specified package directory.

# Arguments
- `pkg_dir::String`: Path to the Julia package directory (defaults to current directory).
  The package environment will be automatically activated.

Configuration is read with the following precedence:
1. **Preferences.jl** (persistent, set via `set_preferences!`)
2. **Environment variables** (TESTPICKER_MCP_TRANSPORT, etc.)
3. **Default values**

Available settings:
- `transport`: "stdio" (default) or "http"
- `host`: HTTP host (default: "127.0.0.1")
- `port`: HTTP port (default: 3000)

# Examples

Start server for current directory:
```bash
julia --project -e 'using TestPickerMCPServer; start_server()'
```

Start server for specific package (useful with tools environment):
```bash
julia --project=~/.julia/environments/mcp-tools -e 'using TestPickerMCPServer; start_server("/path/to/package")'
```

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
function start_server(pkg_dir::String = pwd())
    # Activate the package environment
    Pkg.activate(pkg_dir)

    # Detect and cache package
    SERVER_PKG[] = detect_package()

    # Create server
    server = mcp_server(
        name = "testpicker",
        version = "0.1.0",
        description = "MCP interface for TestPicker.jl",
        tools = ALL_TOOLS,
    )

    # Get configuration with Preferences > ENV > defaults
    transport_type = lowercase(string(get_config("transport", "stdio")))

    # Transport selection
    if transport_type == "http"
        host = string(get_config("host", "127.0.0.1"))
        port = parse(Int, string(get_config("port", "3000")))

        transport = HttpTransport(; host, port)
        server.transport = transport
        connect(transport)
        start!(server; transport)
    else
        start!(server)
    end
end


end # module
