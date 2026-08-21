#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PCLDownloadState) {
    PCLDownloadStatePending = 0,
    PCLDownloadStateDownloading,
    PCLDownloadStateCompleted,
    PCLDownloadStateFailed,
    PCLDownloadStatePaused
};

typedef NS_ENUM(NSInteger, PCLDownloadSource) {
    PCLDownloadSourceAuto = 0,
    PCLDownloadSourceOfficial,
    PCLDownloadSourceBMCL,
    PCLDownloadSourceMCBBS
};

typedef NS_ENUM(NSInteger, PCLResourceType) {
    PCLResourceTypeClient = 0,
    PCLResourceTypeLibrary,
    PCLResourceTypeAsset,
    PCLResourceTypeForge,
    PCLResourceTypeFabric,
    PCLResourceTypeNeoForge,
    PCLResourceTypeOptiFine,
    PCLResourceTypeLiteLoader,
    PCLResourceTypeMod,
    PCLResourceTypeModpack,
    PCLResourceTypeResourcePack,
    PCLResourceTypeShader,
    PCLResourceTypeDataPack,
    PCLResourceTypeWorld
};

@interface PCLDownloadTask : NSObject
@property (nonatomic, copy) NSString *taskId;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, assign) PCLResourceType resourceType;
@property (nonatomic, assign) PCLDownloadState state;
@property (nonatomic, assign) double progress;
@property (nonatomic, assign) long long totalBytes;
@property (nonatomic, assign) long long completedBytes;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *targetPath;
@property (nonatomic, copy) NSString *sha1;
@property (nonatomic, assign) NSInteger retryCount;
@property (nonatomic, strong) NSError *error;
@end

@protocol PCLDownloadManagerDelegate <NSObject>
@optional
- (void)downloadManagerDidUpdateProgress:(PCLDownloadTask *)task;
- (void)downloadManagerDidComplete:(PCLDownloadTask *)task;
- (void)downloadManagerDidFail:(PCLDownloadTask *)task error:(NSError *)error;
@end

@interface PCLDownloadManager : NSObject
@property (nonatomic, weak) id<PCLDownloadManagerDelegate> delegate;
@property (nonatomic, readonly) NSArray<PCLDownloadTask *> *allTasks;
@property (nonatomic, readonly) NSArray<PCLDownloadTask *> *activeTasks;
@property (nonatomic, assign) PCLDownloadSource downloadSource;

+ (instancetype)sharedManager;

- (void)addTask:(PCLDownloadTask *)task;
- (void)removeTask:(PCLDownloadTask *)task;
- (void)pauseTask:(PCLDownloadTask *)task;
- (void)resumeTask:(PCLDownloadTask *)task;
- (void)cancelTask:(PCLDownloadTask *)task;
- (void)retryTask:(PCLDownloadTask *)task;

- (void)startDownload:(PCLDownloadTask *)task;
- (void)startDownload:(PCLDownloadTask *)task
             progress:(void (^)(double progress, NSString *status))progress
           completion:(void (^)(BOOL success, NSError *error))completion;
- (void)downloadFile:(NSString *)urlString
          toPath:(NSString *)path
             sha1:(NSString *)sha1
          success:(void (^)(void))success
          failure:(void (^)(NSError *error))failure;

- (NSString *)replaceURLWithDownloadSource:(NSString *)urlString;

@end
