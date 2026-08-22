#import "PCLLaunchViewController.h"
#import "PCLProfileStore.h"
#import "PCLInstanceManager.h"
#import "PCLInstanceEditViewController.h"
#import "PCLInstanceViewController.h"
#import "PCLGameLauncher.h"

static UIColor *PCLColor(NSUInteger rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
                           green:((rgb >> 8) & 255) / 255.0
                            blue:(rgb & 255) / 255.0
                           alpha:1.0];
}

@interface PCLLaunchCard : UIView
@end

@implementation PCLLaunchCard

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

@interface PCLLaunchViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *headerCard;
@property (nonatomic, strong) UIView *instanceCard;
@property (nonatomic, strong) UIView *profileCard;
@property (nonatomic, strong) UIButton *launchButton;
@property (nonatomic, strong) UILabel *versionLabel;
@property (nonatomic, strong) UITableView *instanceTableView;
@property (nonatomic, strong) NSArray *instances;

@end

@implementation PCLLaunchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithRed:0.96 green:0.97 blue:0.98 alpha:1.0];
    
    [self setupUI];
    [self reloadData];
}

- (void)setupUI {
    // 滚动视图
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    
    // 头部卡片 - 标题和Logo
    [self setupHeaderCard];
    
    // 实例卡片
    [self setupInstanceCard];
    
    // 档案卡片
    [self setupProfileCard];
    
    // 启动按钮
    [self setupLaunchButton];
}

- (void)setupHeaderCard {
    self.headerCard = [[PCLLaunchCard alloc] init];
    self.headerCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.headerCard];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"PCL-iOS";
    titleLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
    titleLabel.textColor = PCLColor(0x1370F3);
    [self.headerCard addSubview:titleLabel];
    
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.text = @"Minecraft Java Edition Launcher";
    subtitleLabel.font = [UIFont systemFontOfSize:13];
    subtitleLabel.textColor = PCLColor(0x8C8C8C);
    [self.headerCard addSubview:subtitleLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.headerCard.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor constant:16],
        [self.headerCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.headerCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.headerCard.heightAnchor constraintEqualToConstant:80],
        
        [titleLabel.topAnchor constraintEqualToAnchor:self.headerCard.topAnchor constant:16],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.headerCard.leadingAnchor constant:20],
        
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:self.headerCard.leadingAnchor constant:20]
    ]];
}

- (void)setupInstanceCard {
    self.instanceCard = [[PCLLaunchCard alloc] init];
    self.instanceCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.instanceCard];
    
    UILabel *cardTitle = [[UILabel alloc] init];
    cardTitle.translatesAutoresizingMaskIntoConstraints = NO;
    cardTitle.text = @"游戏实例";
    cardTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    cardTitle.textColor = PCLColor(0x343D4A);
    [self.instanceCard addSubview:cardTitle];
    
    // 添加实例按钮
    UIButton *addButton = [UIButton buttonWithType:UIButtonTypeSystem];
    addButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
    [addButton setImage:[[UIImage systemImageNamed:@"plus.circle.fill"] imageByApplyingSymbolConfiguration:config] forState:UIControlStateNormal];
    addButton.tintColor = PCLColor(0x1370F3);
    [addButton addTarget:self action:@selector(addInstanceTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.instanceCard addSubview:addButton];
    
    // 实例列表表格
    self.instanceTableView = [[UITableView alloc] init];
    self.instanceTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.instanceTableView.delegate = self;
    self.instanceTableView.dataSource = self;
    self.instanceTableView.backgroundColor = [UIColor clearColor];
    self.instanceTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.instanceTableView.scrollEnabled = NO;
    self.instanceTableView.rowHeight = 64;
    [self.instanceCard addSubview:self.instanceTableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.instanceCard.topAnchor constraintEqualToAnchor:self.headerCard.bottomAnchor constant:12],
        [self.instanceCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.instanceCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        
        [cardTitle.topAnchor constraintEqualToAnchor:self.instanceCard.topAnchor constant:16],
        [cardTitle.leadingAnchor constraintEqualToAnchor:self.instanceCard.leadingAnchor constant:20],
        
        [addButton.centerYAnchor constraintEqualToAnchor:cardTitle.centerYAnchor],
        [addButton.trailingAnchor constraintEqualToAnchor:self.instanceCard.trailingAnchor constant:-16],
        
        [self.instanceTableView.topAnchor constraintEqualToAnchor:cardTitle.bottomAnchor constant:12],
        [self.instanceTableView.leadingAnchor constraintEqualToAnchor:self.instanceCard.leadingAnchor constant:8],
        [self.instanceTableView.trailingAnchor constraintEqualToAnchor:self.instanceCard.trailingAnchor constant:-8],
        [self.instanceTableView.bottomAnchor constraintEqualToAnchor:self.instanceCard.bottomAnchor constant:-12],
        [self.instanceTableView.heightAnchor constraintEqualToConstant:200]
    ]];
}

