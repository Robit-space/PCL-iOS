/*
 *  Copyright (c) 1996, 2024, Oracle and/or its affiliates.
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * iOS Minimal JNI Header
 * Based on OpenJDK JNI spec for iOS/arm64 compatibility
 * Provides required types for PCLJavaLauncher
 */

#ifndef _JAVASOFT_JNI_H_
#define _JAVASOFT_JNI_H_

#include <stdint.h>
#include <stdarg.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * JNI Types
 */
typedef unsigned char   jboolean;
typedef unsigned short  jchar;
typedef short           jshort;
typedef float           jfloat;
typedef double          jdouble;
typedef int32_t         jint;
typedef int64_t         jlong;
typedef int8_t          jbyte;

/*
 * JNI Object Types
 */
typedef void*           jobject;
typedef jobject         jclass;
typedef jobject         jstring;
typedef jobject         jarray;
typedef jarray          jobjectArray;
typedef jarray          jbooleanArray;
typedef jarray          jbyteArray;
typedef jarray          jcharArray;
typedef jarray          jshortArray;
typedef jarray          jintArray;
typedef jarray          jlongArray;
typedef jarray          jfloatArray;
typedef jarray          jdoubleArray;
typedef jobject         jthrowable;
typedef jobject         jweak;
typedef jint            jsize;

/*
 * jvalue union
 */
typedef union jvalue {
    jboolean    z;
    jbyte       b;
    jchar       c;
    jshort      s;
    jint        i;
    jlong       j;
    jfloat      f;
    jdouble     d;
    jobject     l;
} jvalue;

/*
 * JNI Native Method
 */
struct JNINativeMethod {
    const char* name;
    const char* signature;
    void*       fnPtr;
};

/*
 * JNI Version constants
 */
#define JNI_VERSION_1_1 0x00010001
#define JNI_VERSION_1_2 0x00010002
#define JNI_VERSION_1_4 0x00010004
#define JNI_VERSION_1_6 0x00010006
#define JNI_VERSION_1_8 0x00010008
#define JNI_VERSION_9   0x00090000
#define JNI_VERSION_10  0x000a0000
#define JNI_VERSION_19  0x00130000
#define JNI_VERSION_20  0x00140000
#define JNI_VERSION_21  0x00150000

/*
 * jboolean constants
 */
#define JNI_FALSE 0
#define JNI_TRUE  1

/*
 * Return values for JNI functions
 */
#define JNI_OK          0
#define JNI_ERR         (-1)
#define JNI_EDETACHED   (-2)
#define JNI_EVERSION    (-3)
#define JNI_ENOMEM      (-4)
#define JNI_EEXIST      (-5)
#define JNI_EINVAL      (-6)

#ifdef __cplusplus
}
#endif

#endif /* _JAVASOFT_JNI_H_ */
