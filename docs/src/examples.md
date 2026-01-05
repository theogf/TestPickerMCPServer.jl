# Usage Examples

Real-world workflows and examples using TestPickerMCPServer.

## Example 1: Discover and Run Tests

Workflow for exploring a new package's tests:

```json
// Step 1: List all test files
list_testfiles({})
// Returns: {"files": ["runtests.jl", "test_feature.jl", "test_utils.jl"], ...}

// Step 2: List testsets in a specific file
list_testblocks({"file_query": "feature"})
// Returns: {"test_blocks": [{"label": "Edge Cases", ...}, {"label": "Happy Path", ...}]}

// Step 3: Run a specific testset
run_testblocks({"file_query": "feature", "testset_query": "edge"})
// Returns: {"status": "completed"}

// Step 4: Check if any tests failed
get_testresults({})
// Returns: failures and errors, or empty arrays if all passed
```

## Example 2: Debug Failing Tests

When your test suite has failures:

```json
// Step 1: Run all tests to find failures
run_all_tests({})
// Returns: {"status": "completed", "failures": 3}

// Step 2: Get detailed error information
get_testresults({})
// Returns: {
//   "failures": [
//     {"test": "@test foo() == 42", "file": "test_feature.jl:15", ...}
//   ]
// }

// Step 3: Re-run just the failing file
run_testfiles({"query": "feature"})

// Step 4: Check if fixed
get_testresults({})
```

## Example 3: Regression Testing

After making changes, verify specific functionality:

```json
// List testsets related to the changed feature
list_testblocks({"file_query": ""})
// Scan for relevant testsets

// Run only the relevant testsets
run_testblocks({"testset_query": "authentication"})

// Verify no regressions
get_testresults({})
```

## Example 4: CI/CD Integration

Use TestPickerMCPServer in automated workflows:

```julia
using TestPickerMCPServer
using JSON3

# Start in HTTP mode for external access
ENV["TESTPICKER_MCP_TRANSPORT"] = "http"
start_server()

# Or use directly (pseudo-code):
result = run_testfiles(Dict("query" => "integration"))
results = get_testresults(Dict())

if results["count"]["total"] > 0
    # Tests failed
    exit(1)
end
```

## Example 5: Selective Test Execution

Run only tests matching specific patterns:

```json
// Run all "performance" testsets
run_testblocks({"testset_query": "performance"})

// Run all tests in files matching "integration"
run_testfiles({"query": "integration"})

// Run specific edge case tests
run_testblocks({
  "file_query": "feature",
  "testset_query": "edge"
})
```

## Example 6: Test Suite Analysis

Analyze your test suite structure:

```json
// Get overview of all test files
list_testfiles({})
// Count how many test files you have

// Get all testsets
list_testblocks({})
// Analyze:
// - How many testsets?
// - What areas are tested?
// - Are tests well-organized?

// Example response analysis:
// {
//   "test_blocks": [
//     {"label": "Basic Operations", "file": "test_core.jl", ...},
//     {"label": "Edge Cases", "file": "test_core.jl", ...},
//     {"label": "Performance", "file": "test_perf.jl", ...}
//   ],
//   "count": 3
// }
// Shows: 3 testsets across 2 files
```

## Example 7: Interactive Testing Session

Typical LLM-assisted testing session:

**User:** "Can you check if the authentication tests are passing?"

**LLM uses tools:**
```json
// 1. Find auth-related tests
list_testblocks({"file_query": ""})
// Finds: "Authentication Tests" in test_auth.jl

// 2. Run those tests
run_testblocks({"testset_query": "authentication"})

// 3. Check results
get_testresults({})
```

**LLM reports:** "The authentication tests are failing with 2 errors..."

## Example 8: Test Coverage Workflow

Understanding what's tested:

```json
// 1. List all test files
list_testfiles({})

// 2. For each file, list its testsets
list_testblocks({"file_query": "auth"})
list_testblocks({"file_query": "utils"})
list_testblocks({"file_query": "api"})

// 3. Identify gaps
// - Are all modules tested?
// - Are there missing edge cases?
```

## Example 9: Fuzzy Matching

The query system uses fuzzy matching:

```json
// These all match "test_feature_extraction.jl":
{"query": "feature"}
{"query": "extraction"}
{"query": "test_feat"}
{"query": "extract"}

// These all match "@testset \"Feature Extraction Tests\"":
{"testset_query": "feature"}
{"testset_query": "extraction"}
{"testset_query": "feat extract"}
```

## Example 10: Batch Testing

Run multiple test files:

```json
// Run all files matching "integration"
run_testfiles({"query": "integration"})
// Might run: test_integration_api.jl, test_integration_db.jl, etc.

// Run all tests (no filter)
run_all_tests({})
```

## Common Patterns

### Pattern: Test-Driven Development

```json
// 1. Write test
// 2. Run specific testset
run_testblocks({"testset_query": "new feature"})
// 3. See it fail
get_testresults({})
// 4. Implement feature
// 5. Re-run
run_testblocks({"testset_query": "new feature"})
// 6. Verify pass
```

### Pattern: Bug Fix Verification

```json
// 1. Reproduce bug with test
run_testblocks({"testset_query": "bug #123"})
// 2. Verify test fails
get_testresults({})
// 3. Fix bug
// 4. Re-run test
run_testblocks({"testset_query": "bug #123"})
// 5. Verify fix
```

### Pattern: Pre-Commit Check

```json
// Run all tests before committing
run_all_tests({})
get_testresults({})
// If results["count"]["total"] == 0, safe to commit
```

## Tips

1. **Use empty queries** to see everything: `{"query": ""}`
2. **Start broad, narrow down:** List all, then filter
3. **Check results after every run:** `get_testresults({})`
4. **Use fuzzy matching:** Type less, match more
5. **Run specific tests:** Faster feedback than full suite
