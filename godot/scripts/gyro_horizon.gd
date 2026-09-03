extends Control

## Artificial horizon (attitude indicator) showing the pitch and bank of the
## Starship node so it is possible to fly attitude when the runway or ground
## is not in view.

## Path to the Starship node this indicator reports on.
@export var starship_path: NodePath
## Degrees of pitch shown from the horizon line to the top/bottom edge.
@export var pitch_degrees_per_half_height: float = 45.0

const SKY_COLOR := Color(0.25, 0.55, 0.85)
const GROUND_COLOR := Color(0.45, 0.32, 0.16)
const LINE_COLOR := Color(1.0, 1.0, 1.0)
const AIRCRAFT_COLOR := Color(1.0, 0.85, 0.0)
const BEZEL_COLOR := Color(0.05, 0.05, 0.05)

var _ship: Node3D = null

func _ready() -> void:
	_ship = get_node_or_null(starship_path) as Node3D
	clip_contents = true

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var fill_extent: float = maxf(size.x, size.y) * 2.0

	var pitch := 0.0
	var roll := 0.0
	if _ship != null:
		var angles := _pitch_and_roll(_ship)
		pitch = angles.x
		roll = angles.y

	var pixels_per_radian: float = (size.y * 0.5) / deg_to_rad(pitch_degrees_per_half_height)
	var horizon_offset: float = -pitch * pixels_per_radian

	draw_circle(center, maxf(size.x, size.y) * 0.5, BEZEL_COLOR)

	# The ball rotates opposite the bank so it reads as the real, level
	# horizon while the aircraft symbol below stays fixed to the case.
	draw_set_transform(center, -roll, Vector2.ONE)
	draw_rect(Rect2(Vector2(-fill_extent, horizon_offset - fill_extent), Vector2(fill_extent * 2.0, fill_extent)), SKY_COLOR)
	draw_rect(Rect2(Vector2(-fill_extent, horizon_offset), Vector2(fill_extent * 2.0, fill_extent)), GROUND_COLOR)
	draw_line(Vector2(-fill_extent, horizon_offset), Vector2(fill_extent, horizon_offset), LINE_COLOR, 2.0)

	var ladder_step_degrees := 15.0
	var ladder_max_degrees := 45.0
	var rung := ladder_step_degrees
	while rung <= ladder_max_degrees:
		var line_offset := deg_to_rad(rung) * pixels_per_radian
		var half_width := 18.0 if int(rung) % 30 == 0 else 10.0
		draw_line(Vector2(-half_width, horizon_offset - line_offset), Vector2(half_width, horizon_offset - line_offset), LINE_COLOR, 1.5)
		draw_line(Vector2(-half_width, horizon_offset + line_offset), Vector2(half_width, horizon_offset + line_offset), LINE_COLOR, 1.5)
		rung += ladder_step_degrees

	var dial_radius: float = minf(size.x, size.y) * 0.5 - 4.0
	for bank_mark_degrees in [-60, -45, -30, -20, -10, 0, 10, 20, 30, 45, 60]:
		var mark_angle := deg_to_rad(float(bank_mark_degrees))
		var direction := Vector2(sin(mark_angle), -cos(mark_angle))
		var inner_radius := dial_radius - (14.0 if bank_mark_degrees == 0 else 8.0)
		draw_line(direction * inner_radius, direction * dial_radius, LINE_COLOR, 2.0)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Fixed bank pointer at the top of the dial (case-mounted, does not roll).
	var pointer_tip: Vector2 = center + Vector2(0.0, -dial_radius - 2.0)
	draw_colored_polygon(PackedVector2Array([
		pointer_tip,
		pointer_tip + Vector2(-6.0, -9.0),
		pointer_tip + Vector2(6.0, -9.0),
	]), LINE_COLOR)

	# Fixed aircraft reference symbol representing the nose.
	draw_line(center + Vector2(-26.0, 0.0), center + Vector2(-8.0, 0.0), AIRCRAFT_COLOR, 3.0)
	draw_line(center + Vector2(8.0, 0.0), center + Vector2(26.0, 0.0), AIRCRAFT_COLOR, 3.0)
	draw_circle(center, 3.0, AIRCRAFT_COLOR)

func _pitch_and_roll(ship: Node3D) -> Vector2:
	var basis := ship.global_transform.basis
	var forward := -basis.z
	var right := basis.x

	var pitch := asin(clampf(forward.y, -1.0, 1.0))

	var right_level := forward.cross(Vector3.UP)
	if right_level.length_squared() < 0.0001:
		# Looking straight up or down: bank has no meaningful reference, keep it level.
		return Vector2(pitch, 0.0)
	right_level = right_level.normalized()
	var up_level := right_level.cross(forward)
	var roll := atan2(right.dot(up_level), right.dot(right_level))
	return Vector2(pitch, roll)
