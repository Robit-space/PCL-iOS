#import "PCLVersionManager.h"
#import "PCLDownloadManager.h"

static NSString *const kManifestURL = @"https://piston-meta.mojang.com/mc/game/version_manifest_v2.json";

@implementation PCLVersionInfo
@end

@interface PCLVersionManager ()
@property (nonatomic, strong) NSArray<NSDictionary *> *cachedManifest;
@property (nonatomic, strong) NSDate *manifestCacheDate;
@end

@implementation PCLVersionManager

+ (instancetype)sharedManager {
    static PCLVersionManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PCLVersionManager alloc] init];
    });
    return instance;
}

- (NSString *)documentsDirectory {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
}

- (NSString *)gamesDirectory {
    NSString *path = [[self documentsDirectory] stringByAppendingPathComponent:@"PCL Games"];
    [self ensureDirectory:path];
    return path;
}

- (NSString *)versionsDirectory {
    NSString *path = [[self gamesDirectory] stringByAppendingPathComponent:@"versions"];
    [self ensureDirectory:path];
    return path;
}

- (NSString *)librariesDirectory {
    NSString *path = [[self gamesDirectory] stringByAppendingPathComponent:@"libraries"];
    [self ensureDirectory:path];
    return path;
}

- (NSString *)assetsDirectory {
    NSString *path = [[self gamesDirectory] stringByAppendingPathComponent:@"assets"];
    [self ensureDirectory:path];
    return path;
}

- (NSString *)javaDirectory {
    NSString *path = [[self gamesDirectory] stringByAppendingPathComponent:@"java"];
    [self ensureDirectory:path];
    return path;
}

- (NSString *)instancesDirectory {
    NSString *path = [[self documentsDirectory] stringByAppendingPathComponent:@"instances"];
    [self ensureDirectory:path];
    return path;
}

- (NSString *)instanceDirectoryWithName:(NSString *)name {
    NSString *path = [[self instancesDirectory] stringByAppendingPathComponent:name];
    [self ensureDirectory:path];
    return path;
}

- (void)ensureDirectory:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

- (NSArray<PCLVersionInfo *> *)localVersions {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *versionsDir = [self versionsDirectory];
    NSArray *contents = [fm contentsOfDirectoryAtPath:versionsDir error:nil];
    NSMutableArray *versions = [NSMutableArray array];
    
    for (NSString *folderName in contents) {
        NSString *jsonPath = [[versionsDir stringByAppendingPathComponent:folderName] stringByAppendingPathComponent:[folderName stringByAppendingString:@".json"]];
        if ([fm fileExistsAtPath:jsonPath]) {
            PCLVersionInfo *info = [[PCLVersionInfo alloc] init];
            info.versionId = folderName;
            info.jsonPath = jsonPath;
            info.isInstalled = YES;
            [versions addObject:info];
        }
    }
    
    return versions;
}

- (void)fetchRemoteManifest:(void (^)(NSArray<NSDictionary *> *, NSError *))completion {
    if (self.cachedManifest && self.manifestCacheDate && [[NSDate date] timeIntervalSinceDate:self.manifestCacheDate] < 1800) {
        if (completion) completion(self.cachedManifest, nil);
        return;
    }
    
    NSString *manifestURL = [[PCLDownloadManager sharedManager] replaceURLWithDownloadSource:kManifestURL];
    NSURL *url = [NSURL URLWithString:manifestURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error);
            });
            return;
        }
        
        NSError *jsonError = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, jsonError);
            });
            return;
        }
        
        self.cachedManifest = json[@"versions"];
        self.manifestCacheDate = [NSDate date];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(self.cachedManifest, nil);
        });
    }];
    [task resume];
}

- (void)downloadManifest:(void (^)(BOOL, NSError *))completion {
    [self fetchRemoteManifest:^(NSArray<NSDictionary *> *versions, NSError *error) {
        if (completion) completion(versions != nil, error);
    }];
}

