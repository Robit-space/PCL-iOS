#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, PCLSidebarPage) {
    PCLSidebarPageLaunch = 0,
    PCLSidebarPageDownload,
    PCLSidebarPageSettings,
    PCLSidebarPageTools
};

@class PCLSidebarView;

@protocol PCLSidebarViewDelegate <NSObject>
- (void)sidebarView:(PCLSidebarView *)sidebar didSelectPage:(PCLSidebarPage)page;
@end

@interface PCLSidebarView : UIView

@property (nonatomic, weak) id<PCLSidebarViewDelegate> delegate;
@property (nonatomic, assign) PCLSidebarPage selectedPage;

- (void)selectPage:(PCLSidebarPage)page animated:(BOOL)animated;

@end
