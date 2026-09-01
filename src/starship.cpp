#include "starship.h"

#include "conversions.h"
#include "jolt_world.h"
#include "starship_world.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/input_map.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/error_macros.hpp>

#include <algorithm>
#include <cmath>

using namespace godot;

namespace {

double axis_strength(const char *p_negative, const char *p_positive) {
	Input *input = Input::get_singleton();
	InputMap *map = InputMap::get_singleton();
	if (input == nullptr || map == nullptr) {
		return 0.0;
	}
	double value = 0.0;
	const StringName positive(p_positive);
	const StringName negative(p_negative);
	if (map->has_action(positive)) {
		value += input->get_action_strength(positive);
	}
	if (map->has_action(negative)) {
		value -= input->get_action_strength(negative);
	}
	return value;
}

double action_strength(const char *p_action) {
	Input *input = Input::get_singleton();
	InputMap *map = InputMap::get_singleton();
	if (input == nullptr || map == nullptr) {
		return 0.0;
	}
	const StringName action(p_action);
	return map->has_action(action) ? input->get_action_strength(action) : 0.0;
}

bool action_just_pressed(const char *p_action) {
	Input *input = Input::get_singleton();
	InputMap *map = InputMap::get_singleton();
	if (input == nullptr || map == nullptr) {
		return false;
	}
	const StringName action(p_action);
	return map->has_action(action) && input->is_action_just_pressed(action);
}

double approach(double p_current, double p_target, double p_weight) {
	return p_current + (p_target - p_current) * std::clamp(p_weight, 0.0, 1.0);
}

constexpr double DEGREES_TO_RADIANS = 0.017453292519943295;

} // namespace

Starship::Starship() {}

Starship::~Starship() {}

