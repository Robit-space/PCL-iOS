#include "ltw.h"
#include <string.h>
#include <stdlib.h>

static int g_ltw_initialized = 0;
static int g_extensions[64];
static int g_extension_count = 0;

// 主动声明关键扩展 (参考Amethyst LTW)
static const char* g_declared_extensions[] = {
    "GL_ARB_buffer_storage",
    "GL_ARB_texture_buffer_object",
    "GL_ARB_texture_buffer_range",
    "GL_ARB_draw_buffers_blend",
    "GL_ARB_timer_query",
    "GL_ARB_shader_storage_buffer_object",
    "GL_ARB_compute_shader",
    "GL_ARB_shader_image_load_store",
    "GL_EXT_shader_image_load_store",
    "GL_OES_texture_3D",
    "GL_OES_vertex_array_object",
    "GL_OES_mapbuffer",
    "GL_EXT_map_buffer_range",
    "GL_EXT_draw_buffers",
    "GL_EXT_draw_buffers2",
    "GL_EXT_draw_instanced",
    "GL_EXT_instanced_arrays",
    NULL
};

int ltw_init(void) {
    if (g_ltw_initialized) return 0;
    
    // 初始化 MobileGlues
    mobileglues_init(MG_RENDERER_LTW);
    
    // 预声明所有关键扩展
    g_extension_count = 0;
    for (int i = 0; g_declared_extensions[i] != NULL; i++) {
        g_extensions[g_extension_count++] = i;
    }
    
    g_ltw_initialized = 1;
    return 0;
}

void ltw_shutdown(void) {
    if (!g_ltw_initialized) return;
    mobileglues_shutdown();
    g_ltw_initialized = 0;
}

void* ltw_get_proc_address(const char* name) {
    if (!name || !g_ltw_initialized) return NULL;
    // TODO: 实现实际的OpenGL函数转发
    return NULL;
}

int ltw_declare_extension(const char* name) {
    if (!name || !g_ltw_initialized) return 0;
    return ltw_is_extension_supported(name);
}

int ltw_is_extension_supported(const char* name) {
    if (!name || !g_ltw_initialized) return 0;
    
    // 检查是否在预声明列表中
    for (int i = 0; g_declared_extensions[i] != NULL; i++) {
        if (strcmp(name, g_declared_extensions[i]) == 0) {
            return 1;
        }
    }
    
    // 检查基础扩展
    return mobileglues_supports_extension(name);
}
