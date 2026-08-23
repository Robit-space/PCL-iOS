#import "PCLRootViewController.h"
#import "PCLTopBarView.h"
#import "PCLLaunchViewController.h"
#import "PCLDownloadViewController.h"
#import "PCLSettingsViewController.h"

@interface PCLRootViewController () <PCLTopBarViewDelegate>

@property (nonatomic, strong) PCLTopBarView *topBar;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *pageLabel;
@property (nonatomic, strong) PCLLaunchViewController *launchVC;
@property (nonatomic, strong) PCLDownloadViewController *downloadVC;
@property (nonatomic, strong) PCLSettingsViewController *settingsVC;

@property (nonatomic) PCLPageType currentPage;
@property (nonatomic) BOOL isPageTransitioning;

- (void)transitionToPage:(PCLPageType)page;

@end

@implementation PCLRootViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(showInstanceBar:) name:@"PCLShowInstanceBar" object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(hideInstanceBar:) name:@"PCLHideInstanceBar" object:nil];

    self.view.backgroundColor =
        [UIColor systemBackgroundColor];

    [self setupTopBar];
    [self setupContentView];

    self.topBar.alpha = 0.0;
    self.contentView.alpha = 0.0;

    self.currentPage=PCLPageTypeLaunch;
    self.isPageTransitioning=NO;

    [self showPage:PCLPageTypeLaunch];
}

- (void)setupTopBar {
    self.topBar = [[PCLTopBarView alloc] init];
    self.topBar.delegate = self;
    self.topBar.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:self.topBar];
    UIButton *sub=[UIButton buttonWithType:UIButtonTypeSystem]; sub.tag=909; sub.hidden=YES; sub.backgroundColor=self.topBar.backgroundColor;
    [sub setTitle:@"  实例选择" forState:UIControlStateNormal]; [sub setImage:[UIImage systemImageNamed:@"arrow.left"] forState:UIControlStateNormal];
    [sub setTitleColor:UIColor.whiteColor forState:UIControlStateNormal]; sub.tintColor=UIColor.whiteColor; sub.titleLabel.font=[UIFont systemFontOfSize:15]; sub.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;
    [sub addTarget:self action:@selector(instanceBack) forControlEvents:UIControlEventTouchUpInside];
    UIButton *back=[UIButton buttonWithType:UIButtonTypeSystem];
    back.tag=910; back.tintColor=UIColor.whiteColor;
    [back setImage:[UIImage systemImageNamed:@"arrow.left"] forState:UIControlStateNormal];
    UILabel *title=[[UILabel alloc] init]; title.tag=911;
    title.text=@"实例选择"; title.textColor=UIColor.whiteColor;
    title.textAlignment=NSTextAlignmentCenter;
    [sub setTitle:nil forState:UIControlStateNormal];
    [sub setImage:nil forState:UIControlStateNormal];
    [sub addSubview:back]; [sub addSubview:title];
    [self.topBar addSubview:sub];

    [NSLayoutConstraint activateConstraints:@[
        [self.topBar.topAnchor
            constraintEqualToAnchor:self.view.topAnchor],

        [self.topBar.leadingAnchor
            constraintEqualToAnchor:self.view.leadingAnchor],
        [self.topBar.trailingAnchor
            constraintEqualToAnchor:self.view.trailingAnchor],

        [self.topBar.heightAnchor
            constraintEqualToConstant:56.0]
    ]];
}