- (void)setupProfileCard {
    self.profileCard = [[PCLLaunchCard alloc] init];
    self.profileCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.profileCard];
    
    UILabel *cardTitle = [[UILabel alloc] init];
    cardTitle.translatesAutoresizingMaskIntoConstraints = NO;
    cardTitle.text = @"玩家档案";
    cardTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    cardTitle.textColor = PCLColor(0x343D4A);
    [self.profileCard addSubview:cardTitle];
    
    // 档案信息
    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.tag = 100;
    nameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    nameLabel.textColor = PCLColor(0x343D4A);
    [self.profileCard addSubview:nameLabel];
    
    UILabel *typeLabel = [[UILabel alloc] init];
    typeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    typeLabel.tag = 101;
    typeLabel.font = [UIFont systemFontOfSize:12];
    typeLabel.textColor = PCLColor(0x8C8C8C);
    [self.profileCard addSubview:typeLabel];
    
    // 添加档案按钮
    UIButton *addProfileButton = [UIButton buttonWithType:UIButtonTypeSystem];
    addProfileButton.translatesAutoresizingMaskIntoConstraints = NO;
    [addProfileButton setTitle:@"添加档案" forState:UIControlStateNormal];
    addProfileButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    addProfileButton.backgroundColor = PCLColor(0x1370F3);
    [addProfileButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    addProfileButton.layer.cornerRadius = 8;
    [addProfileButton addTarget:self action:@selector(addProfileTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.profileCard addSubview:addProfileButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.profileCard.topAnchor constraintEqualToAnchor:self.instanceCard.bottomAnchor constant:12],
        [self.profileCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.profileCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.profileCard.heightAnchor constraintEqualToConstant:120],
        
        [cardTitle.topAnchor constraintEqualToAnchor:self.profileCard.topAnchor constant:16],
        [cardTitle.leadingAnchor constraintEqualToAnchor:self.profileCard.leadingAnchor constant:20],
        
        [nameLabel.topAnchor constraintEqualToAnchor:cardTitle.bottomAnchor constant:12],
        [nameLabel.leadingAnchor constraintEqualToAnchor:self.profileCard.leadingAnchor constant:20],
        
        [typeLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:4],
        [typeLabel.leadingAnchor constraintEqualToAnchor:self.profileCard.leadingAnchor constant:20],
        
        [addProfileButton.trailingAnchor constraintEqualToAnchor:self.profileCard.trailingAnchor constant:-16],
        [addProfileButton.centerYAnchor constraintEqualToAnchor:self.profileCard.centerYAnchor],
        [addProfileButton.widthAnchor constraintEqualToConstant:90],
        [addProfileButton.heightAnchor constraintEqualToConstant:36]
    ]];
}