- (void)loadVersionJson:(NSString *)versionId completion:(void (^)(PCLVersionInfo *, NSError *))completion {
    NSString *jsonPath = [[[self versionsDirectory] stringByAppendingPathComponent:versionId] stringByAppendingPathComponent:[versionId stringByAppendingString:@".json"]];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:jsonPath]) {
        NSData *data = [NSData dataWithContentsOfFile:jsonPath];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        PCLVersionInfo *info = [self parseVersionJson:dict];
        info.versionId = versionId;
        info.jsonPath = jsonPath;
        info.isInstalled = YES;
        if (completion) completion(info, nil);
    } else {
        if (completion) completion(nil, [NSError errorWithDomain:@"PCLVersion" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Version not found"}]);
    }
}

- (PCLVersionInfo *)parseVersionJson:(NSDictionary *)dict {
    PCLVersionInfo *info = [[PCLVersionInfo alloc] init];
    info.versionId = dict[@"id"] ?: @"";
    info.versionType = dict[@"type"] ?: @"";
    info.javaVersion = dict[@"javaVersion"][@"majorVersion"] ?: @"8";
    info.mainClass = dict[@"mainClass"] ?: @"";
    info.minecraftArguments = dict[@"minecraftArguments"] ?: @"";
    info.inheritsFrom = dict[@"inheritsFrom"] ?: @"";
    info.jar = dict[@"jar"] ?: info.versionId;
    info.libraries = dict[@"libraries"] ?: @[];
    
    NSDictionary *assetIndex = dict[@"assetIndex"];
    if (assetIndex) {
        info.assetIndex = assetIndex[@"id"] ?: @"";
        info.assets = assetIndex[@"id"] ?: @"";
    }
    
    return info;
}

- (PCLVersionInfo *)versionInfoForId:(NSString *)versionId {
    for (PCLVersionInfo *info in [self localVersions]) {
        if ([info.versionId isEqualToString:versionId]) {
            return info;
        }
    }
    return nil;
}

- (BOOL)isVersionInstalled:(NSString *)versionId {
    NSString *jsonPath = [[[self versionsDirectory] stringByAppendingPathComponent:versionId] stringByAppendingPathComponent:[versionId stringByAppendingString:@".json"]];
    return [[NSFileManager defaultManager] fileExistsAtPath:jsonPath];
}

- (BOOL)createInstanceWithName:(NSString *)name baseVersion:(NSString *)versionId {
    NSString *instanceDir = [self instanceDirectoryWithName:name];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ([fm fileExistsAtPath:instanceDir]) return NO;
    
    [fm createDirectoryAtPath:instanceDir withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSMutableDictionary *config = [@{
        @"name": name,
        @"versionId": versionId,
        @"gameDir": instanceDir,
        @"javaArgs": @"-Xmx2G -Xms512M",
        @"resolutionWidth": @"1280",
        @"resolutionHeight": @"720",
        @"created": [[NSDate date] description]
    } mutableCopy];
    
    NSString *configPath = [instanceDir stringByAppendingPathComponent:@"instance.json"];
    NSData *data = [NSJSONSerialization dataWithJSONObject:config options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToFile:configPath atomically:YES];
    
    return YES;
}

- (NSArray<NSDictionary *> *)localInstances {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *instancesDir = [self instancesDirectory];
    NSArray *contents = [fm contentsOfDirectoryAtPath:instancesDir error:nil];
    NSMutableArray *instances = [NSMutableArray array];
    
    for (NSString *name in contents) {
        NSString *configPath = [instancesDir stringByAppendingPathComponent:[name stringByAppendingPathComponent:@"instance.json"]];
        if ([fm fileExistsAtPath:configPath]) {
            NSData *data = [NSData dataWithContentsOfFile:configPath];
            NSDictionary *config = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (config) {
                [instances addObject:config];
            }
        }
    }
    
    return instances;
}

- (NSDictionary *)instanceConfig:(NSString *)name {
    NSString *configPath = [[self instancesDirectory] stringByAppendingPathComponent:[name stringByAppendingPathComponent:@"instance.json"]];
    NSData *data = [NSData dataWithContentsOfFile:configPath];
    if (data) {
        return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    }
    return nil;
}

- (BOOL)saveInstanceConfig:(NSString *)name config:(NSDictionary *)config {
    NSString *instanceDir = [self instanceDirectoryWithName:name];
    NSString *configPath = [instanceDir stringByAppendingPathComponent:@"instance.json"];
    NSData *data = [NSJSONSerialization dataWithJSONObject:config options:NSJSONWritingPrettyPrinted error:nil];
    return [data writeToFile:configPath atomically:YES];
}

- (NSArray<NSDictionary *> *)remoteVersionManifest {
    return self.cachedManifest ?: @[];
}

@end
