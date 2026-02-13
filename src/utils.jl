"""
    detect_package() -> Union{PackageSpec, Nothing}

Detect the current Julia package using TestPicker's current_pkg().
Returns nothing if not in a valid package environment.
"""
function detect_package()
    try
        return TestPicker.current_pkg()
    catch e
        if e isa TestPicker.TestEnvError
            @warn """
            Failed to detect current package. The server will start without an active package.
            Use the 'activate_package' tool to specify a valid Julia package directory.
            
            Error details: $(e.msg)
            """
            return nothing
        else
            rethrow()
        end
    end
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
    parse_results_file(pkg::Union{PackageSpec,Nothing}) -> Dict

Read and parse the TestPicker results file into structured format.
Returns dict with failures, errors, and counts.
"""
function parse_results_file(pkg::Union{PackageSpec,Nothing})
    # Handle case when no package is activated
    if isnothing(pkg)
        return Dict(
            "failures" => [],
            "errors" => [],
            "count" => Dict("failures" => 0, "errors" => 0, "total" => 0),
        )
    end

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
    has_test_failures(results) -> Bool

Check if any test result indicates a failure.
Helper function used by format_file_results and format_block_results.
"""
function has_test_failures(results)
    any(results) do r
        (r isa TestPicker.EvalResult) && !r.success
    end
end

"""
    format_file_results(results) -> Dict

Format test file execution results into a consistent structure.
Handles both successful EvalResult objects and error cases.
Returns empty structure if results is nothing.
"""
function format_file_results(results)
    # Handle case where no results (returns nothing)
    isnothing(results) && return Dict("status" => "completed", "files_run" => [], "count" => 0)

    # Extract file information from EvalResults
    files_run = map(results) do r
        # Handle different result types (EvalResult, EmptyFile, MissingFileException)
        if r isa TestPicker.EvalResult
            Dict("filename" => r.info.filename, "success" => r.success)
        else
            # For error cases (EmptyFile, MissingFileException)
            Dict("error" => string(r))
        end
    end

    # Determine overall status based on individual test results
    status = has_test_failures(results) ? "failed" : "completed"

    return Dict(
        "status" => status,
        "files_run" => files_run,
        "count" => length(files_run),
    )
end

"""
    format_block_results(results) -> Dict

Format test block execution results into a consistent structure.
Handles both successful EvalResult objects and error cases.
Returns empty structure if results is nothing.
"""
function format_block_results(results)
    # Handle case where no results (returns nothing)
    isnothing(results) && return Dict("status" => "completed", "blocks_run" => [], "count" => 0)

    # Extract block information from EvalResults
    blocks_run = map(results) do r
        # Handle different result types (EvalResult vs error cases)
        if r isa TestPicker.EvalResult
            Dict(
                "label" => r.info.label,
                "filename" => r.info.filename,
                "line" => r.info.line,
                "success" => r.success,
            )
        else
            # For error cases
            Dict("error" => string(r))
        end
    end

    # Determine overall status based on individual test results
    status = has_test_failures(results) ? "failed" : "completed"

    return Dict(
        "status" => status,
        "blocks_run" => blocks_run,
        "count" => length(blocks_run),
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
        error_msg = string(e)
        @error "Error in $operation" exception = (e, catch_backtrace())
        return to_json(Dict("error" => error_msg, "operation" => operation))
    end
end
