const REFERENCE_TEMPERATURE = 300.0   # 温度上昇を測る基準（初期温度・環境温度）

_names_for(names, n) = isempty(names) ? ["case_$(i)" for i in 1:n] : String.(names)

"""学習分割のみで POD 分解を行う。返り値は打ち切り前のもの。"""
function _pod(field::AbstractMatrix{Float64}, train_idx::AbstractVector{<:Integer},
               ric_threshold::Float64)
    isempty(train_idx) && throw(RomBuildError("学習ケースが0件のため基底を作れない"))
    Xtr = field[:, train_idx]
    return PODEngine.compute_pod(Xtr; ric_threshold = ric_threshold)
end

"""打ち切り基底数の上限。学習ケース数と POD が返した基底数の小さい方。"""
_max_modes(n_train::Integer, n_basis::Integer) = min(Int(n_train), Int(n_basis))

function _fit_interpolator(mu::AbstractMatrix{Float64}, train_idx::AbstractVector{<:Integer},
                            coeffs::AbstractMatrix{Float64}, settings::RomSettings)
    interp = RBFInterpolator(settings.epsilon)
    fit!(interp, Matrix{Float64}(mu[:, train_idx]),
         Matrix{Float64}(coeffs[1:settings.modes, :]); lambda = settings.lambda)
    return interp
end

"""
    build_rom(field, mu, train_idx, inner_shape, settings; names) -> RomModel

学習用に指定された分割のケースのみを用いて基底と補間を構築する。
`field` の列はゴーストセルを除いた内部領域、`mu` の列は設計変数で、いずれも
列順は `names` と一致する。
"""
function build_rom(field::AbstractMatrix{Float64}, mu::AbstractMatrix{Float64},
                   train_idx::AbstractVector{<:Integer}, inner_shape::NTuple{3,Int},
                   settings::RomSettings; names::AbstractVector{<:AbstractString} = String[])
    size(field, 2) == size(mu, 2) ||
        throw(RomBuildError("温度場の列数 $(size(field,2)) と設計変数の列数 $(size(mu,2)) が一致しない"))
    size(field, 1) == prod(inner_shape) ||
        throw(RomBuildError("温度場の行数 $(size(field,1)) が内部形状 $(inner_shape) と一致しない"))
    n_train = length(train_idx)
    settings.modes <= n_train ||
        throw(RomBuildError("基底数 $(settings.modes) が学習ケース数 $(n_train) を超える。" *
                            "基底数を減らすか学習ケースを増やす必要がある"))

    basis, svals, coeffs, mean_field = _pod(field, train_idx, settings.ric_threshold)
    n_basis = size(basis, 2)
    settings.modes <= n_basis ||
        throw(RomBuildError("基底数 $(settings.modes) が利用可能な基底数 $(n_basis) を超える"))

    interp = _fit_interpolator(mu, train_idx, coeffs, settings)
    all_names = _names_for(names, size(field, 2))
    return RomModel(Matrix{Float64}(basis[:, 1:settings.modes]), mean_field,
                    Vector{Float64}(svals), interp, settings, inner_shape,
                    all_names[train_idx])
end

"""
    predict_field(model, mu_vec) -> Vector{Float64}

設計変数から温度場（内部領域のみ）を再構成する。
"""
predict_field(model::RomModel, mu_vec::AbstractVector{Float64}) =
    reconstruct_field(predict(model.interpolator, Vector{Float64}(mu_vec)),
                      model.basis, model.mean_field)

"""
    predict_tmax(model, mu_vec) -> Float64

設計変数から最大温度を予測する。列は内部領域のみなので最大値をそのまま取る。
"""
predict_tmax(model::RomModel, mu_vec::AbstractVector{Float64}) =
    maximum(predict_field(model, mu_vec))

