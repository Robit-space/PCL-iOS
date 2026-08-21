#import <UIKit/UIKit.h>
#import "PCLSettingsViewController.h"

@interface PCLSettingsLeftView : UIView
@property (nonatomic) CGFloat designScale;
@property (nonatomic, copy) void (^onSelectTab)(PCLSettingsTab tab);
- (void)dismissTransientUI;
- (void)prepareCEEnterAnimation;
- (void)playCEEnterAnimation;
- (void)playCEExitAnimation;
- (void)reloadState;
@end
