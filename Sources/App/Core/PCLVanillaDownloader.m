#import "PCLVanillaDownloader.h"
#import "PCLDownloadManager.h"
#import "PCLLogger.h"
#import "PCLNetworkUtils.h"
#import <CommonCrypto/CommonDigest.h>

static NSString *const kVersionManifestURL = @"https://piston-meta.mojang.com/mc/game/version_manifest_v2.json";

@interface PCLVanillaDownloader ()

@property (nonatomic, readwrite) PCLVanillaDownloadStep currentStep;
@property (nonatomic, readwrite, getter=isDownloading) BOOL downloading;
@property (nonatomic, copy) NSString *currentVersionId;
@property (nonatomic, copy) PCLVanillaDownloadProgressBlock progressBlock;
@property (nonatomic, copy) PCLVanillaDownloadCompletionBlock completionBlock;
@property (nonatomic, strong) NSDictionary *versionJson;
@property (nonatomic, strong) PCLVersionInfo *versionInfo;
@property (nonatomic, strong) NSArray<NSDictionary *> *manifestVersions;

@end

@implementation PCLVanillaDownloader

+ (instancetype)sharedDownloader {
    static PCLVanillaDownloader *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PCLVanillaDownloader alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentStep = PCLVanillaDownloadStepIdle;
    }
    return self;
}

- (void)downloadVersion:(NSString *)versionId
               progress:(PCLVanillaDownloadProgressBlock)progress
             completion:(PCLVanillaDownloadCompletionBlock)completion {
    
    if (self.isDownloading) {
        if (completion) completion(NO, [NSError errorWithDomain:@"PCLVanillaDownloader" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Another download is in progress"}]);
        return;
    }
    
    self.downloading = YES;
    self.currentVersionId = versionId;
    self.progressBlock = progress;
    self.completionBlock = completion;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self _downloadVersion:versionId];
    });
}

- (void)cancelDownload {
    self.downloading = NO;
    self.currentStep = PCLVanillaDownloadStepIdle;
}

- (void)_updateStep:(PCLVanillaDownloadStep)step overall:(double)overall stepProgress:(double)stepProgress message:(NSString *)msg {
    self.currentStep = step;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.progressBlock) self.progressBlock(step, overall, stepProgress, msg);
    });
}

- (void)_downloadVersion:(NSString *)versionId {
    PCLVersionManager *vm = [PCLVersionManager sharedManager];
    
    [self _updateStep:PCLVanillaDownloadStepFetchingManifest overall:0.0 stepProgress:0.0 message:@"获取版本清单..."];
    
    [vm fetchRemoteManifest:^(NSArray<NSDictionary *> *versions, NSError *error) {
        if (error || !versions) {
            [self _failWithError:error ?: [NSError errorWithDomain:@"PCLVanillaDownloader" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Failed to fetch manifest"}]];
            return;
        }
        
        NSDictionary *targetVersion = nil;
        for (NSDictionary *v in versions) {
            if ([v[@"id"] isEqualToString:versionId]) {
                targetVersion = v;
                break;
            }
        }
        
        if (!targetVersion) {
            [self _failWithError:[NSError errorWithDomain:@"PCLVanillaDownloader" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"Version not found in manifest"}]];
            return;
        }
        
        NSString *versionUrl = targetVersion[@"url"];
        if (!versionUrl) {
            [self _failWithError:[NSError errorWithDomain:@"PCLVanillaDownloader" code:-4 userInfo:@{NSLocalizedDescriptionKey: @"No version URL"}]];
            return;
        }
        
        [self _updateStep:PCLVanillaDownloadStepDownloadingVersionJson overall:0.1 stepProgress:0.0 message:@"下载版本JSON..."];
        
        NSString *versionDir = [[vm versionsDirectory] stringByAppendingPathComponent:versionId];
        NSString *jsonPath = [versionDir stringByAppendingPathComponent:[versionId stringByAppendingString:@".json"]];
        
        NSString *mirrorUrl = [[PCLDownloadManager sharedManager] replaceURLWithDownloadSource:versionUrl];
        
        [self _downloadFile:mirrorUrl toPath:jsonPath sha1:nil success:^{
            [self _processVersionJson:jsonPath versionId:versionId];
        } failure:^(NSError *err) {
            [self _failWithError:err];
        }];
    }];
}

- (void)_processVersionJson:(NSString *)jsonPath versionId:(NSString *)versionId {
    [self _updateStep:PCLVanillaDownloadStepParsingVersionJson overall:0.2 stepProgress:0.0 message:@"解析版本JSON..."];
    
    NSData *data = [NSData dataWithContentsOfFile:jsonPath];
    NSError *error = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || !json) {
        [self _failWithError:error ?: [NSError errorWithDomain:@"PCLVanillaDownloader" code:-5 userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse version JSON"}]];
        return;
    }
    
    self.versionJson = json;
    PCLVersionInfo *info = [[PCLVersionManager sharedManager] parseVersionJson:json];
    info.versionId = versionId;
    self.versionInfo = info;
    
    NSString *inheritsFrom = json[@"inheritsFrom"];
    if (inheritsFrom) {
        NSString *parentJsonPath = [[[[PCLVersionManager sharedManager] versionsDirectory] stringByAppendingPathComponent:inheritsFrom] stringByAppendingPathComponent:[inheritsFrom stringByAppendingString:@".json"]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:parentJsonPath]) {
            NSData *parentData = [NSData dataWithContentsOfFile:parentJsonPath];
            NSDictionary *parentJson = [NSJSONSerialization JSONObjectWithData:parentData options:0 error:nil];
            if (parentJson) {
                NSMutableDictionary *merged = [parentJson mutableCopy];
                [json enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                    merged[key] = obj;
                }];
                self.versionJson = merged;
                info = [[PCLVersionManager sharedManager] parseVersionJson:merged];
                info.versionId = versionId;
                self.versionInfo = info;
                json = merged;
            }
        }
    }
    
    [self _downloadClientJar:json versionId:versionId];
}

