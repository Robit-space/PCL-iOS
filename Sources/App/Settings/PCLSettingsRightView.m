#import "PCLSettingsRightView.h"
#import "PCLCEPageAnimator.h"
#import "PCLPathUtils.h"
#import "PCLInstanceManager.h"
#import "PCLDownloadManager.h"
#import <mach/mach.h>
#import <QuartzCore/QuartzCore.h>

static UIColor *PCLColor(NSUInteger rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
                           green:((rgb >> 8) & 255) / 255.0
                            blue:(rgb & 255) / 255.0
                           alpha:1.0];
}

static long long PCLTotalMemory() {
    return [[NSProcessInfo processInfo] physicalMemory];
}

// NSUserDefaults Keys
static NSString *const kMemoryMin = @"memoryMin";
static NSString *const kMemoryMax = @"memoryMax";
static NSString *const kJvmArguments = @"jvmArguments";
static NSString *const kAutoSelectJava = @"autoSelectJava";
static NSString *const kSelectedJavaVersion = @"selectedJavaVersion";
static NSString *const kThemeMode = @"themeMode";
static NSString *const kLauncherOpacity = @"launcherOpacity";
static NSString *const kAutoLaunchGame = @"autoLaunchGame";
static NSString *const kVersionIsolation = @"versionIsolation";
static NSString *const kGameDirectory = @"gameDirectory";

@interface PCLSettingsRightView () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UITextViewDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *cardStackView;
@property (nonatomic) PCLSettingsTab currentTab;

// Launch settings
@property (nonatomic, strong) UISlider *memoryMinSlider;
@property (nonatomic, strong) UISlider *memoryMaxSlider;
@property (nonatomic, strong) UILabel *memoryMinLabel;
@property (nonatomic, strong) UILabel *memoryMaxLabel;
@property (nonatomic, strong) UITextView *jvmArgsTextView;
@property (nonatomic, strong) UISwitch *checkUpdateSwitch;
@property (nonatomic, strong) UISwitch *debugModeSwitch;

// Java settings
@property (nonatomic, strong) UITableView *javaTableView;
@property (nonatomic, strong) NSArray<NSDictionary *> *javaList;
@property (nonatomic, strong) UISwitch *javaAutoSwitch;
@property (nonatomic) NSInteger selectedJavaIndex;

// Game manage settings
@property (nonatomic, strong) UISwitch *versionIsolationSwitch;
@property (nonatomic, strong) UILabel *gameDirLabel;
@property (nonatomic, strong) UISwitch *closeAfterLaunchSwitch;
@property (nonatomic, strong) UISwitch *autoLoginSwitch;

// UI settings
@property (nonatomic, strong) UISegmentedControl *themeSegment;
@property (nonatomic, strong) UISlider *opacitySlider;
@property (nonatomic, strong) UILabel *opacityLabel;
@property (nonatomic, strong) UISwitch *animationSwitch;

// About
@property (nonatomic, strong) UILabel *aboutTitleLabel;
@property (nonatomic, strong) UILabel *aboutDescLabel;

@end

@implementation PCLSettingsRightView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _currentTab = PCLSettingsTabLaunch;
        _selectedJavaIndex = 1;
        [self setupView];
    }
    return self;
}

- (void)setupView {
    self.backgroundColor = [UIColor clearColor];
    
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.alwaysBounceVertical = YES;
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
    self.cardStackView.spacing = 16;
    self.cardStackView.alignment = UIStackViewAlignmentFill;
    self.cardStackView.distribution = UIStackViewDistributionFill;
    [self.scrollView addSubview:self.cardStackView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.cardStackView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor constant:16],
        [self.cardStackView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor constant:16],
        [self.cardStackView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor constant:-16],
        [self.cardStackView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:-16],
        [self.cardStackView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor constant:-32]
    ]];
}

#pragma mark - Card Builder

- (UIView *)createCardWithTitle:(NSString *)title {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 10;
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOpacity = 0.06;
    card.layer.shadowRadius = 8;
    card.layer.shadowOffset = CGSizeMake(0, 2);
    card.translatesAutoresizingMaskIntoConstraints = NO;
    
    if (title.length > 0) {
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.text = title;
        titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
        titleLabel.textColor = PCLColor(0x343D4A);
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:titleLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
            [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
            [titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16]
        ]];
    }
    return card;
}

#pragma mark - Tab Switcher

