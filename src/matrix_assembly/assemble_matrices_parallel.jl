using Base.Threads

"""
    assemble_matrices_parallel(model)

Assemble finite element matrices.
"""
function assemble_matrices_parallel(model::Model{T,dim}) where {T,dim}
    (; mesh, D, T₂, ρ) = model

    # Deduce sizes
    ncompartment, nboundary = size(mesh.facets)
    npoint_cmpts = size.(mesh.points, 2)

    # Assemble finite element matrices
    volumes = zeros(ncompartment)
    for icmpt = 1:ncompartment
        points = mesh.points[icmpt]
        elements = mesh.elements[icmpt]
        fevolumes, = get_mesh_volumes(points, elements)
        volumes[icmpt] = sum(fevolumes)
    end

    # Assemble finite element matrices compartment-wise
    M_cmpts = []
    S_cmpts = []
    Mx_cmpts = [[] for _ = 1:dim]
    G = []

    @time for icmpt = 1:ncompartment
        # @info "compartment $icmpt of $ncompartment"

        # Finite elements
        points   = mesh.points[icmpt]
        elements = mesh.elements[icmpt]
        fevolumes, = get_mesh_volumes(points, elements)

        # Assemble mass, stiffness and flux matrices
        push!(M_cmpts, assemble_mass_matrix(elements, points))
        push!(S_cmpts, assemble_stiffness_matrix(elements, points, D[icmpt]))

        # Assemble first order product moment matrices
        for d = 1:dim
            push!(Mx_cmpts[d], assemble_mass_matrix(elements, points, points[d, :]))
        end

        # Surface integrals with parallelized boundary loop
        npts = npoint_cmpts[icmpt]
        Gi_threads = [zeros(eltype(points), npts, dim) for _ in 1:nthreads()]

        # Collect only non-empty boundaries
        nonempty = Int[]
        for ib = 1:nboundary
            if !isempty(mesh.facets[icmpt, ib])
                push!(nonempty, ib)
            end
        end
        nb_nonempty = length(nonempty)

        Threads.@threads for idx in eachindex(nonempty)
            iboundary = nonempty[idx]
            facets = mesh.facets[icmpt, iboundary]

            # Get facet normals once per boundary
            _, _, normals = get_mesh_surfacenormals(points, elements, facets)

            # Accumulate into this thread's private buffer
            buf = Gi_threads[threadid()]
            @inbounds @views for d = 1:dim
                Q = assemble_mass_matrix(facets, points, normals[d, :])
                buf[:, d] .+= vec(sum(Q; dims = 2))
            end
        end

        # Reduce thread-local accumulators
        Gi = reduce(+, Gi_threads)
        push!(G, Gi)
    end

    # Assemble global finite element matrices
    M = blockdiag(M_cmpts...)
    S = blockdiag(S_cmpts...)
    R = blockdiag((M_cmpts ./ T₂)...)
    Mx = [blockdiag(Mx_cmpts[d]...) for d = 1:dim]
    @info "assembling flux matrices"
    Q_blocks = assemble_flux_matrices_parallel(mesh.points, mesh.facets)
    @info "coupling flux matrices"
    Q = couple_flux_matrix(model, Q_blocks, false)

    (; M, S, R, Mx, Q, M_cmpts, S_cmpts, Mx_cmpts, G, volumes)
end