void Starship::_bind_methods() {
#define BIND_PROPERTY(m_variant, m_name, m_hint, m_hint_string)                                                 \
	ClassDB::bind_method(D_METHOD("set_" #m_name, "value"), &Starship::set_##m_name);                           \
	ClassDB::bind_method(D_METHOD("get_" #m_name), &Starship::get_##m_name);                                    \
	ADD_PROPERTY(PropertyInfo(Variant::m_variant, #m_name, m_hint, m_hint_string), "set_" #m_name, "get_" #m_name);

	ADD_GROUP("Airframe", "");
	BIND_PROPERTY(FLOAT, mass, PROPERTY_HINT_RANGE, "100,500000,1,suffix:kg")
	BIND_PROPERTY(VECTOR3, hull_half_extents, PROPERTY_HINT_NONE, "suffix:m")
	BIND_PROPERTY(FLOAT, gear_friction, PROPERTY_HINT_RANGE, "0,1,0.001")
	BIND_PROPERTY(FLOAT, brake_friction, PROPERTY_HINT_RANGE, "0,2,0.01")
	BIND_PROPERTY(FLOAT, max_speed, PROPERTY_HINT_RANGE, "100,20000,1,suffix:m/s")

	ADD_GROUP("Aerodynamics", "");
	BIND_PROPERTY(FLOAT, wing_area, PROPERTY_HINT_RANGE, "1,2000,0.1,suffix:m\u00b2")
	BIND_PROPERTY(FLOAT, mean_chord, PROPERTY_HINT_RANGE, "0.1,50,0.01,suffix:m")
	BIND_PROPERTY(FLOAT, wing_span, PROPERTY_HINT_RANGE, "0.1,200,0.01,suffix:m")
	BIND_PROPERTY(FLOAT, lift_coefficient_zero, PROPERTY_HINT_RANGE, "-1,2,0.001")
	BIND_PROPERTY(FLOAT, lift_slope, PROPERTY_HINT_RANGE, "0,10,0.01")
	BIND_PROPERTY(FLOAT, stall_angle_degrees, PROPERTY_HINT_RANGE, "1,45,0.1,suffix:\u00b0")
	BIND_PROPERTY(FLOAT, drag_coefficient_zero, PROPERTY_HINT_RANGE, "0,1,0.0001")
	BIND_PROPERTY(FLOAT, induced_drag_factor, PROPERTY_HINT_RANGE, "0,1,0.0001")
	BIND_PROPERTY(FLOAT, side_force_coefficient, PROPERTY_HINT_RANGE, "0,5,0.01")

	ADD_GROUP("Stability", "");
	BIND_PROPERTY(FLOAT, pitch_stability, PROPERTY_HINT_RANGE, "0,5,0.01")
	BIND_PROPERTY(FLOAT, yaw_stability, PROPERTY_HINT_RANGE, "0,5,0.01")
	BIND_PROPERTY(FLOAT, pitch_damping, PROPERTY_HINT_RANGE, "0,50,0.01")
	BIND_PROPERTY(FLOAT, roll_damping, PROPERTY_HINT_RANGE, "0,50,0.01")
	BIND_PROPERTY(FLOAT, yaw_damping, PROPERTY_HINT_RANGE, "0,50,0.01")

	ADD_GROUP("Controls", "");
	BIND_PROPERTY(FLOAT, pitch_authority, PROPERTY_HINT_RANGE, "0,2,0.001")
	BIND_PROPERTY(FLOAT, roll_authority, PROPERTY_HINT_RANGE, "0,2,0.001")
	BIND_PROPERTY(FLOAT, yaw_authority, PROPERTY_HINT_RANGE, "0,2,0.001")
	BIND_PROPERTY(FLOAT, control_smoothing, PROPERTY_HINT_RANGE, "0.1,50,0.1")
	BIND_PROPERTY(BOOL, use_input, PROPERTY_HINT_NONE, "")

	ADD_GROUP("Propulsion", "");
	BIND_PROPERTY(FLOAT, max_thrust, PROPERTY_HINT_RANGE, "0,50000000,100,suffix:N")
	BIND_PROPERTY(FLOAT, atmospheric_thrust_ratio, PROPERTY_HINT_RANGE, "0,1,0.01")
	BIND_PROPERTY(FLOAT, throttle_rate, PROPERTY_HINT_RANGE, "0.01,10,0.01")

#undef BIND_PROPERTY

	ADD_GROUP("", "");
	ClassDB::bind_method(D_METHOD("set_throttle", "value"), &Starship::set_throttle);
	ClassDB::bind_method(D_METHOD("get_throttle"), &Starship::get_throttle);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "throttle", PROPERTY_HINT_RANGE, "0,1,0.001"), "set_throttle", "get_throttle");

	ClassDB::bind_method(D_METHOD("get_airspeed"), &Starship::get_airspeed);
	ClassDB::bind_method(D_METHOD("get_altitude"), &Starship::get_altitude);
	ClassDB::bind_method(D_METHOD("get_vertical_speed"), &Starship::get_vertical_speed);
	ClassDB::bind_method(D_METHOD("get_angle_of_attack"), &Starship::get_angle_of_attack);
	ClassDB::bind_method(D_METHOD("get_sideslip_angle"), &Starship::get_sideslip_angle);
	ClassDB::bind_method(D_METHOD("get_thrust"), &Starship::get_thrust);
	ClassDB::bind_method(D_METHOD("get_load_factor"), &Starship::get_load_factor);
	ClassDB::bind_method(D_METHOD("get_airborne"), &Starship::get_airborne);
	ClassDB::bind_method(D_METHOD("reset_to_start"), &Starship::reset_to_start);
}

void Starship::_ready() {
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}

	for (Node *ancestor = get_parent(); ancestor != nullptr; ancestor = ancestor->get_parent()) {
		sim_world = Object::cast_to<StarshipWorld>(ancestor);
		if (sim_world != nullptr) {
			break;
		}
	}
	ERR_FAIL_NULL_MSG(sim_world, "Starship must be a descendant of a StarshipWorld node.");

	start_transform = get_global_transform();
	sim_world->register_craft(this);
}

void Starship::_exit_tree() {
	if (sim_world != nullptr) {
		sim_world->unregister_craft(this);
		starship::JoltWorld *world = sim_world->get_physics_world();
		if (world != nullptr) {
			world->remove_body(body);
		}
		sim_world = nullptr;
	}
	body = JPH::BodyID();
}

void Starship::set_throttle(double p_value) {
	throttle = std::clamp(p_value, 0.0, 1.0);
}

void Starship::pre_physics_step(double p_delta) {
	starship::JoltWorld *world = sim_world != nullptr ? sim_world->get_physics_world() : nullptr;
	if (world == nullptr) {
		return;
	}

	if (body.IsInvalid()) {
		body = world->add_dynamic_box(
				starship::to_jolt(hull_half_extents),
				starship::to_jolt_r(start_transform.origin),
				starship::to_jolt(start_transform.basis.get_rotation_quaternion()),
				static_cast<float>(mass),
				static_cast<float>(gear_friction),
				static_cast<float>(max_speed));
		ERR_FAIL_COND_MSG(body.IsInvalid(), "Could not create the Jolt body for the starship.");
	}

	read_input(p_delta);
	apply_forces();
}

void Starship::read_input(double p_delta) {
	if (!use_input) {
		return;
	}

	if (action_just_pressed("starship_reset")) {
		reset_to_start();
		return;
	}

	throttle = std::clamp(throttle + axis_strength("starship_throttle_down", "starship_throttle_up") * throttle_rate * p_delta, 0.0, 1.0);

	const double weight = control_smoothing * p_delta;
	pitch_input = approach(pitch_input, axis_strength("starship_pitch_down", "starship_pitch_up"), weight);
	roll_input = approach(roll_input, axis_strength("starship_roll_left", "starship_roll_right"), weight);
	yaw_input = approach(yaw_input, axis_strength("starship_yaw_left", "starship_yaw_right"), weight);
	brake_input = action_strength("starship_brake");
}

void Starship::apply_forces() {
	starship::JoltWorld *world = sim_world->get_physics_world();
	JPH::BodyInterface &bodies = world->bodies();

	const JPH::RVec3 position = bodies.GetPosition(body);
	const JPH::Quat rotation = bodies.GetRotation(body);
	const JPH::Vec3 velocity = bodies.GetLinearVelocity(body);
	const JPH::Vec3 angular_velocity = bodies.GetAngularVelocity(body);

	const JPH::Vec3 right = rotation * JPH::Vec3(1.0f, 0.0f, 0.0f);
	const JPH::Vec3 up = rotation * JPH::Vec3(0.0f, 1.0f, 0.0f);
	const JPH::Vec3 forward = rotation * JPH::Vec3(0.0f, 0.0f, -1.0f);

	altitude = position.GetY();
	airspeed = velocity.Length();
	vertical_speed = velocity.GetY();
	airborne = altitude > sim_world->get_runway_top() + hull_half_extents.y + 0.25;

	const double density = sim_world->get_air_density(altitude);
	const double density_ratio = density / std::max(1e-6, sim_world->get_sea_level_air_density());
	const double dynamic_pressure = 0.5 * density * airspeed * airspeed;

	// Part of the thrust is air breathing and fades with altitude, the rest is
	// rocket thrust that keeps working all the way out of the atmosphere.
	const double thrust_scale = (1.0 - atmospheric_thrust_ratio) + atmospheric_thrust_ratio * density_ratio;
	current_thrust = throttle * max_thrust * thrust_scale;

	JPH::Vec3 force = forward * static_cast<float>(current_thrust);
	JPH::Vec3 torque = JPH::Vec3::sZero();

	if (airspeed > 1.0) {
		const JPH::Vec3 flow = velocity / static_cast<float>(airspeed);

		const double along = forward.Dot(velocity);
		const double downwash = -up.Dot(velocity);
		const double lateral = right.Dot(velocity);

		angle_of_attack = std::atan2(downwash, along);
		sideslip_angle = std::asin(std::clamp(lateral / airspeed, -1.0, 1.0));

		const double stall_angle = stall_angle_degrees * DEGREES_TO_RADIANS;
		double stall_scale = 1.0;
		if (std::abs(angle_of_attack) > stall_angle) {
			stall_scale = std::max(0.15, 1.0 - (std::abs(angle_of_attack) - stall_angle) / stall_angle);
		}

		const double lift_coefficient = (lift_coefficient_zero + lift_slope * angle_of_attack) * stall_scale;
		const double drag_coefficient = drag_coefficient_zero + induced_drag_factor * lift_coefficient * lift_coefficient;
		const double reference = dynamic_pressure * wing_area;

		JPH::Vec3 lift_axis = right.Cross(flow);
		if (lift_axis.LengthSq() > 1.0e-6f) {
			lift_axis = lift_axis.Normalized();
		} else {
			lift_axis = up;
		}

		const JPH::Vec3 lift = lift_axis * static_cast<float>(reference * lift_coefficient);
		const JPH::Vec3 drag = flow * static_cast<float>(-reference * drag_coefficient);
		const JPH::Vec3 side = right * static_cast<float>(-reference * side_force_coefficient * sideslip_angle);
		force += lift + drag + side;

		load_factor = lift.Dot(up) / std::max(1.0, mass * sim_world->get_gravity());

		// Non dimensional rate damping, the classic c/(2V) and b/(2V) factors.
		const double reference_speed = std::max(1.0, airspeed);
		const double pitch_rate = 0.5 * mean_chord / reference_speed * angular_velocity.Dot(right);
		const double roll_rate = 0.5 * wing_span / reference_speed * angular_velocity.Dot(forward);
		const double yaw_rate = 0.5 * wing_span / reference_speed * angular_velocity.Dot(up);

		const double pitch_moment = reference * mean_chord *
				(pitch_authority * pitch_input - pitch_stability * angle_of_attack - pitch_damping * pitch_rate);
		const double roll_moment = reference * wing_span * (roll_authority * roll_input - roll_damping * roll_rate);
		const double yaw_moment = reference * wing_span *
				(yaw_authority * yaw_input + yaw_stability * sideslip_angle + yaw_damping * yaw_rate);

		torque += right * static_cast<float>(pitch_moment);
		torque += forward * static_cast<float>(roll_moment);
		torque -= up * static_cast<float>(yaw_moment);
	} else {
		angle_of_attack = 0.0;
		sideslip_angle = 0.0;
		load_factor = 0.0;
	}

	const double friction = gear_friction + brake_input * std::max(0.0, brake_friction - gear_friction);
	bodies.SetFriction(body, static_cast<float>(friction));

	bodies.AddForce(body, force);
	bodies.AddTorque(body, torque);
	bodies.ActivateBody(body);
}

void Starship::post_physics_step() {
	starship::JoltWorld *world = sim_world != nullptr ? sim_world->get_physics_world() : nullptr;
	if (world == nullptr || body.IsInvalid()) {
		return;
	}

	JPH::BodyInterface &bodies = world->bodies();
	const Basis basis(starship::to_godot(bodies.GetRotation(body)));
	set_global_transform(Transform3D(basis, starship::to_godot(bodies.GetPosition(body))));
}

void Starship::reset_to_start() {
	starship::JoltWorld *world = sim_world != nullptr ? sim_world->get_physics_world() : nullptr;
	if (world == nullptr || body.IsInvalid()) {
		return;
	}

	world->bodies().SetPositionRotationAndVelocity(
			body,
			starship::to_jolt_r(start_transform.origin),
			starship::to_jolt(start_transform.basis.get_rotation_quaternion()),
			JPH::Vec3::sZero(),
			JPH::Vec3::sZero());

	throttle = 0.0;
	pitch_input = 0.0;
	roll_input = 0.0;
	yaw_input = 0.0;
}