- (void)switchToTab:(PCLSettingsTab)tab {
    self.currentTab = tab;
    [self.cardStackView.arrangedSubviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    switch (tab) {
        case PCLSettingsTabLaunch: [self buildLaunchSettings]; break;
        case PCLSettingsTabJava: [self buildJavaSettings]; break;
        case PCLSettingsTabGameManage: [self buildGameManageSettings]; break;
        case PCLSettingsTabUI: [self buildUISettings]; break;
        case PCLSettingsTabAbout: [self buildAboutPage]; break;
        case PCLSettingsTabUpdate: [self buildUpdateSettings]; break;
        case PCLSettingsTabLog: [self buildLogSettings]; break;
        default: [self buildPlaceholder:tab]; break;
    }
}

#pragma mark - Launch Settings (PCL-CE风格: 完整启动设置)

- (void)buildLaunchSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 下载源设置卡片
    UIView *sourceCard = [self createCardWithTitle:@"下载源设置"];
    
    NSArray *sourceNames = @[@"自动选择", @"官方源", @"BMCL API", @"MCBBS API"];
    UISegmentedControl *sourceSegment = [[UISegmentedControl alloc] initWithItems:sourceSegment];
    sourceSegment = [[UISegmentedControl alloc] initWithItems:sourceNames];
    sourceSegment.selectedSegmentIndex = [PCLDownloadManager sharedManager].downloadSource;
    sourceSegment.translatesAutoresizingMaskIntoConstraints = NO;
    sourceSegment.tintColor = PCLColor(0x1370F3);
    [sourceSegment addTarget:self action:@selector(downloadSourceChanged:) forControlEvents:UIControlEventValueChanged];
    [sourceCard addSubview:sourceSegment];
    
    [NSLayoutConstraint activateConstraints:@[
        [sourceSegment.topAnchor constraintEqualToAnchor:sourceCard.topAnchor constant:36],
        [sourceSegment.leadingAnchor constraintEqualToAnchor:sourceCard.leadingAnchor constant:12],
        [sourceSegment.trailingAnchor constraintEqualToAnchor:sourceCard.trailingAnchor constant:-12],
        [sourceSegment.bottomAnchor constraintEqualToAnchor:sourceCard.bottomAnchor constant:-12]
    ]];
    
    // 内存设置卡片
    UIView *memCard = [self createCardWithTitle:@"内存分配"];
    
    // 最小内存
    UILabel *minLabel = [[UILabel alloc] init];
    minLabel.text = @"最小内存";
    minLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    minLabel.textColor = PCLColor(0x343D4A);
    minLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [memCard addSubview:minLabel];
    
    self.memoryMinSlider = [[UISlider alloc] init];
    self.memoryMinSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.memoryMinSlider.minimumValue = 256;
    self.memoryMinSlider.maximumValue = 4096;
    self.memoryMinSlider.value = [defaults integerForKey:kMemoryMin] ?: 512;
    self.memoryMinSlider.tintColor = PCLColor(0x1370F3);
    [self.memoryMinSlider addTarget:self action:@selector(memoryMinChanged:) forControlEvents:UIControlEventValueChanged];
    [memCard addSubview:self.memoryMinSlider];
    
    self.memoryMinLabel = [[UILabel alloc] init];
    self.memoryMinLabel.text = [NSString stringWithFormat:@"%ld MB", (long)self.memoryMinSlider.value];
    self.memoryMinLabel.font = [UIFont systemFontOfSize:13];
    self.memoryMinLabel.textColor = PCLColor(0x8C8C8C);
    self.memoryMinLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [memCard addSubview:self.memoryMinLabel];
    
    // 最大内存
    UILabel *maxLabel = [[UILabel alloc] init];
    maxLabel.text = @"最大内存";
    maxLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    maxLabel.textColor = PCLColor(0x343D4A);
    maxLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [memCard addSubview:maxLabel];
    
    long long totalMemMB = PCLTotalMemory() / (1024 * 1024);
    long long maxMem = totalMemMB > 8192 ? 8192 : totalMemMB;
    
    self.memoryMaxSlider = [[UISlider alloc] init];
    self.memoryMaxSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.memoryMaxSlider.minimumValue = 512;
    self.memoryMaxSlider.maximumValue = (float)maxMem;
    self.memoryMaxSlider.value = [defaults integerForKey:kMemoryMax] ?: MIN(2048, maxMem);
    self.memoryMaxSlider.tintColor = PCLColor(0x1370F3);
    [self.memoryMaxSlider addTarget:self action:@selector(memoryMaxChanged:) forControlEvents:UIControlEventValueChanged];
    [memCard addSubview:self.memoryMaxSlider];
    
    self.memoryMaxLabel = [[UILabel alloc] init];
    self.memoryMaxLabel.text = [NSString stringWithFormat:@"%ld MB", (long)self.memoryMaxSlider.value];
    self.memoryMaxLabel.font = [UIFont systemFontOfSize:13];
    self.memoryMaxLabel.textColor = PCLColor(0x8C8C8C);
    self.memoryMaxLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [memCard addSubview:self.memoryMaxLabel];
    
    UILabel *memHint = [[UILabel alloc] init];
    memHint.text = [NSString stringWithFormat:@"设备总内存: %lld MB", totalMemMB];
    memHint.font = [UIFont systemFontOfSize:11];
    memHint.textColor = PCLColor(0xB0B0B0);
    memHint.translatesAutoresizingMaskIntoConstraints = NO;
    [memCard addSubview:memHint];
    
    [NSLayoutConstraint activateConstraints:@[
        [minLabel.topAnchor constraintEqualToAnchor:memCard.topAnchor constant:52],
        [minLabel.leadingAnchor constraintEqualToAnchor:memCard.leadingAnchor constant:16],
        [self.memoryMinSlider.topAnchor constraintEqualToAnchor:minLabel.bottomAnchor constant:8],
        [self.memoryMinSlider.leadingAnchor constraintEqualToAnchor:memCard.leadingAnchor constant:16],
        [self.memoryMinSlider.trailingAnchor constraintEqualToAnchor:memCard.trailingAnchor constant:-80],
        [self.memoryMinLabel.centerYAnchor constraintEqualToAnchor:self.memoryMinSlider.centerYAnchor],
        [self.memoryMinLabel.leadingAnchor constraintEqualToAnchor:self.memoryMinSlider.trailingAnchor constant:8],
        [self.memoryMinLabel.trailingAnchor constraintEqualToAnchor:memCard.trailingAnchor constant:-16],
        [maxLabel.topAnchor constraintEqualToAnchor:self.memoryMinSlider.bottomAnchor constant:12],
        [maxLabel.leadingAnchor constraintEqualToAnchor:memCard.leadingAnchor constant:16],
        [self.memoryMaxSlider.topAnchor constraintEqualToAnchor:maxLabel.bottomAnchor constant:8],
        [self.memoryMaxSlider.leadingAnchor constraintEqualToAnchor:memCard.leadingAnchor constant:16],
        [self.memoryMaxSlider.trailingAnchor constraintEqualToAnchor:memCard.trailingAnchor constant:-80],
        [self.memoryMaxLabel.centerYAnchor constraintEqualToAnchor:self.memoryMaxSlider.centerYAnchor],
        [self.memoryMaxLabel.leadingAnchor constraintEqualToAnchor:self.memoryMaxSlider.trailingAnchor constant:8],
        [self.memoryMaxLabel.trailingAnchor constraintEqualToAnchor:memCard.trailingAnchor constant:-16],
        [memHint.topAnchor constraintEqualToAnchor:self.memoryMaxSlider.bottomAnchor constant:8],
        [memHint.leadingAnchor constraintEqualToAnchor:memCard.leadingAnchor constant:16],
        [memCard.bottomAnchor constraintEqualToAnchor:memHint.bottomAnchor constant:16]
    ]];
    
    [self.cardStackView addArrangedSubview:memCard];
    
    // JVM参数卡片
    UIView *argsCard = [self createCardWithTitle:@"JVM 参数"];
    
    self.jvmArgsTextView = [[UITextView alloc] init];
    self.jvmArgsTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.jvmArgsTextView.font = [UIFont systemFontOfSize:12];
    self.jvmArgsTextView.textColor = PCLColor(0x404040);
    self.jvmArgsTextView.backgroundColor = PCLColor(0xF8F8F8);
    self.jvmArgsTextView.layer.cornerRadius = 6;
    self.jvmArgsTextView.layer.borderWidth = 1;
    self.jvmArgsTextView.layer.borderColor = PCLColor(0xE0E0E0).CGColor;
    self.jvmArgsTextView.text = [defaults stringForKey:kJvmArguments] ?: @"-XX:+UseG1GC -XX:+UnlockExperimentalVMOptions";
    self.jvmArgsTextView.delegate = self;
    self.jvmArgsTextView.editable = YES;
    self.jvmArgsTextView.scrollEnabled = NO;
    [argsCard addSubview:self.jvmArgsTextView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.jvmArgsTextView.topAnchor constraintEqualToAnchor:argsCard.topAnchor constant:52],
        [self.jvmArgsTextView.leadingAnchor constraintEqualToAnchor:argsCard.leadingAnchor constant:16],
        [self.jvmArgsTextView.trailingAnchor constraintEqualToAnchor:argsCard.trailingAnchor constant:-16],
        [self.jvmArgsTextView.heightAnchor constraintEqualToConstant:80],
        [argsCard.bottomAnchor constraintEqualToAnchor:self.jvmArgsTextView.bottomAnchor constant:16]
    ]];
    
    [self.cardStackView addArrangedSubview:argsCard];
    
    // 启动设置卡片
    UIView *launchCard = [self createCardWithTitle:@"启动设置"];
    
    UILabel *checkUpdateLabel = [[UILabel alloc] init];
    checkUpdateLabel.text = @"启动时检查更新";
    checkUpdateLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    checkUpdateLabel.textColor = PCLColor(0x343D4A);
    checkUpdateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [launchCard addSubview:checkUpdateLabel];
    
    self.checkUpdateSwitch = [[UISwitch alloc] init];
    self.checkUpdateSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.checkUpdateSwitch.onTintColor = PCLColor(0x1370F3);
    self.checkUpdateSwitch.on = [defaults boolForKey:@"checkUpdateAtLaunch"];
    [launchCard addSubview:self.checkUpdateSwitch];
    
    [NSLayoutConstraint activateConstraints:@[
        [checkUpdateLabel.topAnchor constraintEqualToAnchor:launchCard.topAnchor constant:52],
        [checkUpdateLabel.leadingAnchor constraintEqualToAnchor:launchCard.leadingAnchor constant:16],
        [self.checkUpdateSwitch.centerYAnchor constraintEqualToAnchor:checkUpdateLabel.centerYAnchor],
        [self.checkUpdateSwitch.trailingAnchor constraintEqualToAnchor:launchCard.trailingAnchor constant:-16],
        [launchCard.bottomAnchor constraintEqualToAnchor:checkUpdateLabel.bottomAnchor constant:16]
    ]];
    
    [self.cardStackView addArrangedSubview:launchCard];
}

