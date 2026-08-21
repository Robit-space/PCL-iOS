#import <Foundation/Foundation.h>
#import "PCLVersionManager.h"

@interface PCLClasspathBuilder : NSObject

+ (NSString *)buildClasspathForVersion:(NSString *)version;

+ (NSString *)librariesDirectory;
+ (NSString *)versionJarPath:(NSString *)version;

@end
