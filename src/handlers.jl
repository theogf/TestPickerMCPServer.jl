"""
    handle_list_testfiles(params::Dict{String,Any}) -> Content

List all test files in the current package, optionally filtered by query.
"""
function handle_list_testfiles(params::Dict{String,Any})
    with_error_handling("list_testfiles") do
        isnothing(SERVER_PKG[]) && error(
            "No package activated, make sure to give `start_server` a valid Project path.",
        )
        test_dir, files = TestPicker.get_testfiles(SERVER_PKG[])
        files = filter_files(files, get(params, "query", ""))
        to_json(Dict("test_dir" => test_dir, "files" => files, "count" => length(files)))
    end
end

"""
    handle_list_test_blocks(params::Dict{String,Any}) -> Content

List all test blocks/testsets, optionally filtered by file query.
"""
function handle_list_test_blocks(params::Dict{String,Any})
    with_error_handling("list_test_blocks") do
        isnothing(SERVER_PKG[]) && error(
            "No package activated, make sure to give `start_server` a valid Project path.",
        )
        test_dir, files = TestPicker.get_testfiles(SERVER_PKG[])
        files = filter_files(files, get(params, "file_query", ""))

        blocks = []
        for file in files
            try
                for block in TestPicker.get_testblocks(INTERFACES, joinpath(test_dir, file))
                    info = block.info
                    push!(
                        blocks,
                        Dict(
                            "label" => info.label,
                            "file" => relpath(info.file_name, test_dir),
                            "line_start" => info.line_start,
                            "line_end" => info.line_end,
                        ),
                    )
                end
            catch e
                @warn "Failed to parse $file" exception = e
            end
        end

        to_json(Dict("test_blocks" => blocks, "count" => length(blocks)))
    end
end

"""
    handle_run_all_tests(params::Dict{String,Any}) -> Content

Run the entire test suite for the current package.
If runtests.jl exists, run it. Otherwise run all test files.
"""
function handle_run_all_tests(::Dict{String,Any})
    with_error_handling("run_all_tests") do
        isnothing(SERVER_PKG[]) && error(
            "No package activated, make sure to give `start_server` a valid Project path.",
        )
        test_dir, files = TestPicker.get_testfiles(SERVER_PKG[])

        # Check if runtests.jl exists
        if "runtests.jl" in files
            # Run the standard runtests.jl entry point
            results = TestPicker.fzf_testfile("runtests"; interactive = false)
        else
            # Fall back to running all test files with empty query
            results = TestPicker.fzf_testfile(""; interactive = false)
        end

        # Handle case where no results (returns nothing)
        isnothing(results) &&
            return to_json(Dict("status" => "completed", "files_run" => [], "count" => 0))

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

        to_json(
            Dict(
                "status" => "completed",
                "files_run" => files_run,
                "count" => length(files_run),
            ),
        )
    end
end

"""
    handle_run_testfiles(params::Dict{String,Any}) -> Content

Run specific test file(s) matched by query.
"""
function handle_run_testfiles(params::Dict{String,Any})
    with_error_handling("run_testfiles") do
        query = get(params, "query", "")
        isempty(query) && error("query required")

        isnothing(SERVER_PKG[]) && error(
            "No package activated, make sure to give `start_server` a valid Project path.",
        )

        # Run test files matching query
        results = TestPicker.fzf_testfile(query; interactive = false)

        # Handle case where no results (returns nothing)
        isnothing(results) &&
            return to_json(Dict("status" => "completed", "files_run" => [], "count" => 0))

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

        to_json(
            Dict(
                "status" => "completed",
                "files_run" => files_run,
                "count" => length(files_run),
            ),
        )
    end
end

"""
    handle_run_testblocks(params::Dict{String,Any}) -> Content

Run specific test block(s) matched by queries.
"""
function handle_run_testblocks(params::Dict{String,Any})
    with_error_handling("run_testblocks") do
        testset_query = get(params, "testset_query", "")
        isempty(testset_query) && error("testset_query required")

        isnothing(SERVER_PKG[]) && error(
            "No package activated, make sure to give `start_server` a valid Project path.",
        )

        results = TestPicker.fzf_testblock(
            INTERFACES,
            get(params, "file_query", ""),
            testset_query;
            interactive = false,
        )

        # Handle case where no results (returns nothing)
        isnothing(results) &&
            return to_json(Dict("status" => "completed", "blocks_run" => [], "count" => 0))

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

        to_json(
            Dict(
                "status" => "completed",
                "blocks_run" => blocks_run,
                "count" => length(blocks_run),
            ),
        )
    end
end

"""
    handle_get_testresults(params::Dict{String,Any}) -> Content

Retrieve test failures and errors from the last test run.
"""
function handle_get_testresults(params::Dict{String,Any})
    with_error_handling("get_testresults") do
        to_json(parse_results_file(SERVER_PKG[]))
    end
end

"""
    handle_activate_package(params::Dict{String,Any}) -> Content

Activate a different package directory and update the server's active package.
"""
function handle_activate_package(params::Dict{String,Any})
    with_error_handling("activate_package") do
        pkg_dir = get(params, "pkg_dir", "")
        isempty(pkg_dir) && error("pkg_dir required")

        # Check if directory exists
        !isdir(pkg_dir) && error("Directory does not exist: $pkg_dir")

        # Activate the package environment
        Pkg.activate(pkg_dir)

        # Re-detect and update the cached package
        SERVER_PKG[] = detect_package()

        # Ensure package was detected successfully
        isnothing(SERVER_PKG[]) && error(
            "Failed to detect package after activation. Is this a valid Julia package?",
        )

        to_json(
            Dict(
                "status" => "success",
                "pkg_dir" => pkg_dir,
                "package_name" => SERVER_PKG[].name,
            ),
        )
    end
end
