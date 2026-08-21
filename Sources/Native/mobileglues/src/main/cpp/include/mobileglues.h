#ifndef MOBILEGLUES_H
#define MOBILEGLUES_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// MobileGlues 版本
#define MOBILEGLUES_VERSION_MAJOR 1
#define MOBILEGLUES_VERSION_MINOR 0
#define MOBILEGLUES_VERSION_PATCH 0

// 渲染器类型
typedef enum {
    MG_RENDERER_GL4ES = 0,
    MG_RENDERER_METALANGLE = 1,
    MG_RENDERER_MOBILEGLUES = 2,
    MG_RENDERER_ZINK = 3,
    MG_RENDERER_LTW = 4
} MGRendererType;

// 初始化/销毁
int mobileglues_init(MGRendererType type);
void mobileglues_shutdown(void);

// 版本信息
const char* mobileglues_version(void);
const char* mobileglues_renderer_name(MGRendererType type);

// 渲染器能力查询
int mobileglues_supports_extension(const char* extension);
const char* mobileglues_get_version_string(void);
const char* mobileglues_get_renderer_string(void);
const char* mobileglues_get_vendor_string(void);

#ifdef __cplusplus
}
#endif

#endif // MOBILEGLUES_H
