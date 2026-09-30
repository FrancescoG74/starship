class_name CityGenerator
extends Node3D

## Builds a small city from the Kenney "Starter Kit City Builder" models
## (CC0, see assets/city/LICENSE.md). Roads run on a regular grid, the blocks
## between them are filled with buildings, pavement and trees. The node origin
## is the centre of the city.

@export var tile_size: float = 40.0  # World size of one model tile (the models are 1x1)
@export var grid_size: int = 31  # Tiles per side, odd so a road crosses the centre
@export var block_size: int = 4  # Distance in tiles between two roads
@export var seed_value: int = 7
@export var max_height_stretch: float = 2.2  # Vertical scale of the tallest downtown buildings

const MODEL_DIR := "res://assets/city/"
const ROAD_STRAIGHT := "road-straight"
const ROAD_INTERSECTION := "road-intersection"
const GRASS := "grass"
const PAVEMENT := "pavement"
const FOUNTAIN := "pavement-fountain"
const GARAGE := "building-garage"
const BUILDINGS := ["building-small-a", "building-small-b", "building-small-c", "building-small-d"]
const FILLERS := ["grass-trees", "grass-trees-tall", PAVEMENT, GRASS]

const ROAD_SURFACE_HEIGHT := 0.05  # Top of the kit's road tiles, in model units
const GARAGE_CHANCE := 0.12
const DOWNTOWN_BUILDING_CHANCE := 0.95
const OUTSKIRTS_BUILDING_CHANCE := 0.35

var _rng := RandomNumberGenerator.new()
var _scenes := {}  # Model name -> PackedScene

func _ready() -> void:
	_rng.seed = seed_value
	var half := _half_grid()
	for z in range(-half, half + 1):
		for x in range(-half, half + 1):
			_place_cell(Vector2i(x, z))

## Perimeter of every block enclosed by roads, as 4 corners on the road surface (local space).
func get_block_loops() -> Array[PackedVector3Array]:
	var lines := _road_lines()
	var y := ROAD_SURFACE_HEIGHT * tile_size
	var loops: Array[PackedVector3Array] = []
	for zi in range(lines.size() - 1):
		for xi in range(lines.size() - 1):
			var x0: float = lines[xi] * tile_size
			var x1: float = lines[xi + 1] * tile_size
			var z0: float = lines[zi] * tile_size
			var z1: float = lines[zi + 1] * tile_size
			loops.append(PackedVector3Array([
				Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1),
			]))
	return loops

func _half_grid() -> int:
	return grid_size / 2

func _is_road_line(index: int) -> bool:
	return posmod(index, block_size) == 0

func _road_lines() -> Array[int]:
	var half := _half_grid()
	var lines: Array[int] = []
	for i in range(-half, half + 1):
		if _is_road_line(i):
			lines.append(i)
	return lines

func _place_cell(cell: Vector2i) -> void:
	var tile_position := Vector3(cell.x, 0.0, cell.y) * tile_size
	var road_x := _is_road_line(cell.x)
	var road_z := _is_road_line(cell.y)

	if road_x and road_z:
		_spawn(ROAD_INTERSECTION, tile_position)
	elif road_x:
		_spawn(ROAD_STRAIGHT, tile_position)
	elif road_z:
		_spawn(ROAD_STRAIGHT, tile_position, PI * 0.5)
	else:
		_place_lot(cell, tile_position)

func _place_lot(cell: Vector2i, tile_position: Vector3) -> void:
	# The plaza around the central crossing
	if absi(cell.x) <= 1 and absi(cell.y) <= 1:
		_spawn(FOUNTAIN if cell == Vector2i(1, 1) else PAVEMENT, tile_position)
		return

	# 0 downtown, 1 at the edge: the outskirts stay greener and lower
	var center_distance := Vector2(cell).length() / float(_half_grid())
	if _rng.randf() > lerpf(DOWNTOWN_BUILDING_CHANCE, OUTSKIRTS_BUILDING_CHANCE, center_distance):
		_spawn(_pick(FILLERS), tile_position)
		return

	var model: String = GARAGE if _rng.randf() < GARAGE_CHANCE else _pick(BUILDINGS)
	var stretch: float = 1.0 if model == GARAGE else _building_stretch(center_distance)
	_spawn(GRASS, tile_position)
	_spawn(model, tile_position, _facing_road(cell), stretch)

func _building_stretch(center_distance: float) -> float:
	return maxf(1.0, lerpf(max_height_stretch, 1.0, center_distance) * _rng.randf_range(0.7, 1.0))

func _pick(options: Array) -> String:
	return options[_rng.randi() % options.size()]

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

func _spawn(model: String, tile_position: Vector3, yaw := 0.0, height_stretch := 1.0) -> void:
	var instance: Node3D = _model_scene(model).instantiate()
	instance.position = tile_position
	instance.rotation.y = yaw
	instance.scale = Vector3(tile_size, tile_size * height_stretch, tile_size)
	add_child(instance)

func _model_scene(model: String) -> PackedScene:
	if not _scenes.has(model):
		_scenes[model] = load(MODEL_DIR + model + ".glb")
	return _scenes[model]