#pragma mark - Java Settings (PCL-CE风格: Java管理)

- (void)buildJavaSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    UIView *javaCard = [self createCardWithTitle:@"Java 选择"];
    
    UILabel *autoLabel = [[UILabel alloc] init];
    autoLabel.text = @"自动选择 Java";
    autoLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    autoLabel.textColor = PCLColor(0x343D4A);
    autoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [javaCard addSubview:autoLabel];
    
    self.javaAutoSwitch = [[UISwitch alloc] init];
    self.javaAutoSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.javaAutoSwitch.onTintColor = PCLColor(0x1370F3);
    self.javaAutoSwitch.on = [defaults boolForKey:kAutoSelectJava] ?: YES;
    [self.javaAutoSwitch addTarget:self action:@selector(javaAutoChanged:) forControlEvents:UIControlEventValueChanged];
    [javaCard addSubview:self.javaAutoSwitch];
    
    [NSLayoutConstraint activateConstraints:@[
        [autoLabel.topAnchor constraintEqualToAnchor:javaCard.topAnchor constant:52],
        [autoLabel.leadingAnchor constraintEqualToAnchor:javaCard.leadingAnchor constant:16],
        [self.javaAutoSwitch.centerYAnchor constraintEqualToAnchor:autoLabel.centerYAnchor],
        [self.javaAutoSwitch.trailingAnchor constraintEqualToAnchor:javaCard.trailingAnchor constant:-16],
        [javaCard.bottomAnchor constraintEqualToAnchor:autoLabel.bottomAnchor constant:16]
    ]];
    
    [self.cardStackView addArrangedSubview:javaCard];
    
    // Java 列表
    UIView *listCard = [self createCardWithTitle:@"可用的 Java 环境"];
    
    [self refreshJavaList];
    self.selectedJavaIndex = [[defaults objectForKey:kSelectedJavaVersion] integerValue] - 8;
    if (self.selectedJavaIndex < 0) self.selectedJavaIndex = 0;
    
    self.javaTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.javaTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.javaTableView.delegate = self;
    self.javaTableView.dataSource = self;
    self.javaTableView.backgroundColor = [UIColor clearColor];
    self.javaTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.javaTableView.scrollEnabled = NO;
    self.javaTableView.rowHeight = 64;
    self.javaTableView.allowsSelection = YES;
    [listCard addSubview:self.javaTableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.javaTableView.topAnchor constraintEqualToAnchor:listCard.topAnchor constant:52],
        [self.javaTableView.leadingAnchor constraintEqualToAnchor:listCard.leadingAnchor],
        [self.javaTableView.trailingAnchor constraintEqualToAnchor:listCard.trailingAnchor],
        [self.javaTableView.bottomAnchor constraintEqualToAnchor:listCard.bottomAnchor constant:-8],
        [self.javaTableView.heightAnchor constraintEqualToConstant:self.javaList.count * 64]
    ]];
    
    [self.cardStackView addArrangedSubview:listCard];
}

