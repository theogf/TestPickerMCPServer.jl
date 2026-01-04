"""
Tool: list_test_files

List all test files in the current Julia package.
"""
const TOOL_LIST_FILES = MCPTool(;
    name = "list_test_files",
    description = "List all test files in the current Julia package. Returns test directory path, list of test files (relative paths), and count. Optionally filter files with a fuzzy query string.",
    parameters = [
        ToolParameter(;
            name = "query",
            type = "string",
            description = "Optional fuzzy query string to filter test files (e.g., 'feature' matches 'test_feature.jl')",
            required = false,
            default = "",
        ),
    ],
    handler = handle_list_test_files,
)

"""
Tool: list_test_blocks

List all test blocks/testsets in test files.
"""
const TOOL_LIST_BLOCKS = MCPTool(;
    name = "list_test_blocks",
    description = "List all @testset blocks found in test files. Returns label, file path, line start, and line end for each test block. Useful for discovering available testsets before running specific ones.",
    parameters = [
        ToolParameter(;
            name = "file_query",
            type = "string",
            description = "Optional fuzzy query to filter which test files to scan (empty = scan all files)",
            required = false,
            default = "",
        ),
    ],
    handler = handle_list_test_blocks,
)

"""
Tool: run_all_tests

Run the entire test suite.
"""
const TOOL_RUN_ALL = MCPTool(;
    name = "run_all_tests",
    description = "Run all tests in the package test suite. Returns status, number of files run, summary of results, and whether there are failures. Use get_test_results to see detailed failure information.",
    parameters = [],
    handler = handle_run_all_tests,
)

"""
Tool: run_test_files

Run specific test file(s) by query.
"""
const TOOL_RUN_FILES = MCPTool(;
    name = "run_test_files",
    description = "Run specific test file(s) matched by a fuzzy query string. The query is matched against test file paths (e.g., 'feature' runs test_feature.jl). Returns list of files run and execution status.",
    parameters = [
        ToolParameter(;
            name = "query",
            type = "string",
            description = "Fuzzy query string to match test file names (required, e.g., 'utils' matches test_utils.jl)",
            required = true,
        ),
    ],
    handler = handle_run_test_files,
)

"""
Tool: run_test_blocks

Run specific test block(s)/testset(s) by query.
"""
const TOOL_RUN_BLOCKS = MCPTool(;
    name = "run_test_blocks",
    description = "Run specific @testset blocks matched by fuzzy queries. First filters test files (optional), then filters testsets within those files (required). Useful for running a specific testset without running the entire file.",
    parameters = [
        ToolParameter(;
            name = "file_query",
            type = "string",
            description = "Optional fuzzy query to filter test files first (empty = search all files)",
            required = false,
            default = "",
        ),
        ToolParameter(
            name = "testset_query",
            type = "string",
            description = "Fuzzy query to match testset names (required, e.g., 'edge cases' matches '@testset \"Edge Cases\"')",
            required = true,
        ),
    ],
    handler = handle_run_test_blocks,
)

"""
Tool: get_test_results

Get detailed test results from the last run.
"""
const TOOL_GET_RESULTS = MCPTool(;
    name = "get_test_results",
    description = "Retrieve detailed failures and errors from the most recent test run. Returns arrays of failures (assertion failures) and errors (exceptions), each with test expression, file location, error message, and context. Returns empty arrays if all tests passed.",
    parameters = [],
    handler = handle_get_test_results,
)

"""
All tools exported by this module.
"""
const ALL_TOOLS = [
    TOOL_LIST_FILES,
    TOOL_LIST_BLOCKS,
    TOOL_RUN_ALL,
    TOOL_RUN_FILES,
    TOOL_RUN_BLOCKS,
    TOOL_GET_RESULTS,
]
