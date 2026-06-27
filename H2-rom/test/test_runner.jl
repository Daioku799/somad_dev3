using Test

# Load SnapshotGenerator
include("../src/SnapshotGenerator/SnapshotGenerator.jl")
using .SnapshotGenerator: SnapshotCase
using .SnapshotGenerator.Runner: prepare_work_dir

@testset "Runner Workspace Preparation Test" begin
    # Create temporary directory for testing
    test_work_base = mktempdir()
    
    # SnapshotCase for test
    case = SnapshotCase(999, "pending", [0.5], "", 0.0)
    
    # Expected directory path
    expected_dir = joinpath(test_work_base, "case_999")
    
    # 1. First invocation: directory should be created
    actual_dir = prepare_work_dir(case, test_work_base)
    
    @test actual_dir == expected_dir
    @test isdir(expected_dir)
    
    # 2. Add dummy file inside
    dummy_file = joinpath(expected_dir, "dummy.txt")
    write(dummy_file, "temp content")
    @test isfile(dummy_file)
    
    # 3. Second invocation: directory should be cleaned and empty
    prepare_work_dir(case, test_work_base)
    
    @test !isfile(dummy_file)
    @test isdir(expected_dir)
    @test isempty(readdir(expected_dir))
    
    # Clean up test_work_base
    rm(test_work_base, recursive=true, force=true)
end
