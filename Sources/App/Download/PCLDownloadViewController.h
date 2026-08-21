#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, PCLDownloadTab) {
    PCLDownloadTabMinecraft = 0,
    PCLDownloadTabMod,
    PCLDownloadTabModpack,
    PCLDownloadTabDataPack,
    PCLDownloadTabResourcePack,
    PCLDownloadTabShader,
    PCLDownloadTabWorld,
    PCLDownloadTabFavorites,
    PCLDownloadTabClientInstall,
    PCLDownloadTabOptiFine,
    PCLDownloadTabForge,
    PCLDownloadTabNeoForge,
    PCLDownloadTabFabric,
    PCLDownloadTabLiteLoader
};

@interface PCLDownloadViewController : UIViewController

@property (nonatomic, assign) CGFloat leftPanelWidth;
@property (nonatomic, copy) void (^onSelectInstallTab)(PCLDownloadTab tab);

- (void)dismissTransientUI;

@end
