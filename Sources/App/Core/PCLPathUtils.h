#import <Foundation/Foundation.h>

@interface PCLPathUtils : NSObject

+ (NSString *)resourcePath:(NSString *)name;
+ (NSString *)resourcePath:(NSString *)name ofType:(NSString *)ext;

+ (NSString *)gameDirectory;
+ (NSString *)versionsDirectory;
+ (NSString *)instancesDirectory;

+ (NSString *)javaHomeForVersion:(NSInteger)version;
+ (NSString *)javaExecutableForVersion:(NSInteger)version;
+ (NSInteger)recommendedJavaVersionForMC:(NSString *)mcVersion;

+ (NSString *)lwjglJarPath:(NSString *)jarName;
+ (NSArray<NSString *> *)allLwjglJars;
+ (NSString *)caciocavalloJarDir:(NSInteger)javaVersion;

+ (NSString *)frameworkPath:(NSString *)dylibName;
+ (NSString *)rendererDylib:(NSString *)name;

@end
