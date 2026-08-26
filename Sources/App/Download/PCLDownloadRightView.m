#import "PCLDownloadRightView.h"
#import "PCLCEPageAnimator.h"
#import "PCLNetworkUtils.h"
#import "PCLVersionManager.h"
#import "PCLDownloadManager.h"
#import "PCLModLoaderAPI.h"
#import "PCLProfileStore.h"
#import <QuartzCore/QuartzCore.h>

static UIColor *PCLColor(NSUInteger rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
                           green:((rgb >> 8) & 255) / 255.0
                            blue:(rgb & 255) / 255.0
                           alpha:1.0];
}

@interface PCLDownloadVersionCell : UITableViewCell
@property (nonatomic, strong) UIImageView *versionIcon;
@property (nonatomic, strong) UILabel *versionLabel;
@property (nonatomic, strong) UILabel *typeLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UIButton *downloadButton;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, copy) void (^onDownload)(void);
@property(nonatomic) CGFloat fixedHeight;
@end

@implementation PCLDownloadVersionCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self=[super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.contentView.backgroundColor=[UIColor colorWithRed:251/255.0 green:251/255.0 blue:251/255.0 alpha:210/255.0];
    self.contentView.clipsToBounds=YES;
    self.versionIcon=[[UIImageView alloc] init];
    self.versionIcon.contentMode=UIViewContentModeScaleAspectFit;
    self.versionIcon.translatesAutoresizingMaskIntoConstraints=NO;
    [self.contentView addSubview:self.versionIcon];

    self.versionLabel = [[UILabel alloc] init];
    self.versionLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.versionLabel.textColor = PCLColor(0x343D4A);
    self.versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.versionLabel];

    self.typeLabel = [[UILabel alloc] init];
    self.typeLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    self.typeLabel.textColor = [UIColor whiteColor];
    self.typeLabel.backgroundColor = PCLColor(0x1370F3);
    self.typeLabel.layer.cornerRadius = 3;
    self.typeLabel.clipsToBounds = YES;
    self.typeLabel.textAlignment = NSTextAlignmentCenter;
    self.typeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.typeLabel]; self.typeLabel.hidden=YES;

    self.dateLabel = [[UILabel alloc] init];
    self.dateLabel.font = [UIFont systemFontOfSize:12];
    self.dateLabel.textColor = PCLColor(0x8C8C8C);
    self.dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.dateLabel];

    self.downloadButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.downloadButton setTitle:@"下载" forState:UIControlStateNormal];
    [self.downloadButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.downloadButton.backgroundColor = PCLColor(0x1370F3);
    self.downloadButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.downloadButton.layer.cornerRadius = 6;
    self.downloadButton.clipsToBounds = YES;
    self.downloadButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.downloadButton addTarget:self action:@selector(downloadTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.downloadButton]; self.downloadButton.hidden=YES;

    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressView.progressTintColor = PCLColor(0x1370F3);
    self.progressView.trackTintColor = PCLColor(0xE0EAFD);
    self.progressView.hidden = YES;
    [self.contentView addSubview:self.progressView];


}

- (void)layoutSubviews{[super layoutSubviews];CGFloat w=self.contentView.bounds.size.width,h=self.fixedHeight>0?self.fixedHeight:self.contentView.bounds.size.height;

 CGFloat z=MIN(32,h-8);self.versionIcon.frame=CGRectMake(10,(h-z)/2,z,z);self.versionLabel.frame=CGRectMake(50,2,w-60,20);
 self.dateLabel.frame=CGRectMake(50,h-20,w-60,17);self.progressView.frame=CGRectMake(46,h-2,w-54,2);}



- (void)downloadTapped {
    if (self.onDownload) self.onDownload();
}

@end

@interface PCLDownloadRightView () <UITableViewDelegate, UITableViewDataSource, UIPickerViewDelegate, UIPickerViewDataSource>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *cardStackView;
@property (nonatomic, strong) UIView *filterCard;
@property (nonatomic, strong) UISegmentedControl *typeFilter;
@property (nonatomic, strong) UITableView *versionTableView;
@property (nonatomic, strong) UIPickerView *versionPicker;
@property (nonatomic, strong) UIView *versionPickerContainer;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *allVersions;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *filteredVersions;
@property (nonatomic, strong) NSMutableArray<NSString *> *gameVersions;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *loadingView;
@property(nonatomic,strong) UIView*cePick;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic) PCLDownloadTab currentTab;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *downloadProgress;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *expandedSections;
@property(nonatomic,strong) UIView*ceScrollThumb;
@property(nonatomic) BOOL ceAnimatingSection;
- (NSArray *)versionsForSection:(NSInteger)section;
- (void)updateVersionTableHeight;
- (void)layoutCECards;
- (void)updateCEScrollThumb;
@end

@implementation PCLDownloadRightView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _allVersions = [NSMutableArray array];
        _filteredVersions = [NSMutableArray array];
        _gameVersions = [NSMutableArray array];
        _currentTab = PCLDownloadTabMinecraft;
        _downloadProgress = [NSMutableDictionary dictionary];
        _expandedSections=[NSMutableSet setWithObject:@0];
        _selectedGameVersion = @"1.20.4";
        [_gameVersions addObjectsFromArray:@[@"1.21.4", @"1.21.3", @"1.21.2", @"1.21.1", @"1.21", @"1.20.6", @"1.20.4", @"1.20.2", @"1.20.1", @"1.20", @"1.19.4", @"1.19.2", @"1.18.2", @"1.17.1", @"1.16.5", @"1.12.2"]];
        [self setupView];
    }
    return self;
}

- (CGFloat)ce:(CGFloat)v{CGFloat k=MAX(.82,MIN(1.18,MIN(self.bounds.size.width/650,self.bounds.size.height/650)));return(NSInteger)(v*k+.5);}
- (void)layoutSubviews{[super layoutSubviews];self.versionTableView.rowHeight=[self ce:44];if(!self.ceAnimatingSection)[self updateVersionTableHeight];[self.versionTableView layoutIfNeeded];[self layoutCECards];
[self updateCEScrollThumb];
[self bringSubviewToFront:self.ceScrollThumb];}
- (void)layoutCECards{for(NSInteger i=1;i<5;i++)[self.versionTableView viewWithTag:810+i].hidden=YES;}

