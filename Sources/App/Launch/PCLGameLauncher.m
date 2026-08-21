#import "PCLGameLauncher.h"
#import "PCLLaunchArguments.h"
#import "PCLClasspathBuilder.h"
#import "PCLRendererManager.h"
#import "PCLJITManager.h"
#import "PCLProfileStore.h"
#import "PCLPathUtils.h"

static NSString *const kErrorDomain = @"PCLGameLauncher";

@interface PCLGameLauncher ()

@property (nonatomic, assign) BOOL isCancelled;
@property (nonatomic, strong) NSTimer *heartbeatTimer;

@end

@implementation PCLGameLauncher

+ (instancetype)sharedLauncher {
    static PCLGameLauncher *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PCLGameLauncher alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isCancelled = NO;
    }
    return self;
}

#pragma mark - Public Methods

- (void)launchWithVersion:(NSString *)versionId
                  profile:(NSDictionary *)profile
               completion:(PCLLaunchCompletion)completion {
    
    if (!versionId.length) {
        NSError *error = [self errorWithCode:PCLLaunchErrorVersionNotFound message:@"Version ID is empty"];
        if (completion) completion(NO, error);
        return;
    }
    
    if (!profile) {
        profile = [PCLProfileStore selectedProfile];
    }
    
    [self log:@"Starting launch sequence..."];
    [self log:[NSString stringWithFormat:@"  Version: %@", versionId]];
    [self log:[NSString stringWithFormat:@"  Profile: %@", profile[@"name"] ?: profile[@"username"] ?: @"Default"]];
    
    // Step 1: Validate version
    [self log:@"Step 1/5: Validating version..."];
    PCLVersionInfo *versionInfo = [[PCLVersionManager sharedManager] versionInfoForId:versionId];
    if (!versionInfo) {
        [self loadVersionJson:versionId completion:^(PCLVersionInfo *info, NSError *loadError) {
            if (loadError || !info) {
                NSError *error = [self errorWithCode:PCLLaunchErrorVersionNotFound 
                                             message:@"Version JSON not found"];
                if (completion) completion(NO, error);
                return;
            }
            [self proceedWithVersion:info profile:profile completion:completion];
        }];
    } else {
        [self proceedWithVersion:versionInfo profile:profile completion:completion];
    }
}

- (void)cancelLaunch {
    self.isCancelled = YES;
    [self log:@"Launch cancelled by user."];
}

#pragma mark - 版本隔离启动 (PCL2-CE风格)

- (void)launchWithInstance:(PCLInstance *)instance
                   profile:(NSDictionary *)profile
                completion:(PCLLaunchCompletion)completion {
    
    if (!instance) {
        NSError *error = [self errorWithCode:PCLLaunchErrorProfileInvalid message:@"Instance is nil"];
        if (completion) completion(NO, error);
        return;
    }
    
    // 保存当前实例
    [[PCLInstanceManager sharedManager] selectInstance:instance];
    
    [self log:[NSString stringWithFormat:@"Launching instance: %@ (isolation: %@)", 
               instance.name, instance.versionIsolation ? @"ON" : @"OFF"]];
    
    // 加载版本信息
    NSString *versionId = instance.versionId;
    if (!versionId.length) {
        NSError *error = [self errorWithCode:PCLLaunchErrorVersionNotFound message:@"Instance has no version"];
        if (completion) completion(NO, error);
        return;
    }
    
    PCLVersionInfo *versionInfo = [[PCLVersionManager sharedManager] versionInfoForId:versionId];
    if (!versionInfo) {
        [self loadVersionJson:versionId completion:^(PCLVersionInfo *info, NSError *loadError) {
            if (loadError || !info) {
                NSError *error = [self errorWithCode:PCLLaunchErrorVersionNotFound 
                                             message:@"Version JSON not found"];
                if (completion) completion(NO, error);
                return;
            }
            [self proceedWithInstance:instance versionInfo:info profile:profile completion:completion];
        }];
    } else {
        [self proceedWithInstance:instance versionInfo:versionInfo profile:profile completion:completion];
    }
}

- (void)launchWithCurrentInstance:(NSDictionary *)profile
                       completion:(PCLLaunchCompletion)completion {
    
    PCLInstance *currentInstance = [[PCLInstanceManager sharedManager] currentInstance];
    if (!currentInstance) {
        NSError *error = [self errorWithCode:PCLLaunchErrorProfileInvalid message:@"No instance selected"];
        if (completion) completion(NO, error);
        return;
    }
    
    [self launchWithInstance:currentInstance profile:profile completion:completion];
}