- (void)_downloadClientJar:(NSDictionary *)json versionId:(NSString *)versionId {
    [self _updateStep:PCLVanillaDownloadStepDownloadingClient overall:0.3 stepProgress:0.0 message:@"下载客户端JAR..."];
    
    NSDictionary *downloads = json[@"downloads"];
    NSDictionary *client = downloads[@"client"];
    if (!client) {
        [self _downloadAssetIndex:json versionId:versionId];
        return;
    }
    
    NSString *clientUrl = client[@"url"];
    NSString *clientSha1 = client[@"sha1"];
    PCLVersionManager *vm = [PCLVersionManager sharedManager];
    NSString *versionDir = [[vm versionsDirectory] stringByAppendingPathComponent:versionId];
    NSString *clientPath = [versionDir stringByAppendingPathComponent:[versionId stringByAppendingString:@".jar"]];
    
    NSString *mirrorUrl = [[PCLDownloadManager sharedManager] replaceURLWithDownloadSource:clientUrl];
    
    [self _downloadFile:mirrorUrl toPath:clientPath sha1:clientSha1 success:^{
        [self _downloadAssetIndex:json versionId:versionId];
    } failure:^(NSError *err) {
        [self _failWithError:err];
    }];
}

- (void)_downloadAssetIndex:(NSDictionary *)json versionId:(NSString *)versionId {
    [self _updateStep:PCLVanillaDownloadStepDownloadingAssetIndex overall:0.4 stepProgress:0.0 message:@"下载资源索引..."];
    
    NSDictionary *assetIndex = json[@"assetIndex"];
    NSString *assets = json[@"assets"];
    if (!assetIndex || !assets) {
        [self _downloadLibraries:json versionId:versionId];
        return;
    }
    
    NSString *assetUrl = assetIndex[@"url"];
    NSString *assetSha1 = assetIndex[@"sha1"];
    NSString *assetId = assetIndex[@"id"] ?: assets;
    
    PCLVersionManager *vm = [PCLVersionManager sharedManager];
    NSString *indexDir = [[vm assetsDirectory] stringByAppendingPathComponent:@"indexes"];
    NSString *indexPath = [indexDir stringByAppendingPathComponent:[assetId stringByAppendingString:@".json"]];
    
    NSString *mirrorUrl = [[PCLDownloadManager sharedManager] replaceURLWithDownloadSource:assetUrl];
    
    [self _downloadFile:mirrorUrl toPath:indexPath sha1:assetSha1 success:^{
        [self _downloadAssets:indexPath versionId:versionId];
    } failure:^(NSError *err) {
        [self _failWithError:err];
    }];
}

