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
- (void)layoutSubviews {
 [super layoutSubviews];
 CGFloat h=self.bounds.size.height,w=self.bounds.size.width;
 self.imageView.frame=CGRectMake(13,(h-20)/2,20,20);
 self.titleLabel.frame=CGRectMake(44,0,MAX(0,w-79),h);
    [self viewWithTag:702].frame=CGRectMake(-1,(h-20)/2,5,20);
 [self viewWithTag:701].frame=CGRectMake(w-28,(h-14)/2,14,14);
}
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
        [self.scrollView.topAnchor constraintEqualToAnchor:self.topAnchor constant:10],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-8]
    ]];
    
    self.stackView = [[UIStackView alloc] init];
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stackView.axis = UILayoutConstraintAxisVertical;
    self.stackView.spacing = 0;
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
        {PCLDownloadTabMinecraft, @"Minecraft", @"CEDLBoxes", NO},
        {999, @"社区资源", @"", YES},
        {PCLDownloadTabMod, @"Mod", @"CEDLPuzzle", NO},
        {PCLDownloadTabModpack, @"整合包", @"CEDLPackage", NO},
        {PCLDownloadTabDataPack, @"数据包", @"CEDLFileArchive", NO},
        {PCLDownloadTabResourcePack, @"资源包", @"CEDLLayers", NO},
        {PCLDownloadTabShader, @"光影", @"CEDLSparkles", NO},
        {PCLDownloadTabWorld, @"世界", @"CEDLGlobe", NO},
        {PCLDownloadTabFavorites, @"收藏", @"CEDLHeart", NO},
        {999, @"独立安装", @"", YES},
        {PCLDownloadTabClientInstall, @"Minecraft", @"CEDLPackage", NO},
        {PCLDownloadTabOptiFine, @"OptiFine", @"CEDLGauge", NO},
        {PCLDownloadTabForge, @"Forge", @"CEDLAnvil", NO},
        {PCLDownloadTabNeoForge, @"NeoForge", @"CEDLCat", NO},
        {PCLDownloadTabCleanroom, @"Cleanroom", @"CEDLFlaskConical", NO},
        {PCLDownloadTabFabric, @"Fabric", @"CEDLScroll", NO},
        {PCLDownloadTabLegacyFabric, @"Legacy Fabric", @"CEDLScroll", NO},
        {PCLDownloadTabLabyMod, @"LabyMod", @"CEDLBox", NO},
        {PCLDownloadTabLiteLoader, @"LiteLoader", @"CEDLEgg", NO},
    };
    
    int tabCount = sizeof(tabs) / sizeof(tabs[0]);
    
    for (int i = 0; i < tabCount; i++) {
        PCLDownloadTabInfo info = tabs[i];
        
        if (info.isHeader) {
            UILabel *header = [[UILabel alloc] init];
            header.translatesAutoresizingMaskIntoConstraints = NO;
            header.text = info.title;
            header.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
            header.textColor=[PCLColor(0x343D4A) colorWithAlphaComponent:.6];
            header.textAlignment = NSTextAlignmentLeft;
            
            UIView *container = [[UIView alloc] init];
            container.translatesAutoresizingMaskIntoConstraints = NO;
            [container addSubview:header];
            
            [NSLayoutConstraint activateConstraints:@[
                [header.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:13],
                [header.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-5],
                [header.topAnchor constraintEqualToAnchor:container.topAnchor constant:12],
                [header.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-4],
                [container.heightAnchor constraintEqualToConstant:30]
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
    
    btn.layer.cornerRadius = 3;
    btn.clipsToBounds = YES;
    
    if (iconName.length > 0) {
        UIImage *base=[UIImage imageNamed:iconName] ?: [UIImage systemImageNamed:iconName];
        UIImage *icon=[base imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
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
    btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    btn.titleEdgeInsets = UIEdgeInsetsMake(0, iconName.length > 0 ? 8 : 16, 0, 0);
    
    [btn.heightAnchor constraintEqualToConstant:36].active = YES;
    
    [btn addTarget:self action:@selector(tabButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    UIImageView *refresh=[[UIImageView alloc]
      initWithImage:[UIImage imageNamed:@"CEDLRefreshCw"]];
    refresh.tag=701; refresh.tintColor=PCLColor(0x697482);
    refresh.translatesAutoresizingMaskIntoConstraints=NO; refresh.hidden=YES;
    [btn addSubview:refresh];
    [NSLayoutConstraint activateConstraints:@[
      [refresh.trailingAnchor constraintEqualToAnchor:btn.trailingAnchor constant:-13],
      [refresh.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor],
      [refresh.widthAnchor constraintEqualToConstant:14],
      [refresh.heightAnchor constraintEqualToConstant:14]]];

    
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
        btn.backgroundColor = selected ? [PCLColor(0xE0EAFD) colorWithAlphaComponent:.75] : UIColor.clearColor;
        [btn setTitleColor:selected ? PCLColor(0x1370F3) : PCLColor(0x343D4A) forState:UIControlStateNormal];
        btn.tintColor=selected?PCLColor(0x0B5BCB):PCLColor(0x697482);
        [btn viewWithTag:701].hidden=!selected;
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
