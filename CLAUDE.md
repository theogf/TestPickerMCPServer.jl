# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TestPickerMCPServer is an MCP (Model Context Protocol) server that exposes TestPicker.jl functionality to LLMs. It allows Claude Code and other LLM tools to discover, run, and inspect Julia tests programmatically through a standardized protocol.

**Key Dependencies:**
- `TestPicker.jl` - Core test discovery and execution engine
- `ModelContextProtocol.jl` - Julia MCP implementation (v0.4+)

## Development Commands

### Running Tests

When running tests in this Julia project, ALWAYS use the testpicker MCP server tools:
- Use `mcp__testpicker__run_testfiles` to run specific test files
- Use `mcp__testpicker__run_testblocks` to run specific @testset blocks
- Use `mcp__testpicker__list_testfiles` to discover test files
- Use `mcp__testpicker__get_testresults` to see detailed failures

**Test Organization:**
- `test_utils.jl` - Basic utility function tests
- `test_utils_extended.jl` - Extended utility tests (error handling, edge cases)
- `test_config.jl` - Configuration system tests (ENV vars, defaults, precedence)
- `test_tools.jl` - Tool definition validation
- `test_handlers.jl` - Handler function unit tests
- `test_server.jl` - Server module tests
- `test_integration.jl` - End-to-end integration tests

Never use `julia --project=. -e 'Pkg.test()'` directly - prefer the testpicker tools.

### Documentation
```bash
# Build docs
julia --project=docs docs/make.jl

# View locally at docs/build/
```

## Architecture

### Three-Layer Architecture

1. **MCP Tools Layer** (`src/tools.jl`)
   - Defines 8 MCP tools as `MCPTool` constants
   - Tool naming convention: `list_testfiles`, `run_testfiles` (no underscores in "testfiles")
   - Each tool links to a handler function

2. **Handler Layer** (`src/handlers.jl`)
   - Handler functions follow naming: `handle_<toolname>(params::Dict{String,Any})`
   - All handlers wrapped in `with_error_handling()` for consistent error responses
   - Handlers delegate to TestPicker.jl API and utility functions
   - Return `Content` objects (typically `TextContent` with JSON)

3. **Server Core** (`src/TestPickerMCPServer.jl`)
   - `start_server(pkg_dir::String=pwd())` - Main entry point, blocks until shutdown
   - `SERVER_PKG` global ref caches the active package
   - Configuration precedence: Preferences.jl > ENV vars > defaults
   - Supports stdio (default) and HTTP transports

### Key Utilities (`src/utils.jl`)

- `detect_package()` - Detects current Julia package using TestPicker
- `activate_package(pkg_dir)` - Activates a different package environment using `Pkg.activate()`
- `to_json(data)` - Converts data to JSON-wrapped TextContent
- `filter_files(files, query)` - Fuzzy file filtering
- `parse_results_file(pkg)` - Parses TestPicker results into structured failures/errors
- `with_error_handling(f, operation)` - DRY error wrapper for handlers

### State Management

- `SERVER_PKG::Ref{Union{Nothing,PackageSpec}}` - Single source of truth for active package
- Updated by `start_server()` initially and by `activate_package` tool
- All handlers read from `SERVER_PKG[]` to operate on correct package

### Configuration System

Config precedence (highest to lowest):
1. Preferences.jl (persistent, via `set_preferences!`)
2. Environment variables (`TESTPICKER_MCP_<KEY>`)
3. Default values

Available settings:
- `transport`: "stdio" (default) or "http"
- `host`: HTTP host (default: "127.0.0.1")
- `port`: HTTP port (default: 3000)

## Naming Conventions

**CRITICAL:** All tool names use compound words without underscores:
- ✅ `run_testfiles`, `run_testblocks`, `get_testresults`
- ❌ `run_test_files`, `run_test_blocks`, `get_test_results`

**MCP Tool Names:**
- `list_testfiles` - List all test files with optional fuzzy query
- `list_testblocks` - List @testset blocks within files
- `run_all_tests` - Run entire test suite
- `run_testfiles` - Run specific files by fuzzy query
- `run_testblocks` - Run specific testsets by fuzzy query
- `get_testresults` - Retrieve failures/errors from last run
- `activate_package` - Switch active package directory

## Working with MCP Tools

### Adding a New Tool

1. Define tool constant in `src/tools.jl`:
```julia
const TOOL_NEW = MCPTool(;
    name = "tool_name",
    description = "What it does",
    parameters = [...],
    handler = handle_tool_name,
)
```

2. Add handler in `src/handlers.jl`:
```julia
function handle_tool_name(params::Dict{String,Any})
    with_error_handling("tool_name") do
        # Implementation
        to_json(result_dict)
    end
end
```

3. Add to `ALL_TOOLS` array in `src/tools.jl`

### Handler Pattern

All handlers should:
- Use `with_error_handling()` wrapper
- Access active package via `SERVER_PKG[]`
- Return `Content` objects (use `to_json()` helper)
- Validate required parameters early

## Project Standards

### Julia Environment

- Install in `@mcp` named environment (Julia standard for MCP servers)
- Always use `--project=@mcp` in CLI commands and documentation
- Server can work across packages via `activate_package` tool

### Testing This Server

When testing changes to TestPickerMCPServer itself, the server needs to be running. Two approaches:

1. **Self-hosted**: Start server from dev environment, use its own tools
2. **External package**: Test with a different Julia package

### Documentation

- Full docs in `docs/src/`
- Key files: `claude-code.md` (Claude Code integration), `tools.md` (tool reference)
- Use `--project=@mcp` consistently in all examples

## Common Patterns

### Accessing TestPicker API

```julia
# Get files
test_dir, files = TestPicker.get_testfiles(SERVER_PKG[])

# Run files
TestPicker.run_testfiles(file_paths, SERVER_PKG[])

# Get test blocks
TestPicker.get_testblocks(INTERFACES, file_path)

# Fuzzy search and run
TestPicker.fzf_testfile(query; interactive = false)
TestPicker.fzf_testblock(INTERFACES, file_query, testset_query; interactive = false)
```

### Configuration Reading

```julia
value = get_config("key", default_value)
# Checks: Preferences.jl → ENV["TESTPICKER_MCP_KEY"] → default
```

### Package Environment Switching

```julia
# In handlers
activate_package(new_dir)  # Activates environment
SERVER_PKG[] = detect_package()  # Re-detects package
```
