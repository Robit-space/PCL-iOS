#import <Foundation/Foundation.h>
#import "PCLVersionManager.h"
#import "PCLPathUtils.h"
#import "PCLInstanceManager.h"

typedef NS_ENUM(NSInteger, PCLLaunchError) {
    PCLLaunchErrorNone = 0,
    PCLLaunchErrorVersionNotFound,
    PCLLaunchErrorJavaNotFound,
    PCLLaunchErrorJavaVersionMismatch,
    PCLLaunchErrorLibraryMissing,
    PCLLaunchErrorAssetMissing,
    PCLLaunchErrorProfileInvalid,
    PCLLaunchErrorNetworkFailure,
    PCLLaunchErrorCancelled,
    PCLLaunchErrorInternalFailure
};

typedef void(^PCLLogCallback)(NSString *line);
typedef void(^PCLLaunchCompletion)(BOOL success, NSError *error);

@interface PCLGameLauncher : NSObject

@property (nonatomic, copy) PCLLogCallback logCallback;

+ (instancetype)sharedLauncher;
- (void)launchWithVersion:(NSString *)versionId
                  profile:(NSDictionary *)profile
               completion:(PCLLaunchCompletion)completion;

// 版本隔离: 基于PCLInstance启动 (PCL2-CE风格)
- (void)launchWithInstance:(PCLInstance *)instance
                   profile:(NSDictionary *)profile
                completion:(PCLLaunchCompletion)completion;

// 使用当前选中实例启动
- (void)launchWithCurrentInstance:(NSDictionary *)profile
                       completion:(PCLLaunchCompletion)completion;

- (void)cancelLaunch;

@end
