#import "PCLVanillaDownloadViewController.h"
#import "PCLVanillaDownloader.h"
#import "PCLVersionManager.h"
#import "PCLLogger.h"
#import "PCLDownloadManager.h"
#import <QuartzCore/QuartzCore.h>

static UIColor *PCLColor(NSUInteger rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
                           green:((rgb >> 8) & 255) / 255.0
                            blue:(rgb & 255) / 255.0
                           alpha:1.0];
}

#pragma mark - Version Cell

@interface PCLVanillaVersionCell : UITableViewCell

@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UILabel *versionLabel;
@property (nonatomic, strong) UILabel *typeLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, copy) void (^onAction)(void);

- (void)configureWithDictionary:(NSDictionary *)dict installed:(BOOL)installed downloading:(BOOL)downloading progress:(double)progress status:(NSString *)status;

@end

@implementation PCLVanillaVersionCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    
    // Card container
    self.cardView = [[UIView alloc] init];
    self.cardView.backgroundColor = [UIColor whiteColor];
    self.cardView.layer.cornerRadius = 10;
    self.cardView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.cardView.layer.shadowOffset = CGSizeMake(0, 1);
    self.cardView.layer.shadowRadius = 3;
    self.cardView.layer.shadowOpacity = 0.06;
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.cardView];
    
    // Version label
    self.versionLabel = [[UILabel alloc] init];
    self.versionLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.versionLabel.textColor = PCLColor(0x343D4A);
    self.versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cardView addSubview:self.versionLabel];
    
    // Type label
    self.typeLabel = [[UILabel alloc] init];
    self.typeLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    self.typeLabel.textColor = [UIColor whiteColor];
    self.typeLabel.textAlignment = NSTextAlignmentCenter;
    self.typeLabel.layer.cornerRadius = 4;
    self.typeLabel.clipsToBounds = YES;
    self.typeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cardView addSubview:self.typeLabel];
    
    // Date label
    self.dateLabel = [[UILabel alloc] init];
    self.dateLabel.font = [UIFont systemFontOfSize:12];
    self.dateLabel.textColor = PCLColor(0x8C8C8C);
    self.dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cardView addSubview:self.dateLabel];
    
    // Action button
    self.actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.actionButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.actionButton.layer.cornerRadius = 6;
    self.actionButton.clipsToBounds = YES;
    self.actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.actionButton addTarget:self action:@selector(actionTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.cardView addSubview:self.actionButton];
    
    // Progress view
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressView.trackTintColor = PCLColor(0xE8E8E8);
    self.progressView.progressTintColor = PCLColor(0x1370F3);
    self.progressView.hidden = YES;
    [self.cardView addSubview:self.progressView];
    
    // Status label
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont systemFontOfSize:11];
    self.statusLabel.textColor = PCLColor(0x8C8C8C);
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.hidden = YES;
    [self.cardView addSubview:self.statusLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        // Card
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],
        
        // Version
        [self.versionLabel.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:14],
        [self.versionLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:14],
        
        // Type
        [self.typeLabel.centerYAnchor constraintEqualToAnchor:self.versionLabel.centerYAnchor],
        [self.typeLabel.leadingAnchor constraintEqualToAnchor:self.versionLabel.trailingAnchor constant:8],
        [self.typeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:50],
        [self.typeLabel.heightAnchor constraintEqualToConstant:18],
        [self.typeLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.actionButton.leadingAnchor constant:-8],
        
        // Date
        [self.dateLabel.topAnchor constraintEqualToAnchor:self.versionLabel.bottomAnchor constant:4],
        [self.dateLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:14],
        
        // Action button
        [self.actionButton.centerYAnchor constraintEqualToAnchor:self.cardView.centerYAnchor],
        [self.actionButton.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-14],
        [self.actionButton.widthAnchor constraintEqualToConstant:72],
        [self.actionButton.heightAnchor constraintEqualToConstant:32],
        
        // Progress
        [self.progressView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:14],
        [self.progressView.trailingAnchor constraintEqualToAnchor:self.actionButton.leadingAnchor constant:-12],
        [self.progressView.topAnchor constraintEqualToAnchor:self.dateLabel.bottomAnchor constant:8],
        [self.progressView.heightAnchor constraintEqualToConstant:4],
        
        // Status
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:14],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.progressView.bottomAnchor constant:4],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-10]
    ]];
}

