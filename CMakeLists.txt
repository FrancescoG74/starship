cmake_minimum_required(VERSION 3.24)

project(starship
    VERSION 0.1.0
    DESCRIPTION "Jolt Physics powered starship GDExtension for Godot 4"
    LANGUAGES CXX
)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(STARSHIP_GODOT_CPP_TAG "godot-4.4-stable" CACHE STRING "godot-cpp git tag")
set(STARSHIP_JOLT_TAG "v5.6.0" CACHE STRING "JoltPhysics git tag")
set(STARSHIP_GODOT_TARGETS "editor;template_debug" CACHE STRING
    "godot-cpp variants to build (editor;template_debug;template_release)")

set(STARSHIP_ADDON_DIR "${CMAKE_CURRENT_SOURCE_DIR}/godot/bin")

# Dependencies are fetched and built automatically via FetchContent. On first configure,
# they are downloaded to build/_deps/ and compiled (slow). Subsequent runs reuse the
# cached sources and only rebuild if CMakeLists.txt changes. Each preset uses its own
# build directory, so switching presets (clang/gcc) will re-fetch dependencies.
# To preserve the cache across builds, do NOT delete build/; instead use:
#   cmake --build --preset clang --target clean  (cleans only targets, keeps deps)
# Or to clean one preset's cache only:
#   rm -rf build/clang && cmake --preset clang

include(FetchContent)

# --------------------------------------------------------------------------- #
# Jolt Physics
# --------------------------------------------------------------------------- #
# Only the baseline SSE2 instruction set is enabled. Jolt applies its ISA flags
# to its own directory scope only, so anything wider would silently produce a
# different memory layout in our translation units than inside libJolt.
set(USE_SSE4_1 OFF CACHE BOOL "" FORCE)
set(USE_SSE4_2 OFF CACHE BOOL "" FORCE)
set(USE_AVX OFF CACHE BOOL "" FORCE)
set(USE_AVX2 OFF CACHE BOOL "" FORCE)
set(USE_AVX512 OFF CACHE BOOL "" FORCE)
set(USE_LZCNT OFF CACHE BOOL "" FORCE)
set(USE_TZCNT OFF CACHE BOOL "" FORCE)
set(USE_F16C OFF CACHE BOOL "" FORCE)
set(USE_FMADD OFF CACHE BOOL "" FORCE)

# RTTI must match: we derive from Jolt's layer interfaces, so their typeinfo
# has to exist in libJolt.
set(CPP_RTTI_ENABLED ON CACHE BOOL "" FORCE)
# Godot does not expect a host library to unmask FP exceptions.
set(FLOATING_POINT_EXCEPTIONS_ENABLED OFF CACHE BOOL "" FORCE)
set(OVERRIDE_CXX_FLAGS OFF CACHE BOOL "" FORCE)
set(INTERPROCEDURAL_OPTIMIZATION OFF CACHE BOOL "" FORCE)
set(ENABLE_ALL_WARNINGS OFF CACHE BOOL "" FORCE)
set(ENABLE_INSTALL OFF CACHE BOOL "" FORCE)
set(TARGET_UNIT_TESTS OFF CACHE BOOL "" FORCE)
set(TARGET_HELLO_WORLD OFF CACHE BOOL "" FORCE)
set(TARGET_PERFORMANCE_TEST OFF CACHE BOOL "" FORCE)
set(TARGET_SAMPLES OFF CACHE BOOL "" FORCE)
set(TARGET_VIEWER OFF CACHE BOOL "" FORCE)

# The GPU backends only drive Jolt's soft body/hair compute samples and would
# require a shader compiler toolchain we do not need here.
set(JPH_USE_DX12 OFF CACHE BOOL "" FORCE)
set(JPH_USE_VK OFF CACHE BOOL "" FORCE)
set(JPH_USE_MTL OFF CACHE BOOL "" FORCE)
set(JPH_USE_CPU_COMPUTE OFF CACHE BOOL "" FORCE)

FetchContent_Declare(JoltPhysics
    GIT_REPOSITORY https://github.com/jrouwe/JoltPhysics.git
    GIT_TAG ${STARSHIP_JOLT_TAG}
    GIT_SHALLOW ON
    SOURCE_SUBDIR Build
)

# --------------------------------------------------------------------------- #
# godot-cpp
# --------------------------------------------------------------------------- #
FetchContent_Declare(godot-cpp
    GIT_REPOSITORY https://github.com/godotengine/godot-cpp.git
    GIT_TAG ${STARSHIP_GODOT_CPP_TAG}
    GIT_SHALLOW ON
)

