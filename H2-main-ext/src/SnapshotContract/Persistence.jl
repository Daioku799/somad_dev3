function save_snapshot(path::AbstractString, snapshot::ThermalSnapshot)::String
    isempty(strip(path)) && throw(ContractError("snapshot path must not be empty"))
    ispath(path) && throw(ContractError("snapshot path already exists and is immutable"))
    validate_snapshot(snapshot)
    JLD2.save(String(path), Dict("snapshot" => snapshot))
    return String(path)
end

function load_snapshot(path::AbstractString)::ThermalSnapshot
    isfile(path) || throw(ContractError("snapshot file does not exist: $path"))
    data = JLD2.load(String(path))
    haskey(data, "snapshot") || throw(ContractError("snapshot file is missing the snapshot record"))
    snapshot = data["snapshot"]
    snapshot isa ThermalSnapshot || throw(ContractError("snapshot record has an unsupported type"))
    return validate_snapshot(snapshot)
end
