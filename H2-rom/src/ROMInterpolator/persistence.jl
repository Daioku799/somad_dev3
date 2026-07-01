# persistence.jl - モデルの保存・読み込み機能の実装

"""
    save_rom_model(filepath::String, model::AbstractInterpolator)

学習済みのROMモデル（補間器モデル）をJLD2ファイルに保存します。
親ディレクトリが存在しない場合は、自動的に作成します。
"""
function save_rom_model(filepath::String, model::AbstractInterpolator)
    # 親ディレクトリの自動作成
    dir = dirname(filepath)
    if !isempty(dir)
        mkpath(dir)
    end
    
    # JLD2ファイルへの保存
    JLD2.save(filepath, Dict("model" => model))
end

"""
    load_rom_model(filepath::String) -> AbstractInterpolator

JLD2ファイルから保存されたモデルオブジェクトを読み込んで返します。
"""
function load_rom_model(filepath::String)::AbstractInterpolator
    data = JLD2.load(filepath)
    if !haskey(data, "model")
        error("保存されたデータに 'model' キーが存在しません。")
    end
    return data["model"]
end
