#import "PCLClasspathBuilder.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>

@implementation PCLClasspathBuilder

+ (NSString *)buildClasspathForVersion:(NSString *)version {
    PCLVersionInfo *info = [[PCLVersionManager sharedManager] versionInfoForId:version];
    if (!info) {
        return nil;
    }
    
    NSMutableString *classpath = [NSMutableString string];
    NSString *librariesDir = [self librariesDirectory];
    NSString *versionJar = [self versionJarPath:version];
    
    // Add version jar first
    [classpath appendString:versionJar];
    [classpath appendString:@":"];
    
    // Process libraries array
    for (NSDictionary *lib in info.libraries) {
        NSString *name = lib[@"name"];
        if (!name.length) continue;
        
        // Check rules
        if (![self shouldIncludeLibrary:lib]) {
            continue;
        }
        
        NSString *libPath = [self libraryPathForName:name inLibrariesDir:librariesDir];
        if ([[NSFileManager defaultManager] fileExistsAtPath:libPath]) {
            [classpath appendString:libPath];
            [classpath appendString:@":"];
        }
    }
    
    // Remove trailing colon
    if (classpath.length > 0 && [classpath hasSuffix:@":"]) {
        [classpath deleteCharactersInRange:NSMakeRange(classpath.length - 1, 1)];
    }
    
    return [NSString stringWithString:classpath];
}

+ (NSString *)librariesDirectory {
    NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    path = [path stringByAppendingPathComponent:@"PCL Games/libraries"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return path;
}

+ (NSString *)versionJarPath:(NSString *)version {
    NSString *versionsDir = [[PCLVersionManager sharedManager] versionsDirectory];
    NSString *versionDir = [versionsDir stringByAppendingPathComponent:version];
    
    // Try version-specific jar first
    NSString *versionJar = [versionDir stringByAppendingPathComponent:[version stringByAppendingString:@".jar"]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:versionJar]) {
        return versionJar;
    }
    
    // Fallback to inherited jar or default
    PCLVersionInfo *info = [[PCLVersionManager sharedManager] versionInfoForId:version];
    if (info.jar.length > 0) {
        NSString *inheritedJar = [versionDir stringByAppendingPathComponent:[info.jar stringByAppendingString:@".jar"]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:inheritedJar]) {
            return inheritedJar;
        }
    }
    
    return versionJar;
}

#pragma mark - Library Path Resolution

+ (NSString *)libraryPathForName:(NSString *)name inLibrariesDir:(NSString *)librariesDir {
    // Maven coordinates format: group:artifact:version[:classifier]
    NSArray *parts = [name componentsSeparatedByString:@":"];
    if (parts.count < 3) return nil;
    
    NSString *group = parts[0];
    NSString *artifact = parts[1];
    NSString *version = parts[2];
    NSString *classifier = parts.count >= 4 ? parts[3] : @"";
    
    // Convert group to path
    NSString *groupPath = [group stringByReplacingOccurrencesOfString:@"." withString:@"/"];
    
    // Build file name
    NSString *filename;
    if (classifier.length > 0) {
        filename = [NSString stringWithFormat:@"%@-@%@-%@.jar", artifact, version, classifier];
    } else {
        filename = [NSString stringWithFormat:@"%@-@%@.jar", artifact, version];
    }
    
    NSString *libPath = [librariesDir stringByAppendingPathComponent:groupPath];
    libPath = [libPath stringByAppendingPathComponent:artifact];
    libPath = [libPath stringByAppendingPathComponent:version];
    libPath = [libPath stringByAppendingPathComponent:filename];
    
    return libPath;
}

+ (BOOL)libraryExistsAtPath:(NSString *)path {
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

#pragma mark - Native Libraries

+ (NSString *)nativeLibraryPathForLibrary:(NSString *)library inLibrariesDir:(NSString *)librariesDir {
    // Look for native-{os} classifiers
    // For iOS, we may need specific native builds
    return nil;
}

#pragma mark - Rules Processing

+ (BOOL)shouldIncludeLibrary:(NSDictionary *)lib {
    NSArray *rules = lib[@"rules"];
    if (!rules || rules.count == 0) {
        return YES; // No rules means always include
    }
    return [self evaluateRules:rules];
}

+ (BOOL)evaluateRules:(NSArray *)rules {
    NSString *osName = [self currentOSName];
    NSString *osVersion = [self currentOSVersion];
    NSString *arch = [self currentArchitecture];
    
    BOOL allowed = YES;
    for (NSDictionary *rule in rules) {
        NSString *action = rule[@"action"];
        NSDictionary *os = rule[@"os"];
        NSDictionary *features = rule[@"features"];
        
        BOOL osMatch = YES;
        if (os) {
            NSString *ruleOs = os[@"name"];
            NSString *ruleVersion = os[@"version"];
            
            if (ruleOs && ![ruleOs isEqualToString:osName]) {
                osMatch = NO;
            }
            if (ruleVersion && ruleVersion.length > 0) {
                if (![self version:osVersion matchesPattern:ruleVersion]) {
                    osMatch = NO;
                }
            }
        }
        
        BOOL featuresMatch = YES;
        if (features) {
            // Check for specific features
            featuresMatch = [self checkFeatures:features];
        }
        
        if ([action isEqualToString:@"allow"]) {
            if (osMatch && featuresMatch) {
                allowed = YES;
            }
        } else if ([action isEqualToString:@"disallow"]) {
            if (osMatch && featuresMatch) {
                allowed = NO;
            }
        }
    }
    
    return allowed;
}

+ (BOOL)checkFeatures:(NSDictionary *)features {
    // Check for has_custom_resolution, etc.
    return YES;
}

+ (BOOL)version:(NSString *)version matchesPattern:(NSString *)pattern {
    if ([pattern isEqualToString:@"^10\\.0"]) {
        return [version hasPrefix:@"10.0"];
    }
    // Simple version matching
    return YES;
}

+ (NSString *)currentOSName {
    return @"ios";
}

+ (NSString *)currentOSVersion {
    UIDevice *device = [UIDevice currentDevice];
    return device.systemVersion;
}

+ (NSString *)currentArchitecture {
   	struct utsname systemInfo;
    uname(&systemInfo);
    NSString *arch = [NSString stringWithUTF8String:systemInfo.machine];
    
    if ([arch isEqualToString:@"arm64"] || [arch isEqualToString:@"aarch64"]) {
        return @"arm64";
    } else if ([arch hasPrefix:@"x86"]) {
        return @"x86_64";
    }
    return arch;
}

@end
