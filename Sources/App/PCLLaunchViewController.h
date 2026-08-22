#import <UIKit/UIKit.h>

@interface PCLLaunchViewController : UIViewController

@property (nonatomic, assign) CGFloat leftPanelWidth;
@property (nonatomic, copy) void (^onOpenDownload)(void);

@end