- (void)configureWithDictionary:(NSDictionary *)dict installed:(BOOL)installed downloading:(BOOL)downloading progress:(double)progress status:(NSString *)status {
    NSString *versionId = dict[@"id"] ?: @"";
    NSString *type = dict[@"type"] ?: @"";
    NSString *releaseTime = dict[@"releaseTime"] ?: @"";
    
    self.versionLabel.text = versionId;
    
    // Type badge
    self.typeLabel.text = [self displayStringForType:type];
    self.typeLabel.backgroundColor = [self colorForType:type];
    
    // Format date
    self.dateLabel.text = [self formatReleaseDate:releaseTime];
    
    // Action button state
    if (downloading) {
        [self.actionButton setTitle:@"取消" forState:UIControlStateNormal];
        [self.actionButton setTitleColor:PCLColor(0xE74C3C) forState:UIControlStateNormal];
        self.actionButton.backgroundColor = PCLColor(0xFDEDEC);
        self.progressView.hidden = NO;
        self.statusLabel.hidden = NO;
        self.progressView.progress = progress;
        self.statusLabel.text = status ?: @"下载中...";
    } else if (installed) {
        [self.actionButton setTitle:@"已安装" forState:UIControlStateNormal];
        [self.actionButton setTitleColor:PCLColor(0x27AE60) forState:UIControlStateNormal];
        self.actionButton.backgroundColor = PCLColor(0xE8F8F0);
        self.progressView.hidden = YES;
        self.statusLabel.hidden = NO;
        self.statusLabel.text = @"已安装 - 点击验证";
    } else {
        [self.actionButton setTitle:@"下载" forState:UIControlStateNormal];
        [self.actionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.actionButton.backgroundColor = PCLColor(0x1370F3);
        self.progressView.hidden = YES;
        self.statusLabel.hidden = YES;
    }
}

- (NSString *)displayStringForType:(NSString *)type {
    if ([type isEqualToString:@"release"]) return @"正式版";
    if ([type isEqualToString:@"snapshot"]) return @"快照";
    if ([type isEqualToString:@"old_alpha"]) return @"Alpha";
    if ([type isEqualToString:@"old_beta"]) return @"Beta";
    return type;
}

- (UIColor *)colorForType:(NSString *)type {
    if ([type isEqualToString:@"release"]) return PCLColor(0x27AE60);
    if ([type isEqualToString:@"snapshot"]) return PCLColor(0xE67E22);
    if ([type isEqualToString:@"old_alpha"]) return PCLColor(0x9B59B6);
    if ([type isEqualToString:@"old_beta"]) return PCLColor(0x8E44AD);
    return PCLColor(0x95A5A6);
}

- (NSString *)formatReleaseDate:(NSString *)dateString {
    if (dateString.length == 0) return @"";
    
    NSDateFormatter *inputFormatter = [[NSDateFormatter alloc] init];
    inputFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
    NSDate *date = [inputFormatter dateFromString:dateString];
    
    if (!date) {
        // Try without time zone
        inputFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
        date = [inputFormatter dateFromString:dateString];
    }
    
    if (!date) return dateString;
    
    NSDateFormatter *outputFormatter = [[NSDateFormatter alloc] init];
    outputFormatter.dateFormat = @"yyyy-MM-dd";
    return [outputFormatter stringFromDate:date];
}

- (void)actionTapped {
    if (self.onAction) self.onAction();
}

@end

#pragma mark - Main View Controller

@interface PCLVanillaDownloadViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UISegmentedControl *filterControl;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *titleLabel;

@property (nonatomic, assign) PCLVanillaListFilter currentFilter;
@property (nonatomic, strong) NSArray<NSDictionary *> *allVersions;
@property (nonatomic, strong) NSArray<NSDictionary *> *displayedVersions;
@property (nonatomic, strong) NSArray<PCLVersionInfo *> *installedVersions;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *downloadProgress;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *downloadStatus;
@property (nonatomic, copy) NSString *currentDownloadingVersion;

@end

@implementation PCLVanillaDownloadViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = PCLColor(0xF5F7FA);
    self.currentFilter = PCLVanillaListFilterReleases;
    self.allVersions = @[];
    self.displayedVersions = @[];
    self.installedVersions = @[];
    self.downloadProgress = [NSMutableDictionary dictionary];
    self.downloadStatus = [NSMutableDictionary dictionary];
    
    [self setupUI];
    [self loadVersions];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshInstalledVersions];
    [self.tableView reloadData];
}

#pragma mark - Setup

