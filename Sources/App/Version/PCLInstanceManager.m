#import "PCLInstanceManager.h"

NSString *const PCLCurrentInstanceNameKey = @"PCLCurrentInstanceName";

@implementation PCLInstance

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (self.name) dict[@"name"] = self.name;
    if (self.versionId) dict[@"versionId"] = self.versionId;
    if (self.gameDir) dict[@"gameDir"] = self.gameDir;
    if (self.javaArgs) dict[@"javaArgs"] = self.javaArgs;
    dict[@"resolutionWidth"] = @(self.resolutionWidth);
    dict[@"resolutionHeight"] = @(self.resolutionHeight);
    if (self.javaVersion) dict[@"javaVersion"] = self.javaVersion;
    if (self.created) dict[@"created"] = self.created;
    dict[@"memoryMaxMB"] = @(self.memoryMaxMB);
    dict[@"autoSelectJava"] = @(self.autoSelectJava);
    if (self.gameArguments) dict[@"gameArguments"] = self.gameArguments;
    dict[@"renderer"] = @(self.renderer);
    dict[@"versionIsolation"] = @(self.versionIsolation);
    if (self.javaPathOverride) dict[@"javaPathOverride"] = self.javaPathOverride;
    if (self.serverAddress) dict[@"serverAddress"] = self.serverAddress;
    dict[@"autoJoinServer"] = @(self.autoJoinServer);
    dict[@"memoryMinMB"] = @(self.memoryMinMB);
    return dict;
}

+ (instancetype)instanceFromDictionary:(NSDictionary *)dict {
    PCLInstance *instance = [[PCLInstance alloc] init];
    instance.name = dict[@"name"] ?: @"";
    instance.versionId = dict[@"versionId"] ?: @"";
    instance.gameDir = dict[@"gameDir"] ?: @"";
    instance.javaArgs = dict[@"javaArgs"] ?: @"-Xmx2G -Xms512M";
    instance.resolutionWidth = [dict[@"resolutionWidth"] integerValue] ?: 1280;
    instance.resolutionHeight = [dict[@"resolutionHeight"] integerValue] ?: 720;
    instance.javaVersion = dict[@"javaVersion"] ?: @"auto";
    instance.created = dict[@"created"] ?: [[NSDate date] description];
    instance.memoryMaxMB = [dict[@"memoryMaxMB"] integerValue] ?: 2048;
    instance.autoSelectJava = dict[@"autoSelectJava"] ? [dict[@"autoSelectJava"] boolValue] : YES;
    instance.gameArguments = dict[@"gameArguments"] ?: @"";
    instance.renderer = [dict[@"renderer"] integerValue];
    instance.versionIsolation = dict[@"versionIsolation"] ? [dict[@"versionIsolation"] boolValue] : NO;
    instance.javaPathOverride = dict[@"javaPathOverride"] ?: @"";
    instance.serverAddress = dict[@"serverAddress"] ?: @"";
    instance.autoJoinServer = dict[@"autoJoinServer"] ? [dict[@"autoJoinServer"] boolValue] : NO;
    instance.memoryMinMB = [dict[@"memoryMinMB"] integerValue] ?: 512;
    return instance;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<PCLInstance: %@ version=%@>", self.name, self.versionId];
}

@end

@interface PCLInstanceManager ()
@property (nonatomic, strong) NSString *instancesDirectory;
@end

@implementation PCLInstanceManager

+ (instancetype)sharedManager {
    static PCLInstanceManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PCLInstanceManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSString *docsDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        _instancesDirectory = [docsDir stringByAppendingPathComponent:@"instances"];
        [self ensureDirectory:_instancesDirectory];
    }
    return self;
}

- (void)ensureDirectory:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

- (NSString *)instanceDirectoryForName:(NSString *)name {
    return [self.instancesDirectory stringByAppendingPathComponent:name];
}

- (NSString *)configPathForName:(NSString *)name {
    return [[self instanceDirectoryForName:name] stringByAppendingPathComponent:@"instance.json"];
}

