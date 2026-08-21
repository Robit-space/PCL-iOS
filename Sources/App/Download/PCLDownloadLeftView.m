#import "PCLDownloadLeftView.h"
#import "PCLCEPageAnimator.h"
#import <QuartzCore/QuartzCore.h>

static UIColor *PCLColor(NSUInteger rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
                           green:((rgb >> 8) & 255) / 255.0
                            blue:(rgb & 255) / 255.0
                           alpha:1.0];
}

typedef struct {
    PCLDownloadTab tab;
    NSString *title;
    NSString *iconName;
    BOOL isHeader;
} PCLDownloadTabInfo;

@interface PCLDownloadTabButton : UIButton
@property (nonatomic) PCLDownloadTab tab;
@property (nonatomic, copy) NSString *iconName;
@end

@implementation PCLDownloadTabButton
@end

@interface PCLDownloadLeftView () <UIScrollViewDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) NSMutableArray<PCLDownloadTabButton *> *tabButtons;
@property (nonatomic, strong) NSMutableArray<UILabel *> *headerLabels;
@property (nonatomic) PCLDownloadTab selectedTab;
@end

@implementation PCLDownloadLeftView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _tabButtons = [NSMutableArray array];
        _headerLabels = [NSMutableArray array];
        _selectedTab = PCLDownloadTabMinecraft;
        [self setupView];
    }
    return self;
}

- (void)setupView {
    self.backgroundColor = [UIColor clearColor];
    
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.delegate = self;
    self.scrollView.alwaysBounceVertical = YES;
    [self addSubview:self.scrollView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-8]
    ]];
    
    self.stackView = [[UIStackView alloc] init];
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stackView.axis = UILayoutConstraintAxisVertical;
    self.stackView.spacing = 2;
    self.stackView.alignment = UIStackViewAlignmentFill;
    self.stackView.distribution = UIStackViewDistributionFill;
    [self.scrollView addSubview:self.stackView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.stackView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.stackView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.stackView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.stackView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor]
    ]];
    
    [self buildTabs];
}

- (void)buildTabs {
    PCLDownloadTabInfo tabs[] = {
        {PCLDownloadTabMinecraft, @"Minecraft", @"TopBarPlay", NO},
        {999, @"社区资源", @"", YES},
        {PCLDownloadTabMod, @"Mod", @"", NO},
        {PCLDownloadTabModpack, @"整合包", @"", NO},
        {PCLDownloadTabDataPack, @"数据包", @"", NO},
        {PCLDownloadTabResourcePack, @"资源包", @"", NO},
        {PCLDownloadTabShader, @"光影", @"", NO},
        {PCLDownloadTabWorld, @"世界", @"", NO},
        {PCLDownloadTabFavorites, @"收藏", @"", NO},
        {999, @"安装", @"", YES},
        {PCLDownloadTabClientInstall, @"客户端", @"", NO},
        {PCLDownloadTabOptiFine, @"OptiFine", @"", NO},
        {PCLDownloadTabForge, @"Forge", @"", NO},
        {PCLDownloadTabNeoForge, @"NeoForge", @"", NO},
        {PCLDownloadTabFabric, @"Fabric", @"", NO},
        {PCLDownloadTabLiteLoader, @"LiteLoader", @"", NO},
    };
    
    int tabCount = sizeof(tabs) / sizeof(tabs[0]);
    
    for (int i = 0; i < tabCount; i++) {
        PCLDownloadTabInfo info = tabs[i];
        
        if (info.isHeader) {
            UILabel *header = [[UILabel alloc] init];
            header.translatesAutoresizingMaskIntoConstraints = NO;
            header.text = info.title;
            header.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
            header.textColor = PCLColor(0x8C8C8C);
            header.textAlignment = NSTextAlignmentLeft;
            
            UIView *container = [[UIView alloc] init];
            container.translatesAutoresizingMaskIntoConstraints = NO;
            [container addSubview:header];
            
            [NSLayoutConstraint activateConstraints:@[
                [header.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:16],
                [header.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-16],
                [header.topAnchor constraintEqualToAnchor:container.topAnchor constant:12],
                [header.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-4],
                [container.heightAnchor constraintEqualToConstant:32]
            ]];
            
            [self.stackView addArrangedSubview:container];
            [self.headerLabels addObject:header];
        } else {
            PCLDownloadTabButton *btn = [self createTabButtonWithTab:info.tab title:info.title icon:info.iconName];
            [self.tabButtons addObject:btn];
            [self.stackView addArrangedSubview:btn];
        }
    }
    
    [self updateTabAppearance];
}

- (PCLDownloadTabButton *)createTabButtonWithTab:(PCLDownloadTab)tab title:(NSString *)title icon:(NSString *)iconName {
    PCLDownloadTabButton *btn = [PCLDownloadTabButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.tab = tab;
    btn.iconName = iconName;
    
    btn.layer.cornerRadius = 8;
    btn.clipsToBounds = YES;
    
    if (iconName.length > 0) {
        UIImage *icon = [[UIImage imageNamed:iconName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [btn setImage:icon forState:UIControlStateNormal];
        btn.tintColor = PCLColor(0x1370F3);
        btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [btn.imageView.widthAnchor constraintEqualToConstant:18].active = YES;
        [btn.imageView.heightAnchor constraintEqualToConstant:18].active = YES;
        btn.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
        btn.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 8);
    }
    
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:PCLColor(0x343D4A) forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
    btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    btn.titleEdgeInsets = UIEdgeInsetsMake(0, iconName.length > 0 ? 8 : 16, 0, 0);
    
    [btn.heightAnchor constraintEqualToConstant:42].active = YES;
    
    [btn addTarget:self action:@selector(tabButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    btn.backgroundColor = [UIColor clearColor];
    
    return btn;
}

- (void)tabButtonPressed:(PCLDownloadTabButton *)sender {
    self.selectedTab = sender.tab;
    [self updateTabAppearance];
    
    if (self.onSelectTab) {
        self.onSelectTab(sender.tab);
    }
}

- (void)updateTabAppearance {
    for (PCLDownloadTabButton *btn in self.tabButtons) {
        BOOL selected = (btn.tab == self.selectedTab);
        btn.backgroundColor = selected ? PCLColor(0x1370F3) : [UIColor clearColor];
        [btn setTitleColor:selected ? [UIColor whiteColor] : PCLColor(0x343D4A) forState:UIControlStateNormal];
        btn.tintColor = selected ? [UIColor whiteColor] : PCLColor(0x1370F3);
    }
}

- (void)dismissTransientUI {
}

- (void)prepareCEEnterAnimation {
    for (UIView *view in self.tabButtons) {
        view.alpha = 0;
        view.transform = CGAffineTransformMakeTranslation(-20, 0);
    }
    for (UIView *view in self.headerLabels) {
        view.alpha = 0;
    }
}

- (void)playCEEnterAnimation {
    [PCLCEPageAnimator showLeftItems:self.tabButtons];
    for (UIView *view in self.headerLabels) {
        view.alpha = 1;
    }
}

- (void)playCEExitAnimation {
    [PCLCEPageAnimator hideLeftItems:self.tabButtons];
}

- (void)reloadState {
}

@end
