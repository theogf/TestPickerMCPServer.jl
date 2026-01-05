# Configuration

TestPickerMCPServer supports three configuration methods with clear precedence:

1. **Preferences.jl** (persistent, highest priority)
2. **Environment variables** (session-specific)
3. **Default values** (fallback)

## Available Settings

| Setting | Env Variable | Description | Default |
|---------|--------------|-------------|---------|
| `transport` | `TESTPICKER_MCP_TRANSPORT` | Transport type: `"stdio"` or `"http"` | `"stdio"` |
| `host` | `TESTPICKER_MCP_HOST` | HTTP server host | `"127.0.0.1"` |
| `port` | `TESTPICKER_MCP_PORT` | HTTP server port | `3000` |

## Method 1: Preferences.jl (Recommended)

Persistent preferences that survive across sessions:

```julia
using TestPickerMCPServer
using Preferences

# Configure for HTTP mode
set_preferences!(TestPickerMCPServer, "transport" => "http", "port" => 3000)

# Start server (will use saved preferences)
start_server()
```

Preferences are stored in `LocalPreferences.toml` in your project directory.

### View Current Preferences

```julia
using Preferences
@load_preference(TestPickerMCPServer, "transport")  # Returns saved value or nothing
```

### Clear Preferences

```julia
using Preferences
delete_preferences!(TestPickerMCPServer, "transport", "host", "port")
```

## Method 2: Environment Variables

Override preferences for a single session:

```bash
# HTTP mode with custom port
TESTPICKER_MCP_TRANSPORT=http \
TESTPICKER_MCP_PORT=8080 \
julia --project=@mcp -e 'using TestPickerMCPServer; start_server()'
```

## Method 3: Defaults

If neither preferences nor environment variables are set:
- `transport`: stdio
- `host`: 127.0.0.1
- `port`: 3000

## Configuration Precedence Example

```julia
# Scenario: Preference set to HTTP:3000, ENV set to port 8080
set_preferences!(TestPickerMCPServer, "transport" => "http", "port" => 3000)
ENV["TESTPICKER_MCP_PORT"] = "8080"

start_server()
# Result: Uses HTTP on port 8080 (ENV overrides preference for port)
```

## HTTP vs Stdio

### When to Use Stdio (Default)
- Claude Desktop integration
- Local development
- Simple one-client scenarios

### When to Use HTTP
- Testing with MCP Inspector
- Multiple concurrent clients
- Remote access scenarios
- Development and debugging

### HTTP Mode Example

```julia
using Preferences
set_preferences!(TestPickerMCPServer,
    "transport" => "http",
    "host" => "127.0.0.1",
    "port" => 3000
)

start_server()
# Server runs on http://127.0.0.1:3000
```