- (void)setupUI {
    // Header
    self.headerView = [[UIView alloc] init];
    self.headerView.backgroundColor = [UIColor whiteColor];
    self.headerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.headerView];
    
    // Back button
    self.backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.backButton setTitle:@"< 返回" forState:UIControlStateNormal];
    [self.backButton setTitleColor:PCLColor(0x1370F3) forState:UIControlStateNormal];
    self.backButton.titleLabel.font = [UIFont systemFontOfSize:15];
    self.backButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.backButton addTarget:self action:@selector(backTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.backButton];
    
    // Title
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"Minecraft 原版下载";
    self.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    self.titleLabel.textColor = PCLColor(0x343D4A);
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.headerView addSubview:self.titleLabel];
    
    // Filter control
    self.filterControl = [[UISegmentedControl alloc] initWithItems:@[@"正式版", @"快照", @"旧版本", @"已安装"]];
    self.filterControl.selectedSegmentIndex = 0;
    self.filterControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.filterControl addTarget:self action:@selector(filterChanged:) forControlEvents:UIControlEventValueChanged];
    [self.headerView addSubview:self.filterControl];
    
    // Table
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = 100;
    self.tableView.contentInset = UIEdgeInsetsMake(8, 0, 16, 0);
    [self.tableView registerClass:[PCLVanillaVersionCell class] forCellReuseIdentifier:@"VanillaVersionCell"];
    [self.view addSubview:self.tableView];
    
    // Loading
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.loadingIndicator];
    
    // Empty label
    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = @"暂无版本";
    self.emptyLabel.font = [UIFont systemFontOfSize:14];
    self.emptyLabel.textColor = PCLColor(0x8C8C8C);
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.hidden = YES;
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.emptyLabel];
    
    // Layout
    [NSLayoutConstraint activateConstraints:@[
        // Header
        [self.headerView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.headerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.headerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.headerView.heightAnchor constraintEqualToConstant:100],
        
        // Back button
        [self.backButton.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor constant:12],
        [self.backButton.topAnchor constraintEqualToAnchor:self.headerView.topAnchor constant:8],
        [self.backButton.widthAnchor constraintEqualToConstant:60],
        [self.backButton.heightAnchor constraintEqualToConstant:32],
        
        // Title
        [self.titleLabel.centerXAnchor constraintEqualToAnchor:self.headerView.centerXAnchor],
        [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.backButton.centerYAnchor],
        
        // Filter
        [self.filterControl.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor constant:12],
        [self.filterControl.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor constant:-12],
        [self.filterControl.bottomAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:-8],
        [self.filterControl.heightAnchor constraintEqualToConstant:30],
        
        // Table
        [self.tableView.topAnchor constraintEqualToAnchor:self.headerView.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        // Loading
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        
        // Empty
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

#pragma mark - Data Loading

- (void)loadVersions {
    [self.loadingIndicator startAnimating];
    self.emptyLabel.hidden = YES;
    
    [[PCLVersionManager sharedManager] fetchRemoteManifest:^(NSArray<NSDictionary *> *versions, NSError *error) {
        [self.loadingIndicator stopAnimating];
        
        if (error) {
            [[PCLLogger sharedLogger] error:[NSString stringWithFormat:@"[VanillaDownloadVC] Failed to fetch manifest: %@", error]];
            self.emptyLabel.hidden = NO;
            self.emptyLabel.text = @"加载失败，请检查网络";
            return;
        }
        
        self.allVersions = versions ?: @[];
        [self refreshInstalledVersions];
        [self applyFilter];
    }];
    
    // Also check cached manifest
    NSArray *cached = [[PCLVersionManager sharedManager] remoteVersionManifest];
    if (cached.count > 0 && self.allVersions.count == 0) {
        self.allVersions = cached;
        [self refreshInstalledVersions];
        [self applyFilter];
    }
}

- (void)refreshInstalledVersions {
    self.installedVersions = [[PCLVersionManager sharedManager] localVersions];
}

- (void)applyFilter {
    NSMutableArray *filtered = [NSMutableArray array];
    
    switch (self.currentFilter) {
        case PCLVanillaListFilterReleases:
            for (NSDictionary *v in self.allVersions) {
                if ([v[@"type"] isEqualToString:@"release"]) {
                    [filtered addObject:v];
                }
            }
            break;
            
        case PCLVanillaListFilterSnapshots:
            for (NSDictionary *v in self.allVersions) {
                if ([v[@"type"] isEqualToString:@"snapshot"]) {
                    [filtered addObject:v];
                }
            }
            break;
            
        case PCLVanillaListFilterOldVersions:
            for (NSDictionary *v in self.allVersions) {
                NSString *type = v[@"type"];
                if ([type isEqualToString:@"old_alpha"] || [type isEqualToString:@"old_beta"]) {
                    [filtered addObject:v];
                }
            }
            break;
            
        case PCLVanillaListFilterInstalled:
            for (PCLVersionInfo *info in self.installedVersions) {
                // Find matching remote info if available
                BOOL found = NO;
                for (NSDictionary *v in self.allVersions) {
                    if ([v[@"id"] isEqualToString:info.versionId]) {
                        [filtered addObject:v];
                        found = YES;
                        break;
                    }
                }
                if (!found) {
                    [filtered addObject:@{
                        @"id": info.versionId,
                        @"type": @"release",
                        @"releaseTime": @""
                    }];
                }
            }
            break;
    }
    
    self.displayedVersions = filtered;
    self.emptyLabel.hidden = (self.displayedVersions.count > 0);
    self.emptyLabel.text = (self.currentFilter == PCLVanillaListFilterInstalled) ? @"未安装任何版本" : @"暂无版本";
    
    [self.tableView reloadData];
}

#pragma mark - Actions

- (void)backTapped {
    if (self.onBack) self.onBack();
}

- (void)filterChanged:(UISegmentedControl *)sender {
    self.currentFilter = (PCLVanillaListFilter)sender.selectedSegmentIndex;
    [self applyFilter];
}

- (void)reloadData {
    [self refreshInstalledVersions];
    [self applyFilter];
}

#pragma mark - Download Action

- (void)handleActionForVersion:(NSString *)versionId type:(NSString *)type installed:(BOOL)installed downloading:(BOOL)downloading {
    if (downloading) {
        // Cancel download
        [self confirmCancelDownload:versionId];
        return;
    }
    
    if (installed) {
        // Verify installation
        [self verifyVersion:versionId];
        return;
    }
    
    // Start download
    [self confirmDownload:versionId];
}

- (void)confirmDownload:(NSString *)versionId {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认下载"
                                                                  message:[NSString stringWithFormat:@"确定要下载 Minecraft %@ 吗？这将下载客户端JAR、库文件和资源文件。", versionId]
                                                           preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self startDownload:versionId];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)confirmCancelDownload:(NSString *)versionId {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"取消下载"
                                                                  message:@"确定要取消当前下载吗？"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[PCLVanillaDownloader sharedDownloader] cancelDownload];
        self.currentDownloadingVersion = nil;
        [self.downloadProgress removeAllObjects];
        [self.downloadStatus removeAllObjects];
        [self.tableView reloadData];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"继续下载" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)startDownload:(NSString *)versionId {
    self.currentDownloadingVersion = versionId;
    self.downloadProgress[versionId] = @(0.0);
    self.downloadStatus[versionId] = @"正在开始下载...";
    [self.tableView reloadData];
    
    __weak typeof(self) weakSelf = self;
    [[PCLVanillaDownloader sharedDownloader] downloadVersion:versionId
        progress:^(PCLVanillaDownloadStep step, double overallProgress, double stepProgress, NSString *statusMessage) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            
            self.downloadProgress[versionId] = @(overallProgress);
            self.downloadStatus[versionId] = statusMessage ?: @"";
            
            // Reload the specific cell
            [self reloadCellForVersion:versionId];
        }
        completion:^(BOOL success, NSError *error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            
            self.currentDownloadingVersion = nil;
            
            if (success) {
                [[PCLLogger sharedLogger] info:[NSString stringWithFormat:@"[VanillaDownloadVC] Download completed: %@", versionId]];
                [self showDownloadResult:versionId success:YES error:nil];
                if (self.onVersionDownloaded) {
                    self.onVersionDownloaded(versionId);
                }
            } else {
                [[PCLLogger sharedLogger] error:[NSString stringWithFormat:@"[VanillaDownloadVC] Download failed: %@ - %@", versionId, error.localizedDescription]];
                [self showDownloadResult:versionId success:NO error:error];
            }
            
            [self.downloadProgress removeObjectForKey:versionId];
            [self.downloadStatus removeObjectForKey:versionId];
            [self refreshInstalledVersions];
            [self.tableView reloadData];
        }];
}

