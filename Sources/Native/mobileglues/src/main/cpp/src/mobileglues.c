#include "mobileglues.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

static MGRendererType g_current_renderer = MG_RENDERER_GL4ES;
static int g_initialized = 0;

int mobileglues_init(MGRendererType type) {
    if (g_initialized) {
        return 0;
    }
    g_current_renderer = type;
    g_initialized = 1;
    return 0;
}

void mobileglues_shutdown(void) {
    g_initialized = 0;
}

const char* mobileglues_version(void) {
    return "MobileGlues 1.0.0 - iOS arm64";
}

const char* mobileglues_renderer_name(MGRendererType type) {
    switch (type) {
        case MG_RENDERER_GL4ES: return "GL4ES";
        case MG_RENDERER_METALANGLE: return "MetalANGLE";
        case MG_RENDERER_MOBILEGLUES: return "MobileGlues";
        case MG_RENDERER_ZINK: return "Zink (Vulkan)";
        case MG_RENDERER_LTW: return "LTW";
        default: return "Unknown";
    }
}

int mobileglues_supports_extension(const char* extension) {
    if (!extension || !g_initialized) return 0;
    // 基础扩展支持
    if (strcmp(extension, "GL_OES_texture_npot") == 0) return 1;
    if (strcmp(extension, "GL_OES_depth24") == 0) return 1;
    if (strcmp(extension, "GL_OES_depth_texture") == 0) return 1;
    if (strcmp(extension, "GL_OES_packed_depth_stencil") == 0) return 1;
    if (strcmp(extension, "GL_OES_rgb8_rgba8") == 0) return 1;
    if (strcmp(extension, "GL_EXT_texture_format_BGRA8888") == 0) return 1;
    if (strcmp(extension, "GL_APPLE_texture_format_BGRA8888") == 0) return 1;
    return 0;
}

const char* mobileglues_get_version_string(void) {
    return "OpenGL ES 3.0 (MobileGlues 1.0.0)";
}

const char* mobileglues_get_renderer_string(void) {
    return "Apple GPU (Metal)";
}

const char* mobileglues_get_vendor_string(void) {
    return "Apple";
}