FetchContent_MakeAvailable(JoltPhysics godot-cpp)

# godot-cpp's windows.cmake assumes any compiler reporting CXX_COMPILER_ID
# "Clang" on Windows is a MinGW-flavoured clang and unconditionally adds
# "-lstdc++". Plain clang/clang++ from llvm.org instead targets the MSVC ABI
# and has no libstdc++, so that flag makes the linker fail looking for a
# nonexistent stdc++.lib. Strip it from godot-cpp's link interface in that case.
if(WIN32 AND CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND NOT CMAKE_CXX_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC")
    foreach(GODOTCPP_VARIANT editor template_debug template_release)
        if(TARGET godot-cpp.${GODOTCPP_VARIANT})
            get_target_property(GODOTCPP_LINK_OPTS godot-cpp.${GODOTCPP_VARIANT} INTERFACE_LINK_OPTIONS)
            if(GODOTCPP_LINK_OPTS)
                list(FILTER GODOTCPP_LINK_OPTS EXCLUDE REGEX "lstdc\\+\\+")
                set_target_properties(godot-cpp.${GODOTCPP_VARIANT} PROPERTIES INTERFACE_LINK_OPTIONS "${GODOTCPP_LINK_OPTS}")
            endif()
        endif()
    endforeach()
endif()

# --------------------------------------------------------------------------- #
# The GDExtension shared library, one per godot-cpp variant
# --------------------------------------------------------------------------- #
set(STARSHIP_SOURCES
    src/register_types.cpp
    src/register_types.h
    src/jolt_layers.h
    src/jolt_world.cpp
    src/jolt_world.h
    src/conversions.h
    src/starship.cpp
    src/starship.h
    src/starship_world.cpp
    src/starship_world.h
)

foreach(TARGET_ALIAS IN LISTS STARSHIP_GODOT_TARGETS)
    set(TARGET_NAME "starship.${TARGET_ALIAS}")
    set(LINK_TARGET "godot-cpp::${TARGET_ALIAS}")

    add_library(${TARGET_NAME} SHARED)
    target_sources(${TARGET_NAME} PRIVATE ${STARSHIP_SOURCES})
    target_include_directories(${TARGET_NAME} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src")
    target_link_libraries(${TARGET_NAME} PRIVATE ${LINK_TARGET} Jolt)

    # On the Windows/MSVC ABI (including clang targeting it), pointer-to-member-function
    # size depends on the class's inheritance model. godot-cpp's method_bind.hpp normally
    # reinterpret_casts bound methods to an incomplete forward-declared class, which only
    # works under the Itanium ABI. TYPED_METHOD_BIND makes it bind against the real class
    # instead, avoiding that mismatched reinterpret_cast on MSVC-ABI targets.
    if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC" OR (WIN32 AND CMAKE_CXX_COMPILER_ID MATCHES "Clang"))
        target_compile_definitions(${TARGET_NAME} PRIVATE TYPED_METHOD_BIND)
    endif()

    # Keep float behaviour identical to the one libJolt was compiled with.
    target_compile_options(${TARGET_NAME} PRIVATE
        $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-ffp-contract=off>
    )

    get_target_property(GODOTCPP_SUFFIX ${LINK_TARGET} GODOTCPP_SUFFIX)
    get_target_property(OSX_ARCH ${LINK_TARGET} OSX_ARCHITECTURES)

    set_target_properties(${TARGET_NAME} PROPERTIES
        CXX_VISIBILITY_PRESET ${GODOTCPP_SYMBOL_VISIBILITY}
        POSITION_INDEPENDENT_CODE ON
        BUILD_RPATH_USE_ORIGIN ON
        LIBRARY_OUTPUT_DIRECTORY "$<1:${STARSHIP_ADDON_DIR}>"
        RUNTIME_OUTPUT_DIRECTORY "$<1:${STARSHIP_ADDON_DIR}>"
        PDB_OUTPUT_DIRECTORY "$<1:${STARSHIP_ADDON_DIR}>"
        PREFIX "lib"
        OUTPUT_NAME "starship${GODOTCPP_SUFFIX}"
    )

    if(CMAKE_SYSTEM_NAME STREQUAL Darwin)
        set_target_properties(${TARGET_NAME} PROPERTIES
            SUFFIX ""
            OSX_ARCHITECTURES "${OSX_ARCH}"
        )
    endif()
endforeach()
