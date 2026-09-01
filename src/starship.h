#pragma once

#include <Jolt/Jolt.h>

#include <Jolt/Physics/Body/BodyID.h>

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/vector3.hpp>

class StarshipWorld;

// Declares a float property backing field together with its accessors.
#define STARSHIP_PROPERTY(m_type, m_name)                    \
public:                                                      \
	void set_##m_name(m_type p_value) { m_name = p_value; }  \
	m_type get_##m_name() const { return m_name; }           \
                                                             \
private:                                                     \
	m_type m_name

// A rigid body flown with a classic six degree of freedom aerodynamic model:
// thrust along the nose, lift and drag from the relative wind, control moments
// from the stick, and static stability that weathervanes the nose into the
// airflow. It rolls down the runway on low friction "gear" until the wing
// produces enough lift to fly.
class Starship : public godot::Node3D {
	GDCLASS(Starship, godot::Node3D)

protected:
	static void _bind_methods();

public:
	Starship();
	~Starship() override;

	void _ready() override;
	void _exit_tree() override;

	// Driven by the owning StarshipWorld around the Jolt update.
	void pre_physics_step(double p_delta);
	void post_physics_step();

	void reset_to_start();

	double get_airspeed() const { return airspeed; }
	double get_altitude() const { return altitude; }
	double get_vertical_speed() const { return vertical_speed; }
	double get_angle_of_attack() const { return angle_of_attack; }
	double get_sideslip_angle() const { return sideslip_angle; }
	double get_thrust() const { return current_thrust; }
	double get_load_factor() const { return load_factor; }
	bool get_airborne() const { return airborne; }

	void set_throttle(double p_value);
	double get_throttle() const { return throttle; }

	// Airframe
	STARSHIP_PROPERTY(double, mass) = 22000.0;
	STARSHIP_PROPERTY(godot::Vector3, hull_half_extents) = godot::Vector3(1.6f, 1.6f, 10.0f);
	STARSHIP_PROPERTY(double, gear_friction) = 0.002;
	STARSHIP_PROPERTY(double, brake_friction) = 0.7;
	STARSHIP_PROPERTY(double, max_speed) = 3000.0;

	// Aerodynamics
	STARSHIP_PROPERTY(double, wing_area) = 260.0;
	STARSHIP_PROPERTY(double, mean_chord) = 6.5;
	STARSHIP_PROPERTY(double, wing_span) = 24.0;
	STARSHIP_PROPERTY(double, lift_coefficient_zero) = 0.2;
	STARSHIP_PROPERTY(double, lift_slope) = 4.6;
	STARSHIP_PROPERTY(double, stall_angle_degrees) = 16.0;
	STARSHIP_PROPERTY(double, drag_coefficient_zero) = 0.028;
	STARSHIP_PROPERTY(double, induced_drag_factor) = 0.055;
	STARSHIP_PROPERTY(double, side_force_coefficient) = 1.1;

	// Stability and damping derivatives
	STARSHIP_PROPERTY(double, pitch_stability) = 0.6;
	STARSHIP_PROPERTY(double, yaw_stability) = 0.16;
	STARSHIP_PROPERTY(double, pitch_damping) = 8.0;
	STARSHIP_PROPERTY(double, roll_damping) = 0.3;
	STARSHIP_PROPERTY(double, yaw_damping) = 0.5;

	// Control authority
	STARSHIP_PROPERTY(double, pitch_authority) = 0.15;
	STARSHIP_PROPERTY(double, roll_authority) = 0.10;
	STARSHIP_PROPERTY(double, yaw_authority) = 0.035;
	STARSHIP_PROPERTY(double, control_smoothing) = 8.0;

	// Propulsion
	STARSHIP_PROPERTY(double, max_thrust) = 300000.0;
	STARSHIP_PROPERTY(double, atmospheric_thrust_ratio) = 0.35;
	STARSHIP_PROPERTY(double, throttle_rate) = 0.5;
	STARSHIP_PROPERTY(bool, use_input) = true;

private:
	void read_input(double p_delta);
	void apply_forces();

	StarshipWorld *sim_world = nullptr;
	JPH::BodyID body;

	godot::Transform3D start_transform;

	double throttle = 0.0;
	double pitch_input = 0.0;
	double roll_input = 0.0;
	double yaw_input = 0.0;
	double brake_input = 0.0;

	double airspeed = 0.0;
	double altitude = 0.0;
	double vertical_speed = 0.0;
	double angle_of_attack = 0.0;
	double sideslip_angle = 0.0;
	double current_thrust = 0.0;
	double load_factor = 1.0;
	bool airborne = false;
};

#undef STARSHIP_PROPERTY
