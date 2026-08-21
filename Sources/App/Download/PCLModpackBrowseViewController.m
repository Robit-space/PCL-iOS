#import "PCLModpackBrowseViewController.h"
#import "PCLModrinthAPI.h"
#import "PCLNetworkUtils.h"
#import "PCLDownloadManager.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static UIColor *PCLColor(NSUInteger rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
                           green:((rgb >> 8) & 255) / 255.0
                            blue:(rgb & 255) / 255.0
                           alpha:1.0];
}

static NSString *PCLFormatDownloads(long long downloads) {
    if (downloads >= 1000000) {
        return [NSString stringWithFormat:@"%.1fM", downloads / 1000000.0];
    } else if (downloads >= 1000) {
        return [NSString stringWithFormat:@"%.1fK", downloads / 1000.0];
    }
    return [NSString stringWithFormat:@"%lld", downloads];
}

@interface PCLModpackCell : UITableViewCell
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *authorLabel;
@property (nonatomic, strong) UILabel *downloadsLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) UIButton *installButton;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, copy) void (^onInstall)(void);
@end

@implementation PCLModpackCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor whiteColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    
    self.iconImageView = [[UIImageView alloc] init];
    self.iconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconImageView.layer.cornerRadius = 8;
    self.iconImageView.clipsToBounds = YES;
    self.iconImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconImageView.backgroundColor = PCLColor(0xF0F0F0);
    [self.contentView addSubview:self.iconImageView];
    
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    self.nameLabel.textColor = PCLColor(0x343D4A);
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.nameLabel];
    
    self.authorLabel = [[UILabel alloc] init];
    self.authorLabel.font = [UIFont systemFontOfSize:12];
    self.authorLabel.textColor = PCLColor(0x1370F3);
    self.authorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.authorLabel];
    
    self.downloadsLabel = [[UILabel alloc] init];
    self.downloadsLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    self.downloadsLabel.textColor = PCLColor(0x8C8C8C);
    self.downloadsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.downloadsLabel];
    
    self.descriptionLabel = [[UILabel alloc] init];
    self.descriptionLabel.font = [UIFont systemFontOfSize:12];
    self.descriptionLabel.textColor = PCLColor(0x8C8C8C);
    self.descriptionLabel.numberOfLines = 2;
    self.descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.descriptionLabel];
    
    self.installButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.installButton setTitle:@"安装" forState:UIControlStateNormal];
    [self.installButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.installButton.backgroundColor = PCLColor(0x1370F3);
    self.installButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.installButton.layer.cornerRadius = 6;
    self.installButton.clipsToBounds = YES;
    self.installButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.installButton addTarget:self action:@selector(installTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.installButton];
    
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressView.progressTintColor = PCLColor(0x1370F3);
    self.progressView.trackTintColor = PCLColor(0xE0EAFD);
    self.progressView.hidden = YES;
    [self.contentView addSubview:self.progressView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.iconImageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
        [self.iconImageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
        [self.iconImageView.widthAnchor constraintEqualToConstant:48],
        [self.iconImageView.heightAnchor constraintEqualToConstant:48],
        
        [self.nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.iconImageView.trailingAnchor constant:10],
        [self.nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.installButton.leadingAnchor constant:-8],
        
        [self.authorLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:2],
        [self.authorLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        
        [self.downloadsLabel.topAnchor constraintEqualToAnchor:self.authorLabel.bottomAnchor constant:2],
        [self.downloadsLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        
        [self.descriptionLabel.topAnchor constraintEqualToAnchor:self.downloadsLabel.bottomAnchor constant:4],
        [self.descriptionLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.descriptionLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
        [self.descriptionLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-12],
        
        [self.installButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.installButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
        [self.installButton.widthAnchor constraintEqualToConstant:60],
        [self.installButton.heightAnchor constraintEqualToConstant:32],
        
        [self.progressView.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.progressView.trailingAnchor constraintEqualToAnchor:self.installButton.leadingAnchor constant:-8],
        [self.progressView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8]
    ]];
}

- (void)installTapped {
    if (self.onInstall) self.onInstall();
}

@end

@interface PCLModpackBrowseViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>

@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIView *filterBar;
@property (nonatomic, strong) UISegmentedControl *sortFilter;
@property (nonatomic, strong) UIButton *versionFilterButton;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<PCLModrinthProject *> *modpacks;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UILabel *emptyLabel;

@property (nonatomic, assign) NSInteger currentOffset;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL hasMore;
@property (nonatomic, copy) NSString *currentQuery;
@property (nonatomic, assign) PCLModrinthSortType currentSort;
@property (nonatomic, copy) NSString *currentGameVersion;
@property (nonatomic, strong) NSArray<NSString *> *gameVersions;

@property (nonatomic, strong) PCLModrinthProject *installingModpack;
@property (nonatomic, assign) NSInteger installTotalFiles;
@property (nonatomic, assign) NSInteger installCompletedFiles;

@end

@implementation PCLModpackBrowseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"浏览整合包";
    self.view.backgroundColor = PCLColor(0xF5F7FA);
    
    self.modpacks = [NSMutableArray array];
    self.currentOffset = 0;
    self.hasMore = YES;
    self.currentQuery = @"";
    self.currentSort = PCLModrinthSortTypeDownloads;
    self.currentGameVersion = @"1.20.4";
    self.gameVersions = @[@"1.21", @"1.20.4", @"1.20.2", @"1.20.1", @"1.20", @"1.19.4", @"1.18.2"];
    
    [self setupUI];
    [self loadModpacks];
}

- (void)setupUI {
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.placeholder = @"搜索整合包...";
    self.searchBar.delegate = self;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.backgroundColor = [UIColor whiteColor];
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.searchBar];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.searchBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],
        [self.searchBar.heightAnchor constraintEqualToConstant:44]
    ]];
    
    self.filterBar = [[UIView alloc] init];
    self.filterBar.backgroundColor = [UIColor whiteColor];
    self.filterBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.filterBar];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.filterBar.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor],
        [self.filterBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.filterBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.filterBar.heightAnchor constraintEqualToConstant:44]
    ]];
    
    self.versionFilterButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.versionFilterButton setTitle:self.currentGameVersion forState:UIControlStateNormal];
    [self.versionFilterButton setTitleColor:PCLColor(0x343D4A) forState:UIControlStateNormal];
    self.versionFilterButton.backgroundColor = PCLColor(0xF0F0F0);
    self.versionFilterButton.layer.cornerRadius = 4;
    self.versionFilterButton.titleLabel.font = [UIFont systemFontOfSize:12];
    self.versionFilterButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.versionFilterButton addTarget:self action:@selector(versionFilterTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.filterBar addSubview:self.versionFilterButton];
    
    self.sortFilter = [[UISegmentedControl alloc] initWithItems:@[@"下载", @"相关", @"最新", @"更新"]];
    self.sortFilter.selectedSegmentIndex = 0;
    self.sortFilter.translatesAutoresizingMaskIntoConstraints = NO;
    [self.sortFilter addTarget:self action:@selector(sortChanged:) forControlEvents:UIControlEventValueChanged];
    [self.filterBar addSubview:self.sortFilter];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.versionFilterButton.leadingAnchor constraintEqualToAnchor:self.filterBar.leadingAnchor constant:8],
        [self.versionFilterButton.centerYAnchor constraintEqualToAnchor:self.filterBar.centerYAnchor],
        [self.versionFilterButton.widthAnchor constraintEqualToConstant:70],
        [self.versionFilterButton.heightAnchor constraintEqualToConstant:28],
        
        [self.sortFilter.leadingAnchor constraintEqualToAnchor:self.versionFilterButton.trailingAnchor constant:8],
        [self.sortFilter.centerYAnchor constraintEqualToAnchor:self.filterBar.centerYAnchor],
        [self.sortFilter.widthAnchor constraintEqualToConstant:180]
    ]];
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = 110;
    [self.tableView registerClass:[PCLModpackCell class] forCellReuseIdentifier:@"ModpackCell"];
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.filterBar.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.loadingIndicator];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
    
    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = @"暂无结果";
    self.emptyLabel.font = [UIFont systemFontOfSize:14];
    self.emptyLabel.textColor = PCLColor(0x8C8C8C);
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.hidden = YES;
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.emptyLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

