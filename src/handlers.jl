"""
    handle_list_testfiles(params::Dict{String,Any}) -> Content

List all test files in the current package, optionally filtered by query.
"""
function handle_list_testfiles(params::Dict{String,Any})
    with_error_handling("list_testfiles") do
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
"""
function handle_run_all_tests(::Dict{String,Any})
    with_error_handling("run_all_tests") do
        test_dir, files = TestPicker.get_testfiles(SERVER_PKG[])
        TestPicker.run_testfiles([joinpath(test_dir, f) for f in files], SERVER_PKG[])

        results = parse_results_file(SERVER_PKG[])
        to_json(
            Dict(
                "status" => "completed",
                "files_run" => length(files),
                "failures" => results["count"]["total"],
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
        isempty(query) && return TextContent(text = "Error: query required")

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
    handle_run_test_blocks(params::Dict{String,Any}) -> Content

Run specific test block(s) matched by queries.
"""
function handle_run_test_blocks(params::Dict{String,Any})
    with_error_handling("run_test_blocks") do
        testset_query = get(params, "testset_query", "")
        isempty(testset_query) && return TextContent(text = "Error: testset_query required")

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
        blocks_run = [
            Dict(
                "label" => r.info.label,
                "filename" => r.info.filename,
                "line" => r.info.line,
                "success" => r.success,
            ) for r in results
        ]

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
    handle_get_test_results(params::Dict{String,Any}) -> Content

Retrieve test failures and errors from the last test run.
"""
function handle_get_test_results(params::Dict{String,Any})
    with_error_handling("get_test_results") do
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
        isempty(pkg_dir) && return TextContent(text = "Error: pkg_dir required")

        # Activate the package environment
        activate_package(pkg_dir)

        # Re-detect and update the cached package
        SERVER_PKG[] = detect_package()

        to_json(
            Dict(
                "status" => "success",
                "pkg_dir" => pkg_dir,
                "package_name" => SERVER_PKG[].name,
            ),
        )
    end
end
