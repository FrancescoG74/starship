extends Node3D

## Procedural terrain: a FastNoiseLite height field with a plains/mountain mask,
## a ring of guaranteed peaks, a flattened site for the city and a water plane
## flooding the low basins. Visual only; flight physics lives in StarshipWorld.

@export_group("Mesh")
@export var terrain_size: int = 512  # Size of the terrain mesh in vertices (per side)
@export var terrain_scale: float = 60.0  # World space scale per vertex

@export_group("Noise")
@export var noise_scale: float = 600.0  # Scale of terrain features
@export var max_height: float = 300.0  # Maximum terrain height
@export var seed_value: int = 42  # Random seed for reproducibility
@export var octaves: int = 5  # Number of noise octaves for detail
@export var persistence: float = 0.55  # Amplitude reduction per octave
@export var lacunarity: float = 2.1  # Frequency multiplication per octave

@export_group("Landscape")
@export var continent_scale: float = 2500.0  # Scale of large-scale landmass shape (plains vs mountains)
@export var flatness: float = 3.0  # Higher = more low flat plains/lake basins, sharper mountain transitions
@export var water_level: float = 25.0  # World height of the lake/water surface

@export_group("Mountains")
@export var mountain_ridge_scale: float = 350.0  # Feature size of the jagged mountain ridges
@export var mountain_ridge_height: float = 260.0  # Extra peak height layered on top of the base mask, where it applies
@export var mountain_ridge_octaves: int = 4

# A mountain range made of explicitly placed peaks (world x, z), so it always
# appears regardless of what the continent noise happens to roll. Laid out as
# a ring around the runway/city so it reads as a distant range on the horizon.
@export var mountain_peaks: Array[Vector2] = [
	Vector2(8000, 0), Vector2(6472, 4702), Vector2(2472, 7608), Vector2(-2472, 7608), Vector2(-6472, 4702),
	Vector2(-8000, 0), Vector2(-6472, -4702), Vector2(-2472, -7608), Vector2(2472, -7608), Vector2(6472, -4702),
]
@export var mountain_peak_radius: float = 4500.0  # Distance over which each peak's influence fades to nothing
@export var mountain_peak_height: float = 380.0  # Guaranteed extra height added at each peak, independent of noise
@export var mountain_peak_sharpness: float = 2.0  # Higher = influence falls off faster from the peak center

@export_group("Colors")
@export var rock_height: float = 130.0  # World height where grass starts giving way to bare rock
@export var snow_height: float = 260.0  # World height where rock starts giving way to snow

@export_group("City Site")
@export var flatten_enabled: bool = true  # Level the ground under the city
@export var flatten_center: Vector2 = Vector2(700.0, -600.0)  # City centre (world x, z)
@export var flatten_half_extent: float = 650.0  # Half side of the fully flat square
@export var flatten_blend: float = 750.0  # Distance over which the ground returns to natural height
@export var flatten_height: float = 45.0  # World height of the flat site

const GRASS_COLOR := Color(0.24, 0.32, 0.18)
const ROCK_COLOR := Color(0.42, 0.4, 0.38)
const SNOW_COLOR := Color(0.92, 0.94, 0.97)
const SNOW_BLEND := 60.0  # Height over which rock fades into full snow

var _detail_noise: FastNoiseLite
var _continent_noise: FastNoiseLite
var _ridge_noise: FastNoiseLite

func _ready() -> void:
	_setup_noise()
	add_child(_build_terrain())
	add_child(_build_water())
	print("Procedural terrain loaded - %d vertices, scale %.1fm, max height %.1fm" % [terrain_size * terrain_size, terrain_scale, max_height])

func _setup_noise() -> void:
	_detail_noise = _make_noise(seed_value, noise_scale, FastNoiseLite.FRACTAL_FBM, octaves, persistence, lacunarity)
	# Large-scale mask that decides where mountains rise vs. where plains/lake basins sit
	_continent_noise = _make_noise(seed_value + 1000, continent_scale, FastNoiseLite.FRACTAL_FBM, 3, 0.5, 2.0)
	# Ridged fractal gives sharp peaks and valleys instead of smooth rolling hills
	_ridge_noise = _make_noise(seed_value + 2000, mountain_ridge_scale, FastNoiseLite.FRACTAL_RIDGED, mountain_ridge_octaves, 0.5, 2.0)