#pragma mark - Data Loading

- (void)loadModpacks {
    if (self.isLoading) return;
    self.isLoading = YES;
    self.emptyLabel.hidden = YES;
    
    if (self.currentOffset == 0) {
        [self.loadingIndicator startAnimating];
    }
    
    NSMutableDictionary *filters = [NSMutableDictionary dictionary];
    filters[@"projectType"] = @"modpack";
    filters[@"gameVersion"] = self.currentGameVersion;
    filters[@"sortType"] = [PCLModrinthAPI sortTypeString:self.currentSort];
    
    [[PCLModrinthAPI sharedAPI] searchProjects:self.currentQuery
                                       filters:filters
                                         limit:20
                                        offset:self.currentOffset
                                    completion:^(PCLModrinthSearchResult *result, NSError *error) {
        self.isLoading = NO;
        [self.loadingIndicator stopAnimating];
        
        if (error) {
            NSLog(@"[ModpackBrowse] Search failed: %@", error);
            if (self.modpacks.count == 0) {
                self.emptyLabel.hidden = NO;
                self.emptyLabel.text = @"加载失败，请稍后再试";
            }
            return;
        }
        
        if (self.currentOffset == 0) {
            [self.modpacks removeAllObjects];
        }
        
        [self.modpacks addObjectsFromArray:result.hits];
        self.hasMore = (self.currentOffset + result.hits.count) < result.totalHits;
        self.currentOffset += result.hits.count;
        
        self.emptyLabel.hidden = (self.modpacks.count > 0);
        self.emptyLabel.text = self.currentQuery.length > 0 ? @"未找到匹配的整合包" : @"暂无整合包";
        [self.tableView reloadData];
    }];
}

