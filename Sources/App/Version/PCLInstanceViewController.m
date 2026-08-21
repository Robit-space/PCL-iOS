#import "PCLInstanceViewController.h"
#import "PCLInstanceManager.h"
#import "PCLInstanceEditViewController.h"
#import "PCLVersionManager.h"
#import "PCLCEPageAnimator.h"
#import <objc/runtime.h>

static UIColor *PCLColor(NSUInteger rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
                           green:((rgb >> 8) & 255) / 255.0
                            blue:(rgb & 255) / 255.0
                           alpha:1.0];
}

#pragma mark - Instance Cell

@interface PCLInstanceCell : UICollectionViewCell
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *versionLabel;
@property (nonatomic, strong) UIView *selectionIndicator;
@end

@implementation PCLInstanceCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor = PCLColor(0xFAFBFC);
    self.layer.cornerRadius = 8;
    self.layer.borderWidth = 1;
    self.layer.borderColor = PCLColor(0xE8E8E8).CGColor;

    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.nameLabel.textColor = PCLColor(0x343D4A);
    [self.contentView addSubview:self.nameLabel];

    self.versionLabel = [[UILabel alloc] init];
    self.versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.versionLabel.font = [UIFont systemFontOfSize:12];
    self.versionLabel.textColor = PCLColor(0x8C8C8C);
    [self.contentView addSubview:self.versionLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:10],
        [self.nameLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-10],
        [self.versionLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:2],
        [self.versionLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:10],
        [self.versionLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-10]
    ]];

    return self;
}

@end

#pragma mark - Instance Left View

@interface PCLInstanceLeftView : UICollectionView <UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic, strong) NSArray<PCLInstance *> *instances;
@property (nonatomic, copy) void (^onSelectInstance)(PCLInstance *instance);
@property (nonatomic, copy) void (^onCreateInstance)(void);
@property (nonatomic, copy) void (^onDeleteInstance)(PCLInstance *instance);
@property (nonatomic, weak) PCLInstance *selectedInstance;
@end

@implementation PCLInstanceLeftView

- (instancetype)initWithFrame:(CGRect)frame {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = CGSizeMake(frame.size.width - 16, 56);
    layout.minimumLineSpacing = 6;
    layout.sectionInset = UIEdgeInsetsMake(8, 8, 8, 8);

    self = [super initWithFrame:frame collectionViewLayout:layout];
    if (!self) return nil;
    self.backgroundColor = PCLColor(0xF4F5F7);
    self.dataSource = self;
    self.delegate = self;
    [self registerClass:[PCLInstanceCell class] forCellWithReuseIdentifier:@"InstanceCell"];

    return self;
}

- (void)setInstances:(NSArray<PCLInstance *> *)instances {
    _instances = instances;
    [self reloadData];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.instances.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PCLInstanceCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"InstanceCell" forIndexPath:indexPath];
    PCLInstance *instance = self.instances[indexPath.item];
    cell.nameLabel.text = instance.name;
    cell.versionLabel.text = instance.versionId;

    if ([instance.name isEqualToString:self.selectedInstance.name]) {
        cell.contentView.backgroundColor = PCLColor(0xE8F0FE);
        cell.layer.borderColor = PCLColor(0x1370F3).CGColor;
    } else {
        cell.contentView.backgroundColor = PCLColor(0xFAFBFC);
        cell.layer.borderColor = PCLColor(0xE8E8E8).CGColor;
    }

    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    PCLInstance *instance = self.instances[indexPath.item];
    self.selectedInstance = instance;
    [collectionView reloadData];
    if (self.onSelectInstance) self.onSelectInstance(instance);
}

@end

#pragma mark - Instance Right View

@interface PCLInstanceRightView : UIView <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic) PCLInstanceTab currentTab;
@property (nonatomic, strong) PCLInstance *currentInstance;
@property (nonatomic, strong) UITableView *versionTableView;
@property (nonatomic, strong) NSArray<PCLVersionInfo *> *availableVersions;
@property (nonatomic) CGFloat designScale;
@property (nonatomic, copy) void (^onEditInstance)(PCLInstance *instance);
@property (nonatomic, copy) void (^onLaunchInstance)(PCLInstance *instance);
@property (nonatomic, copy) void (^onOpenFolder)(PCLInstance *instance);
@property (nonatomic, strong) UISegmentedControl *javaModeSegment;
@property (nonatomic, strong) UISlider *memorySlider;
@property (nonatomic, strong) UILabel *memoryLabel;
@property (nonatomic, strong) UITextView *jvmArgsTextView;
@property (nonatomic, weak) PCLInstanceViewController *parent;
@end

@implementation PCLInstanceRightView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _currentTab = PCLInstanceTabOverview;
        _designScale = 1.0;
        [self setupScrollView];
    }
    return self;
}

