#import "PCLInstanceEditViewController.h"
#import "PCLInstanceManager.h"
#import "PCLVersionManager.h"
#import "PCLPathUtils.h"
#import "PCLRendererManager.h"

static UIColor *PCLColor(NSUInteger rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
                           green:((rgb >> 8) & 255) / 255.0
                            blue:(rgb & 255) / 255.0
                           alpha:1.0];
}

@interface PCLInstanceEditViewController () <UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong) PCLInstance *instance;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stackView;

@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UILabel *versionLabel;
@property (nonatomic, strong) UISegmentedControl *javaModeSegment;
@property (nonatomic, strong) UIPickerView *javaPicker;
@property (nonatomic, strong) UISlider *memorySlider;
@property (nonatomic, strong) UILabel *memoryLabel;
@property (nonatomic, strong) UITextField *widthField;
@property (nonatomic, strong) UITextField *heightField;
@property (nonatomic, strong) UITextView *jvmArgsView;
@property (nonatomic, strong) UISwitch *autoLoginSwitch;

// 渲染器选择 (参考PCL2-CE)
@property (nonatomic, strong) UISegmentedControl *rendererSegment;
@property (nonatomic, strong) UILabel *rendererDescLabel;

// 版本隔离 (参考PCL2-CE)
@property (nonatomic, strong) UISwitch *versionIsolationSwitch;
@property (nonatomic, strong) UILabel *versionIsolationDescLabel;

@property (nonatomic, strong) NSArray<NSString *> *installedVersions;
@property (nonatomic, strong) NSArray<NSString *> *javaVersions;
@property (nonatomic, assign) NSInteger selectedJavaIndex;

@end

@implementation PCLInstanceEditViewController

- (instancetype)initWithInstance:(PCLInstance *)instance {
    self = [super init];
    if (self) {
        _instance = instance;
        _installedVersions = @[];
        _javaVersions = @[];
        _selectedJavaIndex = 0;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"编辑实例";
    self.view.backgroundColor = [UIColor colorWithRed:251.0/255.0 green:251.0/255.0 blue:251.0/255.0 alpha:1.0];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                          target:self
                                                                                          action:@selector(cancelPressed)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                           target:self
                                                                                           action:@selector(savePressed)];

    [self loadData];
    [self buildUI];
}

- (void)loadData {
    NSMutableArray *versions = [NSMutableArray array];
    for (PCLVersionInfo *ver in [[PCLVersionManager sharedManager] localVersions]) {
        [versions addObject:ver.versionId];
    }
    if (versions.count == 0) {
        [versions addObject:@"1.20.4"];
    }
    self.installedVersions = versions;

    NSMutableArray *javaVers = [NSMutableArray arrayWithObject:@"自动检测"];
    for (NSNumber *ver in @[@8, @17, @21, @25]) {
        if ([PCLPathUtils javaHomeForVersion:ver.integerValue]) {
            [javaVers addObject:[NSString stringWithFormat:@"Java %ld", (long)ver.integerValue]];
        }
    }
    self.javaVersions = javaVers;

    if (![self.installedVersions containsObject:self.instance.versionId]) {
        [versions addObject:self.instance.versionId];
    }
}

- (void)buildUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    self.stackView = [[UIStackView alloc] init];
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stackView.axis = UILayoutConstraintAxisVertical;
    self.stackView.spacing = 18;
    self.stackView.alignment = UIStackViewAlignmentFill;
    self.stackView.distribution = UIStackViewDistributionFill;
    [self.scrollView addSubview:self.stackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.stackView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor constant:20],
        [self.stackView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor constant:20],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor constant:-20],
        [self.stackView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:-20],
        [self.stackView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor constant:-40]
    ]];

    [self buildNameSection];
    [self buildVersionSection];
    [self buildRendererSection];
    [self buildJavaSection];
    [self buildMemorySection];
    [self buildResolutionSection];
    [self buildVersionIsolationSection];
    [self buildJvmArgsSection];
    [self buildAdvancedSection];
}

- (UIView *)createSectionCardWithTitle:(NSString *)title {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 10;
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOpacity = 0.04;
    card.layer.shadowRadius = 6;
    card.layer.shadowOffset = CGSizeMake(0, 2);
    card.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    titleLabel.textColor = PCLColor(0x343D4A);
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.tag = 1001;
    [card addSubview:titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16]
    ]];

    return card;
}

