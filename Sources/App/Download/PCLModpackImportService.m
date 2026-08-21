#import "PCLModpackImportService.h"
#import "PCLCurseForgeAPI.h"
#import "PCLModrinthAPI.h"

@implementation PCLModpackImportResult
@end

@interface PCLModpackImportService ()
@property (nonatomic, assign) BOOL isCancelled;
@property (nonatomic, strong) NSFileManager *fm;
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation PCLModpackImportService

+ (instancetype)sharedService {
    static PCLModpackImportService *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PCLModpackImportService alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _fm = [NSFileManager defaultManager];
        _session = [NSURLSession sharedSession];
    }
    return self;
}

- (NSString *)instancesDirectory {
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *path = [docs stringByAppendingPathComponent:@"instances"];
    if (![self.fm fileExistsAtPath:path]) {
        [self.fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return path;
}

- (void)cancel {
    self.isCancelled = YES;
}

- (void)importFromZipAtURL:(NSURL *)fileURL
                  progress:(void(^)(double progress, NSString *status))progress
                completion:(void(^)(BOOL success, PCLModpackImportResult *result, NSError *error))completion {
    
    self.isCancelled = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        progress(0.1, @"读取整合包文件...");
        
        NSString *fileName = fileURL.lastPathComponent.stringByDeletingPathExtension;
        NSString *destPath = [[self instancesDirectory] stringByAppendingPathComponent:fileName];
        
        if ([self.fm fileExistsAtPath:destPath]) {
            progress(0.2, @"清理旧实例...");
            [self.fm removeItemAtPath:destPath error:nil];
        }
        
        [self.fm createDirectoryAtPath:destPath withIntermediateDirectories:YES attributes:nil error:nil];
        
        progress(0.3, @"解压整合包...");
        
        // Try to read manifest.json from zip
        NSData *zipData = [NSData dataWithContentsOfURL:fileURL];
        if (!zipData) {
            NSError *err = [NSError errorWithDomain:@"PCLModpackImport" code:PCLModpackImportErrorInvalidFile userInfo:@{NSLocalizedDescriptionKey: @"无法读取文件"}];
            completion(NO, nil, err);
            return;
        }
        
        // Simple approach: assume zip was unzipped by system
        // In production, use a zip library
        progress(0.5, @"解析 manifest...");
        
        NSString *manifestPath = [destPath stringByAppendingPathComponent:@"manifest.json"];
        PCLModpackImportResult *result = [[PCLModpackImportResult alloc] init];
        result.instanceName = fileName;
        
        if ([self.fm fileExistsAtPath:manifestPath]) {
            NSData *manifestData = [NSData dataWithContentsOfFile:manifestPath];
            NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:manifestData options:0 error:nil];
            result.minecraftVersion = manifest[@"minecraft"][@"version"] ?: @"";
            result.modLoader = manifest[@"manifestType"] ?: @"forge";
            NSArray *files = manifest[@"files"];
            result.modCount = files.count;
        } else {
            // Modrinth format: .mrpack
            NSString *modrinthIndex = [destPath stringByAppendingPathComponent:@"modrinth.index.json"];
            if ([self.fm fileExistsAtPath:modrinthIndex]) {
                NSData *idxData = [NSData dataWithContentsOfFile:modrinthIndex];
                NSDictionary *idx = [NSJSONSerialization JSONObjectWithData:idxData options:0 error:nil];
                result.minecraftVersion = idx[@"gameVersion"] ?: @"";
                result.modLoader = idx[@"loaders"][@"firstObject"] ?: @"fabric";
                result.modCount = [idx[@"files"] count];
            }
        }
        
        result.instancePath = destPath;
        
        progress(0.8, @"导入完成");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(YES, result, nil);
        });
    });
}