- (void)refreshJavaList {
    NSArray *versions = @[@8, @17, @21, @25];
    NSMutableArray *list = [NSMutableArray array];
    for (NSNumber *ver in versions) {
        NSString *home = [PCLPathUtils javaHomeForVersion:ver.integerValue];
        BOOL available = home != nil;
        [list addObject:@{
            @"version": ver,
            @"home": home ?: @"未安装",
            @"available": @(available)
        }];
    }
    self.javaList = list;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.javaList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"JavaCell"];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    NSDictionary *java = self.javaList[indexPath.row];
    BOOL available = [java[@"available"] boolValue];
    NSInteger version = [java[@"version"] integerValue];
    
    cell.textLabel.text = [NSString stringWithFormat:@"Java %ld", (long)version];
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    cell.textLabel.textColor = available ? PCLColor(0x343D4A) : PCLColor(0xB0B0B0);
    
    cell.detailTextLabel.text = available ? java[@"home"] : @"未找到";
    cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
    cell.detailTextLabel.textColor = available ? PCLColor(0x27AE60) : PCLColor(0xE74C3C);
    
    // Radio button
    UIButton *radio = [UIButton buttonWithType:UIButtonTypeCustom];
    radio.frame = CGRectMake(0, 0, 22, 22);
    radio.userInteractionEnabled = NO;
    radio.layer.cornerRadius = 11;
    radio.layer.borderWidth = 2;
    radio.layer.borderColor = PCLColor(0x1370F3).CGColor;
    
    BOOL isSelected = (indexPath.row == self.selectedJavaIndex);
    if (isSelected) {
        radio.backgroundColor = PCLColor(0x1370F3);
        UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(7, 7, 8, 8)];
        dot.backgroundColor = [UIColor whiteColor];
        dot.layer.cornerRadius = 4;
        [radio addSubview:dot];
    } else {
        radio.backgroundColor = [UIColor clearColor];
    }
    
    cell.accessoryView = radio;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.javaAutoSwitch.isOn) return;
    self.selectedJavaIndex = indexPath.row;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@(self.selectedJavaIndex + 8) forKey:kSelectedJavaVersion];
    [tableView reloadData];
}

