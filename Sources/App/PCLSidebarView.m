#import "PCLSidebarView.h"

@interface PCLSidebarItemView : UIView
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, assign) BOOL isSelected;
@property (nonatomic, copy) void (^onTap)(void);
@end

@implementation PCLSidebarItemView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.layer.cornerRadius = 8.0;
        
        self.iconView = [[UIImageView alloc] init];
        self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
        self.iconView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:self.iconView];
        
        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.titleLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
        [self addSubview:self.titleLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.iconView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [self.iconView.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],
            [self.iconView.widthAnchor constraintEqualToConstant:24],
            [self.iconView.heightAnchor constraintEqualToConstant:24],
            
            [self.titleLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [self.titleLabel.topAnchor constraintEqualToAnchor:self.iconView.bottomAnchor constant:4],
            [self.titleLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-6]
        ]];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)handleTap {
    if (self.onTap) self.onTap();
}

- (void)setIsSelected:(BOOL)isSelected {
    _isSelected = isSelected;
    [self updateAppearance];
}

- (void)updateAppearance {
    UIColor *selectedColor = [UIColor colorWithRed:19.0/255.0 green:112.0/255.0 blue:243.0/255.0 alpha:1.0];
    
    if (self.isSelected) {
        self.backgroundColor = [selectedColor colorWithAlphaComponent:0.12];
        self.titleLabel.textColor = selectedColor;
        self.iconView.tintColor = selectedColor;
    } else {
        self.backgroundColor = [UIColor clearColor];
        self.titleLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
        self.iconView.tintColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    }
}

@end

@interface PCLSidebarView ()
@property (nonatomic, strong) UIView *backgroundView;
@property (nonatomic, strong) UIView *accentLine;
@property (nonatomic, strong) NSMutableArray<PCLSidebarItemView *> *items;
@property (nonatomic, strong) NSArray<NSNumber *> *pageTypes;
@end

@implementation PCLSidebarView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
    }
    return self;
}

- (void)setupView {
    // PCL2-CE风格：白色背景左侧导航栏
    self.backgroundColor = [UIColor whiteColor];
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.08;
    self.layer.shadowRadius = 4;
    self.layer.shadowOffset = CGSizeMake(0, 0);
    
    // 蓝色强调线（左侧边缘）
    self.accentLine = [[UIView alloc] init];
    self.accentLine.backgroundColor = [UIColor colorWithRed:19.0/255.0 green:112.0/255.0 blue:243.0/255.0 alpha:1.0];
    self.accentLine.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.accentLine];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.accentLine.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.accentLine.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.accentLine.widthAnchor constraintEqualToConstant:3],
        [self.accentLine.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];
    
    // 创建导航项
    [self setupItems];
}

- (void)setupItems {
    self.items = [NSMutableArray array];
    
    NSArray *titles = @[@"启动", @"下载", @"设置", @"工具"];
    NSArray *symbols = @[@"gamecontroller", @"arrow.down.circle", @"gearshape", @"wrench"];
    
    UIView *previousView = nil;
    for (NSInteger i = 0; i < titles.count; i++) {
        PCLSidebarItemView *item = [[PCLSidebarItemView alloc] init];
        item.translatesAutoresizingMaskIntoConstraints = NO;
        item.titleLabel.text = titles[i];
        
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
        item.iconView.image = [[UIImage systemImageNamed:symbols[i]] imageByApplyingSymbolConfiguration:config];
        
        __weak typeof(self) weakSelf = self;
        NSInteger page = i;
        item.onTap = ^{
            [weakSelf selectPage:page animated:YES];
            if ([weakSelf.delegate respondsToSelector:@selector(sidebarView:didSelectPage:)]) {
                [weakSelf.delegate sidebarView:weakSelf didSelectPage:page];
            }
        };
        
        [self addSubview:item];
        [self.items addObject:item];
        
        [NSLayoutConstraint activateConstraints:@[
            [item.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
            [item.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [item.heightAnchor constraintEqualToConstant:56],
            [item.widthAnchor constraintEqualToConstant:56]
        ]];
        
        if (previousView) {
            [item.topAnchor constraintEqualToAnchor:previousView.bottomAnchor constant:4].active = YES;
        } else {
            [item.topAnchor constraintEqualToAnchor:self.topAnchor constant:60].active = YES;
        }
        
        previousView = item;
    }
    
    // 默认选中启动页
    [self selectPage:PCLSidebarPageLaunch animated:NO];
}

- (void)selectPage:(PCLSidebarPage)page animated:(BOOL)animated {
    _selectedPage = page;
    
    for (NSInteger i = 0; i < self.items.count; i++) {
        PCLSidebarItemView *item = self.items[i];
        item.isSelected = (i == page);
    }
}

@end