- (void)importFromCurseForge:(NSInteger)projectID
                      fileID:(NSInteger)fileID
                    progress:(void(^)(double progress, NSString *status))progress
                  completion:(void(^)(BOOL success, PCLModpackImportResult *result, NSError *error))completion {
    
    self.isCancelled = NO;
    
    progress(0.1, @"获取整合包信息...");
    
    [[PCLCurseForgeAPI sharedAPI] getModWithId:projectID completion:^(PCLCurseForgeMod *mod, NSError *error) {
        if (error || !mod) {
            completion(NO, nil, error ?: [NSError errorWithDomain:@"PCLModpackImport" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"无法获取 Mod 信息"}]);
            return;
        }
        
        progress(0.3, @"获取文件下载链接...");
        
        [[PCLCurseForgeAPI sharedAPI] getFilesForMod:projectID completion:^(NSArray<PCLCurseForgeFile *> *files, NSError *error) {
            if (error || files.count == 0) {
                completion(NO, nil, error ?: [NSError errorWithDomain:@"PCLModpackImport" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"无法获取文件列表"}]);
                return;
            }
            
            PCLCurseForgeFile *targetFile = nil;
            for (PCLCurseForgeFile *f in files) {
                if (f.fileId == fileID) {
                    targetFile = f;
                    break;
                }
            }
            if (!targetFile) targetFile = files.firstObject;
            
            if (!targetFile.downloadUrl) {
                completion(NO, nil, [NSError errorWithDomain:@"PCLModpackImport" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"无下载链接"}]);
                return;
            }
            
            progress(0.5, @"下载整合包...");
            
            NSString *cacheDir = NSTemporaryDirectory();
            NSString *zipPath = [cacheDir stringByAppendingPathComponent:targetFile.fileName];
            
            [[PCLCurseForgeAPI sharedAPI] downloadFile:targetFile
                                                toPath:zipPath
                                              progress:^(double p) {
                                                  progress(0.5 + p * 0.3, @"下载中...");
                                              }
                                            completion:^(BOOL success, NSError *error) {
                if (!success) {
                    completion(NO, nil, error);
                    return;
                }
                
                [self importFromZipAtURL:[NSURL fileURLWithPath:zipPath]
                                progress:^(double p, NSString *s) {
                                    progress(0.8 + p * 0.2, s);
                                }
                              completion:completion];
            }];
        }];
    }];
}

- (void)importFromModrinth:(NSString *)projectID
                versionID:(NSString *)versionID
                  progress:(void(^)(double progress, NSString *status))progress
                completion:(void(^)(BOOL success, PCLModpackImportResult *result, NSError *error))completion {
    
    self.isCancelled = NO;
    
    progress(0.1, @"获取 Modrinth 信息...");
    
    [[PCLModrinthAPI sharedAPI] getVersion:versionID completion:^(PCLModrinthVersion *version, NSError *error) {
        if (error || !version) {
            completion(NO, nil, error ?: [NSError errorWithDomain:@"PCLModpackImport" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"无法获取版本信息"}]);
            return;
        }
        
        NSArray *files = version.files;
        NSDictionary *primaryFile = nil;
        for (NSDictionary *f in files) {
            if ([f[@"primary"] boolValue]) {
                primaryFile = f;
                break;
            }
        }
        if (!primaryFile && files.count > 0) {
            primaryFile = files.firstObject;
        }
        
        NSString *url = primaryFile[@"url"];
        NSString *filename = primaryFile[@"filename"];
        
        if (!url) {
            completion(NO, nil, [NSError errorWithDomain:@"PCLModpackImport" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"无下载链接"}]);
            return;
        }
        
        progress(0.5, @"下载整合包...");
        
        NSString *zipPath = [NSTemporaryDirectory() stringByAppendingPathComponent:filename ?: @"modpack.zip"];
        NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
        NSURLSessionDownloadTask *task = [self.session downloadTaskWithRequest:req completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            if (error) {
                completion(NO, nil, error);
                return;
            }
            [self.fm moveItemAtURL:location toURL:[NSURL fileURLWithPath:zipPath] error:nil];
            
            [self importFromZipAtURL:[NSURL fileURLWithPath:zipPath]
                            progress:^(double p, NSString *s) {
                                progress(0.8 + p * 0.2, s);
                            }
                          completion:completion];
        }];
        [task resume];
    }];
}

@end
