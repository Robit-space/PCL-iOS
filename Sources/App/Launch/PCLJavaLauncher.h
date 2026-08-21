#import <Foundation/Foundation.h>
#include <jni.h>

typedef int (*PCLJLI_Launch)(int argc, const char ** argv,
        int jargc, const char** jargv,
        int appclassc, const char** appclassv,
        const char* fullversion,
        const char* dotversion,
        const char* pname,
        const char* lname,
        jboolean javaargs,
        jboolean cpwildcard,
        jboolean javaw,
        jint ergo);

@interface PCLJavaLauncher : NSObject

+ (instancetype)sharedLauncher;

@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, strong, readonly) NSMutableDictionary *environment;
@property (nonatomic, strong) NSString *account;
@property (nonatomic) int gameWidth;
@property (nonatomic) int gameHeight;

- (void)setupEnvironment:(NSString *)gameVersion mcVersion:(NSString *)mcVersion;
- (BOOL)launchWithMainClass:(NSString *)mainClass
                  classpath:(NSString *)classpath
                      args:(NSArray<NSString *> *)args
                     error:(NSError **)error;
- (void)terminate;

@end
