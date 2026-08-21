#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PCLModpackImportType) {
    PCLModpackImportTypeCurseForge,
    PCLModpackImportTypeModrinth,
    PCLModpackImportTypeZip
};

typedef NS_ENUM(NSInteger, PCLModpackImportError) {
    PCLModpackImportErrorNone = 0,
    PCLModpackImportErrorInvalidFile,
    PCLModpackImportErrorUnsupportedFormat,
    PCLModpackImportErrorDownloadFailed,
    PCLModpackImportErrorInstallFailed,
    PCLModpackImportErrorCancelled
};

@interface PCLModpackImportResult : NSObject
@property (nonatomic, strong) NSString *instanceName;
@property (nonatomic, strong) NSString *minecraftVersion;
@property (nonatomic, strong) NSString *modLoader; // "forge", "fabric", "quilt", "neoforge"
@property (nonatomic, assign) NSInteger modCount;
@property (nonatomic, strong) NSString *instancePath;
@end

@interface PCLModpackImportService : NSObject

+ (instancetype)sharedService;

// Import from local zip file
- (void)importFromZipAtURL:(NSURL *)fileURL
                  progress:(void(^)(double progress, NSString *status))progress
                completion:(void(^)(BOOL success, PCLModpackImportResult *result, NSError *error))completion;

// Import from CurseForge project + file ID
- (void)importFromCurseForge:(NSInteger)projectID
                      fileID:(NSInteger)fileID
                    progress:(void(^)(double progress, NSString *status))progress
                  completion:(void(^)(BOOL success, PCLModpackImportResult *result, NSError *error))completion;

// Import from Modrinth project + version ID
- (void)importFromModrinth:(NSString *)projectID
                versionID:(NSString *)versionID
                 progress:(void(^)(double progress, NSString *status))progress
               completion:(void(^)(BOOL success, PCLModpackImportResult *result, NSError *error))completion;

// Cancel current operation
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
