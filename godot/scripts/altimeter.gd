extends Control

## Vertical tape altimeter showing the Starship's altitude above sea level,
## with a digital readout so the exact height is always legible.

## Path to the Starship node this instrument reports on.
@export var starship_path: NodePath
## Metres of altitude spanned by the visible tape height.
@export var visible_range_meters: float = 400.0
@export var major_tick_step_meters: float = 100.0
@export var minor_tick_step_meters: float = 20.0

const BEZEL_COLOR := Color(0.05, 0.05, 0.05)
const TAPE_COLOR := Color(0.1, 0.1, 0.12, 0.9)
const TICK_COLOR := Color(1.0, 1.0, 1.0)
const READOUT_BG_COLOR := Color(0.0, 0.0, 0.0, 0.9)
const READOUT_COLOR := Color(1.0, 0.85, 0.0)

var _ship: Node3D = null

func _ready() -> void:
	_ship = get_node_or_null(starship_path) as Node3D
	clip_contents = true

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var rect_size: Vector2 = size
	var center_y: float = rect_size.y * 0.5
	var altitude: float = _ship.get_altitude() if _ship != null else 0.0
	var pixels_per_meter: float = rect_size.y / visible_range_meters
	var font := ThemeDB.fallback_font

	draw_rect(Rect2(Vector2.ZERO, rect_size), BEZEL_COLOR)
	draw_rect(Rect2(Vector2.ZERO, rect_size).grow(-3.0), TAPE_COLOR)

	var first_tick: float = floor((altitude - visible_range_meters * 0.5) / minor_tick_step_meters) * minor_tick_step_meters
	var tick := first_tick
	while tick <= altitude + visible_range_meters * 0.5:
		var y: float = center_y - (tick - altitude) * pixels_per_meter
		if y >= -4.0 and y <= rect_size.y + 4.0:
			var is_major: bool = int(roundf(tick)) % int(major_tick_step_meters) == 0
			var tick_length: float = 16.0 if is_major else 8.0
			draw_line(Vector2(rect_size.x - tick_length, y), Vector2(rect_size.x - 4.0, y), TICK_COLOR, 2.0 if is_major else 1.0)
			if is_major:
				var label := str(int(roundf(tick)))
				draw_string(font, Vector2(6.0, y + 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, rect_size.x - tick_length - 10.0, 13, TICK_COLOR)
		tick += minor_tick_step_meters

	# Fixed pointer marking the exact centre reading.
	draw_line(Vector2(rect_size.x - 18.0, center_y), Vector2(rect_size.x, center_y), READOUT_COLOR, 3.0)

	# Digital readout box, always shows the precise current altitude.
	var box := Rect2(Vector2(2.0, center_y - 12.0), Vector2(rect_size.x - 4.0, 24.0))
	draw_rect(box, READOUT_BG_COLOR)
	draw_rect(box, TICK_COLOR, false, 1.5)
	draw_string(font, Vector2(box.position.x + 4.0, center_y + 5.0), "%d m" % int(roundf(altitude)), HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 8.0, 16, READOUT_COLOR)
