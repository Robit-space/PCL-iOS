// MobileGlues - gles/gles.h
// Copyright (c) 2025-2026 MobileGL-Dev
// Licensed under the GNU Lesser General Public License v2.1:
//   https://www.gnu.org/licenses/old-licenses/lgpl-2.1.txt
// SPDX-License-Identifier: LGPL-2.1-only
// End of Source File Header

#include <GL/gl.h>

#ifndef MOBILEGLUES_GLES_H
#define MOBILEGLUES_GLES_H

#define GL_TEXTURE_LOD_BIAS_QCOM 0x8C96

#define APIENTRY_GLES

#define GL_FUNC_TYPEDEF(type, name, ...) typedef type(APIENTRY_GLES* name##_PTR)(__VA_ARGS__);

#ifdef __cplusplus
extern "C"
{
#endif

    GL_FUNC_TYPEDEF(void, glActiveTexture, GLenum texture)
    GL_FUNC_TYPEDEF(void, glAttachShader, GLuint program, GLuint shader)
    GL_FUNC_TYPEDEF(void, glBindAttribLocation, GLuint program, GLuint index, const GLchar* name)
    GL_FUNC_TYPEDEF(void, glBindBuffer, GLenum target, GLuint buffer)
    GL_FUNC_TYPEDEF(void, glBindFramebuffer, GLenum target, GLuint framebuffer)
    GL_FUNC_TYPEDEF(void, glBindRenderbuffer, GLenum target, GLuint renderbuffer)
    GL_FUNC_TYPEDEF(void, glBindTexture, GLenum target, GLuint texture)

#ifdef __cplusplus
}
#endif

#endif // MOBILEGLUES_GLES_H
