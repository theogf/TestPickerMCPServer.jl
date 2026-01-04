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
```bash
# Terminal 1: Start server in your package
cd your-julia-package
julia --project -e 'using TestPickerMCPServer; start_server()'

# Terminal 2: Launch Claude Code
claude
```

Then ask Claude Code:
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

## Links

- [TestPicker.jl](https://github.com/JuliaTesting/TestPicker.jl) - Fuzzy test picker for Julia
- [ModelContextProtocol.jl](https://github.com/JuliaSMLM/ModelContextProtocol.jl) - Julia MCP implementation
- [Model Context Protocol](https://modelcontextprotocol.io/) - Protocol specification

