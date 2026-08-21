#import <UIKit/UIKit.h>
#import "PCLDownloadViewController.h"

@interface PCLDownloadRightView : UIView

@property (nonatomic) CGFloat designScale;
@property (nonatomic, copy) void (^onCreateProfile)(void);
@property (nonatomic, copy) void (^onLaunch)(void);
@property (nonatomic, copy) void (^onSelectInstance)(void);
@property (nonatomic, copy) void (^onInstanceSettings)(void);
@property (nonatomic, copy) void (^onSkinOptions)(void);
@property (nonatomic, copy) void (^onEditProfile)(void);
@property (nonatomic, copy) void (^onCloseHint)(void);
@property (nonatomic, copy) void (^onOpenDownload)(void);

@property (nonatomic, strong) NSString *selectedGameVersion;

- (void)switchToTab:(PCLDownloadTab)tab;
- (void)dismissTransientUI;
- (void)prepareCEEnterAnimation;
- (void)playCEEnterAnimation;
- (void)playCEExitAnimation;
- (void)reloadState;

@end