- (void)setupView {
    self.backgroundColor = [UIColor clearColor];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator=NO;self.scrollView.indicatorStyle=UIScrollViewIndicatorStyleBlack;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.delaysContentTouches=NO;
    self.scrollView.refreshControl = [[UIRefreshControl alloc] init];
    [self.scrollView.refreshControl addTarget:self action:@selector(refreshData) forControlEvents:UIControlEventValueChanged];
    [self addSubview:self.scrollView];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];

    self.cardStackView = [[UIStackView alloc] init];
    self.cardStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardStackView.axis = UILayoutConstraintAxisVertical;
    self.cardStackView.spacing = 12;
    self.cardStackView.alignment = UIStackViewAlignmentFill;
    self.cardStackView.distribution = UIStackViewDistributionFill;
    [self.scrollView addSubview:self.cardStackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.cardStackView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:[self ce:22]],
        [self.cardStackView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:25],
        [self.cardStackView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-25],
        [self.cardStackView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [self.cardStackView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-50]
    ]];

    [self buildVersionPickerCard];
    [self buildFilterCard];
    [self buildVersionListCard];
    [self buildLoadingView];
}

- (void)buildVersionPickerCard {
    self.versionPickerContainer = [[UIView alloc] init];
    self.versionPickerContainer.backgroundColor = [UIColor whiteColor];
    self.versionPickerContainer.layer.cornerRadius = 10;
    self.versionPickerContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    self.versionPickerContainer.layer.shadowOpacity = 0.06;
    self.versionPickerContainer.layer.shadowRadius = 8;
    self.versionPickerContainer.layer.shadowOffset = CGSizeMake(0, 2);
    self.versionPickerContainer.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *pickerTitle = [[UILabel alloc] init];
    pickerTitle.text = @"游戏版本";
    pickerTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    pickerTitle.textColor = PCLColor(0x343D4A);
    pickerTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [self.versionPickerContainer addSubview:pickerTitle];

    self.versionPicker = [[UIPickerView alloc] init];
    self.versionPicker.translatesAutoresizingMaskIntoConstraints = NO;
    self.versionPicker.delegate = self;
    self.versionPicker.dataSource = self;
    [self.versionPickerContainer addSubview:self.versionPicker];

    [NSLayoutConstraint activateConstraints:@[
        [pickerTitle.topAnchor constraintEqualToAnchor:self.versionPickerContainer.topAnchor constant:12],
        [pickerTitle.leadingAnchor constraintEqualToAnchor:self.versionPickerContainer.leadingAnchor constant:16],
        [pickerTitle.trailingAnchor constraintEqualToAnchor:self.versionPickerContainer.trailingAnchor constant:-16],

        [self.versionPicker.topAnchor constraintEqualToAnchor:pickerTitle.bottomAnchor constant:4],
        [self.versionPicker.leadingAnchor constraintEqualToAnchor:self.versionPickerContainer.leadingAnchor],
        [self.versionPicker.trailingAnchor constraintEqualToAnchor:self.versionPickerContainer.trailingAnchor],
        [self.versionPicker.bottomAnchor constraintEqualToAnchor:self.versionPickerContainer.bottomAnchor],
        [self.versionPicker.heightAnchor constraintEqualToConstant:120]
    ]];

    [self.cardStackView addArrangedSubview:self.versionPickerContainer];
}

#pragma mark - UIPickerView DataSource & Delegate

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return self.gameVersions.count;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return self.gameVersions[row];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    self.selectedGameVersion = self.gameVersions[row];
    [self refreshData];
}

- (void)buildFilterCard {
    self.filterCard = [[UIView alloc] init];
    self.filterCard.backgroundColor = [UIColor whiteColor];
    self.filterCard.layer.cornerRadius = 10;
    self.filterCard.layer.shadowColor = [UIColor blackColor].CGColor;
    self.filterCard.layer.shadowOpacity = 0.06;
    self.filterCard.layer.shadowRadius = 8;
    self.filterCard.layer.shadowOffset = CGSizeMake(0, 2);
    self.filterCard.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *filterTitle = [[UILabel alloc] init];
    filterTitle.text = @"筛选";
    filterTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    filterTitle.textColor = PCLColor(0x343D4A);
    filterTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [self.filterCard addSubview:filterTitle];

    self.typeFilter = [[UISegmentedControl alloc] initWithItems:@[@"全部", @"正式版", @"预览版", @"旧版本"]];
    self.typeFilter.selectedSegmentIndex = 0;
    self.typeFilter.translatesAutoresizingMaskIntoConstraints = NO;
    self.typeFilter.backgroundColor = PCLColor(0xF5F5F5);
    [self.typeFilter addTarget:self action:@selector(filterChanged:) forControlEvents:UIControlEventValueChanged];
    [self.filterCard addSubview:self.typeFilter];

    [NSLayoutConstraint activateConstraints:@[
        [filterTitle.topAnchor constraintEqualToAnchor:self.filterCard.topAnchor constant:16],
        [filterTitle.leadingAnchor constraintEqualToAnchor:self.filterCard.leadingAnchor constant:16],
        [filterTitle.trailingAnchor constraintEqualToAnchor:self.filterCard.trailingAnchor constant:-16],

        [self.typeFilter.topAnchor constraintEqualToAnchor:filterTitle.bottomAnchor constant:12],
        [self.typeFilter.leadingAnchor constraintEqualToAnchor:self.filterCard.leadingAnchor constant:16],
        [self.typeFilter.trailingAnchor constraintEqualToAnchor:self.filterCard.trailingAnchor constant:-16],
        [self.typeFilter.bottomAnchor constraintEqualToAnchor:self.filterCard.bottomAnchor constant:-16],
        [self.typeFilter.heightAnchor constraintEqualToConstant:36]
    ]];

    [self.cardStackView addArrangedSubview:self.filterCard];
}

