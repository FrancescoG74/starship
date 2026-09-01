#pragma once

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <memory>
#include <vector>

#include "jolt_world.h"

class Starship;

// Owns the Jolt simulation and the static runway. Every Starship placed below
// this node in the tree registers itself here and is stepped by it.
class StarshipWorld : public godot::Node3D {
	GDCLASS(StarshipWorld, godot::Node3D)

protected:
	static void _bind_methods();

public:
	StarshipWorld();
	~StarshipWorld() override;

	void _ready() override;
	void _exit_tree() override;
	void _physics_process(double p_delta) override;

	starship::JoltWorld *get_physics_world() const { return world.get(); }
	void register_craft(Starship *p_craft);
	void unregister_craft(Starship *p_craft);

	// Exponential atmosphere: thrust and aerodynamic forces fade out with height.
	double get_air_density(double p_altitude) const;
	double get_runway_top() const;

	void set_gravity(double p_value);
	double get_gravity() const { return gravity; }
	void set_runway_size(const godot::Vector3 &p_value) { runway_size = p_value; }
	godot::Vector3 get_runway_size() const { return runway_size; }
	void set_runway_center(const godot::Vector3 &p_value) { runway_center = p_value; }
	godot::Vector3 get_runway_center() const { return runway_center; }
	void set_runway_friction(double p_value) { runway_friction = p_value; }
	double get_runway_friction() const { return runway_friction; }
	void set_ground_size(const godot::Vector3 &p_value) { ground_size = p_value; }
	godot::Vector3 get_ground_size() const { return ground_size; }
	void set_ground_center(const godot::Vector3 &p_value) { ground_center = p_value; }
	godot::Vector3 get_ground_center() const { return ground_center; }
	void set_sea_level_air_density(double p_value) { sea_level_air_density = p_value; }
	double get_sea_level_air_density() const { return sea_level_air_density; }
	void set_atmosphere_scale_height(double p_value) { atmosphere_scale_height = p_value; }
	double get_atmosphere_scale_height() const { return atmosphere_scale_height; }
	void set_collision_steps(int p_value) { collision_steps = p_value < 1 ? 1 : p_value; }
	int get_collision_steps() const { return collision_steps; }

private:
	std::unique_ptr<starship::JoltWorld> world;
	std::vector<Starship *> crafts;
	JPH::BodyID runway_body;
	JPH::BodyID ground_body;

	double gravity = 9.81;
	godot::Vector3 runway_size = godot::Vector3(60.0f, 1.0f, 4000.0f);
	godot::Vector3 runway_center = godot::Vector3(0.0f, -0.5f, 0.0f);
	godot::Vector3 ground_size = godot::Vector3(30000.0f, 100.0f, 30000.0f);
	godot::Vector3 ground_center = godot::Vector3(0.0f, -51.05f, 0.0f);
	double runway_friction = 0.8;
	double sea_level_air_density = 1.225;
	double atmosphere_scale_height = 8500.0;
	int collision_steps = 1;
};