- (void)proceedWithInstance:(PCLInstance *)instance
                  versionInfo:(PCLVersionInfo *)versionInfo
                      profile:(NSDictionary *)profile
                   completion:(PCLLaunchCompletion)completion {
    
    if (self.isCancelled) {
        if (completion) completion(NO, [self errorWithCode:PCLLaunchErrorCancelled message:@"Cancelled"]);
        return;
    }
    
        // Step 2: Find Java (pre-bundled in .app, like Amethyst)
        [self log:@"Step 2/5: Locating Java runtime..."];
        NSInteger requiredJava = [PCLPathUtils recommendedJavaVersionForMC:versionInfo.versionId];
        NSString *javaPath = instance.javaPathOverride.length > 0 ? instance.javaPathOverride :
                                [PCLPathUtils javaExecutableForVersion:requiredJava];
        if (!javaPath) {
            [self log:[NSString stringWithFormat:@"  Java %ld not found, checking alternatives...", (long)requiredJava]];
            for (NSNumber *ver in @[@8, @17, @21, @25]) {
                javaPath = [PCLPathUtils javaExecutableForVersion:ver.integerValue];
                if (javaPath) {
                    requiredJava = ver.integerValue;
                    break;
                }
            }
        }
        if (!javaPath) {
            NSError *error = [self errorWithCode:PCLLaunchErrorJavaNotFound
                                         message:@"No Java runtime found. JRE must be bundled in .app."];
            if (completion) completion(NO, error);
            return;
        }
        [self log:[NSString stringWithFormat:@"  Java found at: %@", javaPath]];
    
    if (self.isCancelled) {
        if (completion) completion(NO, [self errorWithCode:PCLLaunchErrorCancelled message:@"Cancelled"]);
        return;
    }
    
    // Step 3: Build arguments with instance (版本隔离)
    [self log:@"Step 3/5: 构建启动参数..."];
    NSDictionary *config = [self buildConfigFromInstance:instance profile:profile versionInfo:versionInfo];
    NSDictionary *args = [PCLLaunchArguments buildArgumentsForInstance:instance
                                                            versionInfo:versionInfo
                                                               profile:profile
                                                                config:config];
    
    if (!args) {
        NSError *error = [self errorWithCode:PCLLaunchErrorInternalFailure 
                                     message:@"Failed to build launch arguments"];
        if (completion) completion(NO, error);
        return;
    }
    
    [self log:[NSString stringWithFormat:@"  Game directory: %@", args[@"gameDirectory"]]];
    [self log:[NSString stringWithFormat:@"  Version isolation: %@", args[@"versionIsolation"]]];
    [self log:[NSString stringWithFormat:@"  Main class: %@", args[@"mainClass"]]];
    
    // Step 4: Enable JIT
    [self log:@"Step 4/5: Enabling JIT compilation..."];
    if ([PCLJITManager isJTTAvailable]) {
        [self log:@"  JIT is available."];
        if (completion) completion(YES, nil);
    } else {
        [self log:@"  Attempting to enable JIT..."];
        [PCLJITManager enableJITTWithCompletion:^(BOOL jitSuccess, NSError *jitError) {
            if (jitSuccess) {
                [self log:@"  JIT enabled successfully."];
                if (completion) completion(YES, nil);
            } else {
                [self log:[NSString stringWithFormat:@"  JIT enable failed: %@. Continuing without JIT.", jitError.localizedDescription]];
                if (completion) completion(YES, nil);
            }
        }];
    }
}

- (NSDictionary *)buildConfigFromInstance:(PCLInstance *)instance
                                  profile:(NSDictionary *)profile
                               versionInfo:(PCLVersionInfo *)info {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 优先使用instance设置，否则使用全局设置
    NSInteger memoryMin = instance.memoryMinMB > 0 ? instance.memoryMinMB : ([defaults integerForKey:@"memoryMin"] ?: 512);
    NSInteger memoryMax = instance.memoryMaxMB > 0 ? instance.memoryMaxMB : ([defaults integerForKey:@"memoryMax"] ?: 2048);
    BOOL enableHooks = [defaults boolForKey:@"enableVirtualMachineHooks"];
    
    // 合并JVM参数: instance自定义 + profile自定义
    NSString *jvmArgs = instance.javaArgs ?: @"";
    NSString *profileJavaArgs = profile[@"javaArgs"];
    if ([profileJavaArgs isKindOfClass:[NSString class]] && profileJavaArgs.length > 0) {
        jvmArgs = [jvmArgs length] > 0 ? [jvmArgs stringByAppendingFormat:@" %@", profileJavaArgs] : profileJavaArgs;
    }
    
    return @{
        @"minMemory": @(memoryMin),
        @"maxMemory": @(memoryMax),
        @"enableVirtualMachineHooks": @(enableHooks),
        @"jvmArguments": jvmArgs,
        @"renderer": @(instance.renderer)
    };
}

#pragma mark - Private Methods

- (void)loadVersionJson:(NSString *)versionId completion:(void(^)(PCLVersionInfo *, NSError *))completion {
    [[PCLVersionManager sharedManager] loadVersionJson:versionId completion:completion];
}

