#include "jolt_world.h"

#include <Jolt/Core/Factory.h>
#include <Jolt/Physics/Body/Body.h>
#include <Jolt/Physics/Body/BodyCreationSettings.h>
#include <Jolt/Physics/Body/MotionProperties.h>
#include <Jolt/Physics/Collision/Shape/BoxShape.h>
#include <Jolt/RegisterTypes.h>

#include <algorithm>
#include <thread>

namespace starship {

namespace {

constexpr JPH::uint MAX_BODIES = 1024;
constexpr JPH::uint NUM_BODY_MUTEXES = 0; // 0 = pick a sensible default
constexpr JPH::uint MAX_BODY_PAIRS = 4096;
constexpr JPH::uint MAX_CONTACT_CONSTRAINTS = 2048;
constexpr JPH::uint TEMP_ALLOCATOR_BYTES = 16 * 1024 * 1024;

bool s_jolt_initialized = false;

} // namespace

void jolt_startup() {
	if (s_jolt_initialized) {
		return;
	}
	JPH::RegisterDefaultAllocator();
	JPH::Factory::sInstance = new JPH::Factory();
	JPH::RegisterTypes();
	s_jolt_initialized = true;
}

void jolt_shutdown() {
	if (!s_jolt_initialized) {
		return;
	}
	JPH::UnregisterTypes();
	delete JPH::Factory::sInstance;
	JPH::Factory::sInstance = nullptr;
	s_jolt_initialized = false;
}

JoltWorld::JoltWorld() {
	physics_system.Init(MAX_BODIES, NUM_BODY_MUTEXES, MAX_BODY_PAIRS, MAX_CONTACT_CONSTRAINTS,
			broad_phase_layers, object_vs_broad_phase_filter, object_layer_pair_filter);

	temp_allocator = std::make_unique<JPH::TempAllocatorImpl>(TEMP_ALLOCATOR_BYTES);

	const int worker_threads = std::max(1, static_cast<int>(std::thread::hardware_concurrency()) - 1);
	job_system = std::make_unique<JPH::JobSystemThreadPool>(JPH::cMaxPhysicsJobs, JPH::cMaxPhysicsBarriers, worker_threads);
}

JoltWorld::~JoltWorld() = default;

JPH::BodyID JoltWorld::add_static_box(JPH::Vec3Arg p_half_extent, JPH::RVec3Arg p_position, float p_friction) {
	JPH::BodyCreationSettings settings(new JPH::BoxShape(p_half_extent), p_position, JPH::Quat::sIdentity(),
			JPH::EMotionType::Static, Layers::STATIC);
	settings.mFriction = p_friction;
	settings.mRestitution = 0.0f;

	JPH::BodyID id = bodies().CreateAndAddBody(settings, JPH::EActivation::DontActivate);
	physics_system.OptimizeBroadPhase();
	return id;
}

JPH::BodyID JoltWorld::add_dynamic_box(JPH::Vec3Arg p_half_extent, JPH::RVec3Arg p_position, JPH::QuatArg p_rotation,
		float p_mass, float p_friction, float p_max_speed) {
	JPH::BodyCreationSettings settings(new JPH::BoxShape(p_half_extent), p_position, p_rotation,
			JPH::EMotionType::Dynamic, Layers::MOVING);
	settings.mOverrideMassProperties = JPH::EOverrideMassProperties::CalculateInertia;
	settings.mMassPropertiesOverride.mMass = p_mass;
	settings.mFriction = p_friction;
	settings.mRestitution = 0.0f;
	settings.mAllowSleeping = false;
	// The aerodynamic model supplies its own damping, Jolt must not add more.
	settings.mLinearDamping = 0.0f;
	settings.mAngularDamping = 0.0f;
	// A craft doing several hundred m/s would tunnel through the runway.
	settings.mMotionQuality = JPH::EMotionQuality::LinearCast;
	settings.mMaxLinearVelocity = p_max_speed;

	JPH::Body *body = bodies().CreateBody(settings);
	if (body == nullptr) {
		return JPH::BodyID();
	}
	bodies().AddBody(body->GetID(), JPH::EActivation::Activate);
	return body->GetID();
}

void JoltWorld::remove_body(const JPH::BodyID &p_id) {
	if (p_id.IsInvalid()) {
		return;
	}
	bodies().RemoveBody(p_id);
	bodies().DestroyBody(p_id);
}

void JoltWorld::set_gravity(JPH::Vec3Arg p_gravity) {
	physics_system.SetGravity(p_gravity);
}

void JoltWorld::step(float p_delta, int p_collision_steps) {
	physics_system.Update(p_delta, p_collision_steps, temp_allocator.get(), job_system.get());
}

} // namespace starship
