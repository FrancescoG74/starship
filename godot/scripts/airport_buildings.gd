@tool
extends Node3D

## Spawns a small airport complex (control tower + hangars) beside the
## runway so the air strip has some ground infrastructure around it.

@export var runway_half_width: float = 30.0
@export var apron_offset: float = 60.0  # distance from runway centerline to the building row
@export var tower_position_z: float = 1600.0  # placed near the approach/spawn end of the strip

func _ready() -> void:
	_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()

	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.72, 0.70, 0.66)
	concrete.roughness = 0.9

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.35, 0.55, 0.65, 0.85)
	glass.metallic = 0.4
	glass.roughness = 0.15
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var roof := StandardMaterial3D.new()
	roof.albedo_color = Color(0.55, 0.18, 0.16)
	roof.roughness = 0.7

	var x := runway_half_width + apron_offset

	_build_control_tower(Vector3(x, 0.0, tower_position_z), concrete, glass)
	_build_hangar(Vector3(x + 45.0, 0.0, tower_position_z + 130.0), concrete, roof)
	_build_hangar(Vector3(x + 45.0, 0.0, tower_position_z + 210.0), concrete, roof)

func _build_control_tower(base_position: Vector3, wall_material: Material, glass_material: Material) -> void:
	var tower := Node3D.new()
	tower.position = base_position
	add_child(tower)

	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(14.0, 10.0, 14.0)
	base_mesh.material = wall_material
	_add_box(tower, base_mesh, Vector3(0.0, 5.0, 0.0))

	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(6.0, 30.0, 6.0)
	shaft_mesh.material = wall_material
	_add_box(tower, shaft_mesh, Vector3(0.0, 25.0, 0.0))

	# Glass observation cab that overhangs the shaft, like a real ATC tower
	var cab_mesh := BoxMesh.new()
	cab_mesh.size = Vector3(12.0, 6.0, 12.0)
	cab_mesh.material = glass_material
	_add_box(tower, cab_mesh, Vector3(0.0, 43.0, 0.0))

	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(13.0, 0.6, 13.0)
	roof_mesh.material = wall_material
	_add_box(tower, roof_mesh, Vector3(0.0, 46.3, 0.0))

func _build_hangar(base_position: Vector3, wall_material: Material, roof_material: Material) -> void:
	var hangar := Node3D.new()
	hangar.position = base_position
	add_child(hangar)

	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(40.0, 12.0, 30.0)
	body_mesh.material = wall_material
	_add_box(hangar, body_mesh, Vector3(0.0, 6.0, 0.0))

	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(42.0, 1.0, 32.0)
	roof_mesh.material = roof_material
	_add_box(hangar, roof_mesh, Vector3(0.0, 12.5, 0.0))

func _add_box(parent: Node3D, mesh: Mesh, local_position: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = local_position
	parent.add_child(instance)
