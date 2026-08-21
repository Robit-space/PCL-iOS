#import "PCLSettingsLeftView.h"
#import "PCLCEPageAnimator.h"
#import <QuartzCore/QuartzCore.h>

static UIColor *PCLColor(NSUInteger rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
                           green:((rgb >> 8) & 255) / 255.0
                            blue:(rgb & 255) / 255.0
                           alpha:1.0];
}

@interface PCLSettingsTabBtn : UIButton
@property (nonatomic) PCLSettingsTab tab;
@end

@implementation PCLSettingsTabBtn
@end

@interface PCLSettingsLeftView ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) NSMutableArray<PCLSettingsTabBtn *> *tabButtons;
@property (nonatomic) PCLSettingsTab selectedTab;
@end

@implementation PCLSettingsLeftView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _tabButtons = [NSMutableArray array];
        _selectedTab = PCLSettingsTabLaunch;
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
    struct { PCLSettingsTab tab; NSString *title; BOOL isHeader; } tabs[] = {
        {999, @"游戏", YES},
        {PCLSettingsTabLaunch, @"启动设置", NO},
        {PCLSettingsTabJava, @"Java", NO},
        {PCLSettingsTabGameManage, @"游戏管理", NO},
        {999, @"工具", YES},
        {PCLSettingsTabGameLink, @"游戏联网", NO},
        {999, @"启动器", YES},
        {PCLSettingsTabUI, @"UI 设置", NO},
        {PCLSettingsTabLanguage, @"语言", NO},
        {PCLSettingsTabMisc, @"杂项", NO},
        {999, @"关于", YES},
        {PCLSettingsTabAbout, @"关于", NO},
        {PCLSettingsTabUpdate, @"更新", NO},
        {PCLSettingsTabFeedback, @"反馈", NO},
        {PCLSettingsTabLog, @"日志", NO},
    };
    
    int count = sizeof(tabs) / sizeof(tabs[0]);
    for (int i = 0; i < count; i++) {
        if (tabs[i].isHeader) {
            UILabel *header = [[UILabel alloc] init];
            header.translatesAutoresizingMaskIntoConstraints = NO;
            header.text = tabs[i].title;
            header.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
            header.textColor = PCLColor(0x8C8C8C);
            
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
        } else {
            PCLSettingsTabBtn *btn = [self createTabButton:tabs[i].tab title:tabs[i].title];
            [self.tabButtons addObject:btn];
            [self.stackView addArrangedSubview:btn];
        }
    }
    
    [self updateTabAppearance];
}

- (PCLSettingsTabBtn *)createTabButton:(PCLSettingsTab)tab title:(NSString *)title {
    PCLSettingsTabBtn *btn = [PCLSettingsTabBtn buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.tab = tab;
    btn.layer.cornerRadius = 8;
    btn.clipsToBounds = YES;
    
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:PCLColor(0x343D4A) forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
    btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    btn.titleEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 0);
    [btn.heightAnchor constraintEqualToConstant:42].active = YES;
    btn.backgroundColor = [UIColor clearColor];
    
    [btn addTarget:self action:@selector(tabPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    return btn;
}

- (void)tabPressed:(PCLSettingsTabBtn *)sender {
    self.selectedTab = sender.tab;
    [self updateTabAppearance];
    if (self.onSelectTab) self.onSelectTab(sender.tab);
}

- (void)updateTabAppearance {
    for (PCLSettingsTabBtn *btn in self.tabButtons) {
        BOOL selected = (btn.tab == self.selectedTab);
        btn.backgroundColor = selected ? PCLColor(0x1370F3) : [UIColor clearColor];
        [btn setTitleColor:selected ? [UIColor whiteColor] : PCLColor(0x343D4A) forState:UIControlStateNormal];
    }
}

- (void)dismissTransientUI {}
- (void)prepareCEEnterAnimation {
    for (UIView *v in self.tabButtons) {
        v.alpha = 0;
        v.transform = CGAffineTransformMakeTranslation(-20, 0);
    }
}
- (void)playCEEnterAnimation { [PCLCEPageAnimator showLeftItems:self.tabButtons]; }
- (void)playCEExitAnimation { [PCLCEPageAnimator hideLeftItems:self.tabButtons]; }
- (void)reloadState {}

@end
