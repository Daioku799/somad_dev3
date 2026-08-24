using Test
using JSON

const ROOT = abspath(joinpath(@__DIR__, "..", ".."))
include(joinpath(ROOT, "H2-rom", "src", "PipelineReport", "PipelineReport.jl"))
using .PipelineReport

function make_prov(dir::String)
    return RunProvenance(
        run_dir = dir,
        dataset_id = "test_ds_20260824",
        n_cases = 6,
        split_counts = Dict("train" => 3, "validation" => 1, "test" => 1, "interp" => 1),
    )
end

@testset "PipelineReport" begin

    @testset "結果表は run 配下の解析結果置き場に出る" begin
        mktempdir() do dir
            prov = make_prov(dir)
            path = write_table(prov, "acc.tsv", ["name", "err"], Any[["c01", 0.5], ["c02", 0.25]])
            @test isfile(path)
            @test startswith(path, joinpath(dir, "rom"))
            lines = readlines(path)
            @test lines[1] == "# scope=pooled"
            @test lines[2] == "name\terr"
            @test lines[3] == "c01\t0.5"
        end
    end

    @testset "出力先を run の外に出せない" begin
        mktempdir() do dir
            prov = make_prov(dir)
            for bad in ["../escape.tsv", "a/../../escape.tsv", "/tmp/escape.tsv", "sub/../../x.tsv"]
                @test_throws Exception write_table(prov, bad, ["a"], Any[[1]])
            end
            @test_throws Exception write_text(prov, "../escape.txt", "x")
            # 下位ディレクトリは許可される
            p = write_table(prov, "sub/ok.tsv", ["a"], Any[[1]])
            @test isfile(p)
            @test startswith(p, joinpath(dir, "rom"))
        end
    end

    @testset "集計の範囲は出力上で区別できる" begin
        mktempdir() do dir
            prov = make_prov(dir)
            p1 = write_table(prov, "pooled.tsv", ["a"], Any[[1]]; scope = "pooled")
            p2 = write_table(prov, "per.tsv", ["budget", "a"], Any[[36, 1]]; scope = "per_budget")
            @test readlines(p1)[1] == "# scope=pooled"
            @test readlines(p2)[1] == "# scope=per_budget"
            @test_throws Exception write_table(prov, "bad.tsv", ["a"], Any[[1]]; scope = "whatever")
        end
    end

    @testset "行と見出しの長さが一致しないと拒否する" begin
        mktempdir() do dir
            prov = make_prov(dir)
            @test_throws Exception write_table(prov, "x.tsv", ["a", "b"], Any[[1]])
        end
    end

    @testset "来歴に識別子・分割内訳・基底数・補間設定・乱数指定が揃う" begin
        mktempdir() do dir
            prov = make_prov(dir)
            set_model_settings!(prov; pod_modes = 24, rbf_settings = Dict("epsilon" => 0.05, "lambda" => 1e-6))
            record_seed!(prov, "learning_curve", 20260824)
            record_seed!(prov, "search", 4242)
            path = write_provenance(prov)
            @test isfile(path)
            j = JSON.parsefile(path)
            @test j["dataset_id"] == "test_ds_20260824"
            @test j["n_cases"] == 6
            @test j["split_counts"]["train"] == 3
            @test j["split_counts"]["interp"] == 1
            @test j["pod_modes"] == 24
            @test j["rbf_settings"]["epsilon"] == 0.05
            @test j["seeds"]["learning_curve"] == 20260824
            @test j["seeds"]["search"] == 4242
            @test haskey(j, "generated_at")
        end
    end

    @testset "警告は一箇所に集約される" begin
        mktempdir() do dir
            prov = make_prov(dir)
            @test isempty(warnings(prov))
            record_warning!(prov, "しきい値が配置効果の幅以上")
            record_warning!(prov, "内挿誤差が倍率を超過")
            @test length(warnings(prov)) == 2
            path = write_warnings(prov)
            body = read(path, String)
            @test occursin("しきい値が配置効果の幅以上", body)
            @test occursin("内挿誤差が倍率を超過", body)
        end
    end

    @testset "テキスト出力" begin
        mktempdir() do dir
            prov = make_prov(dir)
            path = write_text(prov, "summary.txt", "要約本文")
            @test read(path, String) == "要約本文"
        end
    end
end
