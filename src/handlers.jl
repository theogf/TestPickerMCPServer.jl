"""
    handle_list_test_files(params::Dict{String,Any}) -> Content

List all test files in the current package, optionally filtered by query.
"""
function handle_list_test_files(params::Dict{String,Any})
    with_error_handling("list_test_files") do
        test_dir, files = TestPicker.get_test_files(SERVER_PKG[])
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
        test_dir, files = TestPicker.get_test_files(SERVER_PKG[])
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
function handle_run_all_tests(params::Dict{String,Any})
    with_error_handling("run_all_tests") do
        test_dir, files = TestPicker.get_test_files(SERVER_PKG[])
        TestPicker.run_test_files([joinpath(test_dir, f) for f in files], SERVER_PKG[])

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
    handle_run_test_files(params::Dict{String,Any}) -> Content

Run specific test file(s) matched by query.
"""
function handle_run_test_files(params::Dict{String,Any})
    with_error_handling("run_test_files") do
        query = get(params, "query", "")
        isempty(query) && return TextContent(text = "Error: query required")

        # Get all test files and filter by query
        test_dir, all_files = TestPicker.get_test_files(SERVER_PKG[])
        files = filter_files(all_files, query)
        isempty(files) && return TextContent(text = "No matches for '$query'")

        # Run the matched files
        abs_files = [joinpath(test_dir, f) for f in files]
        TestPicker.run_test_files(abs_files, SERVER_PKG[])

        to_json(Dict("status" => "completed", "files_run" => files))
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

        TestPicker.fzf_testblock(
            INTERFACES,
            get(params, "file_query", ""),
            testset_query;
            interactive = false,
        )

        to_json(Dict("status" => "completed"))
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