- (void)_downloadAssets:(NSString *)indexPath versionId:(NSString *)versionId {
    [self _updateStep:PCLVanillaDownloadStepDownloadingAssets overall:0.5 stepProgress:0.0 message:@"下载资源文件..."];
    
    NSData *data = [NSData dataWithContentsOfFile:indexPath];
    NSDictionary *index = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSDictionary *objects = index[@"objects"];
    if (!objects) {
        [self _downloadLibraries:self.versionJson versionId:versionId];
        return;
    }
    
    PCLVersionManager *vm = [PCLVersionManager sharedManager];
    NSString *objectsDir = [[vm assetsDirectory] stringByAppendingPathComponent:@"objects"];
    
    NSArray *keys = objects.allKeys;
    __block NSUInteger completed = 0;
    NSUInteger total = keys.count;
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(8);
    
    for (NSString *key in keys) {
        NSDictionary *obj = objects[key];
        NSString *hash = obj[@"hash"];
        if (!hash) continue;
        
        NSString *prefix = [hash substringToIndex:2];
        NSString *assetUrl = [NSString stringWithFormat:@"https://resources.download.minecraft.net/%@/%@", prefix, hash];
        NSString *assetPath = [objectsDir stringByAppendingPathComponent:[prefix stringByAppendingPathComponent:hash]];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:assetPath]) {
            completed++;
            continue;
        }
        
        dispatch_group_enter(group);
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        
        NSString *mirrorUrl = [[PCLDownloadManager sharedManager] replaceURLWithDownloadSource:assetUrl];
        [self _downloadFile:mirrorUrl toPath:assetPath sha1:hash success:^{
            completed++;
            double progress = (double)completed / (double)total;
            [self _updateStep:PCLVanillaDownloadStepDownloadingAssets overall:0.5 + progress * 0.2 stepProgress:progress message:[NSString stringWithFormat:@"资源 %lu/%lu", (unsigned long)completed, (unsigned long)total]];
            dispatch_semaphore_signal(semaphore);
            dispatch_group_leave(group);
        } failure:^(NSError *err) {
            dispatch_semaphore_signal(semaphore);
            dispatch_group_leave(group);
        }];
    }
    
    dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self _downloadLibraries:self.versionJson versionId:versionId];
    });
}

- (void)_downloadLibraries:(NSDictionary *)json versionId:(NSString *)versionId {
    [self _updateStep:PCLVanillaDownloadStepDownloadingLibraries overall:0.7 stepProgress:0.0 message:@"下载库文件..."];
    
    NSArray *libraries = json[@"libraries"];
    if (!libraries || libraries.count == 0) {
        [self _extractNatives:json versionId:versionId];
        return;
    }
    
    PCLVersionManager *vm = [PCLVersionManager sharedManager];
    NSString *libsDir = [vm librariesDirectory];
    NSString *versionDir = [[vm versionsDirectory] stringByAppendingPathComponent:versionId];
    NSString *nativesDir = [versionDir stringByAppendingPathComponent:@"natives"];
    
    NSMutableArray *downloads = [NSMutableArray array];
    
    for (NSDictionary *lib in libraries) {
        NSDictionary *rules = lib[@"rules"];
        if (rules && ![self _rulesAllow:rules]) continue;
        
        NSDictionary *downloadsDict = lib[@"downloads"];
        if (!downloadsDict) continue;
        
        NSDictionary *artifact = downloadsDict[@"artifact"];
        if (artifact) {
            NSString *path = artifact[@"path"];
            NSString *url = artifact[@"url"];
            NSString *sha1 = artifact[@"sha1"];
            if (path && url) {
                [downloads addObject:@{@"url": url, @"path": [libsDir stringByAppendingPathComponent:path], @"sha1": sha1 ?: @""}];
            }
        }
        
        NSDictionary *classifiers = downloadsDict[@"classifiers"];
        if (classifiers) {
            NSString *nativeKey = @"natives-ios";
            NSDictionary *native = classifiers[nativeKey];
            if (!native) native = classifiers[@"natives-osx"];
            if (native) {
                NSString *path = native[@"path"];
                NSString *url = native[@"url"];
                if (path && url) {
                    [downloads addObject:@{@"url": url, @"path": [nativesDir stringByAppendingPathComponent:path], @"sha1": native[@"sha1"] ?: @""}];
                }
            }
        }
    }
    
    if (downloads.count == 0) {
        [self _extractNatives:json versionId:versionId];
        return;
    }
    
    __block NSUInteger completed = 0;
    NSUInteger total = downloads.count;
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(8);
    
    for (NSDictionary *dl in downloads) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:dl[@"path"]]) {
            completed++;
            continue;
        }
        
        dispatch_group_enter(group);
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        
        NSString *mirrorUrl = [[PCLDownloadManager sharedManager] replaceURLWithDownloadSource:dl[@"url"]];
        [self _downloadFile:mirrorUrl toPath:dl[@"path"] sha1:dl[@"sha1"] success:^{
            completed++;
            double progress = (double)completed / (double)total;
            [self _updateStep:PCLVanillaDownloadStepDownloadingLibraries overall:0.7 + progress * 0.2 stepProgress:progress message:[NSString stringWithFormat:@"库 %lu/%lu", (unsigned long)completed, (unsigned long)total]];
            dispatch_semaphore_signal(semaphore);
            dispatch_group_leave(group);
        } failure:^(NSError *err) {
            dispatch_semaphore_signal(semaphore);
            dispatch_group_leave(group);
        }];
    }
    
    dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self _extractNatives:json versionId:versionId];
    });
}