- (void)buildVersionListCard {
    UIView *listCard = [[UIView alloc] init];
    listCard.backgroundColor = UIColor.clearColor;
    listCard.layer.cornerRadius = 0;
    listCard.layer.shadowColor = [UIColor blackColor].CGColor;
    listCard.layer.shadowOpacity = 0;
    listCard.layer.shadowRadius = 8;
    listCard.layer.shadowOffset = CGSizeMake(0, 2);
    listCard.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *listTitle = [[UILabel alloc] init];
    listTitle.text = @"Minecraft 版本";
    listTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    listTitle.textColor = PCLColor(0x343D4A);
    listTitle.translatesAutoresizingMaskIntoConstraints = NO;
    listTitle.hidden=YES;
    [listCard addSubview:listTitle];

    self.versionTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.versionTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.versionTableView.delegate = self;
    self.versionTableView.dataSource = self;
    self.versionTableView.backgroundColor = [UIColor clearColor];
    self.versionTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.versionTableView.rowHeight = 42;
    self.versionTableView.sectionHeaderHeight=55;if(@available(iOS 15.0,*))self.versionTableView.sectionHeaderTopPadding=0;
    self.versionTableView.estimatedSectionHeaderHeight=0;
    self.versionTableView.estimatedRowHeight=0;
    self.versionTableView.sectionFooterHeight=.01;
    self.versionTableView.scrollEnabled = YES;
    self.versionTableView.delaysContentTouches=NO;
    self.versionTableView.clipsToBounds=YES;
    self.versionTableView.showsVerticalScrollIndicator=NO;
    self.ceScrollThumb=[UIView new];
    self.ceScrollThumb.backgroundColor=
        [PCLColor(0x4890F5) colorWithAlphaComponent:.5];
    self.ceScrollThumb.layer.cornerRadius=2;
    self.ceScrollThumb.hidden=YES;
    self.ceScrollThumb.userInteractionEnabled=NO;
    [self addSubview:self.ceScrollThumb];
    self.versionTableView.allowsSelection = YES;
    [self.versionTableView registerClass:[PCLDownloadVersionCell class] forCellReuseIdentifier:@"VersionCell"];
    [listCard addSubview:self.versionTableView];

    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = @"暂无可用版本";
    self.emptyLabel.font = [UIFont systemFontOfSize:14];
    self.emptyLabel.textColor = PCLColor(0x8C8C8C);
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.hidden = YES;
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [listCard addSubview:self.emptyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [listTitle.topAnchor constraintEqualToAnchor:listCard.topAnchor constant:16],
        [listTitle.leadingAnchor constraintEqualToAnchor:listCard.leadingAnchor constant:16],
        [listTitle.trailingAnchor constraintEqualToAnchor:listCard.trailingAnchor constant:-16],

        [self.versionTableView.topAnchor constraintEqualToAnchor:listCard.topAnchor],
        [self.versionTableView.leadingAnchor constraintEqualToAnchor:listCard.leadingAnchor],
        [self.versionTableView.trailingAnchor constraintEqualToAnchor:listCard.trailingAnchor],
        [self.versionTableView.bottomAnchor constraintEqualToAnchor:listCard.bottomAnchor],
        [self.versionTableView.heightAnchor constraintEqualToConstant:400],

        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:listCard.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:listCard.centerYAnchor],
        [self.emptyLabel.heightAnchor constraintEqualToConstant:44]
    ]];

    [self.cardStackView addArrangedSubview:listCard];
}

- (void)buildLoadingView {
    self.loadingView = [[UIView alloc] init];
    self.loadingView.backgroundColor = UIColor.clearColor;
    self.loadingView.layer.cornerRadius = 10;
    self.loadingView.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingView.hidden = YES;
    [self addSubview:self.loadingView];

    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingIndicator.hidden=YES;
    self.cePick=[UIView new];

    self.cePick.translatesAutoresizingMaskIntoConstraints=NO;

    [self.loadingView addSubview:self.cePick];

    CAShapeLayer*k=[CAShapeLayer layer];

    UIBezierPath*q=[UIBezierPath bezierPath];

    [q moveToPoint:CGPointMake(7,12)];

    [q addCurveToPoint:CGPointMake(43,9)

     controlPoint1:CGPointMake(18,3)

     controlPoint2:CGPointMake(34,3)];

    [q moveToPoint:CGPointMake(29,9)];
    [q addLineToPoint:CGPointMake(48,40)];

    k.path=q.CGPath;

    k.strokeColor=PCLColor(0x4890F5).CGColor;

    k.fillColor=UIColor.clearColor.CGColor;

    k.lineWidth=3;

    k.lineCap=kCALineCapRound;

    k.bounds=CGRectMake(0,0,54,46);

    k.position=CGPointMake(31,25);

    k.anchorPoint=CGPointMake(.76,.8);

    k.transform=CATransform3DMakeRotation(.96,0,0,1);

    [self.cePick.layer addSublayer:k];

    UILabel *loadingLabel = [[UILabel alloc] init];
    loadingLabel.text = @"正在加载版本列表...";
    loadingLabel.font = [UIFont systemFontOfSize:14];
    loadingLabel.textColor = PCLColor(0x8C8C8C);
    loadingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.loadingView addSubview:loadingLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.loadingView.topAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.loadingView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [self.loadingView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [self.loadingView.heightAnchor constraintEqualToConstant:120],

        [self.cePick.centerXAnchor constraintEqualToAnchor:self.loadingView.centerXAnchor],
        [self.cePick.centerYAnchor constraintEqualToAnchor:self.loadingView.centerYAnchor constant:-14],

        [loadingLabel.centerYAnchor constraintEqualToAnchor:self.loadingView.centerYAnchor],
        [loadingLabel.leadingAnchor constraintEqualToAnchor:self.cePick.trailingAnchor constant:8]
    ]];
}

- (void)startCELoading{
 self.loadingView.hidden=NO;
 [self bringSubviewToFront:self.loadingView];

 CAKeyframeAnimation*a=[CAKeyframeAnimation
  animationWithKeyPath:@"transform.rotation.z"];
 a.values=@[@(.96),@(-.35),@(.52),
  @(1.1),@(.86),@(.96)];
 a.keyTimes=@[@0,@.2,@.62,@.73,@.86,@1];
 a.duration=1.8;
 a.repeatCount=HUGE_VALF;
 a.calculationMode=kCAAnimationCubic;

 [self.cePick.layer.sublayers.firstObject
  addAnimation:a forKey:@"pick"];
}
- (void)stopCELoading{
 [self.cePick.layer.sublayers.firstObject
  removeAllAnimations];
 self.loadingView.hidden=YES;
}

- (void)switchToTab:(PCLDownloadTab)tab {
    self.currentTab = tab;
    BOOL minecraft=tab==PCLDownloadTabMinecraft||
        tab==PCLDownloadTabClientInstall;
    self.versionPickerContainer.hidden=minecraft;
    self.filterCard.hidden=YES;

    NSString *titles[] = {
        @"Minecraft", @"Mod", @"整合包", @"数据包", @"资源包", @"光影", @"世界", @"收藏",
        @"客户端安装", @"OptiFine", @"Forge", @"NeoForge", @"Fabric", @"LiteLoader"
    };

    NSInteger index = (NSInteger)tab;
    if (index >= 0 && index < 14) {
        [self setTitle:titles[index]];
    }

    [self refreshData];
}

- (void)setTitle:(NSString *)title {
    UILabel *titleLabel = nil;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            if (label.font.pointSize == 20) {
                titleLabel = label;
                break;
            }
        }
    }
    if (!titleLabel) return;
    titleLabel.text = title;
}

- (void)refreshData {
    if (self.currentTab == PCLDownloadTabMinecraft || self.currentTab == PCLDownloadTabClientInstall) {
        [self loadMinecraftVersions];
    } else {
        [self loadModLoaderVersions];
    }
}

