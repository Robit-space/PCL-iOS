#import <UIKit/UIKit.h>
#import "PCLModrinthAPI.h"

typedef NS_ENUM(NSInteger, PCLResourceTab) {
    PCLResourceTabMod = 0,
    PCLResourceTabModpack,
    PCLResourceTabResourcePack,
    PCLResourceTabShader,
    PCLResourceTabDataPack
};

@interface PCLResourceBrowseViewController : UIViewController

@property (nonatomic, copy) void (^onBack)(void);
@property (nonatomic, assign) PCLResourceTab initialTab;

@end
