#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, PCLVanillaListFilter) {
    PCLVanillaListFilterReleases = 0,
    PCLVanillaListFilterSnapshots,
    PCLVanillaListFilterOldVersions,
    PCLVanillaListFilterInstalled
};

@interface PCLVanillaDownloadViewController : UIViewController

@property (nonatomic, copy) void (^onBack)(void);
@property (nonatomic, copy) void (^onVersionDownloaded)(NSString *versionId);

- (void)reloadData;

@end
