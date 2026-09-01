@tool
extends Node3D

## Spawns the centre line dashes and the edge markers of the air strip so the
## ground rush gives a sense of speed during the take off run.

@export var runway_length: float = 4000.0
@export var runway_width: float = 60.0
@export var dash_spacing: float = 60.0

func _ready() -> void:
	_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()

	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(1.6, 0.05, 24.0)
	var dash_material := StandardMaterial3D.new()
	dash_material.albedo_color = Color(0.92, 0.92, 0.88)
	dash_mesh.material = dash_material

	var edge_mesh := BoxMesh.new()
	edge_mesh.size = Vector3(0.6, 0.05, dash_spacing * 0.5)
	edge_mesh.material = dash_material

	var half_length := runway_length * 0.5
	var half_width := runway_width * 0.5
	var position_z := -half_length + dash_spacing

	while position_z < half_length - dash_spacing:
		_add_marker(dash_mesh, Vector3(0.0, 0.03, position_z))
		_add_marker(edge_mesh, Vector3(-half_width + 1.0, 0.03, position_z))
		_add_marker(edge_mesh, Vector3(half_width - 1.0, 0.03, position_z))
		position_z += dash_spacing

func _add_marker(mesh: Mesh, marker_position: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = marker_position
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