func _make_noise(noise_seed: int, feature_scale: float, fractal: FastNoiseLite.FractalType,
		fractal_octaves: int, gain: float, fractal_lacunarity: float) -> FastNoiseLite:
	var result := FastNoiseLite.new()
	result.seed = noise_seed
	result.frequency = 1.0 / feature_scale
	result.fractal_type = fractal
	result.fractal_octaves = fractal_octaves
	result.fractal_gain = gain
	result.fractal_lacunarity = fractal_lacunarity
	return result

# Noise sampled on the y = 0 plane, remapped from [-1, 1] to [0, 1].
func _noise01(source: FastNoiseLite, point: Vector2) -> float:
	return (source.get_noise_3d(point.x, 0.0, point.y) + 1.0) * 0.5

func _height_at(point: Vector2) -> float:
	var peak_mask := _peak_mask_at(point)
	# Skewed toward 0 so most of the map stays low, mountains only where the continent value is high
	var mountain_mask := maxf(pow(_noise01(_continent_noise, point), flatness), peak_mask)

	var height := _noise01(_detail_noise, point) * mountain_mask * max_height
	var ridge := 1.0 - absf(_ridge_noise.get_noise_3d(point.x, 0.0, point.y))
	height += ridge * mountain_mask * mountain_mask * mountain_ridge_height
	height += peak_mask * mountain_peak_height
	return _flatten_city_site(point, height)

# The strongest peak wins so overlapping peaks don't stack into spikes.
func _peak_mask_at(point: Vector2) -> float:
	var mask := 0.0
	for peak in mountain_peaks:
		var falloff := 1.0 - smoothstep(0.0, mountain_peak_radius, point.distance_to(peak))
		mask = maxf(mask, pow(falloff, mountain_peak_sharpness))
	return mask

func _flatten_city_site(point: Vector2, height: float) -> float:
	if not flatten_enabled:
		return height
	var outside := (point - flatten_center).abs() - Vector2(flatten_half_extent, flatten_half_extent)
	var distance := Vector2(maxf(outside.x, 0.0), maxf(outside.y, 0.0)).length()
	return lerpf(flatten_height, height, smoothstep(0.0, flatten_blend, distance))

func _color_for_height(height: float) -> Color:
	var rock_t := smoothstep(rock_height, snow_height, height)
	var snow_t := smoothstep(snow_height, snow_height + SNOW_BLEND, height)
	return GRASS_COLOR.lerp(ROCK_COLOR, rock_t).lerp(SNOW_COLOR, snow_t)

func _build_terrain() -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var half_size := terrain_size / 2.0
	for z in range(terrain_size):
		for x in range(terrain_size):
			var point := Vector2(x - half_size, z - half_size) * terrain_scale
			var height := _height_at(point)
			vertices.append(Vector3(point.x, height, point.y))
			uvs.append(Vector2(x, z) / terrain_size)
			colors.append(_color_for_height(height))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = _grid_indices()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.85

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.set_surface_override_material(0, material)
	return instance

# Two triangles per grid square.
func _grid_indices() -> PackedInt32Array:
	var indices := PackedInt32Array()
	for z in range(terrain_size - 1):
		for x in range(terrain_size - 1):
			var i: int = z * terrain_size + x
			indices.append(i)
			indices.append(i + 1)
			indices.append(i + terrain_size)
			indices.append(i + 1)
			indices.append(i + terrain_size + 1)
			indices.append(i + terrain_size)
	return indices

func _build_water() -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.35, 0.55, 0.75)
	material.roughness = 0.05
	material.metallic = 0.2
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var plane := PlaneMesh.new()
	plane.material = material
	plane.size = Vector2.ONE * terrain_size * terrain_scale

	var instance := MeshInstance3D.new()
	instance.mesh = plane
	instance.position.y = water_level
	return instance

