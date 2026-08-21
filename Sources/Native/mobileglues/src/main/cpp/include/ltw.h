#ifndef LTW_H
#define LTW_H

#include "mobileglues.h"

#ifdef __cplusplus
extern "C" {
#endif

// LTW (Large Thin Wrapper) - OpenGL Core 3.3 → OpenGL ES 3 转译层
// 复刻自官方 MojoLauncher/LTW 仓库，iOS 移植

// LTW 初始化
int ltw_init(void);
void ltw_shutdown(void);

// OpenGL 函数转发
void* ltw_get_proc_address(const char* name);

// 扩展声明 (让 Sodium/Iris 等能正常工作)
int ltw_declare_extension(const char* name);
int ltw_is_extension_supported(const char* name);

// 主动声明关键扩展
// GL_ARB_buffer_storage - Sodium persistent mapped buffers
// GL_ARB_texture_buffer_object - Sodium texture buffers
// GL_ARB_draw_buffers_blend - Iris 必需
// GL_ARB_timer_query - Blaze3D TimerQuery

#ifdef __cplusplus
}
#endif

#endif // LTW_H
