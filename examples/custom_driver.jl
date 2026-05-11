@info "Active environment:" Base.active_project()

using Random

Random.seed!(1234)

using SpinDoctor
using LinearAlgebra
using JSON


function process_mesh(mesh_path::String, name::String, b::Int64, D_vals::NamedTuple, κ_val::Float64, param_mode::String, gradient_direction::String, output_root::String, param_root::String)
    filename = "$(name)_b$(b)_$(param_mode)_gradient_direction_$(gradient_direction).csv"
    parameter_filename = "$(name)_b$(b)_$(param_mode)_gradient_direction_$(gradient_direction).yml"
    savepath = joinpath(output_root, filename)

    @info "Processing mesh at: $mesh_path with b = $b and param mode $param_mode, gradient direction: $gradient_direction, savepath: $savepath"

    # the node, ele and face files are in the directory mesh_path and are all named "mesh" + fileextension
    mesh = @time load_custom_geometry(joinpath(mesh_path, "mesh"))

    metadata_path = joinpath(mesh_path, "mesh_metadata.json")

    metadata = JSON.parsefile(metadata_path)

    if haskey(metadata, "n_background")
        n_ecs = metadata["n_background"]
    else
        error("n_background key not found in metadata file.")
    end

    ncompartment, nboundary = size(mesh.facets)
    # find all outer boundaries, i.e. those that only touch 1 compartment
    outer_boundaries_idx = Int[]
    for iboundary = 1:nboundary
        cmpts_touch = findall(.!isempty.(mesh.facets[:, iboundary]))
        if length(cmpts_touch) == 1
            push!(outer_boundaries_idx, iboundary)
        end
    end

    setup = CustomGeometrySetup{Float64}(
        ;
        ncompartment = ncompartment,
        nboundary = nboundary,
        n_ecs = n_ecs,
        outer_boundaries_idx = outer_boundaries_idx
    )

    dim = size(mesh.points[1], 1)

    # assumes that first n_ecs compartments in the mesh are ecs
    coeffs = coefficients(setup,
        D = (; cell = D_vals.cell * I(dim), ecs = D_vals.ecs * I(dim)),
        T₂ = (; cell = Inf, ecs = Inf),
        κ = κ_val,
        ρ = (; cell = 1.0, ecs = 1.0),
        γ = 2.67513e-4,
    )

    model = Model(; mesh, coeffs...);
    @info "Number of nodes per compartment:" length.(model.mesh.points)
    matrices = nothing
    ## Assemble finite element matrices
    # sometimes assembling fails in get_mesh_surfacenormals
    @info "Assembling matrices"
    try
        matrices = @time assemble_matrices_parallel(model);
    catch e
        @warn "Failed assembling matrices at $mesh_path: $e"
        return
    end

    ## Magnetic field gradient
    if dim == 2
        if gradient_direction == "x"
            dir = [1.0, 0.0]
        elseif gradient_direction == "y"
            dir = [0.0, 1.0]
        end
    elseif dim == 3
        # todo update to accept gradient direction
        dir = [1.0, 0.0, 0.0]
    end        
    delta = 9500.0
    Delta = 25800.0
    profile = PGSE(delta, Delta)
    g = √(b / int_F²(profile)) / coeffs.γ
    gradient = ScalarGradient(dir, profile, g)

    ## Solve BTPDE

    # Choose BTDPE solver (specialized solver only for PGSE)
    solver = IntervalConstantSolver(; θ = 0.5, timestep = 5.0)

    # Solve BTPDE
    btpde = BTPDE(; model, matrices)
    ξ = @time solve(btpde, gradient, solver)

    ## Compute signal
    signal = abs(compute_signal(matrices.M, ξ))

    ## Save magnetization
    savefield_csv(model.mesh, ξ, coeffs, signal, savepath)

    # Create dataset-specific parameter folder
    dataset_param_root = joinpath(param_root, basename(output_root))
    mkpath(dataset_param_root)

    save_parameters(dataset_param_root, parameter_filename;
                    D_cell = D_vals.cell,
                    D_ecs  = D_vals.ecs,
                    κ      = κ_val,
                    b_value = b,
                    delta = delta,
                    Delta = Delta,
                    mesh_path = mesh_path)
end



mesh_path = ARGS[1]
dataset_name = ARGS[2]
b_value = parse(Int, ARGS[3])
gradient_direction = ARGS[4]
output_root = ARGS[5]
param_root = ARGS[6]

@info "Dataset name: $dataset_name"
@info "b-value: $b_value"
@info "Gradient direction: $gradient_direction"

D_vals = (; cell = 0.001, ecs = 0.003)
κ_val = 0.0
param_mode = "fixed"
process_mesh(mesh_path, dataset_name, b_value, D_vals, κ_val, param_mode, gradient_direction, output_root, param_root)

# # Random params
#D_grid = range(0.0002, stop=0.003, step=0.0001)
#κ_grid = range(0, stop=5e-5, step=2e-6)
#         D_vals = (; cell = rand(D_grid), ecs = rand(D_grid))
#         κ_val = rand(κ_grid)
#         param_mode = "random"
#         process_mesh(mesh_path, dataset_name, b, D_vals, κ_val, param_mode, gradient_direction, output_root, param_root)
#end
