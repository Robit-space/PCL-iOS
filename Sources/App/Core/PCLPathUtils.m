#import "PCLPathUtils.h"

@implementation PCLPathUtils

+ (NSString *)resourcePath:(NSString *)name {
    return [[NSBundle mainBundle] pathForResource:name ofType:nil];
}

+ (NSString *)resourcePath:(NSString *)name ofType:(NSString *)ext {
    return [[NSBundle mainBundle] pathForResource:name ofType:ext];
}

+ (NSString *)dependsDir {
    return [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"depends"];
}

+ (NSString *)gameDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsDir = paths.firstObject;
    NSString *gameDir = [docsDir stringByAppendingPathComponent:@".minecraft"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:gameDir]) {
        [fm createDirectoryAtPath:gameDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return gameDir;
}

+ (NSString *)versionsDirectory {
    return [[self gameDirectory] stringByAppendingPathComponent:@"versions"];
}

+ (NSString *)instancesDirectory {
    return [[self gameDirectory] stringByAppendingPathComponent:@"instances"];
}

+ (NSString *)javaHomeForVersion:(NSInteger)version {
    // 优先从.app中的java_runtimes目录查找（参考Amethyst）
    NSString *appJavaDir = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:
        [NSString stringWithFormat:@"java_runtimes/java-%ld-openjdk", (long)version]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[appJavaDir stringByAppendingPathComponent:@"release"]]) {
        return appJavaDir;
    }
    // 回退到depends目录
    NSString *path = [[self dependsDir] stringByAppendingPathComponent:[NSString stringWithFormat:@"java-%ld-openjdk", (long)version]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathComponent:@"release"]]) return path;
    return nil;
}

+ (NSString *)javaExecutableForVersion:(NSInteger)version {
    NSString *home = [self javaHomeForVersion:version];
    if (home) return [home stringByAppendingPathComponent:@"bin/java"];
    return nil;
}

+ (NSInteger)recommendedJavaVersionForMC:(NSString *)mcVersion {
    if (!mcVersion) return 17;
    NSArray *parts = [mcVersion componentsSeparatedByString:@"."];
    if (parts.count < 2) return 17;
    NSInteger minor = [parts[1] integerValue];
    if (minor >= 17) return 21;
    if (minor >= 16) return 17;
    return 8;
}

+ (NSString *)lwjglJarPath:(NSString *)jarName {
    NSString *path = [[[self dependsDir] stringByAppendingPathComponent:@"libs/lwjgl"] stringByAppendingPathComponent:jarName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) return path;
    path = [[[self dependsDir] stringByAppendingPathComponent:@"libs"] stringByAppendingPathComponent:jarName];
    return [[NSFileManager defaultManager] fileExistsAtPath:path] ? path : nil;
}

+ (NSArray<NSString *> *)allLwjglJars {
    NSString *lwjglDir = [[self dependsDir] stringByAppendingPathComponent:@"libs/lwjgl"];
    NSString *othersDir = [[self dependsDir] stringByAppendingPathComponent:@"libs/others"];
    NSArray *lwjglJars = @[
        @"lwjgl.jar", @"lwjgl-opengl.jar", @"lwjgl-openal.jar", @"lwjgl-glfw.jar",
        @"lwjgl-stb.jar", @"lwjgl-nanovg.jar", @"lwjgl-vulkan.jar",
        @"lwjgl-callback-descriptor.jar", @"lwjgl-input.jar",
        @"lwjgl-system.jar", @"lwjgl-util.jar"
    ];
    NSArray *otherJars = @[@"gson-2.13.1.jar", @"jsr305.jar", @"arc_dns_injector.jar"];
    NSMutableArray *result = [NSMutableArray array];
    for (NSString *name in lwjglJars) {
        NSString *path = [lwjglDir stringByAppendingPathComponent:name];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) [result addObject:path];
    }
    for (NSString *name in otherJars) {
        NSString *path = [othersDir stringByAppendingPathComponent:name];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) [result addObject:path];
    }
    return result;
}

+ (NSString *)caciocavalloJarDir:(NSInteger)javaVersion {
    NSString *folder = javaVersion >= 17 ? @"libs/caciocavallo17" : @"libs/caciocavallo";
    NSString *path = [[self dependsDir] stringByAppendingPathComponent:folder];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) return path;
    folder = javaVersion >= 17 ? @"libs_caciocavallo17" : @"libs_caciocavallo";
    path = [[self dependsDir] stringByAppendingPathComponent:folder];
    return [[NSFileManager defaultManager] fileExistsAtPath:path] ? path : nil;
}

+ (NSString *)frameworkPath:(NSString *)dylibName {
    NSString *path = [[NSBundle mainBundle] pathForResource:[dylibName stringByDeletingPathExtension] ofType:@"dylib"];
    return path;
}

+ (NSString *)rendererDylib:(NSString *)name {
    NSDictionary *map = @{
        @"gl4es": @"libgl4es_114.dylib",
        @"angle": @"libtinygl4angle.dylib",
        @"mobileglues": @"libmobileglues.dylib",
        @"osmesa": @"libOSMesa.8.dylib",
        @"ltw": @"libltw.dylib"
    };
    NSString *dylib = map[name] ?: @"libgl4es_114.dylib";
    return [self frameworkPath:dylib];
}

@end
