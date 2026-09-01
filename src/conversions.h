#pragma once

#include <Jolt/Jolt.h>

#include <Jolt/Math/Quat.h>
#include <Jolt/Math/Vec3.h>

#include <godot_cpp/variant/quaternion.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace starship {

inline godot::Vector3 to_godot(const JPH::Vec3 &p_vec) {
	return godot::Vector3(p_vec.GetX(), p_vec.GetY(), p_vec.GetZ());
}

#ifdef JPH_DOUBLE_PRECISION
inline godot::Vector3 to_godot(const JPH::RVec3 &p_vec) {
	return godot::Vector3(static_cast<float>(p_vec.GetX()), static_cast<float>(p_vec.GetY()), static_cast<float>(p_vec.GetZ()));
}
#endif

inline godot::Quaternion to_godot(const JPH::Quat &p_quat) {
	return godot::Quaternion(p_quat.GetX(), p_quat.GetY(), p_quat.GetZ(), p_quat.GetW());
}

inline JPH::Vec3 to_jolt(const godot::Vector3 &p_vec) {
	return JPH::Vec3(p_vec.x, p_vec.y, p_vec.z);
}

inline JPH::RVec3 to_jolt_r(const godot::Vector3 &p_vec) {
	return JPH::RVec3(p_vec.x, p_vec.y, p_vec.z);
}

inline JPH::Quat to_jolt(const godot::Quaternion &p_quat) {
	return JPH::Quat(p_quat.x, p_quat.y, p_quat.z, p_quat.w);
}

} // namespace starship
