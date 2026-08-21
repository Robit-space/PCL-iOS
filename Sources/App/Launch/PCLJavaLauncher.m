#import "PCLJavaLauncher.h"
#import "PCLPathUtils.h"

@implementation PCLJavaLauncher {
    PCLJLI_Launch pJLI_Launch;
    BOOL _isRunning;
    NSMutableDictionary *_environment;
}

+ (instancetype)sharedLauncher {
    static PCLJavaLauncher *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PCLJavaLauncher alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _environment = [NSMutableDictionary dictionary];
        _gameWidth = 1280;
        _gameHeight = 720;
        pJLI_Launch = NULL;
    }
    return self;
}

- (NSMutableDictionary *)environment {
    return _environment;
}

- (BOOL)isRunning {
    return _isRunning;
}

- (void)setupEnvironment:(NSString *)gameVersion mcVersion:(NSString *)mcVersion {
    NSDictionary *env = @{
        @"POJAV_HOME": [NSString stringWithFormat:@"%@/PCL Games", NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject],
        @"MESA_GL_VERSION_OVERRIDE": @"4.1",
        @"LIBGL_NORMALIZE": @"1",
        @"LIBGL_NOINTOVLHACK": @"1",
        @"HACK_IGNORE_START_ON_FIRST_THREAD": @"1",
        @"POJAV_DISABLE_VSYNC": @"0",
        @"MVK_CONFIG_LOG_LEVEL": @"2",
    };
    
   [_environment addEntriesFromDictionary:env];
    
    if (gameVersion) _environment[@"POJAV_GAME_VERSION"] = gameVersion;

    NSInteger javaVer = [PCLPathUtils recommendedJavaVersionForMC:mcVersion];
    NSString *javaHome = [PCLPathUtils javaHomeForVersion:javaVer];
    if (javaHome) {
        _environment[@"JAVA_HOME"] = javaHome;
    }
}

- (BOOL)launchWithMainClass:(NSString *)mainClass
                  classpath:(NSString *)classpath
                      args:(NSArray<NSString *> *)args
                     error:(NSError **)error {
    
    if (_isRunning) {
        if (error) *error = [NSError errorWithDomain:@"PCLJavaLauncher" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"JVM already running"}];
        return NO;
    }
    
    NSString *javaHome = _environment[@"JAVA_HOME"] ?: [PCLPathUtils javaHomeForVersion:17];
    if (!javaHome) {
        for (NSNumber *ver in @[@8, @17, @21, @25]) {
            javaHome = [PCLPathUtils javaHomeForVersion:ver.integerValue];
            if (javaHome) break;
        }
    }
    
    if (!javaHome) {
        if (error) *error = [NSError errorWithDomain:@"PCLJavaLauncher" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"No Java runtime found"}];
        return NO;
    }
    
    NSLog(@"[PCLJavaLauncher] Java home: %@", javaHome);
    NSLog(@"[PCLJavaLauncher] Main class: %@", mainClass);
    NSLog(@"[PCLJavaLauncher] Classpath: %@", classpath);
    
    long long physMem = [NSProcessInfo processInfo].physicalMemory / (1024 * 1024);
    long long maxMem = physMem > 4096 ? 2048 : physMem / 2;
    
    NSMutableArray *argv = [NSMutableArray arrayWithObjects:
        @"java",
        [NSString stringWithFormat:@"-Xmx%lldM", maxMem],
        @"-Xms512M",
        @"-XX:+UseG1GC",
        @"-XX:+UnlockExperimentalVMOptions",
        [NSString stringWithFormat:@"-Djava.library.path=%@/Frameworks", NSBundle.mainBundle.resourcePath],
        [NSString stringWithFormat:@"-Dorg.lwjgl.librarypath=%@/Frameworks", NSBundle.mainBundle.resourcePath],
        [NSString stringWithFormat:@"-Dnet.java.games.input.librarypath=%@/Frameworks", NSBundle.mainBundle.resourcePath],
        @"-cp", classpath,
        mainClass,
        nil
    ];
    
    [argv addObjectsFromArray:args ?: @[]];
    
    if (self.account) {
        [argv addObject:[NSString stringWithFormat:@"--username=%@", self.account]];
        [argv addObject:@"--version=1.20.4"];
        [argv addObject:[NSString stringWithFormat:@"--gameDir=%@/instances/default", _environment[@"POJAV_HOME"]]];
        [argv addObject:[NSString stringWithFormat:@"--width=%d", self.gameWidth]];
        [argv addObject:[NSString stringWithFormat:@"--height=%d", self.gameHeight]];
    }
    
    NSLog(@"[PCLJavaLauncher] Launching JVM with %lu args", (unsigned long)argv.count);
    NSLog(@"[PCLJavaLauncher] argv: %@", argv);
    
    for (NSString *key in _environment) {
        NSString *value = _environment[key];
        if ([value isKindOfClass:[NSString class]]) {
            setenv(key.UTF8String, value.UTF8String, 1);
        }
    }
    
    NSMutableDictionary *launchInfo = [@{
        @"javaHome": javaHome,
        @"mainClass": mainClass ?: @"",
        @"classpath": classpath ?: @"",
        @"arguments": argv,
        @"environment": [_environment copy],
        @"gameWidth": @(self.gameWidth),
        @"gameHeight": @(self.gameHeight),
    } mutableCopy];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PCLJavaLaunchWillStart" object:self userInfo:launchInfo];
    
    _isRunning = YES;
    
    NSLog(@"[PCLJavaLauncher] JVM launch info prepared (actual JVM launch requires libjli.dylib)");
    
    return YES;
}

- (void)terminate {
    _isRunning = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PCLJavaLaunchDidTerminate" object:self];
}

@end
