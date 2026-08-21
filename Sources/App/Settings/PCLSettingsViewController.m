#import "PCLSettingsViewController.h"

static UIColor *PCLColor(NSUInteger rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
                           green:((rgb >> 8) & 255) / 255.0
                            blue:(rgb & 255) / 255.0
                           alpha:1.0];
}

@interface PCLSettingsCard : UIView
@end

@implementation PCLSettingsCard

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        self.layer.cornerRadius = 12.0;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.06;
        self.layer.shadowRadius = 8.0;
        self.layer.shadowOffset = CGSizeMake(0, 2);
    }
    return self;
}

@end

@interface PCLSettingsViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UICollectionView *tabCollectionView;
@property (nonatomic, strong) PCLSettingsCard *contentCard;
@property (nonatomic, strong) UITableView *settingsTableView;
@property (nonatomic, strong) NSArray<NSString *> *tabTitles;
@property (nonatomic, strong) NSArray<NSArray<NSString *> *> *settingsItems;
@property (nonatomic, assign) NSInteger selectedTab;

@end

@implementation PCLSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithRed:0.96 green:0.97 blue:0.98 alpha:1.0];
    
    self.tabTitles = @[
        @"启动", @"Java", @"游戏管理", @"游戏关联",
        @"界面", @"语言", @"杂项", @"关于", @"更新", @"反馈", @"日志"
    ];
    
    self.settingsItems = @[
        @[@"启动时自动检查更新", @"关闭窗口时确认", @"启用调试模式"],
        @[@"Java 路径", @"最大内存", @"JVM 参数", @"自动选择 Java 版本"],
        @[@"游戏目录", @"版本隔离", @"启动后关闭启动器"],
        @[@"文件关联", @"协议注册"],
        @[@"主题颜色", @"背景图片", @"动画效果", @"字体设置"],
        @[@"语言选择"],
        @[@"检查更新", @"清除缓存", @"导出日志"],
        @[@"PCL-iOS 版本", @"开发者", @"开源许可"],
        @[@"检查更新", @"更新源"],
        @[@"提交反馈", @"问题报告"],
        @[@"查看日志", @"导出日志"]
    ];
    
    [self setupUI];
}

- (void)setupUI {
    // 滚动视图
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
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"设置";
    titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    titleLabel.textColor = PCLColor(0x343D4A);
    [self.scrollView addSubview:titleLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor constant:16],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20]
    ]];
    
    // 标签栏
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumInteritemSpacing = 8;
    layout.sectionInset = UIEdgeInsetsMake(0, 16, 0, 16);
    
    self.tabCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.tabCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabCollectionView.backgroundColor = [UIColor clearColor];
    self.tabCollectionView.showsHorizontalScrollIndicator = NO;
    self.tabCollectionView.delegate = self;
    self.tabCollectionView.dataSource = self;
    [self.tabCollectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"TabCell"];
    [self.scrollView addSubview:self.tabCollectionView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tabCollectionView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:16],
        [self.tabCollectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tabCollectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tabCollectionView.heightAnchor constraintEqualToConstant:44]
    ]];
    
    // 内容卡片
    self.contentCard = [[PCLSettingsCard alloc] init];
    self.contentCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentCard];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.contentCard.topAnchor constraintEqualToAnchor:self.tabCollectionView.bottomAnchor constant:16],
        [self.contentCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.contentCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.contentCard.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:-20]
    ]];
    
    // 设置表格
    self.settingsTableView = [[UITableView alloc] init];
    self.settingsTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.settingsTableView.delegate = self;
    self.settingsTableView.dataSource = self;
    self.settingsTableView.backgroundColor = [UIColor clearColor];
    self.settingsTableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.settingsTableView.separatorInset = UIEdgeInsetsMake(0, 20, 0, 20);
    self.settingsTableView.rowHeight = 52;
    self.settingsTableView.scrollEnabled = NO;
    [self.contentCard addSubview:self.settingsTableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.settingsTableView.topAnchor constraintEqualToAnchor:self.contentCard.topAnchor constant:8],
        [self.settingsTableView.leadingAnchor constraintEqualToAnchor:self.contentCard.leadingAnchor],
        [self.settingsTableView.trailingAnchor constraintEqualToAnchor:self.contentCard.trailingAnchor],
        [self.settingsTableView.bottomAnchor constraintEqualToAnchor:self.contentCard.bottomAnchor constant:-8]
    ]];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.tabTitles.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"TabCell" forIndexPath:indexPath];
    
    for (UIView *subview in cell.contentView.subviews) {
        [subview removeFromSuperview];
    }
    
    BOOL selected = (indexPath.item == self.selectedTab);
    
    UIView *bgView = [[UIView alloc] initWithFrame:cell.contentView.bounds];
    bgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    bgView.backgroundColor = selected ? PCLColor(0x1370F3) : [UIColor whiteColor];
    bgView.layer.cornerRadius = 8;
    if (!selected) {
        bgView.layer.borderWidth = 1;
        bgView.layer.borderColor = PCLColor(0xE0E0E0).CGColor;
    }
    [cell.contentView addSubview:bgView];
    
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = self.tabTitles[indexPath.item];
    label.font = [UIFont systemFontOfSize:13 weight:selected ? UIFontWeightSemibold : UIFontWeightMedium];
    label.textColor = selected ? [UIColor whiteColor] : PCLColor(0x343D4A);
    [cell.contentView addSubview:label];
    
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:cell.contentView.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor]
    ]];
    
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSString *title = self.tabTitles[indexPath.item];
    CGSize size = [title sizeWithAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:13]}];
    return CGSizeMake(size.width + 24, 36);
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    self.selectedTab = indexPath.item;
    self.currentTab = (PCLSettingsTab)indexPath.item;
    [collectionView reloadData];
    [self.settingsTableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.selectedTab < self.settingsItems.count) {
        return self.settingsItems[self.selectedTab].count;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"SettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.backgroundColor = [UIColor clearColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    if (self.selectedTab < self.settingsItems.count) {
        NSArray *items = self.settingsItems[self.selectedTab];
        if (indexPath.row < items.count) {
            cell.textLabel.text = items[indexPath.row];
            cell.textLabel.font = [UIFont systemFontOfSize:15];
            cell.textLabel.textColor = PCLColor(0x343D4A);
        }
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // TODO: 处理设置项点击
}

#pragma mark - Public Methods

- (void)switchToTab:(PCLSettingsTab)tab {
    self.selectedTab = tab;
    self.currentTab = tab;
    [self.tabCollectionView reloadData];
    [self.settingsTableView reloadData];
}

- (void)dismissTransientUI {
    // 清理临时UI
}

@end
