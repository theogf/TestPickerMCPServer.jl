# TestPickerMCPServer

[![Stable Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://theogf.github.io/TestPickerMCPServer.jl/stable)
[![Development documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://theogf.github.io/TestPickerMCPServer.jl/dev)
[![Test workflow status](https://github.com/theogf/TestPickerMCPServer.jl/actions/workflows/Test.yml/badge.svg?branch=main)](https://github.com/theogf/TestPickerMCPServer.jl/actions/workflows/Test.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/theogf/TestPickerMCPServer.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/theogf/TestPickerMCPServer.jl)

> MCP server for [TestPicker.jl](https://github.com/JuliaTesting/TestPicker.jl) - Let LLMs discover, run, and inspect your Julia tests.

## Quick Start

**Installation:**
```julia
using Pkg
Pkg.add("TestPickerMCPServer")
```

**Use with Claude Code:**

Add the MCP server using the CLI:

**Stdio transport (default):**
```bash
claude mcp add --transport stdio testpicker --scope project -- \
  julia --startup-file=no --project -e "using TestPickerMCPServer; TestPickerMCPServer.start_server()"
```

**HTTP transport:**
```bash
# First configure the server for HTTP (see Configuration section below)
claude mcp add --transport http testpicker http://localhost:3000/mcp --scope project
```

Or manually add to `.mcp.json` in your project (see [claude_code_config.json](claude_code_config.json) for reference).

Then in your Julia package directory:
```bash
claude
```

Ask Claude Code:
- "List all test files"
- "Run the authentication tests"
- "Show me test failures"

## What It Does

Exposes 6 MCP tools for testing Julia packages:
- `list_test_files` - Discover test files
- `list_test_blocks` - Find @testset blocks
- `run_all_tests` - Run entire suite
- `run_test_files` - Run specific files
- `run_test_blocks` - Run specific testsets
- `get_test_results` - Get failures/errors

## Configuration

**Preferences (persistent for the repository):**
```julia
using Preferences
set_preferences!(TestPickerMCPServer, "transport" => "http", "port" => 3000)
```

**Environment variables (temporary):**
```bash
TESTPICKER_MCP_TRANSPORT=http TESTPICKER_MCP_PORT=3000 julia -e '...'
```

See the [full documentation](https://theogf.github.io/TestPickerMCPServer.jl/dev) for details.

## Non-Invasive Installation (Recommended)

For a cleaner setup that doesn't pollute your project environments, create a dedicated tools environment:

```bash
# 1. Create and set up tools environment
mkdir -p ~/.julia/environments/mcp-tools
julia --project=~/.julia/environments/mcp-tools -e 'using Pkg; Pkg.add("TestPickerMCPServer")'

# 2. Add to Claude Code (will pass package directory as argument)
claude mcp add --transport stdio testpicker --scope project -- \
  julia --startup-file=no --project=~/.julia/environments/mcp-tools \
  -e "using TestPickerMCPServer; TestPickerMCPServer.start_server(\"$PWD\")"
```

This keeps TestPickerMCPServer in a separate environment while still testing your project.

## Making Claude Code Prefer TestPicker Tools

To ensure Claude Code consistently uses the testpicker MCP tools instead of running `julia -e 'Pkg.test()'` directly:

**Create `.claude/CLAUDE.md` in your project:**
```markdown
# Test Picking with TestPicker MCP

When running tests in this Julia project, ALWAYS use the testpicker MCP server tools:
- Use `mcp__testpicker__run_test_files` to run specific test files
- Use `mcp__testpicker__run_test_blocks` to run specific @testset blocks
- Use `mcp__testpicker__list_test_files` to discover test files
- Use `mcp__testpicker__get_test_results` to see detailed failures

Never use `julia --project -e 'Pkg.test()'` directly - prefer the testpicker tools.
```

**Enable auto-approval in `.claude/settings.json`:**
```json
{
  "enabledMcpjsonServers": ["testpicker"],
  "enableAllProjectMcpServers": true
}
```

See the [Claude Code integration docs](https://theogf.github.io/TestPickerMCPServer.jl/dev/claude-code/) for more details.

## Links

- [TestPicker.jl](https://github.com/JuliaTesting/TestPicker.jl) - Fuzzy test picker for Julia
- [ModelContextProtocol.jl](https://github.com/JuliaSMLM/ModelContextProtocol.jl) - Julia MCP implementation
- [Model Context Protocol](https://modelcontextprotocol.io/) - Protocol specification

