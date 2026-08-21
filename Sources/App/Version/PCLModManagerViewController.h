#import <UIKit/UIKit.h>

@class PCLInstance;

// Mod管理类型
typedef NS_ENUM(NSInteger, PCLModManagerType) {
    PCLModManagerTypeMod = 0,        // 模组
    PCLModManagerTypeShader,          // 光影
    PCLModManagerTypeResourcePack,    // 资源包
    PCLModManagerTypeDataPack         // 数据包
};

@interface PCLModManagerViewController : UIViewController

- (instancetype)initWithInstance:(PCLInstance *)instance modType:(PCLModManagerType)type;

@end
