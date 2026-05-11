"""
    load_custom_geometry(mesh_path)
loads mesh from path to tetegen .node, .face and .ele files
e.g. if files are in tetgen_dir/mesh.node, tetgen_dir/mesh.face and tetgen_dir/mesh.ele,
then mesh_path should be "tetgen_dir/mesh"
"""
function load_custom_geometry(mesh_path)
    mesh_all = read_custom_tetgen_mesh(mesh_path)
    # Split mesh into compartments
    mesh = split_custom_mesh(mesh_all)
    mesh
end