#pragma mark - Game Manage Settings (PCL-CE风格: 游戏管理)

- (void)buildGameManageSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 版本隔离
    UIView *isolationCard = [self createCardWithTitle:@"游戏目录"];
    
    UILabel *isolationLabel = [[UILabel alloc] init];
    isolationLabel.text = @"启用版本隔离";
    isolationLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    isolationLabel.textColor = PCLColor(0x343D4A);
    isolationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [isolationCard addSubview:isolationLabel];
    
    self.versionIsolationSwitch = [[UISwitch alloc] init];
    self.versionIsolationSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.versionIsolationSwitch.onTintColor = PCLColor(0x1370F3);
    self.versionIsolationSwitch.on = [defaults boolForKey:kVersionIsolation] ?: YES;
    [self.versionIsolationSwitch addTarget:self action:@selector(versionIsolationChanged:) forControlEvents:UIControlEventValueChanged];
    [isolationCard addSubview:self.versionIsolationSwitch];
    
    // 游戏目录显示
    UILabel *dirLabel = [[UILabel alloc] init];
    dirLabel.text = @"游戏目录:";
    dirLabel.font = [UIFont systemFontOfSize:12];
    dirLabel.textColor = PCLColor(0x8C8C8C);
    dirLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [isolationCard addSubview:dirLabel];
    
    self.gameDirLabel = [[UILabel alloc] init];
    self.gameDirLabel.text = [defaults stringForKey:kGameDirectory] ?: [[PCLInstanceManager sharedManager] sharedGameDirectory];
    self.gameDirLabel.font = [UIFont systemFontOfSize:11];
    self.gameDirLabel.textColor = PCLColor(0x343D4A);
    self.gameDirLabel.numberOfLines = 0;
    self.gameDirLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    self.gameDirLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [isolationCard addSubview:self.gameDirLabel];
    
    UILabel *isolationHint = [[UILabel alloc] init];
    isolationHint.text = @"开启后，每个实例将拥有独立的游戏目录\n(mods, saves, config等)";
    isolationHint.font = [UIFont systemFontOfSize:11];
    isolationHint.textColor = PCLColor(0xB0B0B0);
    isolationHint.numberOfLines = 0;
    isolationHint.translatesAutoresizingMaskIntoConstraints = NO;
    [isolationCard addSubview:isolationHint];
    
    [NSLayoutConstraint activateConstraints:@[
        [isolationLabel.topAnchor constraintEqualToAnchor:isolationCard.topAnchor constant:52],
        [isolationLabel.leadingAnchor constraintEqualToAnchor:isolationCard.leadingAnchor constant:16],
        [self.versionIsolationSwitch.centerYAnchor constraintEqualToAnchor:isolationLabel.centerYAnchor],
        [self.versionIsolationSwitch.trailingAnchor constraintEqualToAnchor:isolationCard.trailingAnchor constant:-16],
        [dirLabel.topAnchor constraintEqualToAnchor:isolationLabel.bottomAnchor constant:12],
        [dirLabel.leadingAnchor constraintEqualToAnchor:isolationCard.leadingAnchor constant:16],
        [self.gameDirLabel.topAnchor constraintEqualToAnchor:dirLabel.bottomAnchor constant:4],
        [self.gameDirLabel.leadingAnchor constraintEqualToAnchor:isolationCard.leadingAnchor constant:16],
        [self.gameDirLabel.trailingAnchor constraintEqualToAnchor:isolationCard.trailingAnchor constant:-16],
        [isolationHint.topAnchor constraintEqualToAnchor:self.gameDirLabel.bottomAnchor constant:8],
        [isolationHint.leadingAnchor constraintEqualToAnchor:isolationCard.leadingAnchor constant:16],
        [isolationHint.trailingAnchor constraintEqualToAnchor:isolationCard.trailingAnchor constant:-16],
        [isolationCard.bottomAnchor constraintEqualToAnchor:isolationHint.bottomAnchor constant:16]
    ]];
    
    [self.cardStackView addArrangedSubview:isolationCard];
    
    // 启动后操作
    UIView *afterCard = [self createCardWithTitle:@"启动后"];
    
    UILabel *closeLabel = [[UILabel alloc] init];
    closeLabel.text = @"启动后关闭启动器";
    closeLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    closeLabel.textColor = PCLColor(0x343D4A);
    closeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [afterCard addSubview:closeLabel];
    
    self.closeAfterLaunchSwitch = [[UISwitch alloc] init];
    self.closeAfterLaunchSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.closeAfterLaunchSwitch.onTintColor = PCLColor(0x1370F3);
    self.closeAfterLaunchSwitch.on = [defaults boolForKey:@"closeAfterLaunch"];
    [afterCard addSubview:self.closeAfterLaunchSwitch];
    
    [NSLayoutConstraint activateConstraints:@[
        [closeLabel.topAnchor constraintEqualToAnchor:afterCard.topAnchor constant:52],
        [closeLabel.leadingAnchor constraintEqualToAnchor:afterCard.leadingAnchor constant:16],
        [self.closeAfterLaunchSwitch.centerYAnchor constraintEqualToAnchor:closeLabel.centerYAnchor],
        [self.closeAfterLaunchSwitch.trailingAnchor constraintEqualToAnchor:afterCard.trailingAnchor constant:-16],
        [afterCard.bottomAnchor constraintEqualToAnchor:closeLabel.bottomAnchor constant:16]
    ]];
    
    [self.cardStackView addArrangedSubview:afterCard];
}

