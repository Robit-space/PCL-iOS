#import <UIKit/UIKit.h>
#import "PCLSettingsViewController.h"

@interface PCLSettingsRightView : UIView
@property (nonatomic) CGFloat designScale;
- (void)switchToTab:(PCLSettingsTab)tab;
- (void)dismissTransientUI;
- (void)prepareCEEnterAnimation;
- (void)playCEEnterAnimation;
- (void)playCEExitAnimation;
- (void)reloadState;
@end
