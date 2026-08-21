#import "PCLRootViewController.h"
#import "PCLLaunchViewController.h"
#import "PCLDownloadViewController.h"
#import "PCLSettingsViewController.h"

@interface PCLRootViewController () <PCLSidebarViewDelegate>

@property (nonatomic, strong) PCLSidebarView *sidebar;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) PCLLaunchViewController *launchVC;
@property (nonatomic, strong) PCLDownloadViewController *downloadVC;
@property (nonatomic, strong) PCLSettingsViewController *settingsVC;

@property (nonatomic) PCLSidebarPage currentPage;
@property (nonatomic) BOOL isPageTransitioning;

@end

@implementation PCLRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithRed:0.97 green:0.97 blue:0.98 alpha:1.0];
    
    [self setupSidebar];
    [self setupContentView];
    
    self.currentPage = PCLSidebarPageLaunch;
    self.isPageTransitioning = NO;
    
    [self showPage:PCLSidebarPageLaunch];
}

- (void)setupSidebar {
    self.sidebar = [[PCLSidebarView alloc] init];
    self.sidebar.delegate = self;
    self.sidebar.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:self.sidebar];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.sidebar.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.sidebar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.sidebar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.sidebar.widthAnchor constraintEqualToConstant:72]
    ]];
}

- (void)setupContentView {
    self.contentView = [[UIView alloc] init];
    self.contentView.clipsToBounds = YES;
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:self.contentView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.contentView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.sidebar.trailingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    
    // 初始化子视图控制器
    self.launchVC = [[PCLLaunchViewController alloc] init];
    [self addChildViewController:self.launchVC];
    self.launchVC.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.launchVC.view];
    [self.launchVC didMoveToParentViewController:self];
    
    self.downloadVC = [[PCLDownloadViewController alloc] init];
    [self addChildViewController:self.downloadVC];
    self.downloadVC.view.translatesAutoresizingMaskIntoConstraints = NO;
    self.downloadVC.view.hidden = YES;
    [self.contentView addSubview:self.downloadVC.view];
    [self.downloadVC didMoveToParentViewController:self];
    
    self.settingsVC = [[PCLSettingsViewController alloc] init];
    [self addChildViewController:self.settingsVC];
    self.settingsVC.view.translatesAutoresizingMaskIntoConstraints = NO;
    self.settingsVC.view.hidden = YES;
    [self.contentView addSubview:self.settingsVC.view];
    [self.settingsVC didMoveToParentViewController:self];
    
    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        [self.launchVC.view.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.launchVC.view.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.launchVC.view.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.launchVC.view.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.downloadVC.view.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.downloadVC.view.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.downloadVC.view.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.downloadVC.view.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.settingsVC.view.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.settingsVC.view.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.settingsVC.view.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.settingsVC.view.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
}

#pragma mark - PCLSidebarViewDelegate

- (void)sidebarView:(PCLSidebarView *)sidebar didSelectPage:(PCLSidebarPage)page {
    [self transitionToPage:page];
}

#pragma mark - Page Transition

- (void)transitionToPage:(PCLSidebarPage)page {
    if (page == self.currentPage) return;
    if (self.isPageTransitioning) return;
    
    self.isPageTransitioning = YES;
    
    PCLSidebarPage fromPage = self.currentPage;
    self.currentPage = page;
    
    // 执行页面切换动画
    [self performTransitionFrom:fromPage to:page completion:^{
        self.isPageTransitioning = NO;
    }];
}

- (void)performTransitionFrom:(PCLSidebarPage)fromPage to:(PCLSidebarPage)toPage completion:(void(^)(void))completion {
    UIViewController *fromVC = [self viewControllerForPage:fromPage];
    UIViewController *toVC = [self viewControllerForPage:toPage];
    
    if (!fromVC || !toVC) {
        [self showPage:toPage];
        if (completion) completion();
        return;
    }
    
    toVC.view.alpha = 0;
    toVC.view.hidden = NO;
    
    [UIView animateWithDuration:0.25
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        fromVC.view.alpha = 0;
        toVC.view.alpha = 1;
    } completion:^(BOOL finished) {
        fromVC.view.hidden = YES;
        fromVC.view.alpha = 1;
        if (completion) completion();
    }];
}

- (void)showPage:(PCLSidebarPage)page {
    self.launchVC.view.hidden = YES;
    self.downloadVC.view.hidden = YES;
    self.settingsVC.view.hidden = YES;
    
    UIViewController *vc = [self viewControllerForPage:page];
    if (vc) {
        vc.view.hidden = NO;
    }
}

- (UIViewController *)viewControllerForPage:(PCLSidebarPage)page {
    switch (page) {
        case PCLSidebarPageLaunch:
            return self.launchVC;
        case PCLSidebarPageDownload:
            return self.downloadVC;
        case PCLSidebarPageSettings:
            return self.settingsVC;
        case PCLSidebarPageTools:
            return nil; // Tools页面暂未实现
    }
    return nil;
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

@end
