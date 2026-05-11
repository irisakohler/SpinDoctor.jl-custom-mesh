"""
    assemble_flux_matrices_parallel(points, facets)

Assemble flux matrix (`Q`) for each compartment and boundary.
"""
function assemble_flux_matrices_parallel(points, facets)
    ncompartment, nboundary = size(facets)
    flux_matrices = Matrix{Any}(undef, ncompartment, nboundary)

    Threads.@threads for icmpt in 1:ncompartment
        for iboundary in 1:nboundary
            f = facets[icmpt, iboundary]
            flux_matrices[icmpt, iboundary] = isempty(f) ? 
                spzeros(size(points[icmpt],2), size(points[icmpt],2)) : 
                assemble_mass_matrix(f, points[icmpt])
        end
    end
    flux_matrices
end