#pragma mark - 名称

- (void)buildNameSection {
    UIView *card = [self createSectionCardWithTitle:@"实例名称"];

    self.nameField = [[UITextField alloc] init];
    self.nameField.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameField.text = self.instance.name;
    self.nameField.font = [UIFont systemFontOfSize:14];
    self.nameField.textColor = PCLColor(0x343D4A);
    self.nameField.borderStyle = UITextBorderStyleRoundedRect;
    self.nameField.delegate = self;
    [card addSubview:self.nameField];

    UILabel *hintLabel = [[UILabel alloc] init];
    hintLabel.text = @"实例名称用于区分不同的游戏存档和配置";
    hintLabel.font = [UIFont systemFontOfSize:12];
    hintLabel.textColor = PCLColor(0x8C8C8C);
    hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:hintLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.nameField.topAnchor constraintEqualToAnchor:card.topAnchor constant:48],
        [self.nameField.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [self.nameField.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [self.nameField.heightAnchor constraintEqualToConstant:36],
        [hintLabel.topAnchor constraintEqualToAnchor:self.nameField.bottomAnchor constant:6],
        [hintLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [hintLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [card.bottomAnchor constraintEqualToAnchor:hintLabel.bottomAnchor constant:14]
    ]];

    [self.stackView addArrangedSubview:card];
}

#pragma mark - 游戏版本

- (void)buildVersionSection {
    UIView *card = [self createSectionCardWithTitle:@"游戏版本"];

    UILabel *currentLabel = [[UILabel alloc] init];
    currentLabel.translatesAutoresizingMaskIntoConstraints = NO;
    currentLabel.font = [UIFont systemFontOfSize:13];
    currentLabel.textColor = PCLColor(0x8C8C8C);
    currentLabel.text = [NSString stringWithFormat:@"当前版本: %@", self.instance.versionId];
    [card addSubview:currentLabel];

    UIPickerView *versionPicker = [[UIPickerView alloc] init];
    versionPicker.translatesAutoresizingMaskIntoConstraints = NO;
    versionPicker.dataSource = self;
    versionPicker.delegate = self;
    versionPicker.tag = 2001;

    NSInteger currentIndex = [self.installedVersions indexOfObject:self.instance.versionId];
    if (currentIndex != NSNotFound) {
        [versionPicker selectRow:currentIndex inComponent:0 animated:NO];
    }

    [card addSubview:versionPicker];

    CGFloat pickerHeight = MIN(160, self.installedVersions.count * 44);
    [NSLayoutConstraint activateConstraints:@[
        [currentLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:48],
        [currentLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [currentLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [versionPicker.topAnchor constraintEqualToAnchor:currentLabel.bottomAnchor constant:4],
        [versionPicker.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [versionPicker.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [versionPicker.heightAnchor constraintEqualToConstant:pickerHeight],
        [card.bottomAnchor constraintEqualToAnchor:versionPicker.bottomAnchor constant:8]
    ]];

    [self.stackView addArrangedSubview:card];
}

#pragma mark - 渲染器选择 (参考PCL2-CE)

- (void)buildRendererSection {
    UIView *card = [self createSectionCardWithTitle:@"渲染器"];
    
    // 渲染器选择 segmented control
    NSArray *rendererNames = @[@"GL4ES", @"MetalANGLE", @"MobileGlues", @"Zink"];
    self.rendererSegment = [[UISegmentedControl alloc] initWithItems:rendererNames];
    self.rendererSegment.translatesAutoresizingMaskIntoConstraints = NO;
    self.rendererSegment.selectedSegmentIndex = self.instance.renderer;
    self.rendererSegment.tintColor = PCLColor(0x1370F3);
    [self.rendererSegment addTarget:self action:@selector(rendererChanged:) forControlEvents:UIControlEventValueChanged];
    [card addSubview:self.rendererSegment];
    
    // 渲染器描述
    self.rendererDescLabel = [[UILabel alloc] init];
    self.rendererDescLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.rendererDescLabel.font = [UIFont systemFontOfSize:12];
    self.rendererDescLabel.textColor = PCLColor(0x8C8C8C);
    self.rendererDescLabel.numberOfLines = 0;
    self.rendererDescLabel.text = [self rendererDescriptionForIndex:self.instance.renderer];
    [card addSubview:self.rendererDescLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.rendererSegment.topAnchor constraintEqualToAnchor:card.topAnchor constant:48],
        [self.rendererSegment.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [self.rendererSegment.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [self.rendererSegment.heightAnchor constraintEqualToConstant:30],
        [self.rendererDescLabel.topAnchor constraintEqualToAnchor:self.rendererSegment.bottomAnchor constant:8],
        [self.rendererDescLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [self.rendererDescLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [card.bottomAnchor constraintEqualToAnchor:self.rendererDescLabel.bottomAnchor constant:14]
    ]];

    [self.stackView addArrangedSubview:card];
}

- (void)rendererChanged:(UISegmentedControl *)sender {
    self.instance.renderer = (PCLRenderRenderer)sender.selectedSegmentIndex;
    self.rendererDescLabel.text = [self rendererDescriptionForIndex:self.instance.renderer];
}

- (NSString *)rendererDescriptionForIndex:(NSInteger)index {
    switch (index) {
        case 0: return @"GL4ES - OpenGL ES翻译层，兼容性好，适合大多数版本";
        case 1: return @"MetalANGLE - 通过Metal实现OpenGL ES，性能较好";
        case 2: return @"MobileGlues - 移动端OpenGL模拟";
        case 3: return @"Zink + Vulkan - OpenGL over Vulkan (实验性)";
        default: return @"";
    }
}

#pragma mark - Java设置

- (void)buildJavaSection {
    UIView *card = [self createSectionCardWithTitle:@"Java 设置"];

    self.javaModeSegment = [[UISegmentedControl alloc] initWithItems:@[@"自动选择", @"手动指定"]];
    self.javaModeSegment.translatesAutoresizingMaskIntoConstraints = NO;
    self.javaModeSegment.selectedSegmentIndex = self.instance.autoSelectJava ? 0 : 1;
    self.javaModeSegment.tintColor = PCLColor(0x1370F3);
    [card addSubview:self.javaModeSegment];

    self.javaPicker = [[UIPickerView alloc] init];
    self.javaPicker.translatesAutoresizingMaskIntoConstraints = NO;
    self.javaPicker.dataSource = self;
    self.javaPicker.delegate = self;
    self.javaPicker.tag = 2002;
    self.javaPicker.hidden = self.instance.autoSelectJava;

    if (!self.instance.autoSelectJava) {
        NSInteger idx = [self.javaVersions indexOfObject:self.instance.javaVersion];
        if (idx != NSNotFound) {
            [self.javaPicker selectRow:idx inComponent:0 animated:NO];
            self.selectedJavaIndex = idx;
        }
    }

    [card addSubview:self.javaPicker];

    [self.javaModeSegment addTarget:self action:@selector(javaModeChanged:) forControlEvents:UIControlEventValueChanged];

    CGFloat pickerH = MIN(120, self.javaVersions.count * 44);
    [NSLayoutConstraint activateConstraints:@[
        [self.javaModeSegment.topAnchor constraintEqualToAnchor:card.topAnchor constant:48],
        [self.javaModeSegment.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [self.javaModeSegment.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [self.javaModeSegment.heightAnchor constraintEqualToConstant:30],
        [self.javaPicker.topAnchor constraintEqualToAnchor:self.javaModeSegment.bottomAnchor constant:4],
        [self.javaPicker.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [self.javaPicker.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [self.javaPicker.heightAnchor constraintEqualToConstant:pickerH],
        [card.bottomAnchor constraintEqualToAnchor:self.javaPicker.bottomAnchor constant:8]
    ]];

    [self.stackView addArrangedSubview:card];
}

- (void)javaModeChanged:(UISegmentedControl *)sender {
    self.javaPicker.hidden = (sender.selectedSegmentIndex == 0);
    if (sender.selectedSegmentIndex == 0) {
        self.instance.autoSelectJava = YES;
    } else {
        self.instance.autoSelectJava = NO;
    }
}

#pragma mark - 内存设置

- (void)buildMemorySection {
    UIView *card = [self createSectionCardWithTitle:@"内存设置"];

    UILabel *memTitle = [[UILabel alloc] init];
    memTitle.text = @"最大内存分配";
    memTitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    memTitle.textColor = PCLColor(0x343D4A);
    memTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:memTitle];

    self.memorySlider = [[UISlider alloc] init];
    self.memorySlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.memorySlider.minimumValue = 512;
    self.memorySlider.maximumValue = 8192;
    self.memorySlider.value = self.instance.memoryMaxMB > 0 ? self.instance.memoryMaxMB : 2048;
    self.memorySlider.tintColor = PCLColor(0x1370F3);
    [self.memorySlider addTarget:self action:@selector(memoryChanged:) forControlEvents:UIControlEventValueChanged];
    [card addSubview:self.memorySlider];

    self.memoryLabel = [[UILabel alloc] init];
    NSInteger memVal = (NSInteger)(self.memorySlider.value / 256) * 256;
    self.memoryLabel.text = [NSString stringWithFormat:@"%ld MB", (long)memVal];
    self.memoryLabel.font = [UIFont systemFontOfSize:13];
    self.memoryLabel.textColor = PCLColor(0x8C8C8C);
    self.memoryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:self.memoryLabel];

    [NSLayoutConstraint activateConstraints:@[
        [memTitle.topAnchor constraintEqualToAnchor:card.topAnchor constant:48],
        [memTitle.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [self.memorySlider.topAnchor constraintEqualToAnchor:memTitle.bottomAnchor constant:8],
        [self.memorySlider.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [self.memorySlider.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-80],
        [self.memoryLabel.centerYAnchor constraintEqualToAnchor:self.memorySlider.centerYAnchor],
        [self.memoryLabel.leadingAnchor constraintEqualToAnchor:self.memorySlider.trailingAnchor constant:8],
        [self.memoryLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [card.bottomAnchor constraintEqualToAnchor:self.memorySlider.bottomAnchor constant:14]
    ]];

    [self.stackView addArrangedSubview:card];
}

- (void)memoryChanged:(UISlider *)slider {
    NSInteger value = (NSInteger)(slider.value / 256) * 256;
    self.memoryLabel.text = [NSString stringWithFormat:@"%ld MB", (long)value];
}

#pragma mark - 分辨率

- (void)buildResolutionSection {
    UIView *card = [self createSectionCardWithTitle:@"游戏分辨率"];

    UILabel *widthTitle = [[UILabel alloc] init];
    widthTitle.text = @"宽度";
    widthTitle.font = [UIFont systemFontOfSize:13];
    widthTitle.textColor = PCLColor(0x8C8C8C);
    widthTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:widthTitle];

    self.widthField = [[UITextField alloc] init];
    self.widthField.translatesAutoresizingMaskIntoConstraints = NO;
    self.widthField.text = [NSString stringWithFormat:@"%ld", (long)self.instance.resolutionWidth];
    self.widthField.keyboardType = UIKeyboardTypeNumberPad;
    self.widthField.font = [UIFont systemFontOfSize:14];
    self.widthField.borderStyle = UITextBorderStyleRoundedRect;
    self.widthField.textColor = PCLColor(0x343D4A);
    [card addSubview:self.widthField];

    UILabel *heightTitle = [[UILabel alloc] init];
    heightTitle.text = @"高度";
    heightTitle.font = [UIFont systemFontOfSize:13];
    heightTitle.textColor = PCLColor(0x8C8C8C);
    heightTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:heightTitle];

    self.heightField = [[UITextField alloc] init];
    self.heightField.translatesAutoresizingMaskIntoConstraints = NO;
    self.heightField.text = [NSString stringWithFormat:@"%ld", (long)self.instance.resolutionHeight];
    self.heightField.keyboardType = UIKeyboardTypeNumberPad;
    self.heightField.font = [UIFont systemFontOfSize:14];
    self.heightField.borderStyle = UITextBorderStyleRoundedRect;
    self.heightField.textColor = PCLColor(0x343D4A);
    [card addSubview:self.heightField];

    [NSLayoutConstraint activateConstraints:@[
        [widthTitle.topAnchor constraintEqualToAnchor:card.topAnchor constant:48],
        [widthTitle.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [self.widthField.topAnchor constraintEqualToAnchor:widthTitle.bottomAnchor constant:4],
        [self.widthField.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [self.widthField.widthAnchor constraintEqualToConstant:100],
        [self.widthField.heightAnchor constraintEqualToConstant:32],
        [heightTitle.topAnchor constraintEqualToAnchor:card.topAnchor constant:48],
        [heightTitle.leadingAnchor constraintEqualToAnchor:self.widthField.trailingAnchor constant:16],
        [self.heightField.topAnchor constraintEqualToAnchor:heightTitle.bottomAnchor constant:4],
        [self.heightField.leadingAnchor constraintEqualToAnchor:self.widthField.trailingAnchor constant:16],
        [self.heightField.widthAnchor constraintEqualToConstant:100],
        [self.heightField.heightAnchor constraintEqualToConstant:32],
        [card.bottomAnchor constraintEqualToAnchor:self.widthField.bottomAnchor constant:14]
    ]];

    [self.stackView addArrangedSubview:card];
}

#pragma mark - 版本隔离 (参考PCL2-CE)

- (void)buildVersionIsolationSection {
    UIView *card = [self createSectionCardWithTitle:@"版本隔离"];

    UILabel *isolationLabel = [[UILabel alloc] init];
    isolationLabel.text = @"启用版本隔离";
    isolationLabel.font = [UIFont systemFontOfSize:14];
    isolationLabel.textColor = PCLColor(0x343D4A);
    isolationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:isolationLabel];

    self.versionIsolationSwitch = [[UISwitch alloc] init];
    self.versionIsolationSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.versionIsolationSwitch.onTintColor = PCLColor(0x1370F3);
    self.versionIsolationSwitch.on = self.instance.versionIsolation;
    [self.versionIsolationSwitch addTarget:self action:@selector(versionIsolationChanged:) forControlEvents:UIControlEventValueChanged];
    [card addSubview:self.versionIsolationSwitch];

    self.versionIsolationDescLabel = [[UILabel alloc] init];
    self.versionIsolationDescLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.versionIsolationDescLabel.font = [UIFont systemFontOfSize:12];
    self.versionIsolationDescLabel.textColor = PCLColor(0x8C8C8C);
    self.versionIsolationDescLabel.numberOfLines = 0;
    self.versionIsolationDescLabel.text = self.instance.versionIsolation ?
        @"已启用: 该实例拥有独立的游戏目录、mods、config等，不影响其他实例" :
        @"已关闭: 该实例与其他实例共享 .minecraft 目录";
    [card addSubview:self.versionIsolationDescLabel];

    [NSLayoutConstraint activateConstraints:@[
        [isolationLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [isolationLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:48],
        [self.versionIsolationSwitch.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [self.versionIsolationSwitch.centerYAnchor constraintEqualToAnchor:isolationLabel.centerYAnchor],
        [self.versionIsolationDescLabel.topAnchor constraintEqualToAnchor:isolationLabel.bottomAnchor constant:8],
        [self.versionIsolationDescLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [self.versionIsolationDescLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [card.bottomAnchor constraintEqualToAnchor:self.versionIsolationDescLabel.bottomAnchor constant:14]
    ]];

    [self.stackView addArrangedSubview:card];
}

- (void)versionIsolationChanged:(UISwitch *)sender {
    self.instance.versionIsolation = sender.on;
    self.versionIsolationDescLabel.text = sender.on ?
        @"已启用: 该实例拥有独立的游戏目录、mods、config等，不影响其他实例" :
        @"已关闭: 该实例与其他实例共享 .minecraft 目录";
}

#pragma mark - JVM参数

- (void)buildJvmArgsSection {
    UIView *card = [self createSectionCardWithTitle:@"JVM 参数"];

    UILabel *hintLabel = [[UILabel alloc] init];
    hintLabel.text = @"自定义 JVM 启动参数";
    hintLabel.font = [UIFont systemFontOfSize:12];
    hintLabel.textColor = PCLColor(0x8C8C8C);
    hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:hintLabel];

    self.jvmArgsView = [[UITextView alloc] init];
    self.jvmArgsView.translatesAutoresizingMaskIntoConstraints = NO;
    self.jvmArgsView.text = self.instance.javaArgs ?: @"";
    self.jvmArgsView.font = [UIFont systemFontOfSize:13];
    self.jvmArgsView.textColor = PCLColor(0x343D4A);
    self.jvmArgsView.backgroundColor = PCLColor(0xF8F9FA);
    self.jvmArgsView.layer.cornerRadius = 6;
    self.jvmArgsView.layer.borderWidth = 1;
    self.jvmArgsView.layer.borderColor = PCLColor(0xE0E0E0).CGColor;
    self.jvmArgsView.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
    [card addSubview:self.jvmArgsView];

    [NSLayoutConstraint activateConstraints:@[
        [hintLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:48],
        [hintLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [hintLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [self.jvmArgsView.topAnchor constraintEqualToAnchor:hintLabel.bottomAnchor constant:6],
        [self.jvmArgsView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [self.jvmArgsView.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [self.jvmArgsView.heightAnchor constraintEqualToConstant:80],
        [card.bottomAnchor constraintEqualToAnchor:self.jvmArgsView.bottomAnchor constant:14]
    ]];

    [self.stackView addArrangedSubview:card];
}

#pragma mark - 高级选项

- (void)buildAdvancedSection {
    UIView *card = [self createSectionCardWithTitle:@"高级选项"];

    UILabel *autoLoginLabel = [[UILabel alloc] init];
    autoLoginLabel.text = @"自动启动游戏";
    autoLoginLabel.font = [UIFont systemFontOfSize:14];
    autoLoginLabel.textColor = PCLColor(0x343D4A);
    autoLoginLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:autoLoginLabel];

    self.autoLoginSwitch = [[UISwitch alloc] init];
    self.autoLoginSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.autoLoginSwitch.onTintColor = PCLColor(0x1370F3);
    [card addSubview:self.autoLoginSwitch];

    [NSLayoutConstraint activateConstraints:@[
        [autoLoginLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [autoLoginLabel.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [self.autoLoginSwitch.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [self.autoLoginSwitch.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [card.heightAnchor constraintEqualToConstant:52]
    ]];

    [self.stackView addArrangedSubview:card];
}

#pragma mark - UIPickerView

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    if (pickerView.tag == 2001) {
        return self.installedVersions.count;
    } else if (pickerView.tag == 2002) {
        return self.javaVersions.count;
    }
    return 0;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    if (pickerView.tag == 2001) {
        return self.installedVersions[row];
    } else if (pickerView.tag == 2002) {
        return self.javaVersions[row];
    }
    return @"";
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    if (pickerView.tag == 2001) {
        self.instance.versionId = self.installedVersions[row];
    } else if (pickerView.tag == 2002) {
        self.selectedJavaIndex = row;
        self.instance.javaVersion = self.javaVersions[row];
    }
}

#pragma mark - Actions

- (void)cancelPressed {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)savePressed {
    NSString *name = self.nameField.text ?: @"";
    if (name.length == 0) {
        [self showAlertWithTitle:@"错误" message:@"请输入实例名称"];
        return;
    }

    self.instance.name = name;

    if (self.javaModeSegment.selectedSegmentIndex == 0) {
        self.instance.autoSelectJava = YES;
        self.instance.javaVersion = @"auto";
    } else {
        self.instance.autoSelectJava = NO;
        if (self.selectedJavaIndex < self.javaVersions.count) {
            self.instance.javaVersion = self.javaVersions[self.selectedJavaIndex];
        }
    }

    NSInteger memVal = (NSInteger)(self.memorySlider.value / 256) * 256;
    self.instance.memoryMaxMB = memVal;
    self.instance.javaArgs = self.jvmArgsView.text ?: [NSString stringWithFormat:@"-Xmx%ldM -Xms512M", (long)memVal];

    self.instance.resolutionWidth = [self.widthField.text integerValue] ?: 1280;
    self.instance.resolutionHeight = [self.heightField.text integerValue] ?: 720;

    [[PCLInstanceManager sharedManager] saveInstance:self.instance];
    [[PCLInstanceManager sharedManager] selectInstance:self.instance];

    if (self.onSaved) self.onSaved();
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
}

@end
