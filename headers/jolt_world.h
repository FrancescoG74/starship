#pragma once

#include <Jolt/Jolt.h>

#include <Jolt/Core/JobSystemThreadPool.h>
#include <Jolt/Core/TempAllocator.h>
#include <Jolt/Physics/Body/BodyID.h>
#include <Jolt/Physics/PhysicsSystem.h>

#include <memory>

#include "jolt_layers.h"

namespace starship {

// Registers the process wide Jolt allocator/factory. Safe to call repeatedly.
void jolt_startup();
void jolt_shutdown();

// A self contained Jolt simulation. Deliberately knows nothing about Godot so
// the flight model can be exercised without an engine instance.
class JoltWorld {
public:
	JoltWorld();
	~JoltWorld();

	JoltWorld(const JoltWorld &) = delete;
	JoltWorld &operator=(const JoltWorld &) = delete;

	JPH::BodyID add_static_box(JPH::Vec3Arg p_half_extent, JPH::RVec3Arg p_position, float p_friction);
	JPH::BodyID add_dynamic_box(JPH::Vec3Arg p_half_extent, JPH::RVec3Arg p_position, JPH::QuatArg p_rotation,
			float p_mass, float p_friction, float p_max_speed);
	void remove_body(const JPH::BodyID &p_id);

	void set_gravity(JPH::Vec3Arg p_gravity);
	void step(float p_delta, int p_collision_steps);

	JPH::PhysicsSystem &system() { return physics_system; }
	JPH::BodyInterface &bodies() { return physics_system.GetBodyInterface(); }

private:
	// Declaration order matters: PhysicsSystem::Init stores references to these.
	BroadPhaseLayerInterfaceImpl broad_phase_layers;
	ObjectVsBroadPhaseLayerFilterImpl object_vs_broad_phase_filter;
	ObjectLayerPairFilterImpl object_layer_pair_filter;

	JPH::PhysicsSystem physics_system;
	std::unique_ptr<JPH::TempAllocatorImpl> temp_allocator;
	std::unique_ptr<JPH::JobSystemThreadPool> job_system;
};

} // namespace starship