- (void)loadMinecraftVersions {
    [self startCELoading];
    self.emptyLabel.hidden = YES;

    [[PCLVersionManager sharedManager] fetchRemoteManifest:^(NSArray<NSDictionary *> *versions, NSError *error) {
        [self stopCELoading];
        [self.scrollView.refreshControl endRefreshing];

        if (error) {
            NSLog(@"[Download] Failed to fetch manifest: %@", error);
            return;
        }

        [self.allVersions removeAllObjects];
        [self.allVersions addObjectsFromArray:versions];
        [self applyFilter];
    }];
}

- (void)loadModLoaderVersions {
    [self.allVersions removeAllObjects];

    if (self.currentTab == PCLDownloadTabForge) {
        [self loadForgeVersions];
    } else if (self.currentTab == PCLDownloadTabFabric) {
        [self loadFabricVersions];
    } else if (self.currentTab == PCLDownloadTabNeoForge) {
        [self loadNeoForgeVersions];
    } else if (self.currentTab == PCLDownloadTabOptiFine) {
        [self loadOptiFineVersions];
    } else if (self.currentTab == PCLDownloadTabLiteLoader) {
        [self loadLiteLoaderVersions];
    } else {
        [self.filteredVersions removeAllObjects];
        [self.versionTableView reloadData];
        self.emptyLabel.hidden = NO;
        self.emptyLabel.text = @"该功能正在开发中";
    }
}

- (void)loadForgeVersions {
    [self startCELoading];

    [[PCLModLoaderAPI sharedAPI] fetchForgeVersions:self.selectedGameVersion completion:^(NSArray *versions, NSError *error) {
        [self stopCELoading];
        [self.scrollView.refreshControl endRefreshing];

        if (error) {
            NSLog(@"[Download] Forge error: %@", error);
        }
        if (versions.count > 0) {
            [self.allVersions removeAllObjects];
            for (id v in versions) {
                if ([v isKindOfClass:[NSDictionary class]]) {
                    [self.allVersions addObject:v];
                } else {
                    NSString *ver = [v valueForKey:@"version"];
                    if (ver) {
                        [self.allVersions addObject:@{@"version": ver, @"type": @"forge", @"mcVersion": self.selectedGameVersion}];
                    }
                }
            }
            [self applyFilter];
        } else {
            [self.filteredVersions removeAllObjects];
            [self.versionTableView reloadData];
            self.emptyLabel.hidden = NO;
            self.emptyLabel.text = [NSString stringWithFormat:@"没有适用于 %@ 的Forge版本", self.selectedGameVersion];
        }
    }];
}

- (void)loadFabricVersions {
    [self startCELoading];

    [[PCLModLoaderAPI sharedAPI] fetchFabricVersions:self.selectedGameVersion completion:^(NSArray *versions, NSError *error) {
        [self stopCELoading];
        [self.scrollView.refreshControl endRefreshing];

        [self.allVersions removeAllObjects];

        if (error) {
            NSLog(@"[Download] Fabric error: %@", error);
        }

        if (versions.count > 0) {
            for (id v in versions) {
                NSString *ver = [v valueForKey:@"version"];
                if (ver) {
                    NSMutableDictionary *info = [@{@"version": ver, @"type": @"fabric", @"url": [v valueForKey:@"url"] ?: @""} mutableCopy];
                    [self.allVersions addObject:info];
                }
            }
        }

        [self applyFilter];
    }];
}

- (void)loadNeoForgeVersions {
    [self startCELoading];

    [[PCLModLoaderAPI sharedAPI] fetchNeoForgeVersions:self.selectedGameVersion completion:^(NSArray *versions, NSError *error) {
        [self stopCELoading];
        [self.scrollView.refreshControl endRefreshing];

        [self.allVersions removeAllObjects];

        if (error) {
            NSLog(@"[Download] NeoForge error: %@", error);
        }

        if (versions.count > 0) {
            for (id v in versions) {
                NSString *ver = [v valueForKey:@"version"];
                if (ver) {
                    [self.allVersions addObject:@{@"version": ver, @"type": @"neoforge", @"mcVersion": self.selectedGameVersion}];
                }
            }
        }

        [self applyFilter];
    }];
}

- (void)loadOptiFineVersions {
    [self startCELoading];

    [[PCLModLoaderAPI sharedAPI] fetchOptiFineVersions:^(NSArray<NSDictionary *> *versions, NSError *error) {
        [self stopCELoading];
        [self.scrollView.refreshControl endRefreshing];

        [self.allVersions removeAllObjects];

        if (error) {
            NSLog(@"[Download] OptiFine error: %@", error);
        }

        if (versions.count > 0) {
            [self.allVersions addObjectsFromArray:versions];
        }

        [self applyFilter];
    }];
}

- (void)loadLiteLoaderVersions {
    [self startCELoading];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self stopCELoading];
        [self.scrollView.refreshControl endRefreshing];

        [self.allVersions removeAllObjects];

        // LiteLoader仅支持1.12.2及以下版本
        if ([self.selectedGameVersion hasPrefix:@"1.12"] || [self.selectedGameVersion hasPrefix:@"1.11"] || [self.selectedGameVersion hasPrefix:@"1.10"] || [self.selectedGameVersion hasPrefix:@"1.9"] || [self.selectedGameVersion hasPrefix:@"1.8"] || [self.selectedGameVersion hasPrefix:@"1.7"] || [self.selectedGameVersion hasPrefix:@"1.6"]) {
            [self.allVersions addObjectsFromArray:@[
                @{@"version": @"1.12.2", @"type": @"liteloader", @"mcVersion": @"1.12.2"},
                @{@"version": @"1.11.2", @"type": @"liteloader", @"mcVersion": @"1.11.2"},
                @{@"version": @"1.10.2", @"type": @"liteloader", @"mcVersion": @"1.10.2"},
                @{@"version": @"1.9.4", @"type": @"liteloader", @"mcVersion": @"1.9.4"},
                @{@"version": @"1.8.9", @"type": @"liteloader", @"mcVersion": @"1.8.9"},
                @{@"version": @"1.7.10", @"type": @"liteloader", @"mcVersion": @"1.7.10"},
                @{@"version": @"1.6.4", @"type": @"liteloader", @"mcVersion": @"1.6.4"},
            ]];
            self.emptyLabel.hidden = YES;
        } else {
            [self.filteredVersions removeAllObjects];
            [self.versionTableView reloadData];
            self.emptyLabel.hidden = NO;
            self.emptyLabel.text = @"LiteLoader仅支持1.12.2及以下版本";
        }

        [self applyFilter];
    });
}