- (void)reloadModpacks {
    self.currentOffset = 0;
    self.hasMore = YES;
    [self loadModpacks];
}

#pragma mark - Actions

- (void)sortChanged:(UISegmentedControl *)sender {
    switch (sender.selectedSegmentIndex) {
        case 0: self.currentSort = PCLModrinthSortTypeDownloads; break;
        case 1: self.currentSort = PCLModrinthSortTypeRelevance; break;
        case 2: self.currentSort = PCLModrinthSortTypeNewest; break;
        case 3: self.currentSort = PCLModrinthSortTypeUpdated; break;
    }
    [self reloadModpacks];
}

- (void)versionFilterTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择游戏版本" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (NSString *version in self.gameVersions) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:version style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            self.currentGameVersion = version;
            [self.versionFilterButton setTitle:version forState:UIControlStateNormal];
            [self reloadModpacks];
        }];
        [alert addAction:action];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover) {
        popover.sourceView = self.versionFilterButton;
        popover.sourceRect = self.versionFilterButton.bounds;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Install Modpack

- (void)installModpack:(PCLModrinthProject *)modpack {
    self.installingModpack = modpack;
    
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"安装整合包"
                                                                    message:[NSString stringWithFormat:@"确定要安装 %@ 吗？将下载所有依赖文件。", modpack.title]
                                                             preferredStyle:UIAlertControllerStyleAlert];
    
    [confirm addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"安装" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self startModpackInstall:modpack];
    }]];
    
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)startModpackInstall:(PCLModrinthProject *)modpack {
    [self showInstallProgress:modpack.title];
    
    [[PCLModrinthAPI sharedAPI] versionsForProject:modpack.projectID
                                           facets:@{@"gameVersion": self.currentGameVersion ?: @""}
                                       completion:^(NSArray<PCLModrinthVersion *> *versions, NSError *error) {
        if (error || versions.count == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideInstallProgress];
                [self showInstallError:error ?: [NSError errorWithDomain:@"PCLModpack" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"无可用版本"}]];
            });
            return;
        }
        
        PCLModrinthVersion *latestVersion = versions[0];
        [self downloadModpackFiles:latestVersion];
    }];
}

