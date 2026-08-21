#import "PCLModManagerViewController.h"
#import "PCLInstanceManager.h"
#import "PCLModrinthAPI.h"
#import "PCLCurseForgeAPI.h"

static UIColor *PCLColor(NSUInteger rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
                           green:((rgb >> 8) & 255) / 255.0
                            blue:(rgb & 255) / 255.0
                           alpha:1.0];
}

@interface PCLModItem : NSObject
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *modLoader;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, copy) NSString *filePath;
@end

@implementation PCLModItem
@end

@interface PCLModManagerViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) PCLInstance *instance;
@property (nonatomic, assign) PCLModManagerType modType;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<PCLModItem *> *mods;
@property (nonatomic, strong) UISegmentedControl *sourceSegment;
@property (nonatomic, strong) UILabel *emptyLabel;

@end

@implementation PCLModManagerViewController

- (instancetype)initWithInstance:(PCLInstance *)instance modType:(PCLModManagerType)type {
    self = [super init];
    if (self) {
        _instance = instance;
        _modType = type;
        _mods = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [self titleForModType:self.modType];
    self.view.backgroundColor = [UIColor colorWithRed:251.0/255.0 green:251.0/255.0 blue:251.0/255.0 alpha:1.0];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                          target:self
                                                                                          action:@selector(donePressed)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                           target:self
                                                                                           action:@selector(addModPressed)];

    [self buildUI];
    [self loadMods];
}

- (NSString *)titleForModType:(PCLModManagerType)type {
    switch (type) {
        case PCLModManagerTypeMod: return @"模组管理";
        case PCLModManagerTypeShader: return @"光影管理";
        case PCLModManagerTypeResourcePack: return @"资源包管理";
        case PCLModManagerTypeDataPack: return @"数据包管理";
    }
}

