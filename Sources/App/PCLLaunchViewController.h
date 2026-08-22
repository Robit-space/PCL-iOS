#import <UIKit/UIKit.h>

@interface PCLLaunchViewController : UIViewController

@property (nonatomic, assign) CGFloat leftPanelWidth;
@property (nonatomic, copy) void (^onOpenDownload)(void);


- (void)dismissTransientUI;
- (void)prepareCEEnterAnimation;
- (void)playCEEnterAnimation;
- (void)playCEExitWithCompletion:(dispatch_block_t)completion;

@end
