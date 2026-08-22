#import <UIKit/UIKit.h>
@class PCLInstance;
@interface PCLInstanceSelectViewController : UIViewController
@property CGFloat leftPanelWidth;
@property (copy) void (^onBack)(void);
@property (copy) void (^onDownload)(void);
@property (copy) void (^onSelect)(PCLInstance *);
- (void)reloadInstances;
@end
