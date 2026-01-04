# Claude Code Integration

Complete guide to using TestPickerMCPServer with Claude Code CLI.

## Quick Start

**1. Navigate to your Julia package:**
```bash
cd /path/to/your/julia/package
```

**2. Start the server:**
```bash
julia --project -e 'using TestPickerMCPServer; start_server()'
```

**3. In another terminal, use Claude Code:**
```bash
claude
```

The server will be available as MCP tools in your Claude Code session.

## Configuration

### Option 1: Stdio Transport (Recommended)

Claude Code works best with stdio transport (the default).

**Start server in package directory:**
```bash
cd ~/MyJuliaPackage
julia --project=/path/to/TestPickerMCPServer -e 'using TestPickerMCPServer; start_server()'
```

### Option 2: HTTP Transport

For persistent server across sessions:

**Terminal 1 - Start server:**
```bash
cd ~/MyJuliaPackage
TESTPICKER_MCP_TRANSPORT=http julia --project -e 'using TestPickerMCPServer; start_server()'
```

**Terminal 2 - Use Claude Code:**
```bash
# Server runs at http://127.0.0.1:3000
claude
```

## MCP Configuration File

Add to your Claude Code MCP settings:

**Location:** `~/.claude/mcp_settings.json`

```json
{
  "mcpServers": {
    "testpicker": {
      "command": "julia",
      "args": [
        "--project",
        "-e",
        "using TestPickerMCPServer; start_server()"
      ],
      "cwd": "/path/to/your/julia/package"
    }
  }
}
```

**Important:** Set `cwd` to your package directory so the server auto-detects it.

## Using the Tools

Once the server is running, you can ask Claude Code to use the testing tools:

### Example Prompts

**Discover tests:**
```
Can you list all the test files in this package?
```

**Run specific tests:**
```
Run the tests in test_feature.jl
```

**Check test results:**
```
Show me any test failures from the last run
```

**Find specific testsets:**
```
List all @testset blocks in files matching "auth"
```

**Run and debug:**
```
Run the authentication tests and show me any failures
```

## Per-Package Configuration

For multiple Julia packages, create separate server configs:

```json
{
  "mcpServers": {
    "testpicker-package1": {
      "command": "julia",
      "args": ["--project", "-e", "using TestPickerMCPServer; start_server()"],
      "cwd": "/home/user/Package1"
    },
    "testpicker-package2": {
      "command": "julia",
      "args": ["--project", "-e", "using TestPickerMCPServer; start_server()"],
      "cwd": "/home/user/Package2"
    }
  }
}
```

## Persistent Configuration with Preferences

Instead of environment variables, use Preferences.jl:

```bash
cd /path/to/your/package
julia --project -e '
using Preferences, TestPickerMCPServer
set_preferences!(TestPickerMCPServer, "transport" => "stdio")
'
```

Then your MCP config stays simple:
```json
{
  "mcpServers": {
    "testpicker": {
      "command": "julia",
      "args": ["--project", "-e", "using TestPickerMCPServer; start_server()"],
      "cwd": "/path/to/package"
    }
  }
}
```

## Workflow Example

**1. Start Claude Code in your package:**
```bash
cd ~/MyJuliaPackage
claude
```

**2. Launch the MCP server (if not auto-started):**
```
Please start the TestPicker MCP server
```

**3. Explore tests:**
```
What test files are available?
```

**4. Run specific tests:**
```
Run the tests in test_core.jl and show me any failures
```

**5. Debug failures:**
```
Show me the detailed error for the first test failure
```

## Advanced: Background Server

Run the server in the background:

```bash
# Start server in background
julia --project -e 'using TestPickerMCPServer; start_server()' &

# Use Claude Code
claude

# When done, kill the background server
pkill -f TestPickerMCPServer
```

## Troubleshooting

### Server Not Found

**Symptom:** Claude Code doesn't see TestPicker tools.

**Solution:**
1. Verify server is running: `ps aux | grep julia`
2. Check MCP config exists: `cat ~/.claude/mcp_settings.json`
3. Restart Claude Code session

### Wrong Package Detected

**Symptom:** Server detects wrong package.

**Solution:** Ensure `cwd` is set in MCP config:
```json
{
  "cwd": "/absolute/path/to/correct/package"
}
```

### Server Crashes

**Check logs:**
```bash
# Server should show errors on stderr
julia --project -e 'using TestPickerMCPServer; start_server()' 2>&1 | tee server.log
```

**Common issues:**
1. Not in a package directory → Set `cwd` in config
2. Missing dependencies → Run `Pkg.instantiate()`
3. Syntax errors in tests → Check test files independently

## Best Practices

1. **Set `cwd` in config** - Don't rely on current directory
2. **Use Preferences.jl** - Persistent config over env vars
3. **One server per package** - Don't share across packages
4. **Keep server running** - Faster responses in HTTP mode
5. **Check server status** - Use `ps` to verify it's running

## Example Session

```bash
# Terminal 1 - Start server
cd ~/MyAwesomePackage
julia --project -e 'using TestPickerMCPServer; start_server()'
# Server starts and waits for requests...

# Terminal 2 - Use Claude Code
cd ~/MyAwesomePackage
claude

# In Claude Code:
> Can you list all test files?
# Claude uses list_test_files tool
# Returns: {"files": ["test_core.jl", "test_utils.jl"], ...}

> Run test_core.jl
# Claude uses run_test_files with query="core"
# Executes tests...

> Show any failures
# Claude uses get_test_results
# Returns detailed failure info
```

## Integration with Development Workflow

### TDD Workflow

```bash
# 1. Write failing test
> Add a testset for the new authentication feature

# 2. Run it to verify it fails
> Run the authentication testset

# 3. Implement feature
> [You write code]

# 4. Re-run test
> Run the authentication testset again

# 5. Verify it passes
> Show test results
```

### Debugging Workflow

```bash
# 1. Run all tests
> Run all tests in the package

# 2. Check failures
> Show me all test failures with details

# 3. Focus on specific failure
> Run only the tests in test_feature.jl

# 4. Iterate until fixed
> Show test results
```

## Tips

1. **Keep server terminal visible** - See real-time test output
2. **Use fuzzy queries** - "auth" matches "test_authentication.jl"
3. **Ask for results** - Claude won't show them automatically
4. **Chain commands** - "Run tests and show failures"
5. **Be specific** - "Run testset 'Edge Cases' in test_feature.jl"
