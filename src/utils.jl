"""
    detect_package() -> PackageSpec

Detect the current Julia package using TestPicker's current_pkg().
Throws an informative error if not in a package environment.
"""
function detect_package()
    try
        return TestPicker.current_pkg()
    catch e
        if e isa TestPicker.TestEnvError
            error("""
            Failed to detect current package. Please ensure you:
            1. Are running the MCP server from within a Julia package directory
            2. Have a valid Project.toml in the current directory
            3. Have activated the package environment

            Error details: $(e.msg)
            """)
        else
            rethrow()
        end
    end
end

"""
    activate_package(pkg_dir::String)

Activate the Julia package environment at the specified directory.

# Arguments
- `pkg_dir::String`: Path to the package directory to activate
"""
function activate_package(pkg_dir::String)
    @info "Activating package environment at: $pkg_dir"
    Pkg.activate(pkg_dir)
end

"""
    to_json(data) -> TextContent

Convert data to JSON and wrap in TextContent. DRY helper for all handlers.
"""
to_json(data) = TextContent(; text = JSON.json(data))

"""
    filter_files(files::Vector{String}, query::String) -> Vector{String}

Filter files by query string. DRY helper used by multiple handlers.
"""
function filter_files(files::Vector{String}, query::String)
    isempty(query) && return files
    filter(f -> occursin(lowercase(query), lowercase(f)), files)
end

"""
    parse_results_file(pkg::PackageSpec) -> Dict

Read and parse the TestPicker results file into structured format.
Returns dict with failures, errors, and counts.
"""
function parse_results_file(pkg::PackageSpec)
    path = TestPicker.pkg_results_path(pkg)

    # Return empty results if file doesn't exist
    if !isfile(path)
        return Dict(
            "failures" => [],
            "errors" => [],
            "count" => Dict("failures" => 0, "errors" => 0, "total" => 0),
        )
    end

    content = read(path, String)
    entries = split(content, '\0')

    failures = []
    errors = []

    for entry in entries
        isempty(strip(entry)) && continue

        parts = split(entry, TestPicker.separator())
        length(parts) < 4 && continue

        test_expr, source, preview, context = parts

        result = Dict(
            "test" => test_expr,
            "file" => source,
            "error" => preview,
            "context" => context,
        )

        # Heuristic: errors typically have stack traces with [1], [2], etc.
        # Failures are assertion failures without stack traces
        if contains(preview, r"\[\d+\]")
            push!(errors, result)
        else
            push!(failures, result)
        end
    end

    return Dict(
        "failures" => failures,
        "errors" => errors,
        "count" => Dict(
            "failures" => length(failures),
            "errors" => length(errors),
            "total" => length(failures) + length(errors),
        ),
    )
end

"""
    with_error_handling(f::Function, operation::String) -> Content

DRY wrapper for tool handlers. Catches exceptions and returns proper MCP responses.
"""
function with_error_handling(f::Function, operation::String)
    try
        return f()
    catch e
        msg = "Error in $operation: $e"
        @error msg exception = (e, catch_backtrace())
        return TextContent(; text = msg)
    end
end
