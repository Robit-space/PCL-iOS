#import <UIKit/UIKit.h>

@class PCLInstance;

@interface PCLInstanceEditViewController : UIViewController

@property (nonatomic, copy) dispatch_block_t onSaved;

- (instancetype)initWithInstance:(PCLInstance *)instance;

@end
