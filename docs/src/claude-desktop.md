# Claude Desktop Integration

Complete guide to integrating TestPickerMCPServer with Claude Desktop.

## Configuration File Location

**macOS/Linux:**
```
~/.config/Claude/claude_desktop_config.json
```

**Windows:**
```
%APPDATA%\Claude\claude_desktop_config.json
```

## Basic Configuration (Stdio)

Add to your Claude Desktop config:

```json
{
  "mcpServers": {
    "testpicker": {
      "command": "julia",
      "args": [
        "--project",
        "-e",
        "using TestPickerMCPServer; start_server()"
      ]
    }
  }
}
```

**Important:** The server must be started from a Julia package directory. You'll need to:
1. Open Claude Desktop
2. Navigate to your package in the terminal
3. The server will auto-detect the package from the current directory

## Advanced: Package-Specific Configuration

If you want to test a specific package, set the working directory:

```json
{
  "mcpServers": {
    "testpicker-mypackage": {
      "command": "julia",
      "args": [
        "--project",
        "-e",
        "cd(\"/path/to/MyPackage\"); using TestPickerMCPServer; start_server()"
      ]
    }
  }
}
```

## HTTP Transport Configuration

For HTTP mode (useful for debugging):

```json
{
  "mcpServers": {
    "testpicker-http": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "http://127.0.0.1:3000",
        "--allow-http"
      ]
    }
  }
}
```

Then start the server separately:
```bash
cd your-package
TESTPICKER_MCP_TRANSPORT=http julia --project=@mcp -e 'using TestPickerMCPServer; start_server()'
```

## Using Preferences for Permanent Settings

Instead of environment variables, use Preferences.jl in your package:

```julia
# In your package directory
julia --project=@mcp -e '
using Preferences, TestPickerMCPServer
set_preferences!(TestPickerMCPServer,
    "transport" => "stdio"  # or "http"
)
'
```

Then your Claude Desktop config can be simple:
```json
{
  "mcpServers": {
    "testpicker": {
      "command": "julia",
      "args": ["--project", "-e", "using TestPickerMCPServer; start_server()"]
    }
  }
}
```

## Verifying Integration

1. **Restart Claude Desktop** after changing config

2. **Check server is available:**
   - Type a message in Claude
   - Look for TestPicker tools in the tools panel

3. **Test a tool:**
   ```
   Can you list the test files in this package?
   ```

4. **Expected response:**
   - Claude will use `list_test_files` tool
   - Returns JSON with test files

## Troubleshooting

### Server Not Appearing

**Check config syntax:**
```bash
# macOS/Linux
cat ~/.config/Claude/claude_desktop_config.json | jq .

# Should parse without errors
```

**Verify Julia installation:**
```bash
which julia
julia --version
```

### Wrong Package Detected

**Symptom:** Server detects different package than expected.

**Solution:** Explicitly set working directory in config:
```json
{
  "args": [
    "--project",
    "-e",
    "cd(\"/absolute/path/to/package\"); using TestPickerMCPServer; start_server()"
  ]
}
```

### Server Crashes on Startup

**Check logs:**
- Claude Desktop → Help → Show Logs
- Look for Julia errors

**Common causes:**
1. Missing dependencies: Run `julia --project=@mcp -e 'using Pkg; Pkg.instantiate()'`
2. Not in a package: Ensure `cd()` points to a valid package
3. Syntax errors in config JSON

## Multiple Package Setup

You can configure multiple servers for different packages:

```json
{
  "mcpServers": {
    "testpicker-package1": {
      "command": "julia",
      "args": [
        "--project",
        "-e",
        "cd(\"/path/to/Package1\"); using TestPickerMCPServer; start_server()"
      ]
    },
    "testpicker-package2": {
      "command": "julia",
      "args": [
        "--project",
        "-e",
        "cd(\"/path/to/Package2\"); using TestPickerMCPServer; start_server()"
      ]
    }
  }
}
```

**Note:** Only one server can run at a time in stdio mode.

## Best Practices

1. **Use absolute paths** in config for reliability
2. **Set preferences** instead of ENV vars for persistence
3. **Test independently first:**
   ```bash
   julia --project=@mcp -e 'using TestPickerMCPServer; start_server()'
   ```
4. **Keep config simple** - let preferences handle settings
5. **Restart Claude Desktop** after config changes
