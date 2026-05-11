"""
save_parameters(output_root::String, folder_name::String;
                      D_cell, D_ecs, κ, b_value, mesh_path)

Writes a single YAML file with all numerical constants that were used for that mesh.
"""
function save_parameters(output_root, parameter_filename;
                               D_cell, D_ecs, κ, b_value, delta, Delta, mesh_path)

    # Build directory structure
    ispath(output_root) || mkpath(output_root)

    # Assemble data
    yaml_data = Dict(
        "mesh_file"      => mesh_path,
        "b_value"        => b_value,
        "PGSE"           => Dict("delta" => delta, "Delta" => Delta),
        "diffusivity"    => Dict("ICS" => D_cell, "ECS" => D_ecs),
        "permeability"   => κ,
    )

    yaml_path = joinpath(output_root, parameter_filename)
    YAML.write_file(yaml_path, yaml_data)
    @info "Parameter YAML written to $yaml_path"
end
