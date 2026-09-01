extends Node3D

var world: Node3D
var ship: Node3D
var elapsed := 0.0
var reported := 0.0

func _ready() -> void:
	world = ClassDB.instantiate("StarshipWorld")
	add_child(world)
	ship = ClassDB.instantiate("Starship")
	ship.position = Vector3(0.0, 1.62, 1800.0)
	world.add_child(ship)

func _physics_process(delta: float) -> void:
	elapsed += delta
	Input.action_press("starship_throttle_up", 1.0)
	if elapsed > 6.0 and elapsed < 9.0:
		Input.action_press("starship_pitch_up", 1.0)
	else:
		Input.action_release("starship_pitch_up")

	if elapsed - reported >= 2.0:
		reported = elapsed
		print("t=%5.1f  thr=%.2f  ias=%7.1f  alt=%8.1f  vs=%+7.1f  aoa=%+6.1f  z=%8.1f  %s" % [
			elapsed, ship.throttle, ship.get_airspeed(), ship.get_altitude(),
			ship.get_vertical_speed(), rad_to_deg(ship.get_angle_of_attack()),
			ship.global_position.z, "AIR" if ship.get_airborne() else "GND"])

	if elapsed > 60.0:
		get_tree().quit()
