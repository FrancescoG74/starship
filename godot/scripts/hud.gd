extends Label

## Path to the Starship node this HUD reports on.
@export var starship_path: NodePath

var _ship: Node3D = null

func _ready() -> void:
	_ship = get_node_or_null(starship_path) as Node3D

func _process(_delta: float) -> void:
	if _ship == null:
		text = "No Starship node found."
		return

	var throttle: float = _ship.throttle
	var bars: int = int(round(throttle * 10.0))
	var gauge: String = "|".repeat(bars).rpad(10, ".")

	text = "\n".join([
		"THROTTLE  [%s] %3d%%" % [gauge, int(round(throttle * 100.0))],
		"AIRSPEED  %7.1f m/s  (%5.0f km/h)" % [_ship.get_airspeed(), _ship.get_airspeed() * 3.6],
		"ALTITUDE  %7.1f m" % _ship.get_altitude(),
		"CLIMB     %+7.1f m/s" % _ship.get_vertical_speed(),
		"AOA       %+7.1f deg" % rad_to_deg(_ship.get_angle_of_attack()),
		"LOAD      %7.2f g" % _ship.get_load_factor(),
		"STATE     %s" % ("AIRBORNE" if _ship.get_airborne() else "ON RUNWAY"),
		"",
		"Shift/Ctrl throttle - W/S pitch - A/D roll - Q/E rudder",
		"B wheel brakes - R reset to the runway",
	])
