#pragma once

#include <Jolt/Jolt.h>

#include <Jolt/Physics/Collision/BroadPhase/BroadPhaseLayer.h>
#include <Jolt/Physics/Collision/ObjectLayer.h>

namespace starship {

namespace Layers {
static constexpr JPH::ObjectLayer STATIC = 0;
static constexpr JPH::ObjectLayer MOVING = 1;
static constexpr JPH::ObjectLayer NUM_LAYERS = 2;
} // namespace Layers

namespace BroadPhaseLayers {
static constexpr JPH::BroadPhaseLayer STATIC(0);
static constexpr JPH::BroadPhaseLayer MOVING(1);
static constexpr JPH::uint NUM_LAYERS(2);
} // namespace BroadPhaseLayers

class ObjectLayerPairFilterImpl final : public JPH::ObjectLayerPairFilter {
public:
	bool ShouldCollide(JPH::ObjectLayer p_a, JPH::ObjectLayer p_b) const override {
		return p_a == Layers::MOVING || p_b == Layers::MOVING;
	}
};

class BroadPhaseLayerInterfaceImpl final : public JPH::BroadPhaseLayerInterface {
public:
	BroadPhaseLayerInterfaceImpl() {
		object_to_broad_phase[Layers::STATIC] = BroadPhaseLayers::STATIC;
		object_to_broad_phase[Layers::MOVING] = BroadPhaseLayers::MOVING;
	}

	JPH::uint GetNumBroadPhaseLayers() const override {
		return BroadPhaseLayers::NUM_LAYERS;
	}

	JPH::BroadPhaseLayer GetBroadPhaseLayer(JPH::ObjectLayer p_layer) const override {
		JPH_ASSERT(p_layer < Layers::NUM_LAYERS);
		return object_to_broad_phase[p_layer];
	}

#if defined(JPH_EXTERNAL_PROFILE) || defined(JPH_PROFILE_ENABLED)
	const char *GetBroadPhaseLayerName(JPH::BroadPhaseLayer p_layer) const override {
		switch (static_cast<JPH::BroadPhaseLayer::Type>(p_layer)) {
			case static_cast<JPH::BroadPhaseLayer::Type>(BroadPhaseLayers::STATIC):
				return "STATIC";
			case static_cast<JPH::BroadPhaseLayer::Type>(BroadPhaseLayers::MOVING):
				return "MOVING";
			default:
				return "INVALID";
		}
	}
#endif

private:
	JPH::BroadPhaseLayer object_to_broad_phase[Layers::NUM_LAYERS];
};

class ObjectVsBroadPhaseLayerFilterImpl final : public JPH::ObjectVsBroadPhaseLayerFilter {
public:
	bool ShouldCollide(JPH::ObjectLayer p_layer, JPH::BroadPhaseLayer p_broad_phase_layer) const override {
		return p_layer == Layers::MOVING || p_broad_phase_layer == BroadPhaseLayers::MOVING;
	}
};

} // namespace starship
