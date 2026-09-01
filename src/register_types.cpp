#include "register_types.h"

#include "jolt_world.h"
#include "starship.h"
#include "starship_world.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_starship_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}

	starship::jolt_startup();

	GDREGISTER_CLASS(StarshipWorld);
	GDREGISTER_CLASS(Starship);
}

void uninitialize_starship_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}

	starship::jolt_shutdown();
}

extern "C" {
GDExtensionBool GDE_EXPORT starship_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address,
		const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

	init_obj.register_initializer(initialize_starship_module);
	init_obj.register_terminator(uninitialize_starship_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

	return init_obj.init();
}
}
