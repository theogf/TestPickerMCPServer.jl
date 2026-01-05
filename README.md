# TestPickerMCPServer

[![Stable Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://theogf.github.io/TestPickerMCPServer.jl/stable)
[![Development documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://theogf.github.io/TestPickerMCPServer.jl/dev)
[![Test workflow status](https://github.com/theogf/TestPickerMCPServer.jl/actions/workflows/Test.yml/badge.svg?branch=main)](https://github.com/theogf/TestPickerMCPServer.jl/actions/workflows/Test.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/theogf/TestPickerMCPServer.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/theogf/TestPickerMCPServer.jl)

> MCP server for [TestPicker.jl](https://github.com/JuliaTesting/TestPicker.jl) - Let LLMs discover, run, and inspect your Julia tests.

## Quick Start

**Recommended Installation:**
```julia
using Pkg
Pkg.activate("@mcp") # Separate global environment for MCPs
Pkg.add("TestPickerMCPServer")
```

**Use with Claude Code:**

Add the MCP server using the CLI:

**Stdio transport (default):**
```bash
claude mcp add --transport stdio testpicker --scope project -- \
  julia --startup-file=no --project=@mcp -e "using TestPickerMCPServer; TestPickerMCPServer.start_server()"
```

**HTTP transport:**
```bash
# First configure the server for HTTP (see Configuration section below)
claude mcp add --transport http testpicker http://localhost:3000/mcp --scope project
```

Or manually add to `.mcp.json` (see this minimal [.mcp.json](.mcp.json) for reference).

## What It Does

Exposes 7 MCP tools for testing Julia packages:
- `list_test_files` - Discover test files
- `list_test_blocks` - Find @testset blocks
- `run_all_tests` - Run entire suite
- `run_test_files` - Run specific files
- `run_test_blocks` - Run specific testsets
- `get_test_results` - Get failures/errors
- `activate_package` - Switch to a different package directory (uses the current one by default)

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

## Making Claude Code Prefer TestPicker Tools

To ensure Claude Code consistently uses the testpicker MCP tools instead of running `julia -e 'Pkg.test()'` directly:

**Create/Add to `.claude/CLAUDE.md` in your project:**

```markdown
# Test Picking with TestPicker MCP

When running tests in this Julia project, ALWAYS use the testpicker MCP server tools:
- Use `mcp__testpicker__run_test_files` to run specific test files
- Use `mcp__testpicker__run_test_blocks` to run specific @testset blocks
- Use `mcp__testpicker__list_test_files` to discover test files
- Use `mcp__testpicker__get_test_results` to see detailed failures

Never use `julia --project -e 'Pkg.test()'` directly - prefer the testpicker tools.
```

See the [Claude Code integration docs](https://theogf.github.io/TestPickerMCPServer.jl/dev/claude-code/) for more details.

## Links

- [TestPicker.jl](https://github.com/JuliaTesting/TestPicker.jl) - Fuzzy test picker for Julia
- [ModelContextProtocol.jl](https://github.com/JuliaSMLM/ModelContextProtocol.jl) - Julia MCP implementation
- [Model Context Protocol](https://modelcontextprotocol.io/) - Protocol specification