- (void)_extractNatives:(NSDictionary *)json versionId:(NSString *)versionId {
    [self _updateStep:PCLVanillaDownloadStepExtractingNatives overall:0.9 stepProgress:0.0 message:@"解压native库..."];
    
    self.downloading = NO;
    self.currentStep = PCLVanillaDownloadStepCompleted;
    
    [self _updateStep:PCLVanillaDownloadStepCompleted overall:1.0 stepProgress:1.0 message:@"下载完成"];
    
    if (self.completionBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.completionBlock(YES, nil);
        });
    }
}

- (BOOL)_rulesAllow:(NSArray *)rules {
    BOOL allow = YES;
    for (NSDictionary *rule in rules) {
        NSString *action = rule[@"action"];
        NSDictionary *os = rule[@"os"];
        if (os) {
            NSString *name = os[@"name"];
            if ([name isEqualToString:@"osx"] || [name isEqualToString:@"ios"]) {
                allow = [action isEqualToString:@"allow"];
            } else {
                allow = [action isEqualToString:@"disallow"];
            }
        } else {
            allow = [action isEqualToString:@"allow"];
        }
    }
    return allow;
}

- (void)_downloadFile:(NSString *)url toPath:(NSString *)path sha1:(NSString *)sha1 success:(void (^)(void))success failure:(void (^)(NSError *))failure {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [path stringByDeletingLastPathComponent];
    [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    
    if ([fm fileExistsAtPath:path] && sha1.length > 0) {
        NSString *existingSHA1 = [self _sha1OfFile:path];
        if ([existingSHA1 isEqualToString:sha1]) {
            if (success) success();
            return;
        }
    }
    
    PCLDownloadTask *task = [[PCLDownloadTask alloc] init];
    task.url = url;
    task.targetPath = path;
    task.sha1 = sha1;
    task.displayName = [path lastPathComponent];
    
    [[PCLDownloadManager sharedManager] addTask:task];
    [[PCLDownloadManager sharedManager] startDownload:task];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([fm fileExistsAtPath:path]) {
            if (success) success();
        } else {
            if (failure) failure([NSError errorWithDomain:@"PCLVanillaDownloader" code:-10 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Download failed: %@", url]}]);
        }
    });
}

- (NSString *)_sha1OfFile:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return @"";
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [result appendFormat:@"%02x", digest[i]];
    }
    return result;
}

- (void)_failWithError:(NSError *)error {
    self.downloading = NO;
    self.currentStep = PCLVanillaDownloadStepFailed;
    PCLLogger *logger = [PCLLogger sharedLogger];
    [logger error:[NSString stringWithFormat:@"[VanillaDownload] Failed: %@", error.localizedDescription]];
    
    if (self.completionBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.completionBlock(NO, error);
        });
    }
}

- (NSArray<NSDictionary *> *)availableReleases {
    return [self _filterVersions:@"release"];
}

- (NSArray<NSDictionary *> *)availableSnapshots {
    return [self _filterVersions:@"snapshot"];
}

- (NSArray<NSDictionary *> *)availableOldVersions {
    return [self _filterVersions:@"old"];
}

- (NSArray<NSDictionary *> *)_filterVersions:(NSString *)type {
    NSMutableArray *result = [NSMutableArray array];
    for (NSDictionary *v in self.manifestVersions) {
        NSString *vType = v[@"type"] ?: @"";
        if ([type isEqualToString:@"old"]) {
            if ([vType isEqualToString:@"old_alpha"] || [vType isEqualToString:@"old_beta"]) {
                [result addObject:v];
            }
        } else if ([vType isEqualToString:type]) {
            [result addObject:v];
        }
    }
    return result;
}

@end
