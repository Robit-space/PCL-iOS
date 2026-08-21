#import <UIKit/UIKit.h>
#import "PCLSidebarView.h"

@interface PCLRootViewController : UIViewController <PCLSidebarViewDelegate>

@property (nonatomic, readonly) PCLSidebarPage currentPage;

@end
