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
	add_child(instance)
