extends Node3D

## Background traffic: low-poly cars that endlessly circle the blocks of the
## parent CityGenerator's road grid. Following a block perimeter keeps every
## car on the road without any pathfinding.

@export_range(40, 100, 1) var car_count: int = 70
@export var car_speed_min: float = 6.0  # m/s
@export var car_speed_max: float = 12.0  # m/s
@export var seed_value: int = 5007

const CAR_COLORS := [
	Color(0.72, 0.1, 0.1), Color(0.1, 0.25, 0.68), Color(0.82, 0.82, 0.84),
	Color(0.12, 0.12, 0.14), Color(0.88, 0.74, 0.05), Color(0.16, 0.5, 0.22),
]
const BODY_SIZE := Vector3(1.9, 0.65, 4.3)
const BODY_OFFSET := Vector3(0.0, 0.45, 0.0)
const CABIN_SIZE := Vector3(1.6, 0.5, 2.2)
const CABIN_OFFSET := Vector3(0.0, 0.9, -0.2)
const WHEEL_RADIUS := 0.28
const WHEEL_WIDTH := 0.24
const WHEEL_OFFSETS := [
	Vector3(0.85, WHEEL_RADIUS, 1.4), Vector3(-0.85, WHEEL_RADIUS, 1.4),
	Vector3(0.85, WHEEL_RADIUS, -1.4), Vector3(-0.85, WHEEL_RADIUS, -1.4),
]

class Car:
	var node: Node3D
	var loop: PackedVector3Array  # 4 corners of a square block
	var side_length: float
	var distance: float  # Travelled along the perimeter
	var direction: float  # +1 or -1
	var speed: float

var _cars: Array[Car] = []
var _body_meshes: Array[BoxMesh] = []  # One per colour, shared by every car
var _cabin_mesh: BoxMesh
var _wheel_mesh: CylinderMesh

func _ready() -> void:
	var city := get_parent() as CityGenerator
	if city == null:
		push_error("City traffic must be a child of a CityGenerator node.")
		return

	var loops := city.get_block_loops()
	if loops.is_empty():
		return

	_build_shared_meshes()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(car_count):
		var car := Car.new()
		car.loop = loops[i % loops.size()]
		car.side_length = car.loop[0].distance_to(car.loop[1])
		car.node = _make_car_node(_body_meshes[rng.randi() % _body_meshes.size()])
		car.distance = rng.randf() * car.side_length * 4.0
		car.direction = 1.0 if rng.randf() < 0.5 else -1.0
		car.speed = rng.randf_range(car_speed_min, car_speed_max)
		add_child(car.node)
		_cars.append(car)

func _process(delta: float) -> void:
	for car in _cars:
		car.distance = fposmod(car.distance + car.direction * car.speed * delta, car.side_length * 4.0)

		var side := mini(int(car.distance / car.side_length), 3)
		var corner_a := car.loop[side]
		var corner_b := car.loop[(side + 1) % 4]
		car.node.position = corner_a.lerp(corner_b, fposmod(car.distance, car.side_length) / car.side_length)

		var heading: Vector3 = corner_b - corner_a if car.direction > 0.0 else corner_a - corner_b
		car.node.rotation.y = atan2(heading.x, heading.z)

func _build_shared_meshes() -> void:
	for color in CAR_COLORS:
		_body_meshes.append(_box_mesh(BODY_SIZE, _material(color, 0.3, 0.4)))
	_cabin_mesh = _box_mesh(CABIN_SIZE, _material(Color(0.05, 0.08, 0.1), 0.1, 0.1))

	_wheel_mesh = CylinderMesh.new()
	_wheel_mesh.top_radius = WHEEL_RADIUS
	_wheel_mesh.bottom_radius = WHEEL_RADIUS
	_wheel_mesh.height = WHEEL_WIDTH
	_wheel_mesh.material = _material(Color(0.05, 0.05, 0.05), 0.0, 0.9)

# The Kenney city kit ships no vehicle model, so cars are assembled from primitives.
func _make_car_node(body_mesh: BoxMesh) -> Node3D:
	var car := Node3D.new()
	_add_part(car, body_mesh, BODY_OFFSET)
	_add_part(car, _cabin_mesh, CABIN_OFFSET)
	for offset in WHEEL_OFFSETS:
		var wheel := _add_part(car, _wheel_mesh, offset)
		wheel.rotation.z = PI * 0.5
	return car

func _add_part(car: Node3D, mesh: Mesh, offset: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = offset
	car.add_child(part)
	return part

func _box_mesh(box_size: Vector3, material: Material) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = material
	return mesh

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