- (NSArray<PCLInstance *> *)allInstances {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtPath:self.instancesDirectory error:nil];
    NSMutableArray *instances = [NSMutableArray array];

    for (NSString *name in contents) {
        NSString *configPath = [self configPathForName:name];
        if ([fm fileExistsAtPath:configPath]) {
            NSData *data = [NSData dataWithContentsOfFile:configPath];
            if (data) {
                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if (dict) {
                    PCLInstance *instance = [PCLInstance instanceFromDictionary:dict];
                    [instances addObject:instance];
                }
            }
        }
    }

    return [instances sortedArrayUsingComparator:^NSComparisonResult(PCLInstance *a, PCLInstance *b) {
        return [a.name localizedCaseInsensitiveCompare:b.name];
    }];
}

- (BOOL)createInstanceWithName:(NSString *)name versionId:(NSString *)versionId {
    if (name.length == 0 || versionId.length == 0) return NO;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *instanceDir = [self instanceDirectoryForName:name];

    if ([fm fileExistsAtPath:instanceDir]) return NO;

    BOOL created = [fm createDirectoryAtPath:instanceDir withIntermediateDirectories:YES attributes:nil error:nil];
    if (!created) return NO;

    PCLInstance *instance = [[PCLInstance alloc] init];
    instance.name = name;
    instance.versionId = versionId;
    instance.gameDir = instanceDir;
    instance.memoryMaxMB = 2048;
    instance.memoryMinMB = 512;
    instance.autoSelectJava = YES;
    instance.resolutionWidth = 1280;
    instance.resolutionHeight = 720;
    instance.javaArgs = [NSString stringWithFormat:@"-Xmx%ldM -Xms512M", (long)instance.memoryMaxMB];
    instance.javaVersion = @"auto";
    instance.created = [[NSDate date] description];
    instance.renderer = PCLRenderRendererGL4ES;
    instance.versionIsolation = NO;

    return [self saveInstance:instance];
}

- (BOOL)deleteInstanceWithName:(NSString *)name {
    if (name.length == 0) return NO;

    NSString *instanceDir = [self instanceDirectoryForName:name];
    NSFileManager *fm = [NSFileManager defaultManager];

    if (![fm fileExistsAtPath:instanceDir]) return NO;

    NSError *error = nil;
    BOOL removed = [fm removeItemAtPath:instanceDir error:&error];
    if (!error && removed) {
        PCLInstance *current = [self currentInstance];
        if (current && [current.name isEqualToString:name]) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:PCLCurrentInstanceNameKey];
        }
        return YES;
    }
    return NO;
}

- (PCLInstance *)instanceWithName:(NSString *)name {
    if (name.length == 0) return nil;

    NSString *configPath = [self configPathForName:name];
    NSData *data = [NSData dataWithContentsOfFile:configPath];
    if (!data) return nil;

    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (!dict) return nil;

    return [PCLInstance instanceFromDictionary:dict];
}

