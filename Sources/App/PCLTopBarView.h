#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, PCLPageType) {
    PCLPageTypeLaunch = 0,
    PCLPageTypeDownload,
    PCLPageTypeSettings,
    PCLPageTypeTools
};

@class PCLTopBarView;

@protocol PCLTopBarViewDelegate <NSObject>
- (void)topBarView:(PCLTopBarView *)topBar didSelectPage:(PCLPageType)page;
@end

@interface PCLTopBarView : UIView

@property (nonatomic, weak) id<PCLTopBarViewDelegate> delegate;
@property (nonatomic, assign) PCLPageType selectedPage;

- (void)selectPage:(PCLPageType)page animated:(BOOL)animated;
- (CGFloat)launchButtonCenterX;

@end
