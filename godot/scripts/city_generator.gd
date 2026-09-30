<<<<<<< HEAD
@tool
extends Node3D

## Scatters a low-poly city grid around the runway so the air strip sits
## inside a small metropolitan area instead of open ground. Buildings are
## rendered via MultiMeshInstance3D (one per material style) for performance.

@export var city_half_extent: float = 2600.0  # how far the city grid reaches from the runway centerline
@export var block_spacing: float = 100.0  # grid cell size (building footprint + street gap)
@export var cell_jitter: float = 18.0  # random offset applied within each cell

@export var runway_clear_half_width: float = 220.0  # keep buildings this far from the runway centerline (x)
@export var runway_clear_half_length: float = 2150.0  # keep buildings this far from the runway centerline (z)

@export var min_building_size: float = 26.0
@export var max_building_size: float = 48.0
@export var min_height: float = 14.0
@export var max_height: float = 95.0

@export var seed_value: int = 1337

func _ready() -> void:
	_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()

	var styles := _make_styles()
	var transforms_by_style: Array = []
	for _i in styles.size():
		transforms_by_style.append([])

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var x := -city_half_extent
	while x <= city_half_extent:
		var z := -city_half_extent
		while z <= city_half_extent:
			# Leave a clear rectangular corridor around the runway/apron
			if not (absf(x) < runway_clear_half_width and absf(z) < runway_clear_half_length):
				var world_x := x + rng.randf_range(-cell_jitter, cell_jitter)
				var world_z := z + rng.randf_range(-cell_jitter, cell_jitter)
				var footprint := rng.randf_range(min_building_size, max_building_size)
				var height := rng.randf_range(min_height, max_height)
				var basis := Basis.IDENTITY.scaled(Vector3(footprint, height, footprint))
				var origin := Vector3(world_x, height * 0.5, world_z)
				var style_index := rng.randi_range(0, styles.size() - 1)
				transforms_by_style[style_index].append(Transform3D(basis, origin))
			z += block_spacing
		x += block_spacing

	for i in styles.size():
		_add_style_multimesh(styles[i], transforms_by_style[i])

func _make_styles() -> Array:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.32, 0.46, 0.58)
	glass.metallic = 0.5
	glass.roughness = 0.2

	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.62, 0.61, 0.58)
	concrete.roughness = 0.9

	var brick := StandardMaterial3D.new()
	brick.albedo_color = Color(0.5, 0.27, 0.22)
	brick.roughness = 0.85

	var sandstone := StandardMaterial3D.new()
	sandstone.albedo_color = Color(0.72, 0.64, 0.48)
	sandstone.roughness = 0.8

	return [glass, concrete, brick, sandstone]

func _add_style_multimesh(material: Material, transforms: Array) -> void:
	if transforms.is_empty():
		return

	var box := BoxMesh.new()
	box.material = material

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])

	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
=======
extends Node3D

## Builds a small city from the Kenney "Starter Kit City Builder" models
## (CC0, see assets/city/LICENSE.md). Roads run on a regular grid, the blocks
## between them are filled with buildings, pavement and trees. The node origin
## is the centre of the city.

@export var tile_size: float = 40.0  # World size of one model tile (the models are 1x1)
@export var grid_size: int = 17  # Tiles per side, odd so a road crosses the centre
@export var block_size: int = 4  # Distance in tiles between two roads
@export var seed_value: int = 7
@export var max_height_stretch: float = 2.2  # Vertical scale of the tallest downtown buildings

const MODEL_DIR := "res://assets/city/"
const BUILDINGS := ["building-small-a", "building-small-b", "building-small-c", "building-small-d"]
const FILLERS := ["grass-trees", "grass-trees-tall", "pavement", "grass"]

var _rng := RandomNumberGenerator.new()
var _scenes := {}

func _ready() -> void:
	_rng.seed = seed_value
	_build()

func _build() -> void:
	var half := grid_size / 2
	for gz in range(grid_size):
		for gx in range(grid_size):
			var cell := Vector2i(gx - half, gz - half)
			var position_3d := Vector3(cell.x * tile_size, 0.0, cell.y * tile_size)
			_place_cell(cell, position_3d, half)

func _is_road_line(index: int) -> bool:
	return posmod(index, block_size) == 0

func _place_cell(cell: Vector2i, position_3d: Vector3, half: int) -> void:
	var road_x := _is_road_line(cell.x)
	var road_z := _is_road_line(cell.y)

	if road_x and road_z:
		_spawn("road-intersection", position_3d, 0.0, 1.0)
	elif road_x:
		_spawn("road-straight", position_3d, 0.0, 1.0)
	elif road_z:
		_spawn("road-straight", position_3d, PI * 0.5, 1.0)
	else:
		_place_lot(cell, position_3d, half)

func _place_lot(cell: Vector2i, position_3d: Vector3, half: int) -> void:
	var center_distance := Vector2(cell).length() / float(half)

	if cell == Vector2i.ZERO or (absi(cell.x) <= 1 and absi(cell.y) <= 1):
		# The plaza next to the central crossing
		_spawn("pavement-fountain" if cell == Vector2i(1, 1) else "pavement", position_3d, 0.0, 1.0)
		return

	# Keep the outskirts greener and lower than the downtown core
	var building_chance := lerpf(0.95, 0.35, center_distance)
	if _rng.randf() > building_chance:
		_spawn(FILLERS[_rng.randi() % FILLERS.size()], position_3d, 0.0, 1.0)
		return

	var model: String = "building-garage" if _rng.randf() < 0.12 else BUILDINGS[_rng.randi() % BUILDINGS.size()]
	var stretch := 1.0
	if model != "building-garage":
		stretch = lerpf(max_height_stretch, 1.0, center_distance) * _rng.randf_range(0.7, 1.0)
		stretch = maxf(stretch, 1.0)

	_spawn("grass", position_3d, 0.0, 1.0)
	_spawn(model, position_3d, _facing_road(cell), stretch)

# Yaw that turns a building's front (+Z) towards the closest road.
func _facing_road(cell: Vector2i) -> float:
	var local_x := posmod(cell.x, block_size)
	var local_z := posmod(cell.y, block_size)
	var to_road := Vector2.ZERO
	if local_x == 1:
		to_road.x = -1.0
	elif local_x == block_size - 1:
		to_road.x = 1.0
	elif local_z == 1:
		to_road.y = -1.0
	elif local_z == block_size - 1:
		to_road.y = 1.0
	else:
		to_road = Vector2(0.0, 1.0).rotated(_rng.randi_range(0, 3) * PI * 0.5)
	return atan2(to_road.x, to_road.y)

func _spawn(model: String, position_3d: Vector3, yaw: float, height_stretch: float) -> void:
	if not _scenes.has(model):
		_scenes[model] = load(MODEL_DIR + model + ".glb")
	var instance: Node3D = _scenes[model].instantiate()
	instance.position = position_3d
	instance.rotation.y = yaw
	instance.scale = Vector3(tile_size, tile_size * height_stretch, tile_size)
>>>>>>> 43bcfc8167ec52213a2fe282ddd042a6764832b7
	add_child(instance)