- (void)selectInstance:(PCLInstance *)instance {
    if (!instance) return;
    [[NSUserDefaults standardUserDefaults] setObject:instance.name forKey:PCLCurrentInstanceNameKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (PCLInstance *)currentInstance {
    NSString *name = [[NSUserDefaults standardUserDefaults] stringForKey:PCLCurrentInstanceNameKey];
    if (name.length == 0) return nil;
    return [self instanceWithName:name];
}

- (BOOL)saveInstance:(PCLInstance *)instance {
    if (!instance || instance.name.length == 0) return NO;

    [self ensureDirectory:[self instanceDirectoryForName:instance.name]];
    NSString *configPath = [self configPathForName:instance.name];
    NSDictionary *dict = [instance toDictionary];
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    if (!data) return NO;

    return [data writeToFile:configPath atomically:YES];
}

#pragma mark - 版本隔离 (参考PCL2-CE)

// 获取共享游戏目录 (版本隔离关闭时使用)
- (NSString *)sharedGameDirectory {
    NSString *docsDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *sharedDir = [docsDir stringByAppendingPathComponent:@".minecraft"];
    [self ensureDirectory:sharedDir];
    return sharedDir;
}

// 根据实例配置返回游戏目录
// 版本隔离开启: 使用 instances/<name>/ 独立目录
// 版本隔离关闭: 使用共享 .minecraft 目录
- (NSString *)gameDirectoryForInstance:(PCLInstance *)instance {
    if (instance.versionIsolation) {
        // 版本隔离: 每个实例独立目录
        NSString *instanceDir = [self instanceDirectoryForName:instance.name];
        [self ensureDirectory:instanceDir];
        return instanceDir;
    } else {
        // 不隔离: 使用共享目录
        return [self sharedGameDirectory];
    }
}

// 获取实例mods目录
- (NSString *)modsDirectoryForInstance:(PCLInstance *)instance {
    NSString *modsDir;
    if (instance.versionIsolation) {
        modsDir = [[self instanceDirectoryForName:instance.name] stringByAppendingPathComponent:@"mods"];
    } else {
        modsDir = [[self sharedGameDirectory] stringByAppendingPathComponent:@"mods"];
    }
    [self ensureDirectory:modsDir];
    return modsDir;
}

// 获取实例config目录
- (NSString *)configDirectoryForInstance:(PCLInstance *)instance {
    NSString *configDir;
    if (instance.versionIsolation) {
        configDir = [[self instanceDirectoryForName:instance.name] stringByAppendingPathComponent:@"config"];
    } else {
        configDir = [[self sharedGameDirectory] stringByAppendingPathComponent:@"config"];
    }
    [self ensureDirectory:configDir];
    return configDir;
}

// 获取实例saves目录 (存档)
- (NSString *)savesDirectoryForInstance:(PCLInstance *)instance {
    NSString *savesDir;
    if (instance.versionIsolation) {
        savesDir = [[self instanceDirectoryForName:instance.name] stringByAppendingPathComponent:@"saves"];
    } else {
        savesDir = [[self sharedGameDirectory] stringByAppendingPathComponent:@"saves"];
    }
    [self ensureDirectory:savesDir];
    return savesDir;
}

// 获取实例screenshots目录 (截图)
- (NSString *)screenshotsDirectoryForInstance:(PCLInstance *)instance {
    NSString *dir;
    if (instance.versionIsolation) {
        dir = [[self instanceDirectoryForName:instance.name] stringByAppendingPathComponent:@"screenshots"];
    } else {
        dir = [[self sharedGameDirectory] stringByAppendingPathComponent:@"screenshots"];
    }
    [self ensureDirectory:dir];
    return dir;
}

// 获取实例logs目录
- (NSString *)logsDirectoryForInstance:(PCLInstance *)instance {
    NSString *dir;
    if (instance.versionIsolation) {
        dir = [[self instanceDirectoryForName:instance.name] stringByAppendingPathComponent:@"logs"];
    } else {
        dir = [[self sharedGameDirectory] stringByAppendingPathComponent:@"logs"];
    }
    [self ensureDirectory:dir];
    return dir;
}

// 获取实例resourcepacks目录 (资源包)
- (NSString *)resourcePacksDirectoryForInstance:(PCLInstance *)instance {
    NSString *dir;
    if (instance.versionIsolation) {
        dir = [[self instanceDirectoryForName:instance.name] stringByAppendingPathComponent:@"resourcepacks"];
    } else {
        dir = [[self sharedGameDirectory] stringByAppendingPathComponent:@"resourcepacks"];
    }
    [self ensureDirectory:dir];
    return dir;
}

// 获取实例shaderpacks目录 (着色器)
- (NSString *)shaderPacksDirectoryForInstance:(PCLInstance *)instance {
    NSString *dir;
    if (instance.versionIsolation) {
        dir = [[self instanceDirectoryForName:instance.name] stringByAppendingPathComponent:@"shaderpacks"];
    } else {
        dir = [[self sharedGameDirectory] stringByAppendingPathComponent:@"shaderpacks"];
    }
    [self ensureDirectory:dir];
    return dir;
}

// 获取实例natives目录 (本地库解压目录)
- (NSString *)nativesDirectoryForInstance:(PCLInstance *)instance {
    NSString *dir;
    if (instance.versionIsolation) {
        dir = [[self instanceDirectoryForName:instance.name] stringByAppendingPathComponent:@"natives"];
    } else {
        dir = [[self sharedGameDirectory] stringByAppendingPathComponent:@"natives"];
    }
    [self ensureDirectory:dir];
    return dir;
}

@end
