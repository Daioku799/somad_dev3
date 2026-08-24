using Test
using JLD2
using JSON

const ROOT = abspath(joinpath(@__DIR__, "..", ".."))
include(joinpath(ROOT, "H2-rom", "src", "PipelineData", "PipelineData.jl"))
using .PipelineData

"""合成データセットを一時ディレクトリに作る。"""
function make_synthetic(dir::String; shape=(5, 5, 4), drop_snapshot=Set{String}(),
                        bad_shape=Set{String}(), omit_plan_key::Union{Nothing,String}=nothing)
    mkpath(joinpath(dir, "cases"))
    cap, ncell = 9, 4
    specs = [
        ("c01", 8,  [3, 3, 1, 1], "train"),
        ("c02", 8,  [2, 2, 2, 2], "train"),
        ("c03", 8,  [8, 0, 0, 0], "validation"),
        ("c04", 12, [3, 3, 3, 3], "train"),
        ("c05", 12, [9, 3, 0, 0], "test"),
        ("c06", 10, [4, 3, 2, 1], "interp"),
    ]
    cases = Any[]
    for (i, (name, budget, counts, split)) in enumerate(specs)
        push!(cases, Dict("case" => i, "name" => name, "budget" => budget,
                          "counts" => counts, "split" => split,
                          "sum_sq" => sum(counts .^ 2), "max_cell" => maximum(counts)))
        name in drop_snapshot && continue
        s = name in bad_shape ? (shape[1] + 1, shape[2], shape[3]) : shape
        T = fill(300.0, s)
        T[2:s[1]-1, 2:s[2]-1, 2:s[3]-1] .= 300.0 .+ Float64(i)
        cdir = joinpath(dir, "cases", name); mkpath(cdir)
        JLD2.save(joinpath(cdir, "snapshot.jld2"), "theta", T)
    end
    plan = Dict{String,Any}("cap" => cap, "ncell" => ncell, "cases" => cases)
    omit_plan_key !== nothing && delete!(plan, omit_plan_key)
    open(joinpath(dir, "case_plan.json"), "w") do io
        JSON.print(io, plan)
    end
    return cap, ncell, specs
end

spec_for(dir) = DatasetSpec(run_dir = dir)

@testset "PipelineData" begin

    @testset "正常系: 読み取りと形" begin
        mktempdir() do dir
            cap, ncell, specs = make_synthetic(dir)
            ds = load_dataset(spec_for(dir))
            @test length(ds.records) == length(specs)
            @test size(ds.field, 2) == length(ds.records)
            @test size(ds.mu, 2) == length(ds.records)
            @test size(ds.mu, 1) == ncell
            @test ds.shape == (5, 5, 4)
            @test length(ds.tmax) == length(ds.records)
            @test length(ds.tmean) == length(ds.records)
            # 内部セルのみが field に入る
            @test size(ds.field, 1) == 3 * 3 * 2
            # 設計変数は cap で正規化される
            @test ds.mu[:, 1] ≈ [3, 3, 1, 1] ./ cap
            # ケース順は計画情報の順
            @test [r.name for r in ds.records] == [s[1] for s in specs]
        end
    end

    @testset "分割: interp は train/validation/test に含まれない" begin
        mktempdir() do dir
            make_synthetic(dir)
            ds = load_dataset(spec_for(dir))
            tr = split_indices(ds, "train")
            va = split_indices(ds, "validation")
            te = split_indices(ds, "test")
            ip = split_indices(ds, "interp")
            @test [ds.records[i].name for i in tr] == ["c01", "c02", "c04"]
            @test [ds.records[i].name for i in va] == ["c03"]
            @test [ds.records[i].name for i in te] == ["c05"]
            @test [ds.records[i].name for i in ip] == ["c06"]
            interp_idx = Set(ip)
            for idx in vcat(tr, va, te)
                @test !(idx in interp_idx)
            end
            @test isempty(intersect(Set(tr), Set(va)))
            @test isempty(intersect(Set(tr), Set(te)))
        end
    end

    @testset "TSV本数による抽出" begin
        mktempdir() do dir
            make_synthetic(dir)
            ds = load_dataset(spec_for(dir))
            @test [ds.records[i].name for i in budget_indices(ds, 8)] == ["c01", "c02", "c03"]
            @test [ds.records[i].name for i in budget_indices(ds, 12)] == ["c04", "c05"]
            @test isempty(budget_indices(ds, 99))
            @test sort(budgets(ds)) == [8, 10, 12]
        end
    end

    @testset "内部領域の3次元ビュー" begin
        mktempdir() do dir
            make_synthetic(dir)
            ds = load_dataset(spec_for(dir))
            v = interior_view(ds.field[:, 3], ds.shape)
            @test size(v) == (3, 3, 2)
            @test all(v .≈ 303.0)
        end
    end

    @testset "異常系: スナップショット欠落はケース名を示して中止" begin
        mktempdir() do dir
            make_synthetic(dir; drop_snapshot = Set(["c04"]))
            err = nothing
            try
                load_dataset(spec_for(dir))
            catch e
                err = e
            end
            @test err !== nothing
            @test occursin("c04", sprint(showerror, err))
        end
    end

    @testset "異常系: 温度場の形の不一致はケース名を示して中止" begin
        mktempdir() do dir
            make_synthetic(dir; bad_shape = Set(["c05"]))
            err = nothing
            try
                load_dataset(spec_for(dir))
            catch e
                err = e
            end
            @test err !== nothing
            @test occursin("c05", sprint(showerror, err))
        end
    end

    @testset "異常系: 計画情報のキー欠落は中止" begin
        mktempdir() do dir
            make_synthetic(dir; omit_plan_key = "cap")
            @test_throws Exception load_dataset(spec_for(dir))
        end
        mktempdir() do dir
            make_synthetic(dir; omit_plan_key = "cases")
            @test_throws Exception load_dataset(spec_for(dir))
        end
    end

    @testset "run固有のパスを内部に持たない" begin
        mktempdir() do d1
            mktempdir() do d2
                make_synthetic(d1)
                make_synthetic(d2)
                ds1 = load_dataset(spec_for(d1))
                ds2 = load_dataset(spec_for(d2))
                @test ds1.spec.run_dir == d1
                @test ds2.spec.run_dir == d2
                @test ds1.spec.run_dir != ds2.spec.run_dir
            end
        end
    end
end