- (void)showDownloadResult:(NSString *)versionId success:(BOOL)success error:(NSError *)error {
    NSString *title = success ? @"下载完成" : @"下载失败";
    NSString *message = success
        ? [NSString stringWithFormat:@"Minecraft %@ 已成功下载并安装", versionId]
        : [NSString stringWithFormat:@"下载失败: %@", error.localizedDescription ?: @"未知错误"];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)verifyVersion:(NSString *)versionId {
    [[PCLLogger sharedLogger] info:[NSString stringWithFormat:@"[VanillaDownloadVC] Verifying version: %@", versionId]];
    
    // Check if version JSON exists
    if ([[PCLVersionManager sharedManager] isVersionInstalled:versionId]) {
        // Check client JAR
        NSString *versionsDir = [[PCLVersionManager sharedManager] versionsDirectory];
        NSString *clientPath = [[versionsDir stringByAppendingPathComponent:versionId] stringByAppendingPathComponent:[versionId stringByAppendingString:@".jar"]];
        
        NSFileManager *fm = [NSFileManager defaultManager];
        if ([fm fileExistsAtPath:clientPath]) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"验证成功"
                                                                          message:[NSString stringWithFormat:@"Minecraft %@ 安装完整", versionId]
                                                                   preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        } else {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"验证结果"
                                                                          message:[NSString stringWithFormat:@"客户端JAR缺失，建议重新下载"]
                                                                   preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"重新下载" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self startDownload:versionId];
            }]];
            [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"未安装"
                                                                      message:[NSString stringWithFormat:@"Minecraft %@ 未安装", versionId]
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)reloadCellForVersion:(NSString *)versionId {
    for (NSInteger i = 0; i < self.displayedVersions.count; i++) {
        NSDictionary *v = self.displayedVersions[i];
        if ([v[@"id"] isEqualToString:versionId]) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
            PCLVanillaVersionCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            if (cell) {
                double progress = [self.downloadProgress[versionId] doubleValue];
                NSString *status = self.downloadStatus[versionId];
                [cell configureWithDictionary:v installed:NO downloading:YES progress:progress status:status];
            }
            break;
        }
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.displayedVersions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PCLVanillaVersionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"VanillaVersionCell" forIndexPath:indexPath];
    
    NSDictionary *version = self.displayedVersions[indexPath.row];
    NSString *versionId = version[@"id"];
    
    BOOL installed = [[PCLVersionManager sharedManager] isVersionInstalled:versionId];
    BOOL downloading = [self.currentDownloadingVersion isEqualToString:versionId];
    double progress = [self.downloadProgress[versionId] doubleValue];
    NSString *status = self.downloadStatus[versionId];
    
    [cell configureWithDictionary:version installed:installed downloading:downloading progress:progress status:status];
    
    __weak typeof(self) weakSelf = self;
    cell.onAction = ^{
        __strong typeof(weakSelf) self = weakSelf;
        [self handleActionForVersion:versionId type:version[@"type"] installed:installed downloading:downloading];
    };
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *version = self.displayedVersions[indexPath.row];
    NSString *versionId = version[@"id"];
    NSString *type = version[@"type"];
    NSString *releaseTime = version[@"releaseTime"];
    
    BOOL installed = [[PCLVersionManager sharedManager] isVersionInstalled:versionId];
    
    // Show version detail
    NSString *detail = [NSString stringWithFormat:@"版本: %@\n类型: %@\n发布时间: %@\n状态: %@",
                        versionId,
                        type,
                        releaseTime,
                        installed ? @"已安装" : @"未安装"];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"版本详情"
                                                                  message:detail
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    
    if (!installed && ![self.currentDownloadingVersion isEqualToString:versionId]) {
        [alert addAction:[UIAlertAction actionWithTitle:@"下载" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self confirmDownload:versionId];
        }]];
    }
    
    if (installed) {
        [alert addAction:[UIAlertAction actionWithTitle:@"验证" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self verifyVersion:versionId];
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [self confirmDeleteVersion:versionId];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover) {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        popover.sourceView = cell;
        popover.sourceRect = cell.bounds;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)confirmDeleteVersion:(NSString *)versionId {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"删除版本"
                                                                  message:[NSString stringWithFormat:@"确定要删除 Minecraft %@ 吗？这将删除版本JAR和natives目录。", versionId]
                                                           preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self deleteVersion:versionId];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)deleteVersion:(NSString *)versionId {
    NSString *versionsDir = [[PCLVersionManager sharedManager] versionsDirectory];
    NSString *versionDir = [versionsDir stringByAppendingPathComponent:versionId];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    [fm removeItemAtPath:versionDir error:&error];
    
    if (error) {
        [[PCLLogger sharedLogger] error:[NSString stringWithFormat:@"[VanillaDownloadVC] Failed to delete version %@: %@", versionId, error]];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"删除失败"
                                                                      message:error.localizedDescription
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        [[PCLLogger sharedLogger] info:[NSString stringWithFormat:@"[VanillaDownloadVC] Deleted version: %@", versionId]];
        [self refreshInstalledVersions];
        [self.tableView reloadData];
    }
}

@end