#pragma mark - UI Settings (PCL-CE风格)

- (void)buildUISettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 主题
    UIView *themeCard = [self createCardWithTitle:@"主题"];
    
    UILabel *modeLabel = [[UILabel alloc] init];
    modeLabel.text = @"主题模式";
    modeLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    modeLabel.textColor = PCLColor(0x343D4A);
    modeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [themeCard addSubview:modeLabel];
    
    self.themeSegment = [[UISegmentedControl alloc] initWithItems:@[@"跟随系统", @"浅色", @"深色"]];
    self.themeSegment.selectedSegmentIndex = [defaults integerForKey:kThemeMode] ?: 0;
    self.themeSegment.translatesAutoresizingMaskIntoConstraints = NO;
    self.themeSegment.backgroundColor = PCLColor(0xF5F5F5);
    [self.themeSegment addTarget:self action:@selector(themeChanged:) forControlEvents:UIControlEventValueChanged];
    [themeCard addSubview:self.themeSegment];
    
    [NSLayoutConstraint activateConstraints:@[
        [modeLabel.topAnchor constraintEqualToAnchor:themeCard.topAnchor constant:52],
        [modeLabel.leadingAnchor constraintEqualToAnchor:themeCard.leadingAnchor constant:16],
        [self.themeSegment.topAnchor constraintEqualToAnchor:modeLabel.bottomAnchor constant:8],
        [self.themeSegment.leadingAnchor constraintEqualToAnchor:themeCard.leadingAnchor constant:16],
        [self.themeSegment.trailingAnchor constraintEqualToAnchor:themeCard.trailingAnchor constant:-16],
        [self.themeSegment.heightAnchor constraintEqualToConstant:36],
        [themeCard.bottomAnchor constraintEqualToAnchor:self.themeSegment.bottomAnchor constant:16]
    ]];
    
    [self.cardStackView addArrangedSubview:themeCard];
    
    // 启动器透明度
    UIView *opacityCard = [self createCardWithTitle:@"启动器透明度"];
    
    self.opacitySlider = [[UISlider alloc] init];
    self.opacitySlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.opacitySlider.minimumValue = 0.3;
    self.opacitySlider.maximumValue = 1.0;
    self.opacitySlider.value = [defaults floatForKey:kLauncherOpacity] ?: 1.0;
    self.opacitySlider.tintColor = PCLColor(0x1370F3);
    [self.opacitySlider addTarget:self action:@selector(opacityChanged:) forControlEvents:UIControlEventValueChanged];
    [opacityCard addSubview:self.opacitySlider];
    
    self.opacityLabel = [[UILabel alloc] init];
    self.opacityLabel.text = [NSString stringWithFormat:@"%.0f%%", self.opacitySlider.value * 100];
    self.opacityLabel.font = [UIFont systemFontOfSize:13];
    self.opacityLabel.textColor = PCLColor(0x8C8C8C);
    self.opacityLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [opacityCard addSubview:self.opacityLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.opacitySlider.topAnchor constraintEqualToAnchor:opacityCard.topAnchor constant:52],
        [self.opacitySlider.leadingAnchor constraintEqualToAnchor:opacityCard.leadingAnchor constant:16],
        [self.opacitySlider.trailingAnchor constraintEqualToAnchor:opacityCard.trailingAnchor constant:-60],
        [self.opacityLabel.centerYAnchor constraintEqualToAnchor:self.opacitySlider.centerYAnchor],
        [self.opacityLabel.trailingAnchor constraintEqualToAnchor:opacityCard.trailingAnchor constant:-16],
        [opacityCard.bottomAnchor constraintEqualToAnchor:self.opacitySlider.bottomAnchor constant:16]
    ]];
    
    [self.cardStackView addArrangedSubview:opacityCard];
}

