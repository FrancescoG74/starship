# starship

A starship that takes off like an airplane from an air strip and keeps climbing
out of the atmosphere.

The flight dynamics run in [Jolt Physics](https://github.com/jrouwe/JoltPhysics)
inside a custom C++ library, built with CMake and Clang, and exposed to
[Godot 4](https://godotengine.org) as a GDExtension. Godot only draws the scene
and feeds input; every force and moment comes from the C++ side.

## Layout

| Path | Purpose |
| --- | --- |
| [CMakeLists.txt](CMakeLists.txt) | Fetches Jolt Physics and godot-cpp, builds the extension |
| [src/jolt_world.h](src/jolt_world.h) | Engine agnostic Jolt simulation wrapper |
| [src/jolt_layers.h](src/jolt_layers.h) | Broad phase and object layer configuration |
| [src/starship_world.cpp](src/starship_world.cpp) | `StarshipWorld` node: owns the Jolt world and the runway |
| [src/starship.cpp](src/starship.cpp) | `Starship` node: thrust, lift, drag, stability and controls |
| [godot/project.godot](godot/project.godot) | The Godot project with the runway scene and the HUD |
| [godot/scripts/city_generator.gd](godot/scripts/city_generator.gd) | Builds the city beside the runway from the CC0 models in `godot/assets/city` ([Kenney Starter Kit City Builder](https://github.com/KenneyNL/Starter-Kit-City-Builder)) |

## Requirements

- CMake 3.24+
- Clang (`sudo apt install clang lld` on Debian/Ubuntu)
- Ninja
- Python 3 (used by godot-cpp to generate its bindings)
- Godot 4.4 or newer

## Build

```bash
cmake --preset clang
cmake --build --preset clang
```

Dependencies are downloaded automatically on the first configure. The shared
libraries land in `godot/bin/` where `godot/starship.gdextension` expects them.

Use `--preset clang-debug` for a debug build, or `--preset clang-export` when you
also need the `template_release` variant for an exported game.

## Run

```bash
godot --path godot
```

or open the `godot/` folder in the Godot editor and press F5.

A headless smoke test that runs the take off without a window:

```bash
godot --headless --path godot res://tests/takeoff_test.tscn
```

It prints airspeed, altitude, climb rate and angle of attack twice a second.

## Controls

| Key | Action |
| --- | --- |
| Shift / Ctrl | Throttle up / down |
| W / S or Up / Down | Pitch down / up |
| A / D or Left / Right | Roll left / right |
| Q / E | Rudder left / right |
| B | Wheel brakes |
| R | Reset to the start of the runway |

Push the throttle to full, let the speed build past roughly 45 m/s, then pull
back gently. The wing takes over from the gear and the ship rotates off the
strip. Higher up the air thins out, lift and air breathing thrust fade, and only
the rocket share of the thrust keeps pushing.

## Flight model

`Starship` runs a six degree of freedom model on a single Jolt rigid body:

- Thrust along the nose, split into an air breathing part that scales with air
  density and a rocket part that works in vacuum.
- Lift and drag from the relative wind, with a lift curve that flattens past the
  stall angle and induced drag that grows with the lift coefficient.
- Control moments in pitch, roll and yaw scaled by dynamic pressure, so the
  controls go soft at low speed exactly like a real airframe.
- Static stability that weathervanes the nose into the airflow plus
  non dimensional rate damping.

Every coefficient is an exported property, so the airframe can be retuned from
the Godot inspector without recompiling.

## Notes on the dependency setup

- Jolt is compiled with the baseline SSE2 instruction set. Jolt applies its
  wider ISA flags only inside its own directory scope, so anything else would
  give the extension a different `Vec3` layout than the one inside `libJolt`.
- RTTI stays enabled in Jolt because the layer interfaces in
  [src/jolt_layers.h](src/jolt_layers.h) derive from Jolt base classes.
- Jolt floating point exceptions are disabled, Godot does not expect a hosted
  library to unmask them.
