#import "PCLLaunchArguments.h"
#import "PCLClasspathBuilder.h"
#import "PCLPathUtils.h"
#import "PCLInstanceManager.h"

@implementation PCLLaunchArguments

+ (NSDictionary *)buildArgumentsForVersion:(PCLVersionInfo *)version
                                   profile:(NSDictionary *)profile
                                    config:(NSDictionary *)config {
    
    NSString *gameDir = [self gameDirectoryForProfile:profile version:version];
    NSString *assetsDir = [[PCLVersionManager sharedManager] assetsDirectory];
    NSString *assetIndex = version.assets ?: version.assetIndex;
    NSString *playerName = profile[@"username"] ?: profile[@"name"] ?: @"Player";
    NSString *versionName = version.versionId;
    
    // Determine if modern args (1.13+) or legacy
    BOOL isModernArgs = [self isModernVersion:version];
    
    // Build classpath
    NSString *classpath = [PCLClasspathBuilder buildClasspathForVersion:version];
    
    // Build JVM arguments
    NSMutableArray *jvmArgs = [NSMutableArray array];
    
    // Memory settings
    NSInteger minMemory = [config[@"minMemory"] integerValue] ?: 512;
    NSInteger maxMemory = [config[@"maxMemory"] integerValue] ?: 2048;
    [jvmArgs addObject:[NSString stringWithFormat:@"-Xms%ldM", (long)minMemory]];
    [jvmArgs addObject:[NSString stringWithFormat:@"-Xmx%ldM", (long)maxMemory]];
    
    // Required JVM options
    [jvmArgs addObject:@"-XX:+UseG1GC"];
    [jvmArgs addObject:@"-XX:-OmitStackTraceInFastThrow"];
    [jvmArgs addObject:@"-XX:+UnlockExperimentalVMOptions"];
    [jvmArgs addObject:@"-XX:G1NewSizePercent=20"];
    [jvmArgs addObject:@"-XX:G1MaxNewSizePercent=40"];
    [jvmArgs addObject:@"-XX:G1HeapRegionSize=8M"];
    [jvmArgs addObject:@"-XX:G1ReservePercent=20"];
    [jvmArgs addObject:@"-Djava.awt.headless=false"];
    
    // Renderer-specific JVM args
    PCLRenderRenderer renderer = [PCLRendererManager selectedRenderer];
    if (renderer == PCLRenderRendererGL4ES) {
        [jvmArgs addObject:@"-Dorg.lwjgl.opengl.libname=libgl4es.dylib"];
    } else if (renderer == PCLRenderRendererMetalANGLE) {
        [jvmArgs addObject:@"-Dorg.lwjgl.opengl.libname=libEGL.dylib"];
    }
    
    // Custom JVM args from config
    NSString *customJvmArgs = config[@"jvmArguments"];
    if (customJvmArgs.length > 0) {
        NSArray *customs = [customJvmArgs componentsSeparatedByString:@" "];
        for (NSString *arg in customs) {
            NSString *trimmed = [arg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (trimmed.length > 0) {
                [jvmArgs addObject:trimmed];
            }
        }
    }
    
    // Game arguments
    NSMutableArray *gameArgs = [NSMutableArray array];
    NSDictionary *varValues = @{
        @"auth_player_name": playerName,
        @"version_name": versionName,
        @"game_directory": gameDir,
        @"assets_root": assetsDir,
        @"assets_index_name": assetIndex,
        @"auth_uuid": profile[@"uuid"] ?: @"0",
        @"auth_access_token": profile[@"accessToken"] ?: @"0",
        @"user_type": profile[@"type"] ?: @"msa",
        @"version_type": version.versionType ?: @"release",
        @"user_properties": @"{}",
        @"auth_session": profile[@"accessToken"] ?: @"0",
        @"game_assets": assetsDir
    };
    
    if (isModernArgs) {
        // Modern arguments (1.13+) - --key value format
        NSArray *modernArgs = @[
            @"--width", @"1280",
            @"--height", @"720",
            @"--fullscreen", @"false",
            @"--autoConnect", @"false",
            @"--disableMultiplayer", @"false",
            @"--disableChat", @"false"
        ];
        [gameArgs addObjectsFromArray:modernArgs];
        
        // Apply minecraftArguments if present in JSON
        if (version.minecraftArguments.length > 0) {
            NSArray *mcArgs = [version.minecraftArguments componentsSeparatedByString:@" "];
            for (NSString *arg in mcArgs) {
                NSString *trimmed = [arg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSString *replaced = [self replaceVariables:trimmed withValues:varValues error:nil];
                if (replaced.length > 0) {
                    [gameArgs addObject:replaced];
                }
            }
        }
    } else {
        // Legacy arguments - space-separated
        NSArray *legacyArgs = @[
            @"--width", @"1280",
            @"--height", @"720"
        ];
        [gameArgs addObjectsFromArray:legacyArgs];
        
        if (version.minecraftArguments.length > 0) {
            NSArray *mcArgs = [version.minecraftArguments componentsSeparatedByString:@" "];
            for (NSString *arg in mcArgs) {
                NSString *replaced = [self replaceVariables:arg withValues:varValues error:nil];
                if (replaced.length > 0) {
                    [gameArgs addObject:replaced];
                }
            }
        }
    }
    
    return @{
        @"mainClass": version.mainClass ?: @"net.minecraft.client.main.Main",
        @"jvmArguments": [jvmArgs copy],
        @"gameArguments": [gameArgs copy],
        @"classpath": classpath,
        @"gameDirectory": gameDir,
        @"javaPath": [PCLPathUtils javaExecutableForVersion:[PCLPathUtils recommendedJavaVersionForMC:version.versionId]] ?: @""
    };
}

+ (NSString *)replaceVariables:(NSString *)string
                    withValues:(NSDictionary *)values
                         error:(NSError **)error {
    if (!string.length) return string;
    
    NSMutableString *result = [string mutableCopy];
    [values enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        NSString *placeholder = [NSString stringWithFormat:@"${%@}", key];
        [result replaceOccurrencesOfString:placeholder
                               withString:value ?: @""
                                  options:0
                                    range:NSMakeRange(0, result.length)];
    }];
    
    return [result copy];
}

+ (BOOL)areModsLoadedForVersion:(NSString *)version {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:[NSString stringWithFormat:@"modsLoaded_%@", version]];
}

