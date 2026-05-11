"""
    savefield(mesh, ξ, filename::String; fieldname = "Magnetization")

Save field `ξ` to a VTK file. It may then be visualized in Paraview.
"""
function savefield(mesh, ξ, filename::String; fieldname = "Magnetization")
    ξ_cmpts = split_field(mesh, ξ)
    isdir(dirname(filename)) || mkpath(dirname(filename))
    vtmfile = vtk_multiblock(filename)
    dim = size(mesh.points[1], 1)
    if dim == 2
        vtk_cell_type = VTKCellTypes.VTK_TRIANGLE
    elseif dim == 3
        vtk_cell_type = VTKCellTypes.VTK_TETRA
    end
    for icmpt = 1:length(mesh.points)
        ξᵢ = ξ_cmpts[icmpt]
        points = mesh.points[icmpt]
        elements = mesh.elements[icmpt]
        cells =
            [MeshCell(vtk_cell_type, elements[:, i]) for i = 1:size(elements, 2)]
        vtkfile = vtk_grid(vtmfile, points, cells)
        vtkfile[fieldname*" (real part)"] = real(ξᵢ)
        vtkfile[fieldname*" (imaginary part)"] = imag(ξᵢ)
    end
    vtk_save(vtmfile)
end