- (void)setupScrollView {
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

    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 14;
    self.contentStack.alignment = UIStackViewAlignmentFill;
    self.contentStack.distribution = UIStackViewDistributionFill;
    [self.scrollView addSubview:self.contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor constant:16],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor constant:16],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor constant:-16],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:-16],
        [self.contentStack.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor constant:-32]
    ]];
}

- (void)switchToTab:(PCLInstanceTab)tab withInstance:(PCLInstance *)instance {
    self.currentTab = tab;
    self.currentInstance = instance;

    [self.contentStack.arrangedSubviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

    switch (tab) {
        case PCLInstanceTabOverview:    [self buildOverviewTab:instance]; break;
        case PCLInstanceTabSettings:    [self buildSettingsTab:instance]; break;
        case PCLInstanceTabInstall:     [self buildInstallTab:instance]; break;
        case PCLInstanceTabExport:      [self buildExportTab:instance]; break;
        case PCLInstanceTabSaves:       [self buildSavesTab:instance]; break;
        case PCLInstanceTabScreenshots: [self buildScreenshotsTab:instance]; break;
        case PCLInstanceTabMods:        [self buildModsTab:instance]; break;
        case PCLInstanceTabResourcePacks: [self buildResourcePacksTab:instance]; break;
        case PCLInstanceTabShaders:     [self buildShadersTab:instance]; break;
    }
}

#pragma mark - Card Helper

- (UIView *)createCardWithTitle:(NSString *)title {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 10;
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOpacity = 0.05;
    card.layer.shadowRadius = 6;
    card.layer.shadowOffset = CGSizeMake(0, 2);
    card.translatesAutoresizingMaskIntoConstraints = NO;

    if (title.length > 0) {
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.text = title;
        titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        titleLabel.textColor = PCLColor(0x343D4A);
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:titleLabel];

        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
            [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
            [titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16]
        ]];
    }

    return card;
}

