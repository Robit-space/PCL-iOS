#import <Foundation/Foundation.h>
#import "PCLVersionManager.h"
#import "PCLRendererManager.h"
#import "PCLInstanceManager.h"

@interface PCLLaunchArguments : NSObject

// 旧版方法 (兼容)
+ (NSDictionary *)buildArgumentsForVersion:(PCLVersionInfo *)version
                                   profile:(NSDictionary *)profile
                                    config:(NSDictionary *)config;

// 新版方法 (基于PCLInstance，支持版本隔离)
+ (NSDictionary *)buildArgumentsForInstance:(PCLInstance *)instance
                                versionInfo:(PCLVersionInfo *)version
                                   profile:(NSDictionary *)profile
                                    config:(NSDictionary *)config;

+ (NSString *)replaceVariables:(NSString *)string
                    withValues:(NSDictionary *)values
                         error:(NSError **)error;

+ (BOOL)areModsLoadedForVersion:(NSString *)version;

@end
