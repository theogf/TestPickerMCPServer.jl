# Claude Code Integration

Complete guide to using TestPickerMCPServer with Claude Code CLI.

## Quick Start

**1. Navigate to your Julia package:**
```bash
cd /path/to/your/julia/package
```

**2. Start the server:**
```bash
julia --project=@mcp -e 'using TestPickerMCPServer; start_server()'
```

**3. In another terminal, use Claude Code:**
```bash
claude
```

The server will be available as MCP tools in your Claude Code session.

## Configuration

### Recommended: @mcp Environment

Install TestPickerMCPServer in the `@mcp` named environment (Julia's standard for MCP tools):

```bash
# 1. Install in @mcp environment
julia --project=@mcp -e 'using Pkg; Pkg.add("TestPickerMCPServer")'

# 2. Add to Claude Code MCP config
cd /path/to/your/julia/package
claude mcp add --transport stdio testpicker --scope project -- \
  julia --startup-file=no --project=@mcp \
  -e "using TestPickerMCPServer; TestPickerMCPServer.start_server()"
```

This approach:
- Uses Julia's standard `@mcp` environment for MCP servers
- Keeps TestPickerMCPServer separate from your project dependencies
- Works across all your Julia packages

### Alternative: Manual Server Start

You can also start the server manually for testing:

```bash
cd ~/MyJuliaPackage
julia --project=@mcp -e 'using TestPickerMCPServer; start_server()'
```

### HTTP Transport

For persistent server across sessions:

```bash
cd ~/MyJuliaPackage
TESTPICKER_MCP_TRANSPORT=http julia --project=@mcp -e 'using TestPickerMCPServer; start_server()'
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
        "--project=@mcp",
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
julia --project=@mcp -e '
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
julia --project=@mcp -e 'using TestPickerMCPServer; start_server()' &

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
julia --project=@mcp -e 'using TestPickerMCPServer; start_server()' 2>&1 | tee server.log
```

**Common issues:**
1. Not in a package directory → Set `cwd` in config
2. Missing dependencies → Run `Pkg.instantiate()`
3. Syntax errors in tests → Check test files independently

## Making Claude Code Prefer TestPicker Tools

By default, Claude Code may choose to run tests using `julia -e 'Pkg.test()'` instead of the testpicker MCP tools. Here's how to ensure it consistently uses the testpicker tools:

### Method 1: CLAUDE.md File (Most Effective)

Create a `.claude/CLAUDE.md` or `.claude/CLAUDE.local.md` file in your project root with explicit instructions:

```markdown
# Test Picking with TestPicker MCP

When running tests in this Julia project, ALWAYS use the testpicker MCP server tools:
- Use `mcp__testpicker__run_testfiles` to run specific test files
- Use `mcp__testpicker__run_test_blocks` to run specific @testset blocks
- Use `mcp__testpicker__list_testfiles` to discover test files
- Use `mcp__testpicker__list_test_blocks` to find @testset blocks
- Use `mcp__testpicker__run_all_tests` to run the entire test suite
- Use `mcp__testpicker__get_test_results` to see detailed failures

Never use `julia --project -e 'Pkg.test()'` directly - prefer the testpicker tools.
```

**Why this works:** Claude Code reads CLAUDE.md files as context and uses them to inform tool selection decisions. This is the most reliable way to guide Claude's behavior.

### Method 2: Auto-Approval in Settings

In `.claude/settings.json`, configure automatic approval for the testpicker server:

```json
{
  "enabledMcpjsonServers": ["testpicker"],
  "enableAllProjectMcpServers": true
}
```

This removes permission prompts and makes MCP tools easier to use.

### Method 3: Create a Skill

Create a `.claude/skills/test.yaml` file that wraps testpicker functionality:

```yaml
name: test
description: Run tests using TestPicker MCP tools
prompt: |
  When the user asks to run tests, use the testpicker MCP server tools:
  - list_testfiles to discover tests
  - run_testfiles to run specific files (accepts fuzzy queries)
  - run_test_blocks to run specific @testset blocks
  - get_test_results to show failures

  Always prefer these MCP tools over running Pkg.test() directly.
```

Then you can simply type `/test` in Claude Code to activate test-picking mode.

### Method 4: Explicit Prompts

When asking Claude to run tests, be explicit about using testpicker:

```
Run the authentication tests using the testpicker tool
```

```
Use testpicker to list all test files
```

### Why Tool Selection Matters

Claude Code doesn't have built-in "tool preferences" settings. Instead, it chooses tools based on:

1. **Semantic understanding** of your request
2. **Tool availability** and context
3. **Instructions in CLAUDE.md** (most influential)
4. **Explicit references** in your prompts

The CLAUDE.md approach is most effective because it provides persistent context that guides all of Claude's decisions in your project.

### Complete Setup Example

```bash
# 1. Install in @mcp environment (one-time)
julia --project=@mcp -e 'using Pkg; Pkg.add("TestPickerMCPServer")'

# 2. In your package, add to MCP config
cd /path/to/your/package
claude mcp add --transport stdio testpicker --scope project -- \
  julia --startup-file=no --project=@mcp \
  -e "using TestPickerMCPServer; TestPickerMCPServer.start_server()"

# 3. Add .claude/CLAUDE.md to prefer testpicker tools (recommended)
mkdir -p .claude
echo "Always use testpicker MCP tools for running tests." > .claude/CLAUDE.md
```

## Best Practices

1. **Set `cwd` in config** - Don't rely on current directory
2. **Use Preferences.jl** - Persistent config over env vars
3. **One server per package** - Don't share across packages
4. **Keep server running** - Faster responses in HTTP mode
5. **Check server status** - Use `ps` to verify it's running
6. **Add CLAUDE.md** - Guide Claude to prefer testpicker tools

## Example Session

```bash
# Terminal 1 - Start server
cd ~/MyAwesomePackage
julia --project=@mcp -e 'using TestPickerMCPServer; start_server()'
# Server starts and waits for requests...

# Terminal 2 - Use Claude Code
cd ~/MyAwesomePackage
claude

# In Claude Code:
> Can you list all test files?
# Claude uses list_testfiles tool
# Returns: {"files": ["test_core.jl", "test_utils.jl"], ...}

> Run test_core.jl
# Claude uses run_testfiles with query="core"
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
