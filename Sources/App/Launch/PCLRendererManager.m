#import "PCLRendererManager.h"

static NSString *const kSelectedRendererKey = @"PCLSelectedRenderer";

@implementation PCLRendererManager

+ (NSArray<NSDictionary *> *)availableRenderers {
    return @[
        @{
            @"id": @(PCLRenderRendererGL4ES),
            @"name": @"GL4ES",
            @"description": @"OpenGL ES 1.1/2.0 translation layer",
            @"dylibName": @"libgl4es.dylib",
            @"minOpenGL": @"2.0",
            @"defaultReset": @YES
        },
        @{
            @"id": @(PCLRenderRendererMetalANGLE),
            @"name": @"MetalANGLE",
            @"description": @"OpenGL ES via Metal on iOS",
            @"dylibName": @"libEGL.dylib",
            @"minOpenGL": @"3.0",
            @"defaultReset": @YES
        },
        @{
            @"id": @(PCLRenderRendererMobileGlues),
            @"name": @"MobileGlues",
            @"description": @"Mobile OpenGL emulation",
            @"dylibName": @"libmobileglues.dylib",
            @"minOpenGL": @"2.0",
            @"defaultReset": @NO
        },
        @{
            @"id": @(PCLRenderRendererZinkVK),
            @"name": @"Zink + VK",
            @"description": @"OpenGL over Vulkan (experimental)",
            @"dylibName": @"libzvulkan.dylib",
            @"minOpenGL": @"4.0",
            @"defaultReset": @YES
        }
    ];
}

+ (PCLRenderRenderer)selectedRenderer {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger stored = [defaults integerForKey:kSelectedRendererKey];
    if (stored >= PCLRenderRendererGL4ES && stored <= PCLRenderRendererZinkVK) {
        return (PCLRenderRenderer)stored;
    }
    return PCLRenderRendererGL4ES; // Default
}

+ (void)setSelectedRenderer:(PCLRenderRenderer)renderer {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:renderer forKey:kSelectedRendererKey];
    [defaults synchronize];
}

+ (NSString *)rendererLibPath {
    PCLRenderRenderer renderer = [self selectedRenderer];
    NSString *dylibName = [self dylibNameForRenderer:renderer];
    
    // First check Support directory
    NSArray *searchPaths = @[
        [[NSBundle mainBundle].bundlePath stringByAppendingPathComponent:@"Frameworks"],
        [[NSBundle mainBundle].bundlePath stringByAppendingPathComponent:@"Frameworks"],
        [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"Frameworks"],
        [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"frameworks"],
        NSHomeDirectory()
    ];
    
    for (NSString *baseDir in searchPaths) {
        NSString *libPath = [baseDir stringByAppendingPathComponent:dylibName];
        if ([[NSFileManager defaultManager] fileExistsAtPath:libPath]) {
            return libPath;
        }
    }
    
    // Return expected path even if not found (will be checked at runtime)
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject 
            stringByAppendingPathComponent:[NSString stringWithFormat:@"frameworks/%@", dylibName]];
}

+ (NSDictionary *)rendererEnvVars {
    PCLRenderRenderer renderer = [self selectedRenderer];
    NSMutableDictionary *env = [NSMutableDictionary dictionary];
    
    switch (renderer) {
        case PCLRenderRendererGL4ES:
            env[@"LIBGL_ES"] = @"2";
            env[@"LIBGL_GL"] = @"21";
            env[@"LIBGL_FB"] = @"1";
            env[@"LIBGL_VSYNC"] = @"1";
            env[@"LIBGL_NOTEXRECT"] = @"1";
            env[@"MESA_GL_VERSION_OVERRIDE"] = @"4.3";
            env[@"MESA_GLSL_VERSION_OVERRIDE"] = @"430";
            env[@"force_glcodes"] = @"false";
            env[@"force_glsl"] = @"true";
            break;
            
        case PCLRenderRendererMetalANGLE:
            env[@"LIBGL_ES"] = @"3";
            env[@"LIBGL_GL"] = @"33";
            env[@"MESA_GL_VERSION_OVERRIDE"] = @"4.1";
            env[@"MESA_GLSL_VERSION_OVERRIDE"] = @"410";
            env[@"ANGLE_DEFAULT_PLATFORM"] = @"metal";
            env[@"dxil_dxc_path"] = @"false";
            break;
            
        case PCLRenderRendererMobileGlues:
            env[@"LIBGL_ES"] = @"2";
            env[@"LIBGL_GL"] = @"21";
            env[@"MOBILEGLUES_NOGLSL"] = @"false";
            env[@"MOBILEGLUES_FORCEGLSL"] = @"true";
            env[@"MOBILEGLUES_NOBOGUS"] = @"true";
            break;
            
        case PCLRenderRendererZinkVK:
            env[@"LIBGL_ES"] = @"3";
            env[@"LIBGL_GL"] = @"46";
            env[@"MESA_GL_VERSION_OVERRIDE"] = @"4.6";
            env[@"MESA_GLSL_VERSION_OVERRIDE"] = @"460";
            env[@"force_vulkan"] = @"true";
            env[@"ZINK_DESCRIPTORS"] = @"auto";
            env[@"ZINK_TEX_CACHE"] = @"true";
            break;
    }
    
    return [env copy];
}

+ (BOOL)isRendererAvailable:(PCLRenderRenderer)renderer {
    // Check if the renderer dylib exists
    NSString *dylibName = [self dylibNameForRenderer:renderer];
    NSArray *searchDirs = @[
        NSHomeDirectory(),
        [NSBundle mainBundle].resourcePath,
        [NSBundle mainBundle].bundlePath,
        [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"frameworks"],
        [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"frameworks"]
    ];
    
    for (NSString *dir in searchDirs) {
        NSString *path = [dir stringByAppendingPathComponent:dylibName];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            return YES;
        }
    }
    
    return NO;
}

+ (NSString *)nameForRenderer:(PCLRenderRenderer)renderer {
    switch (renderer) {
        case PCLRenderRendererNone: return @"默认";
        case PCLRenderRendererGL4ES: return @"GL4ES";
        case PCLRenderRendererMetalANGLE: return @"MetalANGLE";
        case PCLRenderRendererMobileGlues: return @"MobileGlues";
        case PCLRenderRendererZinkVK: return @"Zink + Vulkan";
        default: return @"未知";
    }
}

+ (NSString *)dylibNameForRenderer:(PCLRenderRenderer)renderer {
    switch (renderer) {
        case PCLRenderRendererNone: return @"libgl4es.dylib";
        case PCLRenderRendererGL4ES: return @"libgl4es.dylib";
        case PCLRenderRendererMetalANGLE: return @"libEGL.dylib";
        case PCLRenderRendererMobileGlues: return @"libmobileglues.dylib";
        case PCLRenderRendererZinkVK: return @"libzvulkan.dylib";
        default: return @"libgl4es.dylib";
    }
}

@end