- (void)loadFabricAPIVersions {
    [self startCELoading];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self stopCELoading];

        [self.allVersions removeAllObjects];
        [self.allVersions addObjectsFromArray:@[
            @{@"version": @"0.92.2+b7a3c0ef4f", @"type": @"fabric-api", @"mcVersion": self.selectedGameVersion},
            @{@"version": @"0.92.1+b7a3c0ef4f", @"type": @"fabric-api", @"mcVersion": self.selectedGameVersion},
            @{@"version": @"0.92.0+b7a3c0ef4f", @"type": @"fabric-api", @"mcVersion": self.selectedGameVersion},
        ]];

        [self applyFilter];
    });
}

- (void)filterChanged:(UISegmentedControl *)sender {
    [self applyFilter];
}

- (void)applyFilter {
    NSInteger filterIndex = self.typeFilter.selectedSegmentIndex;

    [self.filteredVersions removeAllObjects];

    for (NSDictionary *version in self.allVersions) {
        NSString *type = version[@"type"] ?: @"";

        BOOL shouldInclude = NO;
        switch (filterIndex) {
            case 0: shouldInclude = YES; break;
            case 1: shouldInclude = [type isEqualToString:@"release"]; break;
            case 2: shouldInclude = [type isEqualToString:@"snapshot"]; break;
            case 3: shouldInclude = [type isEqualToString:@"old_alpha"] || [type isEqualToString:@"old_beta"]; break;
        }

        if (shouldInclude) {
            [self.filteredVersions addObject:version];
        }
    }

    self.emptyLabel.hidden = (self.filteredVersions.count > 0);
    if (self.filteredVersions.count == 0) {
        self.emptyLabel.text = @"没有符合条件的版本";
    }

    [self.versionTableView reloadData];

    [self updateVersionTableHeight];
}
- (void)updateVersionTableHeight{NSInteger n=[self numberOfSectionsInTableView:self.versionTableView];CGFloat h=0;if(n==1)h=[self ce:self.filteredVersions.count*64];else{h=[self ce:92+MIN(2,[self versionsForSection:0].count)*44];for(NSInteger i=1;i<n;i++)h+=[self ce:44+([self.expandedSections containsObject:@(i)]?[self versionsForSection:i].count*44+34:19)];}CGFloat m=MAX([self ce:300],self.bounds.size.height-[self ce:22]);BOOL x=h>m;self.versionTableView.scrollEnabled=x;self.scrollView.scrollEnabled=!x;h=MIN(h,m);for(NSLayoutConstraint*c in self.versionTableView.constraints)if(c.firstAttribute==NSLayoutAttributeHeight){c.constant=MAX(1,h);break;}}

- (void)updateCEScrollThumb{
 UIScrollView*v=self.versionTableView;
 CGFloat h=v.contentSize.height;
 CGFloat w=v.bounds.size.height;
 BOOL show=v.scrollEnabled&&h>w+1;
 self.ceScrollThumb.hidden=!show;
 if(!show)return;
 CGRect f=[v.superview convertRect:v.frame
                            toView:self];
 CGFloat t=MAX(1,f.size.height-8);
 CGFloat q=MAX(32,t*w/h);
 CGFloat m=MAX(1,h-w);
 CGFloat o=MIN(MAX(v.contentOffset.y,0),m);
 CGFloat y=f.origin.y+4+(t-q)*o/m;
 self.ceScrollThumb.frame=
  CGRectMake(self.bounds.size.width-6,y,4,q);
}

- (void)scrollViewDidScroll:(UIScrollView*)v{
 if(v==self.versionTableView)
  [self updateCEScrollThumb];
}

#pragma mark - UITableViewDataSource

- (NSArray*)versionsForSection:(NSInteger)n{if(self.currentTab!=PCLDownloadTabMinecraft&&self.currentTab!=PCLDownloadTabClientInstall)return self.filteredVersions;NSMutableArray*r=[NSMutableArray array],*q=[NSMutableArray array],*o=[NSMutableArray array],*f=[NSMutableArray array];NSArray*ids=@[@"2point0_blue",@"2point0_red",@"2point0_purple",@"2.0_blue",@"2.0_red",@"2.0_purple",@"2.0",@"20w14infinite",@"20w14∞",@"3d shareware v1.34",@"1.rv-pre1",@"15w14a",@"22w13oneblockatatime",@"23w13a_or_b",@"24w14potato",@"25w14craftmine",@"26w14a"];for(NSDictionary*v in self.filteredVersions){NSString*t=[v[@"type"]?:@"" lowercaseString],*i=[v[@"id"]?:@"" lowercaseString],*d=v[@"releaseTime"]?:@"";BOOL fool=[t isEqualToString:@"special"]||[ids containsObject:i]||([d containsString:@"-04-01"]&&![t isEqualToString:@"release"]);if(fool)[f addObject:v];else if([t isEqualToString:@"release"])[r addObject:v];else if([t isEqualToString:@"snapshot"]||[t isEqualToString:@"pending"])[q addObject:v];else[o addObject:v];}if(!n){NSMutableArray*a=[NSMutableArray array];if(r.count)[a addObject:r[0]];if(q.count&&(!r.count||[q[0][@"releaseTime"]compare:r[0][@"releaseTime"]]>=0))[a addObject:q[0]];return a;}return(@[r,q,o,f])[n-1];}

- (NSInteger)numberOfSectionsInTableView:(UITableView*)t{

 return self.currentTab==PCLDownloadTabMinecraft||self.currentTab==PCLDownloadTabClientInstall?5:1;

}

- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s {

    if([self numberOfSectionsInTableView:t]==1)return nil;

    return @[@"最新版本",@"正式版",@"预览版",@"远古版",@"愚人节版"][s];

}

