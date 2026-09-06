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
	add_child(instance)