"""
    evaluate_accuracy(model, field, mu, idx; names) -> AccuracyReport

指定した添字のケースについて、最大温度の3指標と温度場の相対 L2 誤差を算出する。
学習に用いていない分割を渡すことを想定する。
"""
function evaluate_accuracy(model::RomModel, field::AbstractMatrix{Float64},
                           mu::AbstractMatrix{Float64}, idx::AbstractVector{<:Integer};
                           names::AbstractVector{<:AbstractString} = String[])
    isempty(idx) && throw(RomBuildError("評価対象のケースが0件"))
    n = length(idx)
    pred = Vector{Float64}(undef, n)
    truth = Vector{Float64}(undef, n)
    l2 = Vector{Float64}(undef, n)
    rise = Vector{Float64}(undef, n)
    for (k, i) in enumerate(idx)
        p = predict_field(model, @view mu[:, i])
        t = @view field[:, i]
        pred[k] = maximum(p)
        truth[k] = maximum(t)
        e = norm(p .- t)
        l2[k] = e / norm(t) * 100
        rise[k] = e / norm(t .- REFERENCE_TEMPERATURE) * 100
    end
    d = pred .- truth
    all_names = _names_for(names, size(field, 2))
    return AccuracyReport(n, mean(abs.(d)), sqrt(mean(abs2, d)), maximum(abs.(d)),
                          mean(l2), mean(rise), pred, truth, all_names[idx])
end

"""
    select_settings(field, mu, train_idx, val_idx, inner_shape; modes, epsilons, lambdas, names)
        -> (RomSettings, Vector{NamedTuple}, RomModel)

候補の格子を検証用分割で評価し、最大温度の平均絶対誤差が最小の設定・全候補の
成績・最良設定で構築した縮約モデルを返す。基底数が学習ケース数または利用可能な
基底数を超える候補は、中止せず候補から除く。

POD 分解は一度だけ行い、補間のみを張り替える。最良のモデルをそのまま返すのは、
呼び出し側が `build_rom` を再実行して同じ POD 分解を二度行うのを避けるため。
"""
function select_settings(field::AbstractMatrix{Float64}, mu::AbstractMatrix{Float64},
                         train_idx::AbstractVector{<:Integer},
                         val_idx::AbstractVector{<:Integer}, inner_shape::NTuple{3,Int};
                         modes::AbstractVector{<:Integer},
                         epsilons::AbstractVector{<:Real},
                         lambdas::AbstractVector{<:Real},
                         ric_threshold::Real = 0.9999,
                         names::AbstractVector{<:AbstractString} = String[])
    isempty(val_idx) && throw(RomBuildError("検証用のケースが0件のため設定を選べない"))
    basis, svals, coeffs, mean_field = _pod(field, train_idx, Float64(ric_threshold))
    cap = _max_modes(length(train_idx), size(basis, 2))
    all_names = _names_for(names, size(field, 2))

    rows = NamedTuple[]
    best_model = nothing
    best_mae = Inf
    for m in modes, eps in epsilons, lam in lambdas
        m <= cap || continue
        st = RomSettings(modes = m, epsilon = eps, lambda = lam,
                         ric_threshold = ric_threshold)
        interp = _fit_interpolator(mu, train_idx, coeffs, st)
        model = RomModel(Matrix{Float64}(basis[:, 1:m]), mean_field, Vector{Float64}(svals),
                         interp, st, inner_shape, all_names[train_idx])
        r = evaluate_accuracy(model, field, mu, val_idx; names = all_names)
        push!(rows, (modes = m, epsilon = Float64(eps), lambda = Float64(lam),
                     tmax_mae = r.tmax_mae, tmax_rmse = r.tmax_rmse,
                     tmax_maxe = r.tmax_maxe, field_l2_rel = r.field_l2_rel,
                     field_l2_rise = r.field_l2_rise))
        if r.tmax_mae < best_mae
            best_mae = r.tmax_mae
            best_model = model
        end
    end
    best_model === nothing &&
        throw(RomBuildError("成立する候補が無い。基底数の候補 $(collect(modes)) がすべて上限 $cap を超えている"))
    return best_model.settings, rows, best_model
end

"""
    save_rom(path, model) -> String

後続の処理が再読み込みできる形で保存する。Julia の型に依存しないよう、
配列と数値のみを書き出す。
"""
function save_rom(path::AbstractString, model::RomModel)
    dir = dirname(path)
    isempty(dir) || mkpath(dir)
    JLD2.jldopen(String(path), "w") do f
        f["basis"] = model.basis
        f["mean_field"] = model.mean_field
        f["singular_values"] = model.singular_values
        f["rbf_weights"] = model.interpolator.weights
        f["rbf_centers"] = model.interpolator.centers
        f["rbf_epsilon"] = model.interpolator.epsilon
        f["rbf_scale_min"] = model.interpolator.scaling_params.min_vals
        f["rbf_scale_max"] = model.interpolator.scaling_params.max_vals
        f["rbf_bounds"] = model.interpolator.parameter_bounds
        f["settings_modes"] = model.settings.modes
        f["settings_epsilon"] = model.settings.epsilon
        f["settings_lambda"] = model.settings.lambda
        f["settings_ric_threshold"] = model.settings.ric_threshold
        f["inner_shape"] = collect(model.inner_shape)
        f["train_names"] = model.train_names
    end
    return String(path)