- (void)proceedWithVersion:(PCLVersionInfo *)versionInfo
                   profile:(NSDictionary *)profile
                completion:(PCLLaunchCompletion)completion {
    
    if (self.isCancelled) {
        if (completion) completion(NO, [self errorWithCode:PCLLaunchErrorCancelled message:@"Cancelled"]);
        return;
    }
    
    // Step 2: Find Java (pre-bundled in .app)
    [self log:@"Step 2/5: Locating Java runtime..."];
    NSString *javaPath = [PCLPathUtils javaExecutableForVersion:[PCLPathUtils recommendedJavaVersionForMC:versionInfo.versionId]];
    if (!javaPath) {
        NSInteger reqVer = [PCLPathUtils recommendedJavaVersionForMC:versionInfo.versionId];
        [self log:[NSString stringWithFormat:@"  Java %ld not found, checking alternatives...", (long)reqVer]];
        for (NSNumber *ver in @[@8, @17, @21, @25]) {
            javaPath = [PCLPathUtils javaExecutableForVersion:ver.integerValue];
            if (javaPath) break;
        }
    }
    if (!javaPath) {
        NSError *error = [self errorWithCode:PCLLaunchErrorJavaNotFound
                                     message:@"No Java runtime found. JRE must be bundled in .app."];
        if (completion) completion(NO, error);
        return;
    }
    [self log:[NSString stringWithFormat:@"  Java found at: %@", javaPath]];
    [self verifyAndContinue:versionInfo profile:profile javaPath:javaPath completion:completion];
}

- (void)verifyAndContinue:(PCLVersionInfo *)versionInfo
                  profile:(NSDictionary *)profile
                 javaPath:(NSString *)javaPath
               completion:(PCLLaunchCompletion)completion {
    
    if (self.isCancelled) {
        if (completion) completion(NO, [self errorWithCode:PCLLaunchErrorCancelled message:@"Cancelled"]);
        return;
    }
    
    // Step 3: Validate Java version
    [self log:@"Step 3/5: Validating Java version..."];
    NSInteger requiredJava = [PCLPathUtils recommendedJavaVersionForMC:versionInfo.versionId];
    [self log:[NSString stringWithFormat:@"  Required Java: %ld", (long)requiredJava]];
    
    // Step 4: Build classpath and arguments
    [self log:@"Step 4/5: Building launch arguments..."];
    
    NSDictionary *config = [self buildConfigFromProfile:profile versionInfo:versionInfo];
    NSDictionary *args = [PCLLaunchArguments buildArgumentsForVersion:versionInfo
                                                             profile:profile
                                                              config:config];
    
    if (!args) {
        NSError *error = [self errorWithCode:PCLLaunchErrorInternalFailure 
                                     message:@"Failed to build launch arguments"];
        if (completion) completion(NO, error);
        return;
    }
    
    [self log:[NSString stringWithFormat:@"  Main class: %@", args[@"mainClass"]]];
    [self log:[NSString stringWithFormat:@"  JVM args: %@", [args[@"jvmArguments"] componentsJoinedByString:@" "]]];
    [self log:[NSString stringWithFormat:@"  Game args: %@", [args[@"gameArguments"] componentsJoinedByString:@" "]]];
    
    // Step 5: Enable JIT
    [self log:@"Step 5/5: Enabling JIT compilation..."];
    if ([PCLJITManager isJTTAvailable]) {
        [self log:@"  JIT is available."];
        if (completion) completion(YES, nil);
    } else {
        [self log:@"  Attempting to enable JIT..."];
        [PCLJITManager enableJITTWithCompletion:^(BOOL jitSuccess, NSError *jitError) {
            if (jitSuccess) {
                [self log:@"  JIT enabled successfully."];
                if (completion) completion(YES, nil);
            } else {
                [self log:[NSString stringWithFormat:@"  JIT enable failed: %@. Continuing without JIT.", jitError.localizedDescription]];
                // Continue anyway
                if (completion) completion(YES, nil);
            }
        }];
    }
}

#pragma mark - Configuration

- (NSDictionary *)buildConfigFromProfile:(NSDictionary *)profile versionInfo:(PCLVersionInfo *)info {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSInteger memoryMin = [defaults integerForKey:@"memoryMin"] ?: 512;
    NSInteger memoryMax = [defaults integerForKey:@"memoryMax"] ?: 2048;
    BOOL enableHooks = [defaults boolForKey:@"enableVirtualMachineHooks"];
    
    return @{
        @"minMemory": @(memoryMin),
        @"maxMemory": @(memoryMax),
        @"enableVirtualMachineHooks": @(enableHooks),
        @"jvmArguments": profile[@"javaArgs"] ?: @""
    };
}

#pragma mark - Logging

- (void)log:(NSString *)message {
    if (self.logCallback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.logCallback(message);
        });
    }
}

#pragma mark - Error Helper

- (NSError *)errorWithCode:(NSInteger)code message:(NSString *)message {
    return [NSError errorWithDomain:kErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

#pragma mark - Heartbeat

- (void)startHeartbeat {
    [self stopHeartbeat];
    self.heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                          repeats:YES
                                                            block:^(NSTimer *timer) {
        [self log:@"[heartbeat] Process is running..."];
    }];
}

- (void)stopHeartbeat {
    [self.heartbeatTimer invalidate];
    self.heartbeatTimer = nil;
}

@end
