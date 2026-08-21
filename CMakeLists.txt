# PCL-iOS Native dylib Cross-Compilation
# Based on Amethyst-iOS-MyRemastered CMakeLists.txt
# Targets iOS arm64 (iPhone/iPad)
#
# MobileGlues源码内置在仓库中，构建时编译 (参考Amethyst)

cmake_minimum_required(VERSION 3.21)
project(PCLiOS-Native C CXX ASM)

# iOS Platform Settings
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_DEPLOYMENT_TARGET "14.0")
set(CMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH NO)

# Common flags for iOS
set(IOS_FLAGS "-miphoneos-version-min=14.0 -fembed-bitcode")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${IOS_FLAGS}")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${IOS_FLAGS}")
set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} ${IOS_FLAGS}")

# Output directory
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

# Include generated config
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/config.h.in
    ${CMAKE_BINARY_DIR}/include/config.h
)

# ============================================================================
# MobileGlues (GL/Vulkan wrapper) - 源码内置，构建时编译 (参考Amethyst)
# 来源: MobileGL-Dev/MobileGlues (Amethyst使用相同方式)
# ============================================================================
if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/Sources/Native/mobileglues/CMakeLists.txt)
    add_subdirectory(Sources/Native/mobileglues)
endif()

# ============================================================================
# AWT/Caciocavallo (from PojavLauncherTeam)
# ============================================================================

add_library(awt_headless SHARED
   Sources/Native/cacio/cacio-dim.c
)

add_library(awt_xawt SHARED
    Sources/Native/cacio/cacio.c
    Sources/Native/cacio/cacio_awt_pivot.c
)

# ============================================================================
# GL4ES (OpenGL ES 1.1.4 wrapper)
# 来源: https://github.com/PojavLauncherTeam/gl4es
# ============================================================================

add_library(gl4es_114 SHARED
    Sources/Native/gl4es/src/gl/build_info.c
    Sources/Native/gl4es/src/gl/gl4es.c
    Sources/Native/gl4es/src/gl/matvec.c
)

target_include_directories(gl4es_114 PRIVATE
    Sources/Native/gl4es/include
    Sources/Native/gl4es/src/gl
)

target_compile_definitions(gl4es_114 PRIVATE
    GLES1=1
    NO_OMIT_FRAMEBUFFER
)

# ============================================================================
# MetalANGLE wrapper (OpenGL ES via Metal)
# ============================================================================

add_library(tinygl4angle SHARED
    Sources/Native/gl4es/string_utils.c
    Sources/Native/gl4es/tinygl4angle.c
)

target_include_directories(tinygl4angle PRIVATE
    Sources/Native/gl4es/include
)

# ============================================================================
# OSMesa (Software rendering)
# ============================================================================

add_library(OSMesa SHARED
    Sources/Native/osmesa/src/api.c
    Sources/Native/osmesa/src/render.c
)

target_include_directories(OSMesa PRIVATE
    Sources/Native/osmesa/include
)

# ============================================================================
# LTW (Large Thin Wrapper) - OpenGL Core 3.3 → OpenGL ES 3
# 复刻自MojoLauncher/LTW，iOS移植
# ============================================================================

add_library(ltw SHARED
    Sources/Native/mobileglues/src/main/cpp/src/ltw.c
    Sources/Native/mobileglues/src/main/cpp/src/mobileglues.c
)

target_include_directories(ltw PRIVATE
    Sources/Native/mobileglues/src/main/cpp/include
)

target_compile_definitions(ltw PRIVATE
    LTW_BUILD=1
)

set_target_properties(ltw PROPERTIES
    C_STANDARD 11
    C_STANDARD_REQUIRED ON
)

# ============================================================================
# Install rules
# ============================================================================
install(TARGETS
    awt_headless
    awt_xawt
    gl4es_114
    tinygl4angle
    mobileglues
    OSMesa
    ltw
    DESTINATION Frameworks
)

# ============================================================================
# Summary
# ============================================================================
message(STATUS "")
message(STATUS "=== PCL-iOS Native Build Configuration ===")
message(STATUS "  System:           iOS arm64")
message(STATUS "  Deployment target: 14.0")
message(STATUS "  Build type:       ${CMAKE_BUILD_TYPE}")
message(STATUS "  MobileGlues:      内置源码 (Sources/Native/mobileglues)")
message(STATUS "  Output:           ${CMAKE_BINARY_DIR}/lib")
message(STATUS "")