- (UIView*)latestHeader:(CGFloat)w{
 NSArray*a=[self versionsForSection:0];CGFloat h=[self ce:62+MIN(2,a.count)*44];UIView*wra=[[UIView alloc]initWithFrame:CGRectMake(0,0,w,h+[self ce:15])];wra.tag=820;UIView*c=[[UIView alloc]initWithFrame:CGRectMake(0,0,w,h)];c.backgroundColor=[UIColor colorWithWhite:.995 alpha:.94];c.layer.cornerRadius=[self ce:11];[wra addSubview:c];
 UIButton*l=[[UIButton alloc]initWithFrame:CGRectMake(12,0,w-24,[self ce:40])];[l setTitle:@"最新版本" forState:0];[l setTitleColor:PCLColor(0x343D4A) forState:0];l.titleLabel.font=[UIFont systemFontOfSize:16 weight:UIFontWeightBold];l.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;[l addGestureRecognizer:[[UIHoverGestureRecognizer alloc]initWithTarget:self action:@selector(latestTitleHover:)]];[c addSubview:l];
 for(NSInteger i=0;i<MIN(2,a.count);i++){NSDictionary*d=a[i];NSString*y=d[@"type"]?:@"",*z=d[@"releaseTime"]?:@"";PCLDownloadVersionCell*r=[[PCLDownloadVersionCell alloc]initWithStyle:0 reuseIdentifier:nil];r.frame=CGRectMake(20,[self ce:49+i*44],w-38,[self ce:44]);r.fixedHeight=[self ce:44];r.tag=i;r.contentView.backgroundColor=UIColor.clearColor;r.versionIcon.image=[UIImage imageNamed:[y isEqualToString:@"release"]?@"CEGrass":@"CECommandBlock"];r.versionIcon.transform=CGAffineTransformMakeScale(1.24,1.24);r.versionLabel.transform=CGAffineTransformMakeTranslation(0,5);r.versionLabel.font=[UIFont systemFontOfSize:16 weight:UIFontWeightMedium];r.dateLabel.font=[UIFont systemFontOfSize:14];r.versionLabel.text=d[@"id"]?:@"";NSString*day=z.length>10?[z substringToIndex:10]:z;r.dateLabel.text=[NSString stringWithFormat:@"%@，发布于 %@",[y isEqualToString:@"release"]?@"最新正式版":@"最新预览版",day];[r addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(latestTapped:)]];[c addSubview:r];[r setNeedsLayout];[r layoutIfNeeded];}return wra;
}

- (UIView*)categoryHeader:(NSInteger)n width:(CGFloat)w{
 UIView*v=[[UIView alloc]initWithFrame:CGRectMake(0,0,w,[self ce:44])];v.tag=820+n;v.backgroundColor=UIColor.whiteColor;v.layer.cornerRadius=[self ce:11];v.clipsToBounds=YES;v.backgroundColor=[UIColor colorWithWhite:.995 alpha:.94];v.layer.cornerRadius=[self ce:11];v.clipsToBounds=YES;NSArray*a=@[@"最新版本",@"正式版",@"预览版",@"远古版",@"愚人节版"];UILabel*l=[[UILabel alloc]initWithFrame:CGRectMake(16,0,w-64,v.bounds.size.height)];l.text=[NSString stringWithFormat:@"%@ (%ld)",a[n],(long)[self versionsForSection:n].count];l.font=[UIFont systemFontOfSize:16 weight:UIFontWeightBold];l.textColor=PCLColor(0x343D4A);[v addSubview:l];
 UIButton*q=[[UIButton alloc]initWithFrame:v.bounds];q.tag=n;BOOL o=[self.expandedSections containsObject:@(n)];v.layer.maskedCorners=o?3:15;[q setImage:[UIImage systemImageNamed:@"chevron.down"] forState:0];q.imageView.preferredSymbolConfiguration=[UIImageSymbolConfiguration configurationWithPointSize:9 weight:UIImageSymbolWeightBold];q.imageView.transform=o?CGAffineTransformMakeRotation(3.14159):CGAffineTransformIdentity;q.tintColor=PCLColor(0x505A66);q.contentHorizontalAlignment=UIControlContentHorizontalAlignmentRight;q.contentEdgeInsets=UIEdgeInsetsMake(0,0,0,16);[q addTarget:self action:@selector(toggleVersionSection:) forControlEvents:UIControlEventTouchUpInside];[v addSubview:q];return v;
}
- (CGFloat)tableView:(UITableView*)t heightForHeaderInSection:(NSInteger)n{return [self numberOfSectionsInTableView:t]>1?[self ce:n?44:77+MIN(2,[self versionsForSection:0].count)*44]:.01;}
- (UIView*)tableView:(UITableView*)t viewForHeaderInSection:(NSInteger)n{if([self numberOfSectionsInTableView:t]==1)return nil;return n?[self categoryHeader:n width:t.bounds.size.width]:[self latestHeader:t.bounds.size.width];}
- (CGFloat)tableView:(UITableView*)t heightForFooterInSection:(NSInteger)n{return [self numberOfSectionsInTableView:t]>1?(n?[self.expandedSections containsObject:@(n)]?[self ce:34]:[self ce:19]:[self ce:15]):.01;}
- (UIView*)tableView:(UITableView*)t viewForFooterInSection:(NSInteger)n{UIView*v=[UIView new];if(!n||![self.expandedSections containsObject:@(n)])return v;UIView*f=[[UIView alloc]initWithFrame:CGRectMake(0,0,t.bounds.size.width,[self ce:15])];f.backgroundColor=[UIColor colorWithWhite:.995 alpha:.9];f.layer.cornerRadius=[self ce:11];f.layer.maskedCorners=kCALayerMinXMaxYCorner|kCALayerMaxXMaxYCorner;[v addSubview:f];return v;}

- (void)toggleVersionSection:(UIButton*)b{
 if(self.ceAnimatingSection)return;
 NSInteger n=b.tag;
 NSNumber*k=@(n);
 BOOL open=![self.expandedSections containsObject:k];
 NSArray*v=[self versionsForSection:n];
 NSMutableArray*p=[NSMutableArray array];
 for(NSInteger i=0;i<v.count;i++)
  [p addObject:[NSIndexPath
   indexPathForRow:i inSection:n]];
 [self layoutIfNeeded];
 self.ceAnimatingSection=YES;
 NSUInteger z=UIViewAnimationOptionCurveEaseInOut|
  UIViewAnimationOptionBeginFromCurrentState|
  UIViewAnimationOptionAllowUserInteraction;

 for(PCLDownloadVersionCell*c in self.versionTableView.visibleCells){
  NSIndexPath*p=[self.versionTableView indexPathForCell:c];
  if(p.section==n){
   [c.layer removeAllAnimations];
   c.transform=CGAffineTransformIdentity;
   c.contentView.transform=CGAffineTransformIdentity;
  }
 }
 if(open)b.superview.layer.maskedCorners=3;
 [self.versionTableView performBatchUpdates:^{
  if(open)[self.expandedSections addObject:k];
  else [self.expandedSections removeObject:k];

  if(open)[self.versionTableView
   insertRowsAtIndexPaths:p
   withRowAnimation:UITableViewRowAnimationFade];
  else [self.versionTableView
   deleteRowsAtIndexPaths:p
   withRowAnimation:UITableViewRowAnimationFade];
 } completion:nil];
 [UIView animateWithDuration:.24 delay:0 options:z animations:^{
  b.imageView.transform=open?
   CGAffineTransformMakeRotation(3.14159):
   CGAffineTransformIdentity;
  [self layoutIfNeeded];[self updateCEScrollThumb];
 } completion:^(BOOL done){
  self.ceAnimatingSection=NO;
  [self updateVersionTableHeight];[self updateCEScrollThumb];
 }];
}

