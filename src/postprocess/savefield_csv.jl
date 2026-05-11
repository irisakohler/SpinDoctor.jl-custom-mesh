"""
    savefield_csv(mesh, ξ, coefficients, signal, filename::String)

Saves the magnetization `ξ` to a CSV file, together with an indicator whether each point is an interface point or an interior point.
For interior points, the diffusivity is saved as under "parameter_value", for interface points, the permeability is saved. The signal
(absolute value of integral of magnetization) is saved in the last column
"""
function savefield_csv(mesh, ξ, coefficients, signal, filename::String)
    ξ_cmpts = split_field(mesh, ξ)  # Split the field into components
    isdir(dirname(filename)) || mkpath(dirname(filename))  # Ensure the directory exists
    dim = size(mesh.points[1], 1)

    # Prepare a DataFrame to hold all point data
    all_data = DataFrame()

    # Loop over each compartment in the mesh
    for icmpt = 1:length(mesh.points)
        ξᵢ = ξ_cmpts[icmpt]
        points = mesh.points[icmpt]
        compartment_facets = mesh.facets[icmpt, :]  # length nboundary, contains local indices of boundary points, but is empty where boundary does not belong to icmpt

        boundary_points_to_boundary_index = Dict()

        for iboundary = 1:length(compartment_facets)
            facet_list = compartment_facets[iboundary]
            if !isempty(facet_list)
                for local_point_index in facet_list
                    boundary_points_to_boundary_index[points[:, local_point_index]] = iboundary
                end
            end
        end

        is_interface = []
        is_interior_point =  []
        parameter_value = []
        for i in 1:size(points, 2)
            point = points[:, i]

            is_boundary_point = haskey(boundary_points_to_boundary_index, point)

            push!(is_interface, is_boundary_point ? 1 : 0)
            push!(is_interior_point, is_boundary_point ? 0 : 1)

            if is_boundary_point
                index = boundary_points_to_boundary_index[point]
                permeability = coefficients.κ[index]
                push!(parameter_value, permeability)
            else
                diffusivity = coefficients.D[icmpt]
                if diffusivity isa AbstractMatrix
                    # in this case the diffusivity should be a diagonal matrix -> only take diagonal entry
                    diffusivity = diffusivity[1]
                end
                push!(parameter_value, diffusivity)
            end

        end

        df = DataFrame(
            X = points[1, :],  # X coordinates
            Y = points[2, :],  # Y coordinates
            Z = dim == 3 ? points[3, :] : zeros(size(points, 2)),  # Z coordinates, or 0 for 2D
            magnetization_real = real(ξᵢ),  # Real part of magnetization
            magnetization_imag = imag(ξᵢ),  # Imaginary part of magnetization
            is_interface = is_interface,  # 1 for interface points, 0 otherwise
            is_interior_point = is_interior_point,  # 1 for non-interface points, 0 otherwise
            parameter_value = parameter_value,
            signal = fill(signal, size(points, 2))  # same value for all rows
        )

        # Append this compartment's data to the overall DataFrame
        append!(all_data, df)
    end

    # Save the DataFrame to a CSV file
    CSV.write(filename, all_data)
end