- (void)setupContentView {
    self.contentView = [[UIView alloc] init];
    self.contentView.clipsToBounds=YES;
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:self.contentView];

    [NSLayoutConstraint activateConstraints:@[
        [self.contentView.topAnchor
            constraintEqualToAnchor:self.topBar.bottomAnchor],

        [self.contentView.leadingAnchor
            constraintEqualToAnchor:self.view.leadingAnchor],
        [self.contentView.trailingAnchor
            constraintEqualToAnchor:self.view.trailingAnchor],

        [self.contentView.bottomAnchor
            constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    self.pageLabel = [[UILabel alloc] init];
    self.pageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.pageLabel.font =
        [UIFont systemFontOfSize:30.0
                          weight:UIFontWeightSemibold];

    self.pageLabel.textColor = [UIColor labelColor];

    [self.contentView addSubview:self.pageLabel];

    self.launchVC =
        [[PCLLaunchViewController alloc] init];

    __weak typeof(self) weakSelf = self;
    self.launchVC.onOpenDownload = ^{
        [weakSelf.topBar
            selectPage:PCLPageTypeDownload
              animated:YES];

        [weakSelf transitionToPage:
            PCLPageTypeDownload];
    };

    [self addChildViewController:self.launchVC];
    self.launchVC.view.translatesAutoresizingMaskIntoConstraints = NO;

    [self.contentView addSubview:self.launchVC.view];
    [self.launchVC didMoveToParentViewController:self];

    self.downloadVC=[[PCLDownloadViewController alloc] init];
    [self addChildViewController:self.downloadVC];
    self.downloadVC.view.translatesAutoresizingMaskIntoConstraints=NO;
    self.downloadVC.view.hidden=YES;
    [self.contentView addSubview:self.downloadVC.view];
    [self.downloadVC didMoveToParentViewController:self];

    self.settingsVC=[[PCLSettingsViewController alloc] init];
    [self addChildViewController:self.settingsVC];
    self.settingsVC.view.translatesAutoresizingMaskIntoConstraints=NO;
    self.settingsVC.view.hidden=YES;
    [self.contentView addSubview:self.settingsVC.view];
    [self.settingsVC didMoveToParentViewController:self];


    for (UIView *v in @[self.downloadVC.view,self.settingsVC.view]) {
        [NSLayoutConstraint activateConstraints:@[
            [v.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [v.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [v.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [v.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
        ]];
    }

    [self.view bringSubviewToFront:self.topBar];

    [NSLayoutConstraint activateConstraints:@[
        [self.launchVC.view.topAnchor
            constraintEqualToAnchor:self.contentView.topAnchor],
        [self.launchVC.view.leadingAnchor
            constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.launchVC.view.trailingAnchor
            constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.launchVC.view.bottomAnchor
            constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [self.pageLabel.centerXAnchor
            constraintEqualToAnchor:self.contentView.centerXAnchor],
        [self.pageLabel.centerYAnchor
            constraintEqualToAnchor:self.contentView.centerYAnchor]
    ]];
}

- (void)topBarView:(PCLTopBarView *)topBar
     didSelectPage:(PCLPageType)page {

    [self transitionToPage:page];
}
- (void)transitionToPage:(PCLPageType)page {
    if (page==self.currentPage)
        return;

    if (self.isPageTransitioning) {
        [self.topBar
            selectPage:self.currentPage
              animated:YES];
        return;
    }

    self.isPageTransitioning=YES;

    __weak typeof(self) weakSelf=self;

    if (self.currentPage==PCLPageTypeLaunch) {
        [self.launchVC
            playCEExitWithCompletion:^{

            [weakSelf showPage:page];
            weakSelf.currentPage=page;

            weakSelf.pageLabel.alpha=0;

            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    (int64_t)(.030*NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{

                [UIView animateWithDuration:.10
                    animations:^{
                        weakSelf.pageLabel.alpha=1;
                    }
                    completion:^(BOOL done) {
                        weakSelf.isPageTransitioning=NO;
                    }];
            });
        }];

        return;
    }

    if (page==PCLPageTypeLaunch) {

        [UIView animateWithDuration:.110

            animations:^{

                weakSelf.pageLabel.alpha=0;

            }

            completion:^(BOOL done) {

            [weakSelf.launchVC

                prepareCEEnterAnimation];

            [weakSelf showPage:

                PCLPageTypeLaunch];

            weakSelf.pageLabel.alpha=1;

            weakSelf.currentPage=PCLPageTypeLaunch;

            dispatch_after(

                dispatch_time(

                    DISPATCH_TIME_NOW,

                    (int64_t)(.030*NSEC_PER_SEC)),                dispatch_get_main_queue(), ^{

                [weakSelf.launchVC

                    playCEEnterAnimation];

                dispatch_after(

                    dispatch_time(

                        DISPATCH_TIME_NOW,

                        (int64_t)(.400*NSEC_PER_SEC)),

                    dispatch_get_main_queue(), ^{

                        weakSelf.isPageTransitioning=NO;

                    });

            });

        }];

        return;

    }

    [UIView animateWithDuration:.110
        animations:^{
            weakSelf.pageLabel.alpha=0;
        }
        completion:^(BOOL done) {

        [weakSelf showPage:page];
        weakSelf.currentPage=page;

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(.030*NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{

            [UIView animateWithDuration:.10
                animations:^{
                    weakSelf.pageLabel.alpha=1;
                }
                completion:^(BOOL finished) {
                    weakSelf.isPageTransitioning=NO;
                }];
        });
    }];
}

- (void)showPage:(PCLPageType)page {

    [self.launchVC dismissTransientUI];

    [self.downloadVC dismissTransientUI];

    [self.settingsVC dismissTransientUI];

    self.launchVC.view.hidden=YES;

    self.downloadVC.view.hidden=YES;

    self.settingsVC.view.hidden=YES;

    self.pageLabel.hidden=YES;

    switch (page) {

        case PCLPageTypeLaunch:

            self.launchVC.view.hidden=NO;

            break;

        case PCLPageTypeDownload:

            self.downloadVC.view.hidden=NO;

            break;

        case PCLPageTypeSettings:

            self.settingsVC.view.hidden=NO;

            break;

        case PCLPageTypeTools:

            self.pageLabel.hidden=NO;

            self.pageLabel.text=@"工具";

            break;

    }

}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self.topBar layoutIfNeeded];
    UIView *sub=[self.topBar viewWithTag:909]; sub.frame=self.topBar.bounds;
    [sub viewWithTag:910].frame=CGRectMake(12,0,48,56);
    [sub viewWithTag:911].frame=CGRectMake(70,0,CGRectGetWidth(sub.bounds)-140,56);
    CGFloat leftW=MIN(300.0,CGRectGetWidth(self.contentView.bounds));
    self.launchVC.leftPanelWidth=leftW;
    self.downloadVC.leftPanelWidth=leftW;
    self.settingsVC.leftPanelWidth=leftW;

    [self.launchVC.view setNeedsLayout];
    [self.downloadVC.view setNeedsLayout];
    [self.settingsVC.view setNeedsLayout];
}

- (void)showInstanceBar:(NSNotification *)n {UIView *v=[self.topBar viewWithTag:909];v.hidden=NO;v.alpha=0;[UIView animateWithDuration:.2 animations:^{v.alpha=1;}];}
- (void)hideInstanceBar:(NSNotification *)n {UIView *v=[self.topBar viewWithTag:909];[UIView animateWithDuration:.15 animations:^{v.alpha=0;} completion:^(BOOL x){v.hidden=YES;}];}
- (void)instanceBack {[self.launchVC dismissTransientUI];}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)playEntranceAnimation {
    [UIView animateWithDuration:0.30
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.25
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{

        self.topBar.alpha = 1.0;
        self.topBar.transform =
            CGAffineTransformIdentity;

        self.contentView.alpha = 1.0;
        self.contentView.transform =
            CGAffineTransformIdentity;

    } completion:nil];
}

@end
