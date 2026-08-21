#import <UIKit/UIKit.h>
#import "PCLDownloadViewController.h"

@interface PCLDownloadLeftView : UIView

@property (nonatomic) CGFloat designScale;
@property (nonatomic, copy) void (^onSelectTab)(PCLDownloadTab tab);

- (void)dismissTransientUI;
- (void)prepareCEEnterAnimation;
- (void)playCEEnterAnimation;
- (void)playCEExitAnimation;
- (void)reloadState;

@end
