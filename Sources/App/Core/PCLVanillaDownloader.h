#import <Foundation/Foundation.h>
#import "PCLVersionManager.h"

typedef NS_ENUM(NSInteger, PCLVanillaDownloadStep) {
    PCLVanillaDownloadStepIdle = 0,
    PCLVanillaDownloadStepFetchingManifest,
    PCLVanillaDownloadStepDownloadingVersionJson,
    PCLVanillaDownloadStepParsingVersionJson,
    PCLVanillaDownloadStepDownloadingClient,
    PCLVanillaDownloadStepDownloadingAssetIndex,
    PCLVanillaDownloadStepDownloadingAssets,
    PCLVanillaDownloadStepDownloadingLibraries,
    PCLVanillaDownloadStepExtractingNatives,
    PCLVanillaDownloadStepCompleted,
    PCLVanillaDownloadStepFailed
};

typedef void(^PCLVanillaDownloadProgressBlock)(PCLVanillaDownloadStep step, double overallProgress, double stepProgress, NSString *statusMessage);
typedef void(^PCLVanillaDownloadCompletionBlock)(BOOL success, NSError *error);

@interface PCLVanillaDownloader : NSObject

@property (nonatomic, readonly) PCLVanillaDownloadStep currentStep;
@property (nonatomic, readonly, getter=isDownloading) BOOL downloading;

+ (instancetype)sharedDownloader;

- (void)downloadVersion:(NSString *)versionId
               progress:(PCLVanillaDownloadProgressBlock)progress
             completion:(PCLVanillaDownloadCompletionBlock)completion;

- (void)cancelDownload;

- (NSArray<NSDictionary *> *)availableReleases;
- (NSArray<NSDictionary *> *)availableSnapshots;
- (NSArray<NSDictionary *> *)availableOldVersions;

@end
