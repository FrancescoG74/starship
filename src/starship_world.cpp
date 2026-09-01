#include "starship_world.h"

#include "conversions.h"
#include "starship.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <cmath>

using namespace godot;

StarshipWorld::StarshipWorld() {}

StarshipWorld::~StarshipWorld() {}

void StarshipWorld::_bind_methods() {
#define BIND_PROPERTY(m_variant, m_name, m_hint, m_hint_string)                                                     \
	ClassDB::bind_method(D_METHOD("set_" #m_name, "value"), &StarshipWorld::set_##m_name);                          \
	ClassDB::bind_method(D_METHOD("get_" #m_name), &StarshipWorld::get_##m_name);                                   \
	ADD_PROPERTY(PropertyInfo(Variant::m_variant, #m_name, m_hint, m_hint_string), "set_" #m_name, "get_" #m_name);

	BIND_PROPERTY(FLOAT, gravity, PROPERTY_HINT_RANGE, "0,50,0.01,suffix:m/s\u00b2")
	BIND_PROPERTY(VECTOR3, runway_size, PROPERTY_HINT_NONE, "suffix:m")
	BIND_PROPERTY(VECTOR3, runway_center, PROPERTY_HINT_NONE, "suffix:m")
	BIND_PROPERTY(VECTOR3, ground_size, PROPERTY_HINT_NONE, "suffix:m")
	BIND_PROPERTY(VECTOR3, ground_center, PROPERTY_HINT_NONE, "suffix:m")
	BIND_PROPERTY(FLOAT, runway_friction, PROPERTY_HINT_RANGE, "0,2,0.01")
	BIND_PROPERTY(FLOAT, sea_level_air_density, PROPERTY_HINT_RANGE, "0,5,0.001,suffix:kg/m\u00b3")
	BIND_PROPERTY(FLOAT, atmosphere_scale_height, PROPERTY_HINT_RANGE, "100,50000,1,suffix:m")
	BIND_PROPERTY(INT, collision_steps, PROPERTY_HINT_RANGE, "1,8,1")

#undef BIND_PROPERTY

	ClassDB::bind_method(D_METHOD("get_air_density", "altitude"), &StarshipWorld::get_air_density);
	ClassDB::bind_method(D_METHOD("get_runway_top"), &StarshipWorld::get_runway_top);
}

void StarshipWorld::_ready() {
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}

	starship::jolt_startup();

	world = std::make_unique<starship::JoltWorld>();
	world->set_gravity(JPH::Vec3(0.0f, static_cast<float>(-gravity), 0.0f));

	runway_body = world->add_static_box(
			JPH::Vec3(runway_size.x * 0.5f, runway_size.y * 0.5f, runway_size.z * 0.5f),
			starship::to_jolt_r(runway_center),
			static_cast<float>(runway_friction));

	// Terrain beside and beyond the strip, so a craft that leaves the runway
	// still has something to land on.
	ground_body = world->add_static_box(
			JPH::Vec3(ground_size.x * 0.5f, ground_size.y * 0.5f, ground_size.z * 0.5f),
			starship::to_jolt_r(ground_center),
			static_cast<float>(runway_friction));

	set_physics_process(true);
}

void StarshipWorld::_exit_tree() {
	if (world) {
		world->remove_body(runway_body);
		world->remove_body(ground_body);
	}
	runway_body = JPH::BodyID();
	ground_body = JPH::BodyID();
	crafts.clear();
	world.reset();
}

void StarshipWorld::_physics_process(double p_delta) {
	if (Engine::get_singleton()->is_editor_hint() || !world || p_delta <= 0.0) {
		return;
	}

	for (Starship *craft : crafts) {
		craft->pre_physics_step(p_delta);
	}

	world->step(static_cast<float>(p_delta), collision_steps);

	for (Starship *craft : crafts) {
		craft->post_physics_step();
	}
}

void StarshipWorld::register_craft(Starship *p_craft) {
	if (p_craft != nullptr && std::find(crafts.begin(), crafts.end(), p_craft) == crafts.end()) {
		crafts.push_back(p_craft);
	}
}

void StarshipWorld::unregister_craft(Starship *p_craft) {
	crafts.erase(std::remove(crafts.begin(), crafts.end(), p_craft), crafts.end());
}

double StarshipWorld::get_air_density(double p_altitude) const {
	const double height = std::max(0.0, p_altitude - get_runway_top());
	return sea_level_air_density * std::exp(-height / std::max(1.0, atmosphere_scale_height));
}

double StarshipWorld::get_runway_top() const {
	return runway_center.y + runway_size.y * 0.5;
}

void StarshipWorld::set_gravity(double p_value) {
	gravity = p_value;
	if (world) {
		world->set_gravity(JPH::Vec3(0.0f, static_cast<float>(-gravity), 0.0f));
	}
}
