# 3目的の交換関係（Req 7.1, 7.2, 7.5）
#
#   julia --project=H2-rom runs/paper_final_20260824T0140JST/pareto.jl
#
# 最大温度・TSV本数・第3目的の3者について非劣解集合を求める。
# 重み付けは一切与えない。標本済み設計と探索で得た設計を同じ土俵に載せるため、
# 支配関係の判定には両者とも縮約モデルの予測値を用い、実測値は別列に残す。

using Printf, Dates, Statistics, DelimitedFiles

include(joinpath(@__DIR__, "common.jl"))

"""`# scope=` 行を飛ばして表を読む。"""
function read_table(path)
    lines = [l for l in readlines(path) if !startswith(l, "#")]
    header = split(lines[1], '\t')
    rows = [split(l, '\t') for l in lines[2:end]]
    return header, rows
end

function main()
    started = now()
    @printf("=== pareto start %s ===\n", started)

    ds = load_main(CFG)
    prov = make_provenance(CFG, ds)
    geom = load_geometry(CFG, ds)
    inner = (ds.shape[1] - 2, ds.shape[2] - 2, ds.shape[3] - 2)
    cap = ds.cap
    model = load_rom(resolve_output(prov, "rom_model.jld2"))
    third = JSON.parsefile(resolve_output(prov, "third_objective.json"))
    metric = third["adopted"]
    @printf("第3目的: %s\n", third["label"])

    # --- 標本済み設計（424件）--------------------------------------------
    # 実測値と、同じ設計に対する縮約モデルの予測値の双方を持つ
    t0 = time()
    n = length(ds.records)
    names = [r.name for r in ds.records]
    budget = [r.budget for r in ds.records]
    tmax_fvm = copy(ds.tmax)
    tmax_rom = Vector{Float64}(undef, n)
    third_fvm = Vector{Float64}(undef, n)
    third_rom = Vector{Float64}(undef, n)
    for i in 1:n
        third_fvm[i] = getproperty(field_metrics(@view(ds.field[:, i]), inner, geom),
                                   Symbol(metric))
        p = predict_field(model, @view ds.mu[:, i])
        tmax_rom[i] = maximum(p)
        third_rom[i] = getproperty(field_metrics(p, inner, geom), Symbol(metric))
    end
    origin = fill("sampled", n)
    counts_str = [join(r.counts, ",") for r in ds.records]
    @printf("標本済み %d 件の目的値を算出（%.1f 秒）\n", n, time() - t0)

    # --- 探索で得た設計 ---------------------------------------------------
    sweep_path = resolve_output(prov, "budget_sweep.tsv")
    if isfile(sweep_path)
        h, rows = read_table(sweep_path)
        col(k) = findfirst(==(k), h)
        for r in rows
            for (kind, ccol, tcol) in (("searched_best", "counts_best", "tmax_best"),
                                       ("searched_worst", "counts_worst", "tmax_worst"),
                                       ("uniform", "counts_uniform", "tmax_uniform"))
                c = [parse(Int, x) for x in split(r[col(ccol)], ",")]
                p = predict_field(model, Float64.(c) ./ cap)
                push!(names, "$(kind)_N$(r[col("budget")])")
                push!(budget, parse(Int, r[col("budget")]))
                push!(tmax_fvm, NaN)              # 実測はまだ無い
                push!(tmax_rom, parse(Float64, r[col(tcol)]))
                push!(third_fvm, NaN)
                push!(third_rom, getproperty(field_metrics(p, inner, geom), Symbol(metric)))
                push!(origin, kind)
                push!(counts_str, join(c, ","))
            end
        end
        @printf("探索由来 %d 件を追加\n", length(names) - n)
    else
        record_warning!(prov, "$(sweep_path) が無いため探索由来の設計を含めない")
        @printf("[警告] 走査結果が無いため標本済み設計のみで求める\n")
    end

    # --- 非劣解集合（重み付けなし）----------------------------------------
    # 3目的とも小さいほど良い: 最大温度、TSV本数、第3目的
    M = hcat(tmax_rom, Float64.(budget), third_rom)
    keep3 = non_dominated(M)
    @printf("\n3目的の非劣解集合: %d / %d 件\n", length(keep3), length(names))

    by_budget = non_dominated_by_group(M[:, [1, 3]], budget)
    println("\n=== 本数を固定したときの2目的（最大温度 vs 第3目的）===")
    @printf("%5s %7s %9s %s\n", "N", "候補数", "非劣解数", "由来の内訳")
    for b in sort(collect(keys(by_budget)))
        idx = by_budget[b]
        cnt = Dict{String,Int}()
        for i in idx
            cnt[origin[i]] = get(cnt, origin[i], 0) + 1
        end
        @printf("%5d %7d %9d %s\n", b, count(==(b), budget), length(idx),
                join(["$k=$v" for (k, v) in sort(collect(cnt))], " "))
    end

    on3 = falses(length(names))
    on3[keep3] .= true
    on2 = falses(length(names))
    for (_, idx) in by_budget
        on2[idx] .= true
    end
    write_table(prov, "pareto_points.tsv",
                ["name", "origin", "budget", "counts", "tmax_rom", "tmax_fvm",
                 "third_rom", "third_fvm", "on_front_3obj", "on_front_2obj_per_budget"],
                [[names[i], origin[i], budget[i], counts_str[i], tmax_rom[i], tmax_fvm[i],
                  third_rom[i], third_fvm[i], on3[i], on2[i]] for i in eachindex(names)])

    println("\n=== 3目的の非劣解（最大温度の小さい順に上位20件）===")
    ord = sort(keep3, by = i -> tmax_rom[i])
    @printf("%-22s %-15s %5s %11s %13s\n", "設計", "由来", "N", "Tmax", "第3目的")
    for i in first(ord, 20)
        @printf("%-22s %-15s %5d %11.4f %13.5g\n",
                names[i], origin[i], budget[i], tmax_rom[i], third_rom[i])
    end

    write_provenance(prov)
    write_warnings(prov)
    @printf("\n=== pareto end %s（所要 %.1f 分）===\n",
            now(), (now() - started).value / 60000)
end

main()