#pragma mark - Update Settings

- (void)buildUpdateSettings {
    UIView *card = [self createCardWithTitle:@"更新"];
    
    UILabel *versionLabel = [[UILabel alloc] init];
    versionLabel.text = @"当前版本: PCL-iOS v0.1.0";
    versionLabel.font = [UIFont systemFontOfSize:14];
    versionLabel.textColor = PCLColor(0x343D4A);
    versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:versionLabel];
    
    UILabel *sourceLabel = [[UILabel alloc] init];
    sourceLabel.text = @"更新源: GitHub Releases";
    sourceLabel.font = [UIFont systemFontOfSize:12];
    sourceLabel.textColor = PCLColor(0x8C8C8C);
    sourceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:sourceLabel];
    
    UIButton *checkButton = [UIButton buttonWithType:UIButtonTypeSystem];
    checkButton.translatesAutoresizingMaskIntoConstraints = NO;
    [checkButton setTitle:@"检查更新" forState:UIControlStateNormal];
    checkButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    checkButton.tintColor = PCLColor(0x1370F3);
    [card addSubview:checkButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [versionLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:52],
        [versionLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [sourceLabel.topAnchor constraintEqualToAnchor:versionLabel.bottomAnchor constant:8],
        [sourceLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [checkButton.topAnchor constraintEqualToAnchor:sourceLabel.bottomAnchor constant:16],
        [checkButton.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [card.bottomAnchor constraintEqualToAnchor:checkButton.bottomAnchor constant:16]
    ]];
    
    [self.cardStackView addArrangedSubview:card];
}

#pragma mark - Log Settings

- (void)buildLogSettings {
    UIView *card = [self createCardWithTitle:@"日志"];
    
    UILabel *logLabel = [[UILabel alloc] init];
    logLabel.text = @"查看启动器日志以诊断问题";
    logLabel.font = [UIFont systemFontOfSize:13];
    logLabel.textColor = PCLColor(0x8C8C8C);
    logLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:logLabel];
    
    UIButton *exportButton = [UIButton buttonWithType:UIButtonTypeSystem];
    exportButton.translatesAutoresizingMaskIntoConstraints = NO;
    [exportButton setTitle:@"导出日志" forState:UIControlStateNormal];
    exportButton.tintColor = PCLColor(0x1370F3);
    [card addSubview:exportButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [logLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:52],
        [logLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [exportButton.topAnchor constraintEqualToAnchor:logLabel.bottomAnchor constant:12],
        [exportButton.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [card.bottomAnchor constraintEqualToAnchor:exportButton.bottomAnchor constant:16]
    ]];
    
    [self.cardStackView addArrangedSubview:card];
}

#pragma mark - About

- (void)buildAboutPage {
    UIView *aboutCard = [self createCardWithTitle:@"关于 PCL-iOS"];
    
    self.aboutTitleLabel = [[UILabel alloc] init];
    self.aboutTitleLabel.text = @"PCL-iOS v0.1.0";
    self.aboutTitleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    self.aboutTitleLabel.textColor = PCLColor(0x343D4A);
    self.aboutTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.aboutTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [aboutCard addSubview:self.aboutTitleLabel];
    
    self.aboutDescLabel = [[UILabel alloc] init];
    self.aboutDescLabel.text = @"基于 PCL2 Community Edition 设计\nMinecraft Java Edition iOS 启动器\n\n开发者: robitspace\n许可证: GPL-3.0";
    self.aboutDescLabel.font = [UIFont systemFontOfSize:13];
    self.aboutDescLabel.textColor = PCLColor(0x8C8C8C);
    self.aboutDescLabel.textAlignment = NSTextAlignmentCenter;
    self.aboutDescLabel.numberOfLines = 0;
    self.aboutDescLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [aboutCard addSubview:self.aboutDescLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.aboutTitleLabel.topAnchor constraintEqualToAnchor:aboutCard.topAnchor constant:52],
        [self.aboutTitleLabel.centerXAnchor constraintEqualToAnchor:aboutCard.centerXAnchor],
        [self.aboutDescLabel.topAnchor constraintEqualToAnchor:self.aboutTitleLabel.bottomAnchor constant:16],
        [self.aboutDescLabel.leadingAnchor constraintEqualToAnchor:aboutCard.leadingAnchor constant:16],
        [self.aboutDescLabel.trailingAnchor constraintEqualToAnchor:aboutCard.trailingAnchor constant:-16],
        [aboutCard.bottomAnchor constraintEqualToAnchor:self.aboutDescLabel.bottomAnchor constant:16]
    ]];
    
    [self.cardStackView addArrangedSubview:aboutCard];
}