- (void)downloadModpackFiles:(PCLModrinthVersion *)version {
    self.installTotalFiles = version.files.count;
    self.installCompletedFiles = 0;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *modpacksDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"modpacks"];
    NSString *modpackDir = [modpacksDir stringByAppendingPathComponent:self.installingModpack.projectID];
    [fm createDirectoryAtPath:modpackDir withIntermediateDirectories:YES attributes:nil error:nil];
    
    __weak typeof(self) weakSelf = self;
    
    for (PCLModrinthFileInfo *file in version.files) {
        NSString *targetPath = [modpackDir stringByAppendingPathComponent:file.fileName];
        
        [[PCLModrinthAPI sharedAPI] downloadFile:file
                                           toPath:targetPath
                                         progress:^(double progress) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf updateInstallProgress:progress];
            });
        } completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.installCompletedFiles++;
                
                if (success) {
                    NSLog(@"[Modpack] Downloaded: %@", file.fileName);
                } else {
                    NSLog(@"[Modpack] Failed: %@ - %@", file.fileName, error);
                }
                
                if (weakSelf.installCompletedFiles >= weakSelf.installTotalFiles) {
                    [weakSelf hideInstallProgress];
                    [weakSelf showInstallSuccess];
                }
            });
        }];
    }
}

- (void)showInstallProgress:(NSString *)title {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"正在安装 %@", title] message:@"正在下载文件..." preferredStyle:UIAlertControllerStyleAlert];
    
    UIProgressView *progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    progressView.progress = 0;
    progressView.translatesAutoresizingMaskIntoConstraints = NO;
    alert.title = [NSString stringWithFormat:@"正在安装 %@\n\n", title];
    
    [self presentViewController:alert animated:YES completion:nil];
    
    objc_setAssociatedObject(alert, "progressView", progressView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIView *alertView = alert.view;
        if (alertView) {
            [alertView addSubview:progressView];
            [NSLayoutConstraint activateConstraints:@[
                [progressView.centerXAnchor constraintEqualToAnchor:alertView.centerXAnchor],
                [progressView.bottomAnchor constraintEqualToAnchor:alertView.bottomAnchor constant:-60],
                [progressView.widthAnchor constraintEqualToAnchor:alertView.widthAnchor multiplier:0.8]
            ]];
        }
    });
    
    objc_setAssociatedObject(self, "installAlert", alert, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)updateInstallProgress:(double)progress {
    UIAlertController *alert = objc_getAssociatedObject(self, "installAlert");
    UIProgressView *progressView = objc_getAssociatedObject(alert, "progressView");
    if (progressView) {
        progressView.progress = progress;
    }
}

- (void)hideInstallProgress {
    UIAlertController *alert = objc_getAssociatedObject(self, "installAlert");
    if (alert) {
        [alert dismissViewControllerAnimated:YES completion:nil];
        objc_setAssociatedObject(self, "installAlert", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (void)showInstallSuccess {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"安装完成"
                                                                  message:[NSString stringWithFormat:@"%@ 已安装完成", self.installingModpack.title]
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showInstallError:(NSError *)error {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"安装失败"
                                                                  message:error.localizedDescription ?: @"未知错误"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UISearchBarDelegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    self.currentQuery = searchBar.text ?: @"";
    [self reloadModpacks];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        self.currentQuery = @"";
        [self reloadModpacks];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.modpacks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PCLModpackCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ModpackCell" forIndexPath:indexPath];
    
    PCLModrinthProject *modpack = self.modpacks[indexPath.row];
    
    cell.nameLabel.text = modpack.title;
    cell.authorLabel.text = [NSString stringWithFormat:@"by %@", modpack.author];
    cell.downloadsLabel.text = [NSString stringWithFormat:@"⬇ %@", PCLFormatDownloads(modpack.downloads)];
    cell.descriptionLabel.text = modpack.descriptionText;
    
    if (cell.iconImageView && modpack.iconUrl.length > 0) {
        NSURL *url = [NSURL URLWithString:modpack.iconUrl];
        if (url) {
            NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (data) {
                    UIImage *image = [UIImage imageWithData:data];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        cell.iconImageView.image = image;
                    });
                }
            }];
            [task resume];
        }
    }
    
    cell.progressView.hidden = (self.installingModpack != modpack);
    
    __weak typeof(self) weakSelf = self;
    cell.onInstall = ^{
        [weakSelf installModpack:modpack];
    };
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == self.modpacks.count - 5 && self.hasMore && !self.isLoading) {
        [self loadModpacks];
    }
}

@end
