#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, PCLInstanceTab) {
    PCLInstanceTabOverview = 0,
    PCLInstanceTabSettings,
    PCLInstanceTabInstall,
    PCLInstanceTabExport,
    PCLInstanceTabSaves,
    PCLInstanceTabScreenshots,
    PCLInstanceTabMods,
    PCLInstanceTabResourcePacks,
    PCLInstanceTabShaders
};

@interface PCLInstanceViewController : UIViewController

@property (nonatomic, assign) CGFloat leftPanelWidth;
@property (nonatomic) PCLInstanceTab currentTab;
@property (nonatomic, copy) void (^onComplete)(void);

- (void)switchToTab:(PCLInstanceTab)tab;
- (void)dismissTransientUI;
- (void)prepareCEEnterAnimation;
- (void)playCEEnterAnimation;
- (void)playCEExitWithCompletion:(dispatch_block_t)completion;
- (void)reloadState;

@end