end

"""
    load_rom(path) -> RomModel

`save_rom` が書き出した縮約モデルを読み戻す。同じ設計変数に対して
保存前と同一の予測を返す。
"""
function load_rom(path::AbstractString)
    isfile(path) || throw(RomBuildError("縮約モデルが見つからない: $path"))
    d = JLD2.load(String(path))
    for k in ("basis", "mean_field", "rbf_weights", "rbf_centers", "rbf_epsilon",
              "settings_modes", "inner_shape")
        haskey(d, k) || throw(RomBuildError("縮約モデル $path にキー '$k' が無い"))
    end
    scaling = ScalingParams(d["rbf_scale_min"], d["rbf_scale_max"])
    interp = RBFInterpolator(d["rbf_weights"], d["rbf_centers"], d["rbf_epsilon"],
                             scaling, d["rbf_bounds"],
                             Dict{String,Any}("kernel_type" => "gaussian"))
    settings = RomSettings(modes = d["settings_modes"], epsilon = d["settings_epsilon"],
                           lambda = d["settings_lambda"],
                           ric_threshold = d["settings_ric_threshold"])
    shape = Tuple(Int.(d["inner_shape"]))
    return RomModel(d["basis"], d["mean_field"], d["singular_values"], interp,
                    settings, shape, String.(d["train_names"]))
end

"""
    pod_spectrum(model) -> (Vector{Float64}, Vector{Float64})

特異値と累積寄与率を返す。特異値減衰の図（Req 9.5）に用いる。
"""
function pod_spectrum(model::RomModel)
    s2 = model.singular_values .^ 2
    total = sum(s2)
    return model.singular_values, total ≈ 0.0 ? zero(s2) : cumsum(s2) ./ total
end

"""
    hot_row_indices(field, idx, k) -> Vector{Int}

指定した列における各行の最大値を求め、その大きい順に `k` 行の添字を返す。
最大温度は場全体の最大なので、常に上位に来る行だけを見れば足りる。
探索では1回の評価につき全行を再構成する余裕がないため、この限定を用いる。
"""
function hot_row_indices(field::AbstractMatrix{Float64},
                         idx::AbstractVector{<:Integer}, k::Integer)
    isempty(idx) && throw(RomBuildError("行の選定に使う列が0件"))
    n = size(field, 1)
    k >= 1 || throw(RomBuildError("行数は1以上: $k"))
    kk = min(Int(k), n)
    rowmax = fill(-Inf, n)
    for j in idx
        col = @view field[:, j]
        @inbounds @simd for i in 1:n
            col[i] > rowmax[i] && (rowmax[i] = col[i])
        end
    end
    return collect(partialsortperm(rowmax, 1:kk, rev = true))
end

"""
    TmaxEvaluator

限定した行だけで最大温度を予測する評価器。探索の内側で何万回も呼ばれるため、
基底と平均場をあらかじめ行方向に切り出して保持する。
`ev(mu)` の形で呼べる。
"""
struct TmaxEvaluator
    rows::Vector{Int}
    basis_rows::Matrix{Float64}
    mean_rows::Vector{Float64}
    interpolator::RBFInterpolator
end

"""
    tmax_evaluator(model, rows) -> TmaxEvaluator

`rows` に限定した最大温度の評価器を作る。
"""
function tmax_evaluator(model::RomModel, rows::AbstractVector{<:Integer})
    r = collect(Int, rows)
    isempty(r) && throw(RomBuildError("評価に使う行が0件"))
    (minimum(r) >= 1 && maximum(r) <= size(model.basis, 1)) ||
        throw(RomBuildError("行の添字が基底の範囲外"))
    return TmaxEvaluator(r, Matrix{Float64}(model.basis[r, :]),
                         Vector{Float64}(model.mean_field[r]), model.interpolator)
end

function (ev::TmaxEvaluator)(mu::AbstractVector{<:Real})
    a = predict(ev.interpolator, Vector{Float64}(mu))
    v = copy(ev.mean_rows)
    @inbounds for m in eachindex(a)
        am = a[m]
        col = @view ev.basis_rows[:, m]
        @simd for i in eachindex(v)
            v[i] += col[i] * am
        end
    end
    return maximum(v)
end