- (UIView *)createActionRowWithTitle:(NSString *)subtitle action:(void (^)(void))action buttonTitle:(NSString *)buttonTitle {
    UIView *card = [self createCardWithTitle:@""];

    UILabel *label = [[UILabel alloc] init];
    label.text = subtitle;
    label.font = [UIFont systemFontOfSize:13];
    label.textColor = PCLColor(0x8C8C8C);
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:label];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn setTitle:buttonTitle forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    btn.backgroundColor = PCLColor(0x1370F3);
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.layer.cornerRadius = 6;
    btn.contentEdgeInsets = UIEdgeInsetsMake(6, 14, 6, 14);
    objc_setAssociatedObject(btn, "action", action, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [btn addTarget:self action:@selector(actionButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:btn];

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [label.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [btn.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [btn.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [card.heightAnchor constraintEqualToConstant:50]
    ]];

    return card;
}

- (void)actionButtonPressed:(UIButton *)sender {
    void (^action)(void) = objc_getAssociatedObject(sender, "action");
    if (action) action();
}

#pragma mark - Overview Tab

- (void)buildOverviewTab:(PCLInstance *)instance {
    if (!instance) {
        UILabel *placeholder = [[UILabel alloc] init];
        placeholder.text = @"请从左侧选择或创建一个实例";
        placeholder.font = [UIFont systemFontOfSize:15];
        placeholder.textColor = PCLColor(0x8C8C8C);
        placeholder.textAlignment = NSTextAlignmentCenter;
        placeholder.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentStack addArrangedSubview:placeholder];
        [self.contentStack addArrangedSubview:[[UIView alloc] init]];
        return;
    }

    UIView *infoCard = [self createCardWithTitle:@"实例信息"];

    UILabel *nameValue = [[UILabel alloc] init];
    nameValue.text = [NSString stringWithFormat:@"名称: %@", instance.name];
    nameValue.font = [UIFont systemFontOfSize:14];
    nameValue.textColor = PCLColor(0x343D4A);
    nameValue.translatesAutoresizingMaskIntoConstraints = NO;
    [infoCard addSubview:nameValue];

    UILabel *versionValue = [[UILabel alloc] init];
    versionValue.text = [NSString stringWithFormat:@"版本: %@", instance.versionId];
    versionValue.font = [UIFont systemFontOfSize:14];
    versionValue.textColor = PCLColor(0x343D4A);
    versionValue.translatesAutoresizingMaskIntoConstraints = NO;
    [infoCard addSubview:versionValue];

    UILabel *dirValue = [[UILabel alloc] init];
    dirValue.text = [NSString stringWithFormat:@"路径: %@", instance.gameDir];
    dirValue.font = [UIFont systemFontOfSize:12];
    dirValue.textColor = PCLColor(0x8C8C8C);
    dirValue.numberOfLines = 0;
    dirValue.translatesAutoresizingMaskIntoConstraints = NO;
    [infoCard addSubview:dirValue];

    [NSLayoutConstraint activateConstraints:@[
        [nameValue.topAnchor constraintEqualToAnchor:infoCard.topAnchor constant:48],
        [nameValue.leadingAnchor constraintEqualToAnchor:infoCard.leadingAnchor constant:16],
        [nameValue.trailingAnchor constraintEqualToAnchor:infoCard.trailingAnchor constant:-16],
        [versionValue.topAnchor constraintEqualToAnchor:nameValue.bottomAnchor constant:6],
        [versionValue.leadingAnchor constraintEqualToAnchor:infoCard.leadingAnchor constant:16],
        [versionValue.trailingAnchor constraintEqualToAnchor:infoCard.trailingAnchor constant:-16],
        [dirValue.topAnchor constraintEqualToAnchor:versionValue.bottomAnchor constant:6],
        [dirValue.leadingAnchor constraintEqualToAnchor:infoCard.leadingAnchor constant:16],
        [dirValue.trailingAnchor constraintEqualToAnchor:infoCard.trailingAnchor constant:-16],
        [infoCard.bottomAnchor constraintEqualToAnchor:dirValue.bottomAnchor constant:16]
    ]];

    [self.contentStack addArrangedSubview:infoCard];

    UIView *launchRow = [self createActionRowWithTitle:@"启动游戏" action:^{
        if (self.onLaunchInstance) self.onLaunchInstance(instance);
    } buttonTitle:@"启动"];
    [self.contentStack addArrangedSubview:launchRow];

    UIView *editRow = [self createActionRowWithTitle:@"编辑实例配置" action:^{
        if (self.onEditInstance) self.onEditInstance(instance);
    } buttonTitle:@"编辑"];
    [self.contentStack addArrangedSubview:editRow];

    UIView *folderRow = [self createActionRowWithTitle:@"打开实例文件夹" action:^{
        if (self.onOpenFolder) self.onOpenFolder(instance);
    } buttonTitle:@"打开"];
    [self.contentStack addArrangedSubview:folderRow];

    [self.contentStack addArrangedSubview:[[UIView alloc] init]];
}

#pragma mark - Settings Tab

- (void)buildSettingsTab:(PCLInstance *)instance {
    if (!instance) {
        UILabel *placeholder = [[UILabel alloc] init];
        placeholder.text = @"请先选择一个实例";
        placeholder.font = [UIFont systemFontOfSize:15];
        placeholder.textColor = PCLColor(0x8C8C8C);
        placeholder.textAlignment = NSTextAlignmentCenter;
        [self.contentStack addArrangedSubview:placeholder];
        [self.contentStack addArrangedSubview:[[UIView alloc] init]];
        return;
    }

    UIView *javaCard = [self createCardWithTitle:@"Java 设置"];

    UILabel *modeLabel = [[UILabel alloc] init];
    modeLabel.text = @"Java 选择";
    modeLabel.font = [UIFont systemFontOfSize:13];
    modeLabel.textColor = PCLColor(0x8C8C8C);
    modeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [javaCard addSubview:modeLabel];

    self.javaModeSegment = [[UISegmentedControl alloc] initWithItems:@[@"自动选择", @"手动指定"]];
    self.javaModeSegment.translatesAutoresizingMaskIntoConstraints = NO;
    self.javaModeSegment.selectedSegmentIndex = instance.autoSelectJava ? 0 : 1;
    self.javaModeSegment.tintColor = PCLColor(0x1370F3);
    [self.javaModeSegment addTarget:self action:@selector(javaModeChanged:) forControlEvents:UIControlEventValueChanged];
    [javaCard addSubview:self.javaModeSegment];

    UILabel *javaVersionLabel = [[UILabel alloc] init];
    javaVersionLabel.text = instance.javaVersion ?: @"auto";
    javaVersionLabel.font = [UIFont systemFontOfSize:13];
    javaVersionLabel.textColor = PCLColor(0x343D4A);
    javaVersionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    javaVersionLabel.tag = 100;
    [javaCard addSubview:javaVersionLabel];

    [NSLayoutConstraint activateConstraints:@[
        [modeLabel.topAnchor constraintEqualToAnchor:javaCard.topAnchor constant:48],
        [modeLabel.leadingAnchor constraintEqualToAnchor:javaCard.leadingAnchor constant:16],
        [self.javaModeSegment.topAnchor constraintEqualToAnchor:modeLabel.bottomAnchor constant:6],
        [self.javaModeSegment.leadingAnchor constraintEqualToAnchor:javaCard.leadingAnchor constant:16],
        [self.javaModeSegment.trailingAnchor constraintEqualToAnchor:javaCard.trailingAnchor constant:-16],
        [self.javaModeSegment.heightAnchor constraintEqualToConstant:30],
        [javaVersionLabel.topAnchor constraintEqualToAnchor:self.javaModeSegment.bottomAnchor constant:8],
        [javaVersionLabel.leadingAnchor constraintEqualToAnchor:javaCard.leadingAnchor constant:16],
        [javaVersionLabel.trailingAnchor constraintEqualToAnchor:javaCard.trailingAnchor constant:-16],
        [javaCard.bottomAnchor constraintEqualToAnchor:javaVersionLabel.bottomAnchor constant:16]
    ]];

    [self.contentStack addArrangedSubview:javaCard];

    UIView *memCard = [self createCardWithTitle:@"内存设置"];

    UILabel *memLabel = [[UILabel alloc] init];
    memLabel.text = @"最大内存";
    memLabel.font = [UIFont systemFontOfSize:13];
    memLabel.textColor = PCLColor(0x8C8C8C);
    memLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [memCard addSubview:memLabel];

    self.memorySlider = [[UISlider alloc] init];
    self.memorySlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.memorySlider.minimumValue = 512;
    self.memorySlider.maximumValue = 8192;
    self.memorySlider.value = instance.memoryMaxMB > 0 ? instance.memoryMaxMB : 2048;
    self.memorySlider.tintColor = PCLColor(0x1370F3);
    [self.memorySlider addTarget:self action:@selector(memorySliderChanged:) forControlEvents:UIControlEventValueChanged];
    [memCard addSubview:self.memorySlider];

    self.memoryLabel = [[UILabel alloc] init];
    self.memoryLabel.text = [NSString stringWithFormat:@"%ld MB", (long)instance.memoryMaxMB];
    self.memoryLabel.font = [UIFont systemFontOfSize:13];
    self.memoryLabel.textColor = PCLColor(0x343D4A);
    self.memoryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [memCard addSubview:self.memoryLabel];

    [NSLayoutConstraint activateConstraints:@[
        [memLabel.topAnchor constraintEqualToAnchor:memCard.topAnchor constant:48],
        [memLabel.leadingAnchor constraintEqualToAnchor:memCard.leadingAnchor constant:16],
        [self.memorySlider.topAnchor constraintEqualToAnchor:memLabel.bottomAnchor constant:6],
        [self.memorySlider.leadingAnchor constraintEqualToAnchor:memCard.leadingAnchor constant:16],
        [self.memorySlider.trailingAnchor constraintEqualToAnchor:memCard.trailingAnchor constant:-70],
        [self.memoryLabel.centerYAnchor constraintEqualToAnchor:self.memorySlider.centerYAnchor],
        [self.memoryLabel.leadingAnchor constraintEqualToAnchor:self.memorySlider.trailingAnchor constant:8],
        [self.memoryLabel.trailingAnchor constraintEqualToAnchor:memCard.trailingAnchor constant:-16],
        [memCard.bottomAnchor constraintEqualToAnchor:self.memorySlider.bottomAnchor constant:16]
    ]];

    [self.contentStack addArrangedSubview:memCard];

    UIView *jvmCard = [self createCardWithTitle:@"JVM 参数"];

    UILabel *jvmLabel = [[UILabel alloc] init];
    jvmLabel.text = [NSString stringWithFormat:@"当前: %@", instance.javaArgs ?: @""];
    jvmLabel.font = [UIFont systemFontOfSize:12];
    jvmLabel.textColor = PCLColor(0x8C8C8C);
    jvmLabel.numberOfLines = 0;
    jvmLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [jvmCard addSubview:jvmLabel];

    [NSLayoutConstraint activateConstraints:@[
        [jvmLabel.topAnchor constraintEqualToAnchor:jvmCard.topAnchor constant:48],
        [jvmLabel.leadingAnchor constraintEqualToAnchor:jvmCard.leadingAnchor constant:16],
        [jvmLabel.trailingAnchor constraintEqualToAnchor:jvmCard.trailingAnchor constant:-16],
        [jvmCard.bottomAnchor constraintEqualToAnchor:jvmLabel.bottomAnchor constant:16]
    ]];

    [self.contentStack addArrangedSubview:jvmCard];

    UIButton *saveBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    saveBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [saveBtn setTitle:@"保存设置" forState:UIControlStateNormal];
    saveBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    saveBtn.backgroundColor = PCLColor(0x1370F3);
    [saveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    saveBtn.layer.cornerRadius = 8;
    [saveBtn addTarget:self action:@selector(saveSettings:) forControlEvents:UIControlEventTouchUpInside];
    objc_setAssociatedObject(saveBtn, "instance", instance, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [saveBtn.heightAnchor constraintEqualToConstant:44].active = YES;
    [self.contentStack addArrangedSubview:saveBtn];

    [self.contentStack addArrangedSubview:[[UIView alloc] init]];
}

- (void)javaModeChanged:(UISegmentedControl *)sender {
    if (sender.selectedSegmentIndex == 0) {
        self.currentInstance.autoSelectJava = YES;
    } else {
        self.currentInstance.autoSelectJava = NO;
    }
}

- (void)memorySliderChanged:(UISlider *)slider {
    NSInteger value = (NSInteger)(slider.value / 256) * 256;
    self.memoryLabel.text = [NSString stringWithFormat:@"%ld MB", (long)value];
    if (self.currentInstance) {
        self.currentInstance.memoryMaxMB = value;
        self.currentInstance.javaArgs = [NSString stringWithFormat:@"-Xmx%ldM -Xms512M", (long)value];
    }
}

- (void)saveSettings:(UIButton *)sender {
    PCLInstance *instance = objc_getAssociatedObject(sender, "instance");
    if (!instance) return;

    instance.autoSelectJava = (self.javaModeSegment.selectedSegmentIndex == 0);
    instance.memoryMaxMB = (NSInteger)(self.memorySlider.value / 256) * 256;
    instance.javaArgs = [NSString stringWithFormat:@"-Xmx%ldM -Xms512M", (long)instance.memoryMaxMB];

    [[PCLInstanceManager sharedManager] saveInstance:instance];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"保存成功"
                                                                   message:@"实例设置已保存"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self.parent presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Install Tab

- (void)buildInstallTab:(PCLInstance *)instance {
    if (!instance) {
        UILabel *placeholder = [[UILabel alloc] init];
        placeholder.text = @"请先选择一个实例";
        placeholder.font = [UIFont systemFontOfSize:15];
        placeholder.textColor = PCLColor(0x8C8C8C);
        placeholder.textAlignment = NSTextAlignmentCenter;
        [self.contentStack addArrangedSubview:placeholder];
        [self.contentStack addArrangedSubview:[[UIView alloc] init]];
        return;
    }

    UIView *card = [self createCardWithTitle:@"更换版本"];

    UILabel *currentLabel = [[UILabel alloc] init];
    currentLabel.text = [NSString stringWithFormat:@"当前版本: %@", instance.versionId];
    currentLabel.font = [UIFont systemFontOfSize:13];
    currentLabel.textColor = PCLColor(0x8C8C8C);
    currentLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:currentLabel];

    [NSLayoutConstraint activateConstraints:@[
        [currentLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:48],
        [currentLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [currentLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [card.bottomAnchor constraintEqualToAnchor:currentLabel.bottomAnchor constant:16]
    ]];

    [self.contentStack addArrangedSubview:card];

    NSArray *installed = [[PCLVersionManager sharedManager] localVersions];
    for (PCLVersionInfo *ver in installed) {
        UIView *verRow = [self createActionRowWithTitle:ver.versionId action:^{
            instance.versionId = ver.versionId;
            [[PCLInstanceManager sharedManager] saveInstance:instance];
        } buttonTitle:@"切换"];
        [self.contentStack addArrangedSubview:verRow];
    }

    [self.contentStack addArrangedSubview:[[UIView alloc] init]];
}

#pragma mark - Export / Saves / Screenshots / Mods / ResourcePacks / Shaders

- (void)buildExportTab:(PCLInstance *)instance {
    UIView *card = [self createCardWithTitle:@"导出实例"];
    UILabel *desc = [[UILabel alloc] init];
    desc.text = @"将当前实例打包为 zip 文件以便分享或备份。";
    desc.font = [UIFont systemFontOfSize:13];
    desc.textColor = PCLColor(0x8C8C8C);
    desc.numberOfLines = 0;
    desc.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:desc];

    [NSLayoutConstraint activateConstraints:@[
        [desc.topAnchor constraintEqualToAnchor:card.topAnchor constant:48],
        [desc.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [desc.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [card.bottomAnchor constraintEqualToAnchor:desc.bottomAnchor constant:16]
    ]];

    [self.contentStack addArrangedSubview:card];
    [self.contentStack addArrangedSubview:[[UIView alloc] init]];
}

- (void)buildSavesTab:(PCLInstance *)instance {
    UIView *card = [self createCardWithTitle:@"存档"];
    if (instance) {
        UILabel *pathLabel = [[UILabel alloc] init];
        NSString *savesPath = [instance.gameDir stringByAppendingPathComponent:@"saves"];
        pathLabel.text = savesPath;
        pathLabel.font = [UIFont systemFontOfSize:12];
        pathLabel.textColor = PCLColor(0x8C8C8C);
        pathLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:pathLabel];
        [NSLayoutConstraint activateConstraints:@[
            [pathLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:48],
            [pathLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
            [pathLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
            [card.bottomAnchor constraintEqualToAnchor:pathLabel.bottomAnchor constant:16]
        ]];
    } else {
        UILabel *placeholder = [[UILabel alloc] init];
        placeholder.text = @"请先选择一个实例";
        placeholder.font = [UIFont systemFontOfSize:14];
        placeholder.textColor = PCLColor(0x8C8C8C);
        placeholder.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:placeholder];
        [NSLayoutConstraint activateConstraints:@[
            [placeholder.topAnchor constraintEqualToAnchor:card.topAnchor constant:48],
            [placeholder.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
            [card.bottomAnchor constraintEqualToAnchor:placeholder.bottomAnchor constant:16]
        ]];
    }
    [self.contentStack addArrangedSubview:card];
    [self.contentStack addArrangedSubview:[[UIView alloc] init]];
}

- (void)buildScreenshotsTab:(PCLInstance *)instance {
    UIView *card = [self createCardWithTitle:@"截图"];
    UILabel *placeholder = [[UILabel alloc] init];
    placeholder.text = @"暂无截图";
    placeholder.font = [UIFont systemFontOfSize:14];
    placeholder.textColor = PCLColor(0x8C8C8C);
    placeholder.textAlignment = NSTextAlignmentCenter;
    placeholder.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:placeholder];
    [card.heightAnchor constraintEqualToConstant:100].active = YES;
    [NSLayoutConstraint activateConstraints:@[
        [placeholder.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [placeholder.centerYAnchor constraintEqualToAnchor:card.centerYAnchor]
    ]];
    [self.contentStack addArrangedSubview:card];
    [self.contentStack addArrangedSubview:[[UIView alloc] init]];
}

- (void)buildModsTab:(PCLInstance *)instance {
    UIView *card = [self createCardWithTitle:@"Mod 管理"];
    UILabel *placeholder = [[UILabel alloc] init];
    placeholder.text = @"暂无 Mod";
    placeholder.font = [UIFont systemFontOfSize:14];
    placeholder.textColor = PCLColor(0x8C8C8C);
    placeholder.textAlignment = NSTextAlignmentCenter;
    placeholder.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:placeholder];
    [card.heightAnchor constraintEqualToConstant:100].active = YES;
    [NSLayoutConstraint activateConstraints:@[
        [placeholder.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [placeholder.centerYAnchor constraintEqualToAnchor:card.centerYAnchor]
    ]];
    [self.contentStack addArrangedSubview:card];
    [self.contentStack addArrangedSubview:[[UIView alloc] init]];
}

- (void)buildResourcePacksTab:(PCLInstance *)instance {
    UIView *card = [self createCardWithTitle:@"资源包"];
    UILabel *placeholder = [[UILabel alloc] init];
    placeholder.text = @"暂无资源包";
    placeholder.font = [UIFont systemFontOfSize:14];
    placeholder.textColor = PCLColor(0x8C8C8C);
    placeholder.textAlignment = NSTextAlignmentCenter;
    placeholder.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:placeholder];
    [card.heightAnchor constraintEqualToConstant:100].active = YES;
    [NSLayoutConstraint activateConstraints:@[
        [placeholder.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [placeholder.centerYAnchor constraintEqualToAnchor:card.centerYAnchor]
    ]];
    [self.contentStack addArrangedSubview:card];
    [self.contentStack addArrangedSubview:[[UIView alloc] init]];
}

- (void)buildShadersTab:(PCLInstance *)instance {
    UIView *card = [self createCardWithTitle:@"着色器"];
    UILabel *placeholder = [[UILabel alloc] init];
    placeholder.text = @"暂无着色器";
    placeholder.font = [UIFont systemFontOfSize:14];
    placeholder.textColor = PCLColor(0x8C8C8C);
    placeholder.textAlignment = NSTextAlignmentCenter;
    placeholder.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:placeholder];
    [card.heightAnchor constraintEqualToConstant:100].active = YES;
    [NSLayoutConstraint activateConstraints:@[
        [placeholder.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [placeholder.centerYAnchor constraintEqualToAnchor:card.centerYAnchor]
    ]];
    [self.contentStack addArrangedSubview:card];
    [self.contentStack addArrangedSubview:[[UIView alloc] init]];
}

- (void)dismissTransientUI {}
- (void)prepareCEEnterAnimation { self.contentStack.alpha = 0; }
- (void)playCEEnterAnimation { [PCLCEPageAnimator showRightItems:self.contentStack.arrangedSubviews scrollView:self.scrollView]; }
- (void)playCEExitAnimation { [PCLCEPageAnimator hideRightItems:self.contentStack.arrangedSubviews scrollView:self.scrollView]; }
- (void)reloadState {}

@end

#pragma mark - Main View Controller

@interface PCLInstanceViewController () <UICollectionViewDelegate>

@property (nonatomic, strong) UICollectionView *leftCollectionView;
@property (nonatomic, strong) PCLInstanceRightView *rightView;
@property (nonatomic, strong) NSArray<PCLInstance *> *instances;
@property (nonatomic, strong) PCLInstance *selectedInstance;
@property (nonatomic, strong) CAGradientLayer *backgroundGradient;
@property (nonatomic, strong) UIView *leftShadowView;
@property (nonatomic, strong) CAGradientLayer *leftShadowGradient;
@property (nonatomic, strong) UIScrollView *tabScrollView;
@property (nonatomic, strong) UIStackView *tabStack;

@end

@implementation PCLInstanceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:251.0/255.0 green:251.0/255.0 blue:251.0/255.0 alpha:1.0];
    self.currentTab = PCLInstanceTabOverview;
    self.instances = [[PCLInstanceManager sharedManager] allInstances];
    PCLInstance *saved = [[PCLInstanceManager sharedManager] currentInstance];
    if (saved) self.selectedInstance = saved;

    [self buildCEBackground];
    [self buildUI];
}

- (void)buildCEBackground {
    self.backgroundGradient = [CAGradientLayer layer];
    self.backgroundGradient.colors = @[
        (id)[UIColor colorWithRed:.68 green:.80 blue:.98 alpha:1].CGColor,
        (id)[UIColor colorWithRed:.92 green:.96 blue:1 alpha:1].CGColor,
        (id)[UIColor colorWithRed:.76 green:.84 blue:.99 alpha:1].CGColor
    ];
    self.backgroundGradient.locations = @[@0, @.4, @1];
    self.backgroundGradient.startPoint = CGPointMake(.9, 0);
    self.backgroundGradient.endPoint = CGPointMake(.1, 1);
    [self.view.layer insertSublayer:self.backgroundGradient atIndex:0];
}

- (void)buildUI {
    [self buildLeftPanel];
    [self buildRightPanel];
    [self refreshInstanceList];
}

- (void)buildLeftPanel {
    UIView *leftContainer = [[UIView alloc] init];
    leftContainer.translatesAutoresizingMaskIntoConstraints = NO;
    leftContainer.backgroundColor = PCLColor(0xF4F5F7);
    [self.view addSubview:leftContainer];

    self.tabScrollView = [[UIScrollView alloc] init];
    self.tabScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabScrollView.showsHorizontalScrollIndicator = NO;
    [leftContainer addSubview:self.tabScrollView];

    self.tabStack = [[UIStackView alloc] init];
    self.tabStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabStack.axis = UILayoutConstraintAxisVertical;
    self.tabStack.spacing = 2;
    self.tabStack.alignment = UIStackViewAlignmentFill;
    self.tabStack.distribution = UIStackViewDistributionFill;
    [self.tabScrollView addSubview:self.tabStack];

    struct { PCLInstanceTab tab; NSString *title; } tabs[] = {
        {PCLInstanceTabOverview, @"概览"},
        {PCLInstanceTabSettings, @"设置"},
        {PCLInstanceTabInstall, @"安装"},
        {PCLInstanceTabExport, @"导出"},
        {PCLInstanceTabSaves, @"存档"},
        {PCLInstanceTabScreenshots, @"截图"},
        {PCLInstanceTabMods, @"Mod"},
        {PCLInstanceTabResourcePacks, @"资源包"},
        {PCLInstanceTabShaders, @"着色器"},
    };

    int count = sizeof(tabs) / sizeof(tabs[0]);
    for (int i = 0; i < count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        btn.tag = tabs[i].tab;
        [btn setTitle:tabs[i].title forState:UIControlStateNormal];
        [btn setTitleColor:PCLColor(0x343D4A) forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        btn.titleEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 0);
        btn.layer.cornerRadius = 6;
        [btn.heightAnchor constraintEqualToConstant:34].active = YES;
        [btn addTarget:self action:@selector(tabButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self.tabStack addArrangedSubview:btn];
    }

    UIButton *createBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    createBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [createBtn setTitle:@"+ 新建实例" forState:UIControlStateNormal];
    createBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [createBtn setTitleColor:PCLColor(0x1370F3) forState:UIControlStateNormal];
    [createBtn addTarget:self action:@selector(showCreateInstanceDialog) forControlEvents:UIControlEventTouchUpInside];
    [createBtn.heightAnchor constraintEqualToConstant:34].active = YES;
    [self.tabStack addArrangedSubview:createBtn];

    [self updateTabAppearance];

    [NSLayoutConstraint activateConstraints:@[
        [leftContainer.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [leftContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tabScrollView.topAnchor constraintEqualToAnchor:leftContainer.topAnchor constant:8],
        [self.tabScrollView.leadingAnchor constraintEqualToAnchor:leftContainer.leadingAnchor],
        [self.tabScrollView.trailingAnchor constraintEqualToAnchor:leftContainer.trailingAnchor],
        [self.tabScrollView.bottomAnchor constraintEqualToAnchor:leftContainer.bottomAnchor constant:-8],
        [self.tabStack.topAnchor constraintEqualToAnchor:self.tabScrollView.topAnchor],
        [self.tabStack.leadingAnchor constraintEqualToAnchor:self.tabScrollView.leadingAnchor constant:8],
        [self.tabStack.trailingAnchor constraintEqualToAnchor:self.tabScrollView.trailingAnchor constant:-8],
        [self.tabStack.bottomAnchor constraintEqualToAnchor:self.tabScrollView.bottomAnchor],
        [self.tabStack.widthAnchor constraintEqualToAnchor:self.tabScrollView.widthAnchor constant:-16]
    ]];

    self.leftCollectionView = (UICollectionView *)leftContainer;
}

- (void)buildRightPanel {
    self.rightView = [[PCLInstanceRightView alloc] init];
    self.rightView.translatesAutoresizingMaskIntoConstraints = NO;
    self.rightView.parent = self;
    [self.view addSubview:self.rightView];

    self.rightView.onEditInstance = ^(PCLInstance *instance) {
        [self showEditInstance:instance];
    };

    self.rightView.onLaunchInstance = ^(PCLInstance *instance) {
        NSLog(@"[PCLInstance] Launching instance: %@", instance.name);
    };

    self.rightView.onOpenFolder = ^(PCLInstance *instance) {
        NSLog(@"[PCLInstance] Opening folder: %@", instance.gameDir);
    };

    [self.rightView switchToTab:self.currentTab withInstance:self.selectedInstance];
}

- (void)tabButtonPressed:(UIButton *)sender {
    PCLInstanceTab tab = (PCLInstanceTab)sender.tag;
    self.currentTab = tab;
    [self updateTabAppearance];
    [self switchToTab:tab];
}

- (void)updateTabAppearance {
    for (UIView *view in self.tabStack.arrangedSubviews) {
        if (![view isKindOfClass:[UIButton class]]) continue;
        UIButton *btn = (UIButton *)view;
        if (btn.tag == 999) continue;
        BOOL selected = (btn.tag == self.currentTab);
        btn.backgroundColor = selected ? PCLColor(0x1370F3) : [UIColor clearColor];
        [btn setTitleColor:selected ? [UIColor whiteColor] : PCLColor(0x343D4A) forState:UIControlStateNormal];
    }
}

- (void)switchToTab:(PCLInstanceTab)tab {
    self.currentTab = tab;
    [self updateTabAppearance];
    [self.rightView switchToTab:tab withInstance:self.selectedInstance];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    self.backgroundGradient.frame = self.view.bounds;

    CGFloat leftW = self.leftPanelWidth > 0 ? MIN(self.leftPanelWidth, w * 0.6) : MIN(260, w * 0.35);

    for (UIView *subview in self.view.subviews) {
        if (subview.backgroundColor && CGColorEqualToColor(subview.backgroundColor.CGColor, PCLColor(0xF4F5F7).CGColor)) {
            subview.frame = CGRectMake(0, 0, leftW, h);
        }
    }

    self.rightView.frame = CGRectMake(leftW, 0, MAX(0, w - leftW), h);
}

#pragma mark - Instance Operations

- (void)refreshInstanceList {
    self.instances = [[PCLInstanceManager sharedManager] allInstances];
    if (self.instances.count > 0 && !self.selectedInstance) {
        self.selectedInstance = self.instances.firstObject;
        [self.rightView switchToTab:self.currentTab withInstance:self.selectedInstance];
    }
}

- (void)showCreateInstanceDialog {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"新建实例"
                                                                   message:@"输入实例名称和选择版本"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"实例名称";
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"创建" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = alert.textFields.firstObject.text;
        if (name.length == 0) return;

        NSArray *versions = [[PCLVersionManager sharedManager] localVersions];
        PCLVersionInfo *firstVersion = [versions firstObject];
        NSString *versionId = firstVersion.versionId ?: @"1.20.4";

        if ([[PCLInstanceManager sharedManager] createInstanceWithName:name versionId:versionId]) {
            [self refreshInstanceList];
        }
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showEditInstance:(PCLInstance *)instance {
    PCLInstanceEditViewController *editVC = [[PCLInstanceEditViewController alloc] initWithInstance:instance];
    __weak typeof(self) weakSelf = self;
    editVC.onSaved = ^{
        [weakSelf refreshInstanceList];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:editVC];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)dismissTransientUI {}
- (void)prepareCEEnterAnimation { self.rightView.contentStack.alpha = 0; }
- (void)playCEEnterAnimation { [PCLCEPageAnimator showRightItems:self.rightView.contentStack.arrangedSubviews scrollView:self.rightView.scrollView]; }
- (void)playCEExitWithCompletion:(dispatch_block_t)completion {
    [self dismissTransientUI];
    [PCLCEPageAnimator hideRightItems:self.rightView.contentStack.arrangedSubviews scrollView:self.rightView.scrollView];
    if (completion) completion();
}
- (void)reloadState { [self refreshInstanceList]; }

@end
