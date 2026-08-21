// MobileGlues - gles/loader.cpp
// Copyright (c) 2025-2026 MobileGL-Dev
// Licensed under the GNU Lesser General Public License v2.1:
//   https://www.gnu.org/licenses/old-licenses/lgpl-2.1.txt
// SPDX-License-Identifier: LGPL-2.1-only
// End of Source File Header

#include <cstring>
#include <cstdio>
#include <limits.h>
#include <string>
#include "loader.h"
#include "../includes.h"
#include "loader.h"
#include <GL/gl.h>
#include "../gl/glext.h"
#include "../gl/envvars.h"
#include "../gl/log.h"
#include "../gl/mg.h"
#include "../gl/buffer.h"
#include "../gl/getter.h"
#include "../config/settings.h"
#include "../gl/texture.h"
#include "../gl/framebuffer.h"

#define DEBUG 0

void *gles = nullptr, *egl = nullptr;

struct gles_func_t g_gles_func;

static const char* path_prefix[] = {
    "", "/opt/vc/lib/", "/usr/local/lib/", "/usr/lib/", nullptr,
};

static const char* lib_ext[] = {
#ifndef NO_GBM
    "so.19",
#endif
    "so",    "so.1", "so.2", "dylib", "dll", nullptr,
};

static const char* gles3_lib[] = {"libGLESv3_CM", "libGLESv3", nullptr};

static const char* egl_lib[] = {
#if defined(BCMHOST)
    "libbrcmEGL",
#endif
    "libEGL", nullptr};

const char* GLES_ANGLE = "libGLESv2_angle.so";
const char* EGL_ANGLE = "libEGL_angle.so";

bool g_angle_in_use = false;

extern "C" __attribute__((visibility("default"))) int mg_angle_in_use(void) {
    return g_angle_in_use ? 1 : 0;
}

static const char* angle_override(const char* name, std::string& storage) {
    const char* dir = getenv("MG_ANGLE_DIR");
    if (dir == nullptr) {
        storage = name;
        return storage.c_str();
    }
    if (*dir == '\0') return nullptr;
    storage.assign(dir);
    if (storage.back() != '/') storage.push_back('/');
    storage.append(name);
    return storage.c_str();
}

void* open_lib(const char** names, const char* override, bool* used_override) {
    void* lib = nullptr;

    char path_name[PATH_MAX + 1];
    int flags = RTLD_LOCAL | RTLD_NOW;
    if (override) {
        if ((lib = dlopen(override, flags))) {
            strncpy(path_name, override, PATH_MAX);
            LOG_D("LIBGL:loaded: %s\n", path_name)
            if (used_override) *used_override = true;
            return lib;
        } else {
            LOG_E("LIBGL_GLES override failed: %s\n", dlerror())
        }
    }
    for (int p = 0; path_prefix[p]; p++) {
        for (int i = 0; names[i]; i++) {
            for (int e = 0; lib_ext[e]; e++) {
                snprintf(path_name, PATH_MAX, "%s%s.%s", path_prefix[p], names[i], lib_ext[e]);
                if ((lib = dlopen(path_name, flags))) {
                    return lib;
                }
            }
        }
    }
    return lib;
}

void load_libs() {
#ifndef __APPLE__
    const bool want_angle = global_settings.angle == AngleMode::Enabled;
    std::string gles_angle, egl_angle;
    const char* gles_override = want_angle ? angle_override(GLES_ANGLE, gles_angle) : nullptr;
    const char* egl_override = want_angle ? angle_override(EGL_ANGLE, egl_angle) : nullptr;

    g_angle_in_use = false;
    gles = open_lib(gles3_lib, gles_override, &g_angle_in_use);
    egl = open_lib(egl_lib, egl_override, nullptr);
    if (want_angle && !g_angle_in_use) {
        LOG_E("ANGLE was requested but was not loaded; running on the system driver\n")
    }
#else
    gles = (void*)(~(uintptr_t)0);
    egl = (void*)(~(uintptr_t)0);
#endif
}

void* proc_address(void* lib, const char* name) {
    return dlsym(lib, name);
}
