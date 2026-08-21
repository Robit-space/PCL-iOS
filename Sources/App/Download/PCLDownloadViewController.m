#import "PCLDownloadViewController.h"
#import "PCLVanillaDownloadViewController.h"
#import "PCLResourceBrowseViewController.h"

static UIColor *PCLColor(NSUInteger rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
                           green:((rgb >> 8) & 255) / 255.0
                            blue:(rgb & 255) / 255.0
                           alpha:1.0];
}

@interface PCLDownloadViewController () <UIScrollViewDelegate>

@property (nonatomic, strong) UIScrollView *tabScrollView;
@property (nonatomic, strong) UIStackView *tabStackView;
@property (nonatomic, strong) NSMutableArray<UIButton *> *tabButtons;
@property (nonatomic, strong) UIView *indicatorView;
@property (nonatomic, strong) UIView *contentContainer;

// Child view controllers
@property (nonatomic, strong) PCLVanillaDownloadViewController *vanillaVC;
@property (nonatomic, strong) PCLResourceBrowseViewController *modVC;
@property (nonatomic, strong) PCLResourceBrowseViewController *modpackVC;
@property (nonatomic, strong) PCLResourceBrowseViewController *resourcePackVC;
@property (nonatomic, strong) PCLResourceBrowseViewController *shaderVC;
@property (nonatomic, strong) PCLResourceBrowseViewController *dataPackVC;

@property (nonatomic, strong) NSArray<NSString *> *tabTitles;
@property (nonatomic, assign) NSInteger selectedTab;

@end

@implementation PCLDownloadViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = PCLColor(0xF5F7FA);
    
    // PCL-CE风格: 统一资源浏览 (原版 + 5种资源类型)
    self.tabTitles = @[@"Minecraft", @"模组", @"整合包", @"资源包", @"光影", @"数据包"];
    self.tabButtons = [NSMutableArray array];
    self.selectedTab = 0;
    
    [self setupUI];
    [self setupChildViewControllers];
    [self switchToTab:0];
}

- (void)setupUI {
    // 顶部标签栏 (PCL-CE风格: 可滚动+指示器动画)
    self.tabScrollView = [[UIScrollView alloc] init];
    self.tabScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabScrollView.showsHorizontalScrollIndicator = NO;
    self.tabScrollView.backgroundColor = [UIColor whiteColor];
    self.tabScrollView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.tabScrollView.layer.shadowOpacity = 0.05;
    self.tabScrollView.layer.shadowRadius = 4;
    self.tabScrollView.layer.shadowOffset = CGSizeMake(0, 2);
    self.tabScrollView.delegate = self;
    [self.view addSubview:self.tabScrollView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tabScrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tabScrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tabScrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tabScrollView.heightAnchor constraintEqualToConstant:48]
    ]];
    
    // 标签按钮容器
    self.tabStackView = [[UIStackView alloc] init];
    self.tabStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabStackView.axis = UILayoutConstraintAxisHorizontal;
    self.tabStackView.spacing = 0;
    self.tabStackView.alignment = UIStackViewAlignmentCenter;
    [self.tabScrollView addSubview:self.tabStackView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tabStackView.topAnchor constraintEqualToAnchor:self.tabScrollView.topAnchor],
        [self.tabStackView.leadingAnchor constraintEqualToAnchor:self.tabScrollView.leadingAnchor constant:8],
        [self.tabStackView.trailingAnchor constraintEqualToAnchor:self.tabScrollView.trailingAnchor constant:-8],
        [self.tabStackView.bottomAnchor constraintEqualToAnchor:self.tabScrollView.bottomAnchor],
        [self.tabStackView.heightAnchor constraintEqualToAnchor:self.tabScrollView.heightAnchor]
    ]];
    
    // 创建标签按钮
    for (NSInteger i = 0; i < self.tabTitles.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        [btn setTitle:self.tabTitles[i] forState:UIControlStateNormal];
        [btn setTitleColor:PCLColor(0x8C8C8C) forState:UIControlStateNormal];
        [btn setTitleColor:PCLColor(0x1370F3) forState:UIControlStateSelected];
        [btn setTitleColor:PCLColor(0x1370F3) forState:UIControlStateSelected | UIControlStateHighlighted];
        btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        btn.tag = i;
        [btn addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        btn.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
        [self.tabStackView addArrangedSubview:btn];
        [self.tabButtons addObject:btn];
        [btn.heightAnchor constraintEqualToConstant:48].active = YES;
    }
    
    // 选中指示器 (PCL-CE风格: 下划线动画)
    self.indicatorView = [[UIView alloc] init];
    self.indicatorView.backgroundColor = PCLColor(0x1370F3);
    self.indicatorView.layer.cornerRadius = 1.5;
    [self.tabScrollView addSubview:self.indicatorView];
    
    // 内容容器
    self.contentContainer = [[UIView alloc] init];
    self.contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentContainer.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.contentContainer];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.contentContainer.topAnchor constraintEqualToAnchor:self.tabScrollView.bottomAnchor],
        [self.contentContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.contentContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.contentContainer.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)setupChildViewControllers {
    // Tab 0: Minecraft 原版下载
    self.vanillaVC = [[PCLVanillaDownloadViewController alloc] init];
    [self addChildViewController:self.vanillaVC];
    [self.contentContainer addSubview:self.vanillaVC.view];
    self.vanillaVC.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self constrainChildView:self.vanillaVC.view];
    [self.vanillaVC didMoveToParentViewController:self];
    
    // Tab 1: 模组 (Mod)
    self.modVC = [[PCLResourceBrowseViewController alloc] init];
    self.modVC.initialTab = 0; // Mod
    [self addChildViewController:self.modVC];
    [self.contentContainer addSubview:self.modVC.view];
    self.modVC.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self constrainChildView:self.modVC.view];
    [self.modVC didMoveToParentViewController:self];
    self.modVC.view.hidden = YES;
    
    // Tab 2: 整合包 (Modpack)
    self.modpackVC = [[PCLResourceBrowseViewController alloc] init];
    self.modpackVC.initialTab = 1; // Modpack
    [self addChildViewController:self.modpackVC];
    [self.contentContainer addSubview:self.modpackVC.view];
    self.modpackVC.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self constrainChildView:self.modpackVC.view];
    [self.modpackVC didMoveToParentViewController:self];
    self.modpackVC.view.hidden = YES;
    
    // Tab 3: 资源包 (Resource Pack)
    self.resourcePackVC = [[PCLResourceBrowseViewController alloc] init];
    self.resourcePackVC.initialTab = 2; // ResourcePack
    [self addChildViewController:self.resourcePackVC];
    [self.contentContainer addSubview:self.resourcePackVC.view];
    self.resourcePackVC.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self constrainChildView:self.resourcePackVC.view];
    [self.resourcePackVC didMoveToParentViewController:self];
    self.resourcePackVC.view.hidden = YES;
    
    // Tab 4: 光影 (Shader)
    self.shaderVC = [[PCLResourceBrowseViewController alloc] init];
    self.shaderVC.initialTab = 3; // Shader
    [self addChildViewController:self.shaderVC];
    [self.contentContainer addSubview:self.shaderVC.view];
    self.shaderVC.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self constrainChildView:self.shaderVC.view];
    [self.shaderVC didMoveToParentViewController:self];
    self.shaderVC.view.hidden = YES;
    
    // Tab 5: 数据包 (Data Pack)
    self.dataPackVC = [[PCLResourceBrowseViewController alloc] init];
    self.dataPackVC.initialTab = 4; // DataPack
    [self addChildViewController:self.dataPackVC];
    [self.contentContainer addSubview:self.dataPackVC.view];
    self.dataPackVC.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self constrainChildView:self.dataPackVC.view];
    [self.dataPackVC didMoveToParentViewController:self];
    self.dataPackVC.view.hidden = YES;
}