- (void)setupLaunchButton {
    self.launchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.launchButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.launchButton setTitle:@"启动游戏" forState:UIControlStateNormal];
    self.launchButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    self.launchButton.backgroundColor = PCLColor(0x1370F3);
    [self.launchButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.launchButton.layer.cornerRadius = 12;
    self.launchButton.layer.shadowColor = PCLColor(0x1370F3).CGColor;
    self.launchButton.layer.shadowOpacity = 0.3;
    self.launchButton.layer.shadowRadius = 8;
    self.launchButton.layer.shadowOffset = CGSizeMake(0, 4);
    [self.launchButton addTarget:self action:@selector(launchGame) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.launchButton];
    
    self.versionLabel = [[UILabel alloc] init];
    self.versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.versionLabel.font = [UIFont systemFontOfSize:12];
    self.versionLabel.textColor = PCLColor(0x8C8C8C);
    self.versionLabel.textAlignment = NSTextAlignmentCenter;
    [self.scrollView addSubview:self.versionLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.launchButton.topAnchor constraintEqualToAnchor:self.profileCard.bottomAnchor constant:24],
        [self.launchButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.launchButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [self.launchButton.heightAnchor constraintEqualToConstant:56],
        
        [self.versionLabel.topAnchor constraintEqualToAnchor:self.launchButton.bottomAnchor constant:12],
        [self.versionLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.versionLabel.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:-32]
    ]];
}

#pragma mark - Data

- (void)reloadData {
    // 加载实例列表
    self.instances = [[PCLInstanceManager sharedManager] allInstances] ?: @[];
    [self.instanceTableView reloadData];
    
    // 更新档案信息
    NSDictionary *profile = [PCLProfileStore selectedProfile];
    UILabel *nameLabel = [self.profileCard viewWithTag:100];
    UILabel *typeLabel = [self.profileCard viewWithTag:101];
    
    if (profile) {
        nameLabel.text = profile[@"username"] ?: @"未命名";
        NSString *type = profile[@"type"];
        if ([type isEqual:@"microsoft"]) {
            typeLabel.text = @"正版验证";
        } else if ([type isEqual:@"offline"]) {
            typeLabel.text = @"离线验证";
        } else {
            typeLabel.text = @"第三方验证";
        }
    } else {
        nameLabel.text = @"未选择档案";
        typeLabel.text = @"请先添加档案";
    }
    
    // 更新版本标签
    NSString *instance = [[NSUserDefaults standardUserDefaults] stringForKey:@"PCLSelectedInstance"];
    self.versionLabel.text = instance.length ? [NSString stringWithFormat:@"当前实例: %@", instance] : @"请先选择游戏实例";
    
    // 更新启动按钮状态
    BOOL canLaunch = (profile != nil && instance.length > 0);
    self.launchButton.enabled = canLaunch;
    self.launchButton.backgroundColor = canLaunch ? PCLColor(0x1370F3) : PCLColor(0xA6A6A6);
    self.launchButton.layer.shadowOpacity = canLaunch ? 0.3 : 0;
}

#pragma mark - Actions

- (void)addInstanceTapped {
    PCLInstanceViewController *vc = [[PCLInstanceViewController alloc] init];
    __weak typeof(self) weakSelf = self;
    vc.onComplete = ^{
        [weakSelf reloadData];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)addProfileTapped {
    // TODO: 打开档案添加界面
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"添加档案"
                                                                   message:@"请选择档案类型"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"离线档案" style:UIAlertActionStyleDefault handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"微软账号" style:UIAlertActionStyleDefault handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)launchGame {
    NSString *instance = [[NSUserDefaults standardUserDefaults] stringForKey:@"PCLSelectedInstance"];
    if (!instance.length) {
        if (self.onOpenDownload) self.onOpenDownload();
        return;
    }
    
    NSDictionary *profile = [PCLProfileStore selectedProfile];
    if (!profile) {
        return;
    }
    
    // 启动游戏
    [[PCLGameLauncher sharedLauncher] launchWithVersion:instance
                                                profile:profile
                                             completion:^(BOOL success, NSError *error) {
        if (!success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"启动失败"
                                                                               message:error.localizedDescription
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            });
        }
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.instances.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"InstanceCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.backgroundColor = [UIColor clearColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    NSDictionary *instance = self.instances[indexPath.row];
    cell.textLabel.text = instance[@"name"] ?: instance[@"id"];
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    cell.textLabel.textColor = PCLColor(0x343D4A);
    cell.detailTextLabel.text = instance[@"versionId"] ?: @"";
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    cell.detailTextLabel.textColor = PCLColor(0x8C8C8C);
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *instance = self.instances[indexPath.row];
    NSString *instanceId = instance[@"id"];
    
    [[NSUserDefaults standardUserDefaults] setObject:instanceId forKey:@"PCLSelectedInstance"];
    [self reloadData];
}

@end