- (void)latestTapped:(UITapGestureRecognizer*)g{NSArray*a=[self versionsForSection:0];if(g.view.tag>=a.count)return;NSDictionary*v=a[g.view.tag];[self downloadVersion:v[@"id"]?:@"" url:v[@"url"]?:v[@"downloadURL"]?:v[@"jar"]?:@"" type:v[@"type"]?:@""];}

- (void)latestTitleHover:(UIHoverGestureRecognizer*)g{UIButton*b=(UIButton*)g.view;BOOL on=g.state==UIGestureRecognizerStateBegan||g.state==UIGestureRecognizerStateChanged;[b setTitleColor:PCLColor(on?0x1370F3:0x343D4A) forState:0];}

- (CGFloat)tableView:(UITableView*)t heightForRowAtIndexPath:(NSIndexPath*)p{if([self numberOfSectionsInTableView:t]>1&&p.section&&![self.expandedSections containsObject:@(p.section)])return CGFLOAT_MIN;return [self ce:(p.section?44:64)];}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if([self numberOfSectionsInTableView:tableView]>1&&section==0)return 0;
    if(section&&![self.expandedSections containsObject:@(section)])return 0;
    return [self versionsForSection:section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PCLDownloadVersionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"VersionCell" forIndexPath:indexPath];
    cell.fixedHeight=[self ce:(indexPath.section?44:64)];
    [cell.layer removeAllAnimations];
    [cell.contentView.layer removeAllAnimations];
    cell.transform=CGAffineTransformIdentity;
    cell.contentView.transform=CGAffineTransformIdentity;
    cell.contentView.alpha=1;
    cell.contentView.layer.cornerRadius=0;
    cell.contentView.layer.maskedCorners=0;

    NSArray*rows=
        [self versionsForSection:indexPath.section];
    if(indexPath.row>=rows.count)return cell;
    NSDictionary*version=rows[indexPath.row];
    NSString *versionId = version[@"id"] ?: version[@"version"] ?: @"";
    NSString *type = version[@"type"] ?: @"";
    NSString *releaseTime = version[@"releaseTime"] ?: @"";

    cell.textLabel.hidden=YES;cell.detailTextLabel.hidden=YES;cell.imageView.hidden=YES;

    cell.versionIcon.hidden=NO;cell.versionLabel.hidden=NO;cell.dateLabel.hidden=NO;

    cell.versionLabel.text=versionId;

    NSString*icon=@"CEGoldBlock";
    if([type isEqualToString:@"release"])
        icon=@"CEGrass";
    else if([type isEqualToString:@"snapshot"]||
            [type isEqualToString:@"pending"])
        icon=@"CECommandBlock";
    else if([type hasPrefix:@"old_"])
        icon=@"CECobbleStone";
    cell.versionIcon.image=[UIImage imageNamed:icon];
    cell.versionIcon.transform=
        CGAffineTransformIdentity;
    cell.versionLabel.transform=
        CGAffineTransformIdentity;
    cell.dateLabel.transform=
        CGAffineTransformIdentity;

    BOOL last=indexPath.row+1==[tableView numberOfRowsInSection:indexPath.section];

    cell.contentView.backgroundColor=[self numberOfSectionsInTableView:tableView]>1?[UIColor colorWithWhite:.995 alpha:.94]:[UIColor colorWithWhite:.995 alpha:.9];cell.contentView.layer.cornerRadius=0;




    if ([type isEqualToString:@"release"]) {
        cell.typeLabel.text = @"正式版";
        cell.typeLabel.backgroundColor = PCLColor(0x1370F3);
    } else if ([type isEqualToString:@"snapshot"]) {
        cell.typeLabel.text = @"快照";
        cell.typeLabel.backgroundColor = PCLColor(0xF39C12);
    } else if ([type isEqualToString:@"old_alpha"]) {
        cell.typeLabel.text = @"Alpha";
        cell.typeLabel.backgroundColor = PCLColor(0x8C8C8C);
    } else if ([type isEqualToString:@"old_beta"]) {
        cell.typeLabel.text = @"Beta";
        cell.typeLabel.backgroundColor = PCLColor(0x8C8C8C);
    } else if ([type isEqualToString:@"forge"]) {
        cell.typeLabel.text = @"Forge";
        cell.typeLabel.backgroundColor = PCLColor(0xE67E22);
    } else if ([type isEqualToString:@"fabric"]) {
        cell.typeLabel.text = @"Fabric";
        cell.typeLabel.backgroundColor = PCLColor(0x9B59B6);
    } else if ([type isEqualToString:@"neoforge"]) {
        cell.typeLabel.text = @"NeoForge";
        cell.typeLabel.backgroundColor = PCLColor(0xE74C3C);
    } else if ([type isEqualToString:@"optifine"]) {
        cell.typeLabel.text = @"OptiFine";
        cell.typeLabel.backgroundColor = PCLColor(0x27AE60);
    } else if ([type isEqualToString:@"liteloader"]) {
        cell.typeLabel.text = @"LiteLoader";
        cell.typeLabel.backgroundColor = PCLColor(0x3498DB);
    } else if ([type isEqualToString:@"fabric-api"]) {
        cell.typeLabel.text = @"Fabric API";
        cell.typeLabel.backgroundColor = PCLColor(0x9B59B6);
    } else {
        cell.typeLabel.text = type;
        cell.typeLabel.backgroundColor = PCLColor(0x8C8C8C);
    }

    if (releaseTime.length > 10) {
        NSUInteger n=MIN((NSUInteger)16,releaseTime.length);
        NSString*d=[releaseTime substringToIndex:n];
        d=[d stringByReplacingOccurrencesOfString:@"T"
          withString:@" "];cell.dateLabel.text=indexPath.section?d:[NSString stringWithFormat:@"%@，发布于 %@",[type isEqualToString:@"release"]?@"最新正式版":@"最新预览版",d];
    } else {
        cell.dateLabel.text = releaseTime;
    }

    NSString *urlString = version[@"url"] ?: version[@"downloadURL"] ?: version[@"jar"] ?: @"";

    // 检查是否正在下载
    BOOL isDownloading = (self.downloadProgress[versionId] != nil);
    double progress = [self.downloadProgress[versionId] doubleValue];

    if (isDownloading) {
        cell.progressView.hidden = NO;
        cell.progressView.progress = progress;
        [cell.downloadButton setTitle:@"取消" forState:UIControlStateNormal];
    } else {
        cell.progressView.hidden = YES;
        [cell.downloadButton setTitle:@"下载" forState:UIControlStateNormal];
    }

    cell.onDownload = ^{
        if (isDownloading) {
            // 取消下载
            [self.downloadProgress removeObjectForKey:versionId];
            [self.versionTableView reloadData];
        } else {
            [self downloadVersion:versionId url:urlString type:type];
        }
    };

    return cell;
}
- (void)tableView:(UITableView*)t didSelectRowAtIndexPath:(NSIndexPath*)p{PCLDownloadVersionCell*c=[t cellForRowAtIndexPath:p];if(c.onDownload)c.onDownload();}