- (void)constrainChildView:(UIView *)childView {
    [NSLayoutConstraint activateConstraints:@[
        [childView.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor],
        [childView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor],
        [childView.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor],
        [childView.bottomAnchor constraintEqualToAnchor:self.contentContainer.bottomAnchor]
    ]];
}

#pragma mark - Tab Switching

- (void)tabTapped:(UIButton *)sender {
    [self switchToTab:sender.tag];
}

- (void)switchToTab:(NSInteger)tab {
    self.selectedTab = tab;
    
    // 更新按钮状态 (PCL-CE风格: 选中项字体加粗+蓝色)
    for (UIButton *btn in self.tabButtons) {
        BOOL isSelected = (btn.tag == tab);
        btn.selected = isSelected;
        btn.titleLabel.font = isSelected ?
            [UIFont systemFontOfSize:14 weight:UIFontWeightBold] :
            [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    }
    
    // 切换子视图控制器显示
    self.vanillaVC.view.hidden = (tab != 0);
    self.modVC.view.hidden = (tab != 1);
    self.modpackVC.view.hidden = (tab != 2);
    self.resourcePackVC.view.hidden = (tab != 3);
    self.shaderVC.view.hidden = (tab != 4);
    self.dataPackVC.view.hidden = (tab != 5);
    
    // 更新指示器位置 (PCL-CE风格: 平滑动画)
    [self updateIndicatorPosition];
}

- (void)updateIndicatorPosition {
    UIButton *selectedBtn = self.tabButtons[self.selectedTab];
    CGRect btnFrame = [self.tabScrollView convertRect:selectedBtn.frame fromView:self.tabStackView];
    
    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.indicatorView.frame = CGRectMake(btnFrame.origin.x + btnFrame.size.width / 2 - 15,
                                             self.tabScrollView.bounds.size.height - 3,
                                             30, 3);
    } completion:nil];
    
    // 滚动标签栏使选中项可见
    CGFloat targetX = selectedBtn.center.x - self.tabScrollView.bounds.size.width / 2;
    targetX = MAX(0, MIN(targetX, self.tabScrollView.contentSize.width - self.tabScrollView.bounds.size.width));
    [self.tabScrollView setContentOffset:CGPointMake(targetX, 0) animated:YES];
}

- (void)dismissTransientUI {
    // 清理临时UI
}

@end