#pragma mark - Private Helpers

+ (BOOL)isModernVersion:(PCLVersionInfo *)version {
    // 1.13+ uses the modern argument format
    if ([version.versionId hasPrefix:@"1."]) {
        NSArray *parts = [version.versionId componentsSeparatedByString:@"."];
        if (parts.count >= 2) {
            NSInteger minor = [parts[1] integerValue];
            if (minor >= 13) return YES;
        }
    } else if ([version.versionId hasPrefix:@"2"] || [version.versionId hasPrefix:@"3"]) {
        return YES;
    }
    return NO;
}

+ (NSString *)gameDirectoryForProfile:(NSDictionary *)profile version:(PCLVersionInfo *)version {
    if (profile[@"gameDir"]) {
        return profile[@"gameDir"];
    }
    return [[PCLVersionManager sharedManager] instanceDirectoryWithName:version.versionId];
}

#pragma mark - 版本隔离支持 (PCL2-CE风格)

+ (NSDictionary *)buildArgumentsForInstance:(PCLInstance *)instance
                                 versionInfo:(PCLVersionInfo *)version
                                    profile:(NSDictionary *)profile
                                     config:(NSDictionary *)config {
    
    // 使用PCLInstanceManager获取版本隔离的游戏目录
    PCLInstanceManager *instanceManager = [PCLInstanceManager sharedManager];
    NSString *gameDir = [instanceManager gameDirectoryForInstance:instance];
    
    // 如果instance有自定义gameDir，优先使用
    if (instance.gameDir.length > 0) {
        gameDir = instance.gameDir;
    }
    
    NSString *assetsDir = [[PCLVersionManager sharedManager] assetsDirectory];
    NSString *assetIndex = version.assets ?: version.assetIndex;
    NSString *playerName = profile[@"username"] ?: profile[@"name"] ?: @"Player";
    NSString *versionName = version.versionId;
    
    // Determine if modern args (1.13+) or legacy
    BOOL isModernArgs = [self isModernVersion:version];
    
    // Build classpath
    NSString *classpath = [PCLClasspathBuilder buildClasspathForVersion:version];
    
    // Build JVM arguments
    NSMutableArray *jvmArgs = [NSMutableArray array];
    
    // Memory settings (优先使用instance设置)
    NSInteger minMemory = instance.memoryMinMB > 0 ? instance.memoryMinMB : ([config[@"minMemory"] integerValue] ?: 512);
    NSInteger maxMemory = instance.memoryMaxMB > 0 ? instance.memoryMaxMB : ([config[@"maxMemory"] integerValue] ?: 2048);
    [jvmArgs addObject:[NSString stringWithFormat:@"-Xms%ldM", (long)minMemory]];
    [jvmArgs addObject:[NSString stringWithFormat:@"-Xmx%ldM", (long)maxMemory]];
    
    // Required JVM options
    [jvmArgs addObject:@"-XX:+UseG1GC"];
    [jvmArgs addObject:@"-XX:-OmitStackTraceInFastThrow"];
    [jvmArgs addObject:@"-XX:+UnlockExperimentalVMOptions"];
    [jvmArgs addObject:@"-XX:G1NewSizePercent=20"];
    [jvmArgs addObject:@"-XX:G1MaxNewSizePercent=40"];
    [jvmArgs addObject:@"-XX:G1HeapRegionSize=8M"];
    [jvmArgs addObject:@"-XX:G1ReservePercent=20"];
    [jvmArgs addObject:@"-Djava.awt.headless=false"];
    
    // Renderer-specific JVM args (优先使用instance的渲染器选择)
    PCLRenderRenderer renderer = instance.renderer;
    if (renderer == PCLRenderRendererNone) {
        renderer = [PCLRendererManager selectedRenderer];
    }
    if (renderer == PCLRenderRendererGL4ES) {
        [jvmArgs addObject:@"-Dorg.lwjgl.opengl.libname=libgl4es.dylib"];
    } else if (renderer == PCLRenderRendererMetalANGLE) {
        [jvmArgs addObject:@"-Dorg.lwjgl.opengl.libname=libEGL.dylib"];
    }
    
    // Instance自定义JVM参数
    if (instance.javaArgs.length > 0) {
        NSArray *customs = [instance.javaArgs componentsSeparatedByString:@" "];
        for (NSString *arg in customs) {
            NSString *trimmed = [arg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (trimmed.length > 0) {
                [jvmArgs addObject:trimmed];
            }
        }
    }
    
    // Custom JVM args from config
    NSString *customJvmArgs = config[@"jvmArguments"];
    if (customJvmArgs.length > 0) {
        NSArray *customs = [customJvmArgs componentsSeparatedByString:@" "];
        for (NSString *arg in customs) {
            NSString *trimmed = [arg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (trimmed.length > 0) {
                [jvmArgs addObject:trimmed];
            }
        }
    }
    
    // Game arguments
    NSMutableArray *gameArgs = [NSMutableArray array];
    NSDictionary *varValues = @{
        @"auth_player_name": playerName,
        @"version_name": versionName,
        @"game_directory": gameDir,
        @"assets_root": assetsDir,
        @"assets_index_name": assetIndex,
        @"auth_uuid": profile[@"uuid"] ?: @"0",
        @"auth_access_token": profile[@"accessToken"] ?: @"0",
        @"user_type": profile[@"type"] ?: @"msa",
        @"version_type": version.versionType ?: @"release",
        @"user_properties": @"{}",
        @"auth_session": profile[@"accessToken"] ?: @"0",
        @"game_assets": assetsDir
    };
    
    // 分辨率设置 (优先使用instance设置)
    NSInteger resWidth = instance.resolutionWidth > 0 ? instance.resolutionWidth : 1280;
    NSInteger resHeight = instance.resolutionHeight > 0 ? instance.resolutionHeight : 720;
    
    if (isModernArgs) {
        NSArray *modernArgs = @[
            @"--width", @(resWidth).stringValue,
            @"--height", @(resHeight).stringValue,
            @"--fullscreen", @"false",
            @"--autoConnect", @"false",
            @"--disableMultiplayer", @"false",
            @"--disableChat", @"false"
        ];
        [gameArgs addObjectsFromArray:modernArgs];
        
        if (version.minecraftArguments.length > 0) {
            NSArray *mcArgs = [version.minecraftArguments componentsSeparatedByString:@" "];
            for (NSString *arg in mcArgs) {
                NSString *trimmed = [arg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSString *replaced = [self replaceVariables:trimmed withValues:varValues error:nil];
                if (replaced.length > 0) {
                    [gameArgs addObject:replaced];
                }
            }
        }
    } else {
        NSArray *legacyArgs = @[
            @"--width", @(resWidth).stringValue,
            @"--height", @(resHeight).stringValue
        ];
        [gameArgs addObjectsFromArray:legacyArgs];
        
        if (version.minecraftArguments.length > 0) {
            NSArray *mcArgs = [version.minecraftArguments componentsSeparatedByString:@" "];
            for (NSString *arg in mcArgs) {
                NSString *replaced = [self replaceVariables:arg withValues:varValues error:nil];
                if (replaced.length > 0) {
                    [gameArgs addObject:replaced];
                }
            }
        }
    }
    
    // Instance自定义游戏参数
    if (instance.gameArguments.length > 0) {
        NSArray *customGameArgs = [instance.gameArguments componentsSeparatedByString:@" "];
        for (NSString *arg in customGameArgs) {
            NSString *trimmed = [arg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (trimmed.length > 0) {
                [gameArgs addObject:trimmed];
            }
        }
    }
    
    // 自动加入服务器
    if (instance.autoJoinServer && instance.serverAddress.length > 0) {
        [gameArgs addObject:@"--server"];
        [gameArgs addObject:instance.serverAddress];
    }
    
    // Java路径 (优先使用instance的Java路径覆盖)
    NSString *javaPath = instance.javaPathOverride.length > 0 ? instance.javaPathOverride :
                        [PCLPathUtils javaExecutableForVersion:[PCLPathUtils recommendedJavaVersionForMC:version.versionId]] ?: @"";
    
    return @{
        @"mainClass": version.mainClass ?: @"net.minecraft.client.main.Main",
        @"jvmArguments": [jvmArgs copy],
        @"gameArguments": [gameArgs copy],
        @"classpath": classpath,
        @"gameDirectory": gameDir,
        @"javaPath": javaPath,
        @"instanceName": instance.name ?: @"",
        @"versionIsolation": @(instance.versionIsolation)
    };
}

@end