- (void)downloadVersion:(NSString *)versionId url:(NSString *)urlString type:(NSString *)type {
    if (urlString.length == 0) {
        NSLog(@"[Download] No URL for version %@", versionId);
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法下载" message:[NSString stringWithFormat:@"%@ %@ 暂无下载地址", type, versionId] preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        [rootVC presentViewController:alert animated:YES completion:nil];
        return;
    }

    NSString *displayName = [NSString stringWithFormat:@"%@ %@", type, versionId];
    self.downloadProgress[versionId] = @(0.0);
    [self.versionTableView reloadData];

    // 使用PCLDownloadManager下载
    PCLDownloadTask *task = [[PCLDownloadTask alloc] init];
    task.url = urlString;
    task.targetPath = [self targetPathForLoader:versionId type:type];
    task.displayName = displayName;
    task.resourceType = [self resourceTypeForType:type];

    __weak typeof(self) weakSelf = self;
    [[PCLDownloadManager sharedManager] addTask:task];
    [[PCLDownloadManager sharedManager] startDownload:task progress:^(double progress, NSString *status) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.downloadProgress[versionId] = @(progress);
        [self updateCellProgress:versionId progress:progress status:status];
    } completion:^(BOOL success, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self.downloadProgress removeObjectForKey:versionId];
        [self.versionTableView reloadData];

        NSString *title = success ? @"下载完成" : @"下载失败";
        NSString *msg = success ? [NSString stringWithFormat:@"%@ 安装成功", displayName] : error.localizedDescription;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        [rootVC presentViewController:alert animated:YES completion:nil];
    }];
}

- (NSString *)targetPathForLoader:(NSString *)versionId type:(NSString *)type {
    NSString *versionsDir = [[PCLVersionManager sharedManager] versionsDirectory];
    NSString *versionDir = [versionsDir stringByAppendingPathComponent:versionId];

    if ([type isEqualToString:@"forge"]) {
        return [versionDir stringByAppendingPathComponent:[NSString stringWithFormat:@"forge-%@.jar", versionId]];
    } else if ([type isEqualToString:@"fabric"]) {
        return [versionDir stringByAppendingPathComponent:[NSString stringWithFormat:@"fabric-loader-%@.jar", versionId]];
    } else if ([type isEqualToString:@"neoforge"]) {
        return [versionDir stringByAppendingPathComponent:[NSString stringWithFormat:@"neoforge-%@.jar", versionId]];
    } else if ([type isEqualToString:@"optifine"]) {
        return [versionDir stringByAppendingPathComponent:[NSString stringWithFormat:@"OptiFine_%@.jar", versionId]];
    } else if ([type isEqualToString:@"liteloader"]) {
        return [versionDir stringByAppendingPathComponent:[NSString stringWithFormat:@"liteloader-%@.jar", versionId]];
    } else if ([type isEqualToString:@"fabric-api"]) {
        return [versionDir stringByAppendingPathComponent:[NSString stringWithFormat:@"fabric-api-%@.jar", versionId]];
    }
    return [versionDir stringByAppendingPathComponent:[versionId stringByAppendingString:@".jar"]];
}

- (PCLResourceType)resourceTypeForType:(NSString *)type {
    if ([type isEqualToString:@"forge"]) return PCLResourceTypeForge;
    if ([type isEqualToString:@"fabric"]) return PCLResourceTypeFabric;
    if ([type isEqualToString:@"neoforge"]) return PCLResourceTypeNeoForge;
    if ([type isEqualToString:@"optifine"]) return PCLResourceTypeOptiFine;
    if ([type isEqualToString:@"liteloader"]) return PCLResourceTypeLiteLoader;
    if ([type isEqualToString:@"fabric-api"]) return PCLResourceTypeFabric;
    return PCLResourceTypeClient;
}

- (void)updateCellProgress:(NSString *)versionId progress:(double)progress status:(NSString *)status {
    for (NSInteger i = 0; i < self.filteredVersions.count; i++) {
        NSDictionary *v = self.filteredVersions[i];
        NSString *vid = v[@"id"] ?: v[@"version"] ?: @"";
        if ([vid isEqualToString:versionId]) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
            PCLDownloadVersionCell *cell = [self.versionTableView cellForRowAtIndexPath:indexPath];
            if (cell) {
                cell.progressView.hidden = NO;
                cell.progressView.progress = progress;
                [cell.downloadButton setTitle:@"取消" forState:UIControlStateNormal];
            }
            break;
        }
    }
}

#pragma mark - Animation

- (NSArray*)ceSection:(NSInteger)n{NSMutableArray*a=[NSMutableArray array];UIView*c=[self.versionTableView viewWithTag:810+n],*h=[self.versionTableView viewWithTag:820+n];if(n&&c&&!c.hidden)[a addObject:c];if(h)[a addObject:h];for(NSInteger r=0;r<[self.versionTableView numberOfRowsInSection:n];r++){UIView*v=[self.versionTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:r inSection:n]];if(v)[a addObject:v];}return a;}

- (void)resetCESections{
 [self.expandedSections removeAllObjects];
 [self.expandedSections addObject:@0];
 [self.versionTableView reloadData];
 [self updateVersionTableHeight];
}

- (void)dismissTransientUI{}

- (void)prepareCEEnterAnimation{[self resetCESections];[self.versionTableView layoutIfNeeded];[self layoutCECards];for(NSInteger n=0;n<[self numberOfSectionsInTableView:self.versionTableView];n++)for(UIView*v in[self ceSection:n]){[v.layer removeAllAnimations];v.alpha=0;v.transform=CGAffineTransformMakeTranslation(0,-10);}}
- (void)playCEEnterAnimation{for(NSInteger n=0;n<[self numberOfSectionsInTableView:self.versionTableView];n++){NSArray*a=[self ceSection:n];[UIView animateWithDuration:.15 delay:.025*n options:UIViewAnimationOptionCurveEaseOut animations:^{for(UIView*v in a){v.alpha=1;v.transform=CGAffineTransformIdentity;}} completion:nil];}}

- (void)playCEExitAnimation{for(NSInteger n=0;n<[self numberOfSectionsInTableView:self.versionTableView];n++){NSArray*a=[self ceSection:n];[UIView animateWithDuration:.07 delay:.01*n options:UIViewAnimationOptionCurveEaseIn animations:^{for(UIView*v in a){v.alpha=0;v.transform=CGAffineTransformMakeTranslation(0,-8);}} completion:nil];}}

- (void)reloadState {
    [self refreshData];
}

@end
