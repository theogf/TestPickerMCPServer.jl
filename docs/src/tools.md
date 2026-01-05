# MCP Tools Reference

TestPickerMCPServer exposes 7 tools via the Model Context Protocol.

## 1. list_testfiles

List all test files in the current package.

**Parameters:**
- `query` (string, optional): Fuzzy query to filter files

**Returns:**
```json
{
  "test_dir": "/absolute/path/to/test",
  "files": ["runtests.jl", "test_feature.jl"],
  "count": 2
}
```

**Example:**
```json
// List all test files
{"query": ""}

// Filter for files containing "feature"
{"query": "feature"}
```

---

## 2. list_testblocks

List all @testset blocks in test files.

**Parameters:**
- `file_query` (string, optional): Filter which files to scan (empty = all files)

**Returns:**
```json
{
  "testblocks": [
    {
      "label": "Feature Tests",
      "file": "test_feature.jl",
      "line_start": 10,
      "line_end": 25
    }
  ],
  "count": 1
}
```

**Example:**
```json
// List all testsets
{"file_query": ""}

// List testsets only in files matching "utils"
{"file_query": "utils"}
```

---

## 3. run_all_tests

Run the entire test suite.

**Parameters:** None

**Returns:**
```json
{
  "status": "completed",
  "files_run": 5,
  "failures": 0
}
```

**Notes:**
- Runs all tests in the package's `test/` directory
- Use `get_testresults` after to see failures/errors

---

## 4. run_testfiles

Run specific test file(s) matched by query.

**Parameters:**
- `query` (string, required): Fuzzy query to match files

**Returns:**
```json
{
  "status": "completed",
  "files_run": ["test_feature.jl", "test_utils.jl"]
}
```

**Example:**
```json
// Run files matching "feature"
{"query": "feature"}

// Run files matching "test"
{"query": "test"}
```

**Error Response:**
```json
// If no matches found
"No matches for 'nonexistent'"
```

---

## 5. run_testblocks

Run specific @testset blocks by query.

**Parameters:**
- `file_query` (string, optional): Filter files first
- `testset_query` (string, required): Match testset names

**Returns:**
```json
{
  "status": "completed"
}
```

**Example:**
```json
// Run all testsets matching "edge cases"
{
  "file_query": "",
  "testset_query": "edge cases"
}

// Run testsets matching "performance" in files matching "utils"
{
  "file_query": "utils",
  "testset_query": "performance"
}
```

---

## 6. get_testresults

Retrieve detailed failures and errors from the last test run.

**Parameters:** None

**Returns:**
```json
{
  "failures": [
    {
      "test": "@test foo == bar",
      "file": "test_feature.jl:15",
      "error": "Expected: bar\nGot: baz",
      "context": "Feature Tests"
    }
  ],
  "errors": [
    {
      "test": "Exception in test block",
      "file": "test_utils.jl:42",
      "error": "UndefVarError: x not defined\n  [1] ...",
      "context": "test_utils.jl"
    }
  ],
  "count": {
    "failures": 1,
    "errors": 1,
    "total": 2
  }
}
```

**Notes:**
- Returns empty arrays if all tests passed
- **failures**: Test assertion failures (@test failures)
- **errors**: Exceptions during test execution
- Results persist until next test run

## Tool Workflow Examples

### Discover and Run Workflow

```json
// 1. List all test files
list_testfiles({})

// 2. List testsets in specific file
list_testblocks({"file_query": "feature"})

// 3. Run specific testset
run_testblocks({"file_query": "feature", "testset_query": "edge cases"})

// 4. Check results
get_testresults({})
```

### Debug Failing Tests Workflow

```json
// 1. Run all tests
run_all_tests({})

// 2. Get failures
get_testresults({})
// See which file has failures

// 3. Re-run just that file
run_testfiles({"query": "feature"})

// 4. Get updated results
get_testresults({})
```
