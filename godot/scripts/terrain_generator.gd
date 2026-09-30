extends Node3D
## Procedural terrain generator using FastNoiseLite with mesh generation

@export var terrain_size: int = 512  # Size of the terrain mesh in vertices (per side)
@export var terrain_scale: float = 60.0  # World space scale per vertex
@export var noise_scale: float = 600.0  # Scale of terrain features
@export var max_height: float = 300.0  # Maximum terrain height
@export var seed_value: int = 42  # Random seed for reproducibility
@export var octaves: int = 5  # Number of noise octaves for detail
@export var persistence: float = 0.55  # Amplitude reduction per octave
@export var lacunarity: float = 2.1  # Frequency multiplication per octave

@export var continent_scale: float = 2500.0  # Scale of large-scale landmass shape (plains vs mountains)
@export var flatness: float = 3.0  # Higher = more low flat plains/lake basins, sharper mountain transitions
@export var water_level: float = 25.0  # World height of the lake/water surface

@export var flatten_enabled: bool = true  # Level the ground under the city
@export var flatten_center: Vector2 = Vector2(700.0, -600.0)  # City centre (world x, z)
@export var flatten_half_extent: float = 400.0  # Half side of the fully flat square
@export var flatten_blend: float = 600.0  # Distance over which the ground returns to natural height
@export var flatten_height: float = 45.0  # World height of the flat site

var noise: FastNoiseLite
var continent_noise: FastNoiseLite
var terrain_mesh: MeshInstance3D
var terrain_collider: CollisionShape3D
var water_mesh: MeshInstance3D

func _ready() -> void:
	setup_noise()
	generate_terrain_mesh()
	setup_collider()
	setup_water()
	print("Procedural terrain loaded - %d vertices, scale %.1fm, max height %.1fm" % [terrain_size * terrain_size, terrain_scale, max_height])

func setup_noise() -> void:
	noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.0 / noise_scale
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_gain = persistence
	noise.fractal_lacunarity = lacunarity

	# Large-scale mask that decides where mountains rise vs. where plains/lake basins sit
	continent_noise = FastNoiseLite.new()
	continent_noise.seed = seed_value + 1000
	continent_noise.frequency = 1.0 / continent_scale
	continent_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	continent_noise.fractal_octaves = 3
	continent_noise.fractal_gain = 0.5
	continent_noise.fractal_lacunarity = 2.0

func generate_terrain_mesh() -> void:
	"""Generate procedural terrain mesh from noise"""
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
			
			var detail = (noise.get_noise_3d(world_x, 0.0, world_z) + 1.0) / 2.0
			var continent = (continent_noise.get_noise_3d(world_x, 0.0, world_z) + 1.0) / 2.0
			# Skew the mask toward 0 so most of the map stays flat/low, with mountains only where continent is high
			var mountain_mask = pow(continent, flatness)
			var height = detail * mountain_mask * max_height
			if flatten_enabled:
				var outside = (Vector2(world_x, world_z) - flatten_center).abs() - Vector2(flatten_half_extent, flatten_half_extent)
				var distance = Vector2(maxf(outside.x, 0.0), maxf(outside.y, 0.0)).length()
				height = lerpf(flatten_height, height, smoothstep(0.0, flatten_blend, distance))
			
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
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
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

func setup_water() -> void:
	"""Add a flat water plane that floods the low-lying basins created by the mountain mask"""
	var water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color(0.1, 0.35, 0.55, 0.75)
	water_material.roughness = 0.05
	water_material.metallic = 0.2
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var plane = PlaneMesh.new()
	plane.material = water_material
	plane.size = Vector2(terrain_size * terrain_scale, terrain_size * terrain_scale)

	water_mesh = MeshInstance3D.new()
	water_mesh.mesh = plane
	water_mesh.position = Vector3(0, water_level, 0)
	add_child(water_mesh)

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
