"""
    SearchConfig

探索の条件。設計空間の形（セル上限とセル数）と、多点スタートの回数・乱数指定を持つ。
`maximize` を切り替えることで、最小化と最大化を同一の実装で扱う。
"""
struct SearchConfig
    cap::Int
    ncell::Int
    n_restart::Int
    seed::Int
    maximize::Bool
end

function SearchConfig(; cap::Integer, ncell::Integer, n_restart::Integer,
                        seed::Integer, maximize::Bool = false)
    cap >= 1 || throw(ArgumentError("セル上限は1以上: $cap"))
    ncell >= 2 || throw(ArgumentError("セル数は2以上: $ncell"))
    n_restart >= 1 || throw(ArgumentError("リスタート数は1以上: $n_restart"))
    return SearchConfig(Int(cap), Int(ncell), Int(n_restart), Int(seed), maximize)
end

"""1回の降下で得られた解。`n_eval` はその降下での目的関数の評価回数。"""
struct SearchSolution
    counts::Vector{Int}
    value::Float64
    steps::Int
    n_eval::Int
end

"""
    SearchResult

1つの総本数に対する多点スタート探索の結果。`solutions` は相異なる解のみを
値の順に並べたもので、`best` はその先頭。
"""
struct SearchResult
    budget::Int
    best::SearchSolution
    solutions::Vector{SearchSolution}
    n_restart::Int
    n_distinct::Int
    n_eval::Int
    maximize::Bool
end

"""探索を実行できないことを示す。"""
struct SearchError <: Exception
    msg::String
end

Base.showerror(io::IO, e::SearchError) = print(io, "SearchError: ", e.msg)
