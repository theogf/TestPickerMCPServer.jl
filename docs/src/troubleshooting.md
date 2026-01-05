# Troubleshooting

Common issues and solutions when using TestPickerMCPServer.

## Package Environment Error

**Error:**
```
Failed to detect current package. Please ensure you:
1. Are running the MCP server from within a Julia package directory
2. Have a valid Project.toml in the current directory
3. Have activated the package environment
```

**Cause:** Server started outside a Julia package directory.

**Solution:**

Navigate to your package directory before starting:
```bash
cd /path/to/your/package
julia --project=@mcp -e 'using TestPickerMCPServer; start_server()'
```

Verify you're in a package:
```bash
# Should show Project.toml
ls Project.toml

# Should have a test directory
ls test/
```

---

## No Matching Tests Found

**Error:**
```json
"No matches for 'myquery'"
```

**Cause:** Query doesn't match any test files or blocks.

**Solutions:**

1. **List available files first:**
```json
list_testfiles({})
```

2. **List available testsets:**
```json
list_test_blocks({})
```

3. **Use simpler queries:**
```json
// Instead of
{"query": "test_my_complex_feature"}

// Try
{"query": "feature"}
```

4. **Check for typos** - queries are case-insensitive but must match substrings

---

## HTTP Transport Not Working on Windows

**Error:** Server starts but MCP Inspector can't connect.

**Cause:** Windows IPv6 issues with `localhost`.

**Solution:**

Use `127.0.0.1` explicitly:

```julia
using Preferences
set_preferences!(TestPickerMCPServer,
    "transport" => "http",
    "host" => "127.0.0.1",
    "port" => 3000
)
```

Or via environment:
```powershell
set TESTPICKER_MCP_HOST=127.0.0.1
set TESTPICKER_MCP_TRANSPORT=http
julia --project=@mcp -e "using TestPickerMCPServer; start_server()"
```

---

## Empty Test Results

**Response:**
```json
{
  "failures": [],
  "errors": [],
  "count": {"failures": 0, "errors": 0, "total": 0}
}
```

**Cause:** All tests passed!

**Verification:**

This is expected when tests succeed. Verify with run responses:
```json
{
  "status": "completed",
  "files_run": 3,
  "failures": 0  // <-- 0 means all passed
}
```

---

## Failed to Parse Test Blocks

**Warning:**
```
Failed to parse test_file.jl
```

**Cause:** Syntax error or unsupported test structure in file.

**Solutions:**

1. **Check file syntax:**
```bash
julia --project=@mcp -e 'include("test/test_file.jl")'
```

2. **Verify @testset structure:**
```julia
# Good
@testset "My Tests" begin
    @test 1 + 1 == 2
end

# May cause issues
@testset begin  # Missing label
    @test 1 + 1 == 2
end
```

3. **File continues to work** - only that file's testsets won't be listed

---

## Connection Refused (HTTP Mode)

**Error:** MCP Inspector shows "Connection refused"

**Checks:**

1. **Verify server is running:**
```bash
# Should show server listening
netstat -an | grep 3000
```

2. **Check firewall:**
```bash
# Allow Julia through firewall
sudo ufw allow 3000/tcp  # Linux
```

3. **Verify configuration:**
```julia
using Preferences
@load_preference(TestPickerMCPServer, "transport")  # Should be "http"
@load_preference(TestPickerMCPServer, "port")       # Should match
```

---

## Server Hangs or Freezes

**Symptom:** Server starts but doesn't respond to requests.

**Potential Causes:**

1. **Long-running tests** - Tests are executing, be patient
2. **Deadlock in test code** - Check your test suite independently
3. **Wrong transport mode** - Verify transport configuration

**Solutions:**

1. **Check if tests run normally:**
```bash
julia --project=@mcp -e 'using Pkg; Pkg.test()'
```

2. **Enable logging:**
```bash
JULIA_DEBUG=TestPickerMCPServer julia --project=@mcp -e '...'
```

3. **Try HTTP mode for debugging:**
```julia
set_preferences!(TestPickerMCPServer, "transport" => "http")
# HTTP transport is easier to debug with curl/browser
```

---

## Preferences Not Persisting

**Symptom:** Settings reset every session.

**Cause:** Writing preferences to wrong location or missing LocalPreferences.toml.

**Solution:**

1. **Verify LocalPreferences.toml exists:**
```bash
ls LocalPreferences.toml
```

2. **Check you're in package root:**
```bash
pwd  # Should be your package directory
ls Project.toml  # Should exist
```

3. **Set preferences correctly:**
```julia
# Must use the module, not a string
using TestPickerMCPServer
set_preferences!(TestPickerMCPServer, "transport" => "http")
# NOT: set_preferences!("TestPickerMCPServer", ...)
```

---

## Getting Help

If your issue isn't listed:

1. Check [GitHub Issues](https://github.com/theogf/TestPickerMCPServer.jl/issues)
2. Enable debug logging: `JULIA_DEBUG=TestPickerMCPServer`
3. Test TestPicker.jl directly to isolate the issue
4. Open a new issue with:
   - Julia version (`versioninfo()`)
   - Server configuration
   - Minimal reproducible example