- (void)buildPlaceholder:(PCLSettingsTab)tab {
    UIView *card = [self createCardWithTitle:@""];
    UILabel *label = [[UILabel alloc] init];
    NSArray *names = @[@"启动", @"Java", @"游戏管理", @"游戏关联", @"界面", @"语言", @"杂项", @"关于", @"更新", @"反馈", @"日志"];
    label.text = names[(NSInteger)tab];
    label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    label.textColor = PCLColor(0x8C8C8C);
    label.textAlignment = NSTextAlignmentCenter;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [card.heightAnchor constraintEqualToConstant:80]
    ]];
    [self.cardStackView addArrangedSubview:card];
}

#pragma mark - Actions (持久化到NSUserDefaults)

- (void)downloadSourceChanged:(UISegmentedControl *)sender {
    [PCLDownloadManager sharedManager].downloadSource = sender.selectedSegmentIndex;
}

- (void)memoryMinChanged:(UISlider *)slider {
    NSInteger value = (NSInteger)(slider.value / 128) * 128;
    if (value < 256) value = 256;
    self.memoryMinLabel.text = [NSString stringWithFormat:@"%ld MB", (long)value];
    [[NSUserDefaults standardUserDefaults] setInteger:value forKey:kMemoryMin];
}

- (void)memoryMaxChanged:(UISlider *)slider {
    NSInteger value = (NSInteger)(slider.value / 256) * 256;
    if (value < 512) value = 512;
    self.memoryMaxLabel.text = [NSString stringWithFormat:@"%ld MB", (long)value];
    [[NSUserDefaults standardUserDefaults] setInteger:value forKey:kMemoryMax];
}

- (void)javaAutoChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kAutoSelectJava];
    self.javaTableView.userInteractionEnabled = !sender.isOn;
    self.javaTableView.alpha = sender.isOn ? 0.4 : 1.0;
}

- (void)versionIsolationChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kVersionIsolation];
}

- (void)themeChanged:(UISegmentedControl *)sender {
    [[NSUserDefaults standardUserDefaults] setInteger:sender.selectedSegmentIndex forKey:kThemeMode];
}

- (void)opacityChanged:(UISlider *)slider {
    self.opacityLabel.text = [NSString stringWithFormat:@"%.0f%%", slider.value * 100];
    [[NSUserDefaults standardUserDefaults] setFloat:slider.value forKey:kLauncherOpacity];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidEndEditing:(UITextView *)textView {
    if (textView == self.jvmArgsTextView) {
        [[NSUserDefaults standardUserDefaults] setObject:textView.text forKey:kJvmArguments];
    }
}

#pragma mark - Animation

- (void)dismissTransientUI {}
- (void)prepareCEEnterAnimation { self.cardStackView.alpha = 0; }
- (void)playCEEnterAnimation { [PCLCEPageAnimator showRightItems:self.cardStackView.arrangedSubviews scrollView:self.scrollView]; }
- (void)playCEExitAnimation { [PCLCEPageAnimator hideRightItems:self.cardStackView.arrangedSubviews scrollView:self.scrollView]; }
- (void)reloadState {}

@end
