extends Node3D
## Procedural terrain generator using FastNoise3D with mesh generation

@export var terrain_size: int = 512  # Size of the terrain mesh in vertices (per side)
@export var terrain_scale: float = 2.0  # World space scale per vertex
@export var noise_scale: float = 100.0  # Scale of terrain features
@export var max_height: float = 150.0  # Maximum terrain height
@export var seed_value: int = 42  # Random seed for reproducibility
@export var octaves: int = 4  # Number of noise octaves for detail
@export var persistence: float = 0.55  # Amplitude reduction per octave
@export var lacunarity: float = 2.1  # Frequency multiplication per octave

var noise: FastNoise3D
var terrain_mesh: MeshInstance3D
var terrain_collider: CollisionShape3D

func _ready() -> void:
	setup_noise()
	generate_terrain_mesh()
	setup_collider()
	print("Procedural terrain loaded - %d vertices, scale %.1fm, max height %.1fm" % [terrain_size * terrain_size, terrain_scale, max_height])

func setup_noise() -> void:
	"""Initialize FastNoise3D generator"""
	noise = FastNoise3D.new()
	noise.seed = seed_value
	noise.frequency = 1.0 / noise_scale
	noise.fractal_type = FastNoise3D.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_persistence = persistence
	noise.fractal_lacunarity = lacunarity

func generate_terrain_mesh() -> void:
	"""Generate procedural terrain mesh from noise"""
	var mesh_data = MeshDataTool.new()
	var mesh = ArrayMesh.new()
	
	# Create vertices and height map
	var vertices = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	var half_size = terrain_size / 2.0
	
	# Generate vertices
	for z in range(terrain_size):
		for x in range(terrain_size):
			var world_x = (x - half_size) * terrain_scale
			var world_z = (z - half_size) * terrain_scale
			
			# Sample noise for height
			var height_value = noise.get_noise_3d(world_x, 0.0, world_z)
			var height = ((height_value + 1.0) / 2.0) * max_height
			
			vertices.append(Vector3(world_x, height, world_z))
			uvs.append(Vector2(float(x) / terrain_size, float(z) / terrain_size))
	
	# Generate indices for triangles
	for z in range(terrain_size - 1):
		for x in range(terrain_size - 1):
			var idx = z * terrain_size + x
			
			# First triangle
			indices.append(idx)
			indices.append(idx + 1)
			indices.append(idx + terrain_size)
			
			# Second triangle
			indices.append(idx + 1)
			indices.append(idx + terrain_size + 1)
			indices.append(idx + terrain_size)
	
	# Create surface from arrays
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	# Calculate normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mesh_with_normals = mesh.create_trimesh_shape()
	
	# Create material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.32, 0.18, 1.0)  # Grass green
	material.roughness = 0.85
	material.metallic = 0.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	
	# Create mesh instance
	terrain_mesh = MeshInstance3D.new()
	terrain_mesh.mesh = mesh
	terrain_mesh.set_surface_override_material(0, material)
	add_child(terrain_mesh)

func setup_collider() -> void:
	"""Setup physics collider for terrain"""
	# Create trimesh collider for realistic collision
	var trimesh_shape = terrain_mesh.mesh.create_trimesh_shape()
	
	terrain_collider = CollisionShape3D.new()
	terrain_collider.shape = trimesh_shape
	add_child(terrain_collider)

func _process(_delta: float) -> void:
	# Optional: add realtime terrain manipulation here
	pass