- (void)buildUI {
    // 来源切换
    self.sourceSegment = [[UISegmentedControl alloc] initWithItems:@[@"已安装", @"在线搜索"]];
    self.sourceSegment.translatesAutoresizingMaskIntoConstraints = NO;
    self.sourceSegment.selectedSegmentIndex = 0;
    self.sourceSegment.tintColor = PCLColor(0x1370F3);
    [self.sourceSegment addTarget:self action:@selector(sourceChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.sourceSegment];

    // 表格
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = 72;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ModCell"];
    [self.view addSubview:self.tableView];

    // 空状态
    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.text = @"暂无内容\n点击右上角+添加";
    self.emptyLabel.font = [UIFont systemFontOfSize:14];
    self.emptyLabel.textColor = PCLColor(0x8C8C8C);
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.sourceSegment.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [self.sourceSegment.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.sourceSegment.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.sourceSegment.heightAnchor constraintEqualToConstant:32],

        [self.tableView.topAnchor constraintEqualToAnchor:self.sourceSegment.bottomAnchor constant:12],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

- (void)loadMods {
    [self.mods removeAllObjects];
    
    // 根据版本隔离设置获取mods目录
    NSString *modsDir = [[PCLInstanceManager sharedManager] modsDirectoryForInstance:self.instance];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *files = [fm contentsOfDirectoryAtPath:modsDir error:nil];
    
    NSString *extension = [self fileExtensionForModType:self.modType];
    
    for (NSString *file in files) {
        if ([file.pathExtension isEqualToString:extension]) {
            PCLModItem *item = [[PCLModItem alloc] init];
            item.fileName = file;
            item.name = [file stringByDeletingPathExtension];
            item.version = @"";
            item.modLoader = [self detectModLoader:file];
            item.enabled = ![file.stringByDeletingPathExtension hasSuffix:@".disabled"];
            item.filePath = [modsDir stringByAppendingPathComponent:file];
            [self.mods addObject:item];
        }
    }
    
    // 也检查全局mods目录(如果未启用版本隔离)
    if (!self.instance.versionIsolation) {
        NSString *docsDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *globalModsDir = [docsDir stringByAppendingPathComponent:@"mods"];
        if ([fm fileExistsAtPath:globalModsDir]) {
            NSArray *globalFiles = [fm contentsOfDirectoryAtPath:globalModsDir error:nil];
            for (NSString *file in globalFiles) {
                if ([file.pathExtension isEqualToString:extension]) {
                    PCLModItem *item = [[PCLModItem alloc] init];
                    item.fileName = file;
                    item.name = [file stringByDeletingPathExtension];
                    item.version = @"";
                    item.modLoader = [self detectModLoader:file];
                    item.enabled = ![file.stringByDeletingPathExtension hasSuffix:@".disabled"];
                    item.filePath = [globalModsDir stringByAppendingPathComponent:file];
                    [self.mods addObject:item];
                }
            }
        }
    }
    
    self.emptyLabel.hidden = self.mods.count > 0;
    [self.tableView reloadData];
}

- (NSString *)fileExtensionForModType:(PCLModManagerType)type {
    switch (type) {
        case PCLModManagerTypeMod: return @"jar";
        case PCLModManagerTypeShader: return @"zip";
        case PCLModManagerTypeResourcePack: return @"zip";
        case PCLModManagerTypeDataPack: return @"zip";
    }
}

- (NSString *)detectModLoader:(NSString *)fileName {
    NSString *lower = fileName.lowercaseString;
    if ([lower containsString:@"fabric"]) return @"Fabric";
    if ([lower containsString:@"forge"]) return @"Forge";
    if ([lower containsString:@"neoforge"]) return @"NeoForge";
    if ([lower containsString:@"quilt"]) return @"Quilt";
    if ([lower containsString:@"liteloader"]) return @"LiteLoader";
    return @"未知";
}

#pragma mark - Actions

- (void)donePressed {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)addModPressed {
    // 打开在线搜索
    self.sourceSegment.selectedSegmentIndex = 1;
    [self sourceChanged:self.sourceSegment];
}

- (void)sourceChanged:(UISegmentedControl *)sender {
    if (sender.selectedSegmentIndex == 0) {
        [self loadMods];
    } else {
        // 在线搜索模式
        [self showOnlineSearch];
    }
}

- (void)showOnlineSearch {
    // TODO: 实现在线搜索
}

- (void)toggleMod:(PCLModItem *)item {
    item.enabled = !item.enabled;
    // 重命名文件来启用/禁用
    NSString *newFileName;
    if (item.enabled) {
        newFileName = [item.fileName stringByReplacingOccurrencesOfString:@".disabled" withString:@""];
    } else {
        newFileName = [item.fileName stringByAppendingString:@".disabled"];
    }
    NSString *newPath = [item.filePath.stringByDeletingLastPathComponent stringByAppendingPathComponent:newFileName];
    [[NSFileManager defaultManager] moveItemAtPath:item.filePath toPath:newPath error:nil];
    item.filePath = newPath;
    item.fileName = newFileName;
}

- (void)deleteMod:(PCLModItem *)item {
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:item.filePath error:&error];
    if (!error) {
        [self.mods removeObject:item];
        [self.tableView reloadData];
    }
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.mods.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ModCell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    // 清除旧视图
    for (UIView *subview in cell.contentView.subviews) {
        [subview removeFromSuperview];
    }
    
    PCLModItem *item = self.mods[indexPath.row];
    
    // 卡片背景
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(16, 4, cell.contentView.bounds.size.width - 32, 64)];
    card.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 8;
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOpacity = 0.04;
    card.layer.shadowRadius = 4;
    card.layer.shadowOffset = CGSizeMake(0, 1);
    [cell.contentView addSubview:card];
    
    // 启用/禁用开关
    UISwitch *toggleSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(card.bounds.size.width - 60, 16, 51, 31)];
    toggleSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    toggleSwitch.on = item.enabled;
    toggleSwitch.onTintColor = PCLColor(0x1370F3);
    toggleSwitch.tag = indexPath.row;
    [toggleSwitch addTarget:self action:@selector(modSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [card addSubview:toggleSwitch];
    
    // Mod名称
    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, card.bounds.size.width - 100, 20)];
    nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    nameLabel.text = item.name;
    nameLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    nameLabel.textColor = item.enabled ? PCLColor(0x343D4A) : PCLColor(0x8C8C8C);
    [card addSubview:nameLabel];
    
    // Mod加载器标签
    UILabel *loaderLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 36, 80, 16)];
    loaderLabel.text = item.modLoader;
    loaderLabel.font = [UIFont systemFontOfSize:11];
    loaderLabel.textColor = PCLColor(0x1370F3);
    loaderLabel.backgroundColor = PCLColor(0xE8F0FE);
    loaderLabel.textAlignment = NSTextAlignmentCenter;
    loaderLabel.layer.cornerRadius = 4;
    loaderLabel.clipsToBounds = YES;
    [card addSubview:loaderLabel];
    
    // 文件名标签
    UILabel *fileLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 36, card.bounds.size.width - 180, 16)];
    fileLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    fileLabel.text = item.fileName;
    fileLabel.font = [UIFont systemFontOfSize:11];
    fileLabel.textColor = PCLColor(0x8C8C8C);
    [card addSubview:fileLabel];
    
    // 删除按钮
    UIButton *deleteBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    deleteBtn.frame = CGRectMake(card.bounds.size.width - 90, 16, 24, 24);
    deleteBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [deleteBtn setTitle:@"🗑" forState:UIControlStateNormal];
    deleteBtn.tag = indexPath.row;
    [deleteBtn addTarget:self action:@selector(deleteBtnPressed:) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:deleteBtn];
    
    return cell;
}

- (void)modSwitchChanged:(UISwitch *)sender {
    if (sender.tag < self.mods.count) {
        PCLModItem *item = self.mods[sender.tag];
        [self toggleMod:item];
    }
}

- (void)deleteBtnPressed:(UIButton *)sender {
    if (sender.tag < self.mods.count) {
        PCLModItem *item = self.mods[sender.tag];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"删除确认"
                                                                       message:[NSString stringWithFormat:@"确定要删除 %@ 吗?", item.name]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [self deleteMod:item];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

@end
