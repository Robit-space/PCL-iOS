#import "PCLModBrowseViewController.h"
#import "PCLModrinthAPI.h"
#import "PCLNetworkUtils.h"
#import "PCLDownloadManager.h"
#import <QuartzCore/QuartzCore.h>

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

@interface PCLModCell : UITableViewCell
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *authorLabel;
@property (nonatomic, strong) UILabel *downloadsLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) UIButton *installButton;
@property (nonatomic, copy) void (^onInstall)(void);
@end

@implementation PCLModCell

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
        [self.installButton.heightAnchor constraintEqualToConstant:32]
    ]];
}

- (void)installTapped {
    if (self.onInstall) self.onInstall();
}

@end

@interface PCLModDetailView : UIView
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *authorLabel;
@property (nonatomic, strong) UILabel *downloadsLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) UILabel *versionsTitleLabel;
@property (nonatomic, strong) UIStackView *versionsStack;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, copy) void (^onClose)(void);
@property (nonatomic, copy) void (^onInstallVersion)(PCLModrinthVersion *version);
@end

@implementation PCLModDetailView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
    
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 16;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:card];
    
    [NSLayoutConstraint activateConstraints:@[
        [card.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [card.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [card.widthAnchor constraintEqualToAnchor:self.widthAnchor multiplier:0.85],
        [card.heightAnchor constraintEqualToAnchor:self.heightAnchor multiplier:0.75]
    ]];
    
    self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.closeButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:PCLColor(0x8C8C8C) forState:UIControlStateNormal];
    self.closeButton.titleLabel.font = [UIFont systemFontOfSize:20];
    self.closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.closeButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.closeButton.topAnchor constraintEqualToAnchor:card.topAnchor constant:12],
        [self.closeButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12],
        [self.closeButton.widthAnchor constraintEqualToConstant:32],
        [self.closeButton.heightAnchor constraintEqualToConstant:32]
    ]];
    
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [card addSubview:self.scrollView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.closeButton.bottomAnchor constant:4],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16]
    ]];
    
    self.iconImageView = [[UIImageView alloc] init];
    self.iconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconImageView.layer.cornerRadius = 12;
    self.iconImageView.clipsToBounds = YES;
    self.iconImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconImageView.backgroundColor = PCLColor(0xF0F0F0);
    [self.scrollView addSubview:self.iconImageView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.iconImageView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.iconImageView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.iconImageView.widthAnchor constraintEqualToConstant:64],
        [self.iconImageView.heightAnchor constraintEqualToConstant:64]
    ]];
    
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    self.titleLabel.textColor = PCLColor(0x343D4A);
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.titleLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.iconImageView.topAnchor],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.iconImageView.trailingAnchor constant:12],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor]
    ]];
    
    self.authorLabel = [[UILabel alloc] init];
    self.authorLabel.font = [UIFont systemFontOfSize:13];
    self.authorLabel.textColor = PCLColor(0x1370F3);
    self.authorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.authorLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.authorLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
        [self.authorLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.authorLabel.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor]
    ]];
    
    self.downloadsLabel = [[UILabel alloc] init];
    self.downloadsLabel.font = [UIFont systemFontOfSize:12];
    self.downloadsLabel.textColor = PCLColor(0x8C8C8C);
    self.downloadsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.downloadsLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.downloadsLabel.topAnchor constraintEqualToAnchor:self.authorLabel.bottomAnchor constant:4],
        [self.downloadsLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor]
    ]];
    
    self.descriptionLabel = [[UILabel alloc] init];
    self.descriptionLabel.font = [UIFont systemFontOfSize:13];
    self.descriptionLabel.textColor = PCLColor(0x343D4A);
    self.descriptionLabel.numberOfLines = 0;
    self.descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.descriptionLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.descriptionLabel.topAnchor constraintEqualToAnchor:self.iconImageView.bottomAnchor constant:16],
        [self.descriptionLabel.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.descriptionLabel.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor]
    ]];
    
    self.versionsTitleLabel = [[UILabel alloc] init];
    self.versionsTitleLabel.text = @"可用版本";
    self.versionsTitleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    self.versionsTitleLabel.textColor = PCLColor(0x343D4A);
    self.versionsTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.versionsTitleLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.versionsTitleLabel.topAnchor constraintEqualToAnchor:self.descriptionLabel.bottomAnchor constant:20],
        [self.versionsTitleLabel.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.versionsTitleLabel.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor]
    ]];
    
    self.versionsStack = [[UIStackView alloc] init];
    self.versionsStack.axis = UILayoutConstraintAxisVertical;
    self.versionsStack.spacing = 8;
    self.versionsStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.versionsStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.versionsStack.topAnchor constraintEqualToAnchor:self.versionsTitleLabel.bottomAnchor constant:12],
        [self.versionsStack.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.versionsStack.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.versionsStack.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:-16]
    ]];
}

- (void)closeTapped {
    if (self.onClose) self.onClose();
}

@end

@interface PCLModBrowseViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>

@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIView *filterBar;
@property (nonatomic, strong) UISegmentedControl *loaderFilter;
@property (nonatomic, strong) UISegmentedControl *sortFilter;
@property (nonatomic, strong) UIButton *versionFilterButton;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<PCLModrinthProject *> *mods;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) PCLModDetailView *detailView;

@property (nonatomic, assign) NSInteger currentOffset;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL hasMore;
@property (nonatomic, copy) NSString *currentQuery;
@property (nonatomic, assign) PCLModrinthModLoader currentLoader;
@property (nonatomic, assign) PCLModrinthSortType currentSort;
@property (nonatomic, copy) NSString *currentGameVersion;

@property (nonatomic, strong) NSArray<NSString *> *gameVersions;
@property (nonatomic, strong) PCLModrinthProject *selectedMod;
@property (nonatomic, strong) NSArray<PCLModrinthVersion *> *selectedModVersions;

@end

@implementation PCLModBrowseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"浏览 Mods";
    self.view.backgroundColor = PCLColor(0xF5F7FA);
    
    self.mods = [NSMutableArray array];
    self.currentOffset = 0;
    self.hasMore = YES;
    self.currentQuery = @"";
    self.currentLoader = PCLModrinthModLoaderForge;
    self.currentSort = PCLModrinthSortTypeRelevance;
    self.currentGameVersion = @"1.20.4";
    self.gameVersions = @[@"1.21", @"1.20.4", @"1.20.2", @"1.20.1", @"1.20", @"1.19.4", @"1.18.2"];
    
    [self setupUI];
    [self loadMods];
}

- (void)setupUI {
    self.view.backgroundColor = PCLColor(0xF5F7FA);
    
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.placeholder = @"搜索 Mods...";
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
    
    self.loaderFilter = [[UISegmentedControl alloc] initWithItems:@[@"Forge", @"Fabric", @"NeoForge", @"Quilt"]];
    self.loaderFilter.selectedSegmentIndex = 0;
    self.loaderFilter.translatesAutoresizingMaskIntoConstraints = NO;
    [self.loaderFilter addTarget:self action:@selector(loaderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.filterBar addSubview:self.loaderFilter];
    
    self.versionFilterButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.versionFilterButton setTitle:self.currentGameVersion forState:UIControlStateNormal];
    [self.versionFilterButton setTitleColor:PCLColor(0x343D4A) forState:UIControlStateNormal];
    self.versionFilterButton.backgroundColor = PCLColor(0xF0F0F0);
    self.versionFilterButton.layer.cornerRadius = 4;
    self.versionFilterButton.titleLabel.font = [UIFont systemFontOfSize:12];
    self.versionFilterButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.versionFilterButton addTarget:self action:@selector(versionFilterTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.filterBar addSubview:self.versionFilterButton];
    
    self.sortFilter = [[UISegmentedControl alloc] initWithItems:@[@"相关", @"下载", @"最新"]];
    self.sortFilter.selectedSegmentIndex = 0;
    self.sortFilter.translatesAutoresizingMaskIntoConstraints = NO;
    [self.sortFilter addTarget:self action:@selector(sortChanged:) forControlEvents:UIControlEventValueChanged];
    [self.filterBar addSubview:self.sortFilter];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.loaderFilter.leadingAnchor constraintEqualToAnchor:self.filterBar.leadingAnchor constant:8],
        [self.loaderFilter.centerYAnchor constraintEqualToAnchor:self.filterBar.centerYAnchor],
        [self.loaderFilter.widthAnchor constraintEqualToConstant:160],
        
        [self.versionFilterButton.leadingAnchor constraintEqualToAnchor:self.loaderFilter.trailingAnchor constant:8],
        [self.versionFilterButton.centerYAnchor constraintEqualToAnchor:self.filterBar.centerYAnchor],
        [self.versionFilterButton.widthAnchor constraintEqualToConstant:70],
        [self.versionFilterButton.heightAnchor constraintEqualToConstant:28],
        
        [self.sortFilter.leadingAnchor constraintEqualToAnchor:self.versionFilterButton.trailingAnchor constant:8],
        [self.sortFilter.centerYAnchor constraintEqualToAnchor:self.filterBar.centerYAnchor],
        [self.sortFilter.widthAnchor constraintEqualToConstant:120]
    ]];
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = 110;
    [self.tableView registerClass:[PCLModCell class] forCellReuseIdentifier:@"ModCell"];
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
    [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
    [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor].active = YES;
    [self.view addSubview:self.loadingIndicator];
    
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

- (void)loadMods {
    if (self.isLoading) return;
    self.isLoading = YES;
    self.emptyLabel.hidden = YES;
    
    if (self.currentOffset == 0) {
        [self.loadingIndicator startAnimating];
    }
    
    [[PCLModrinthAPI sharedAPI] searchProjects:self.currentQuery
                                    projectType:PCLModrinthProjectTypeMod
                                         loader:self.currentLoader
                                    gameVersion:self.currentGameVersion
                                       category:nil
                                       sortType:self.currentSort
                                          limit:20
                                         offset:self.currentOffset
                                     completion:^(PCLModrinthSearchResult *result, NSError *error) {
        self.isLoading = NO;
        [self.loadingIndicator stopAnimating];
        
        if (error) {
            NSLog(@"[ModBrowse] Search failed: %@", error);
            if (self.mods.count == 0) {
                self.emptyLabel.hidden = NO;
                self.emptyLabel.text = @"加载失败，请稍后再试";
            }
            return;
        }
        
        if (self.currentOffset == 0) {
            [self.mods removeAllObjects];
        }
        
        [self.mods addObjectsFromArray:result.hits];
        self.hasMore = (self.currentOffset + result.hits.count) < result.totalHits;
        self.currentOffset += result.hits.count;
        
        self.emptyLabel.hidden = (self.mods.count > 0);
        self.emptyLabel.text = self.currentQuery.length > 0 ? @"未找到匹配的 Mods" : @"暂无 Mods";
        [self.tableView reloadData];
    }];
}

- (void)reloadMods {
    self.currentOffset = 0;
    self.hasMore = YES;
    [self loadMods];
}

#pragma mark - Actions

- (void)loaderChanged:(UISegmentedControl *)sender {
    self.currentOffset = 0;
    self.hasMore = YES;
    [self loadMods];
}

- (void)sortChanged:(UISegmentedControl *)sender {
    switch (sender.selectedSegmentIndex) {
        case 0: self.currentSort = PCLModrinthSortTypeRelevance; break;
        case 1: self.currentSort = PCLModrinthSortTypeDownloads; break;
        case 2: self.currentSort = PCLModrinthSortTypeNewest; break;
    }
    [self reloadMods];
}

- (void)versionFilterTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择游戏版本" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (NSString *version in self.gameVersions) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:version style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            self.currentGameVersion = version;
            [self.versionFilterButton setTitle:version forState:UIControlStateNormal];
            [self reloadMods];
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

- (void)showModDetail:(PCLModrinthProject *)mod {
    self.selectedMod = mod;
    
    self.detailView = [[PCLModDetailView alloc] initWithFrame:self.view.bounds];
    self.detailView.alpha = 0;
    [self.view addSubview:self.detailView];
    
    self.detailView.titleLabel.text = mod.title;
    self.detailView.authorLabel.text = [NSString stringWithFormat:@"by %@", mod.author];
    self.detailView.downloadsLabel.text = [NSString stringWithFormat:@"%@ 次下载", PCLFormatDownloads(mod.downloads)];
    self.detailView.descriptionLabel.text = mod.descriptionText;
    
    __weak typeof(self) weakSelf = self;
    
    self.detailView.onClose = ^{
        [weakSelf hideDetailView];
    };
    
    [UIView animateWithDuration:0.2 animations:^{
        self.detailView.alpha = 1;
    }];
    
    [self loadVersionsForMod:mod];
}

- (void)hideDetailView {
    [UIView animateWithDuration:0.2 animations:^{
        self.detailView.alpha = 0;
    } completion:^(BOOL finished) {
        [self.detailView removeFromSuperview];
        self.detailView = nil;
    }];
}

- (void)loadVersionsForMod:(PCLModrinthProject *)mod {
    [[PCLModrinthAPI sharedAPI] versionsForProject:mod.projectID
                                           facets:@{@"gameVersion": self.currentGameVersion ?: @""}
                                       completion:^(NSArray<PCLModrinthVersion *> *versions, NSError *error) {
        if (error) {
            NSLog(@"[ModBrowse] Failed to load versions: %@", error);
            return;
        }
        
        self.selectedModVersions = versions;
        
        [self.detailView.versionsStack.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        
        for (PCLModrinthVersion *version in versions) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            NSString *title = [NSString stringWithFormat:@"%@ (%@) - %@",
                              version.name,
                              [version.gameVersions componentsJoinedByString:@", "],
                              PCLFormatDownloads(version.downloads)];
            [btn setTitle:title forState:UIControlStateNormal];
            [btn setTitleColor:PCLColor(0x1370F3) forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont systemFontOfSize:13];
            btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
            btn.translatesAutoresizingMaskIntoConstraints = NO;
            btn.tag = [versions indexOfObject:version];
            [btn addTarget:self action:@selector(versionInstallTapped:) forControlEvents:UIControlEventTouchUpInside];
            [self.detailView.versionsStack addArrangedSubview:btn];
            [btn.heightAnchor constraintEqualToConstant:36].active = YES;
        }
        
        if (versions.count == 0) {
            UILabel *noVersions = [[UILabel alloc] init];
            noVersions.text = @"暂无可用版本";
            noVersions.font = [UIFont systemFontOfSize:13];
            noVersions.textColor = PCLColor(0x8C8C8C);
            [self.detailView.versionsStack addArrangedSubview:noVersions];
        }
    }];
}

- (void)versionInstallTapped:(UIButton *)sender {
    if (sender.tag >= self.selectedModVersions.count) return;
    
    PCLModrinthVersion *version = self.selectedModVersions[sender.tag];
    [self installVersion:version];
}

- (void)installVersion:(PCLModrinthVersion *)version {
    PCLModrinthFileInfo *primaryFile = nil;
    for (PCLModrinthFileInfo *file in version.files) {
        if (file.isPrimary) {
            primaryFile = file;
            break;
        }
    }
    if (!primaryFile && version.files.count > 0) {
        primaryFile = version.files[0];
    }
    
    if (!primaryFile) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"下载失败" message:@"无法获取文件信息" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *modsDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"mods"];
    [fm createDirectoryAtPath:modsDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *targetPath = [modsDir stringByAppendingPathComponent:primaryFile.fileName];
    
    __weak typeof(self) weakSelf = self;
    
    [[PCLModrinthAPI sharedAPI] downloadFile:primaryFile
                                       toPath:targetPath
                                     progress:^(double progress) {
        NSLog(@"[ModBrowse] Download progress: %.1f%%", progress * 100);
    } completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"安装成功" message:[NSString stringWithFormat:@"%@ 已下载", primaryFile.fileName] preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
                [weakSelf presentViewController:alert animated:YES completion:nil];
                [weakSelf hideDetailView];
            } else {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"下载失败" message:error.localizedDescription ?: @"未知错误" preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
                [weakSelf presentViewController:alert animated:YES completion:nil];
            }
        });
    }];
}

#pragma mark - UISearchBarDelegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    self.currentQuery = searchBar.text ?: @"";
    [self reloadMods];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        self.currentQuery = @"";
        [self reloadMods];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.mods.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PCLModCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ModCell" forIndexPath:indexPath];
    
    PCLModrinthProject *mod = self.mods[indexPath.row];
    
    cell.nameLabel.text = mod.title;
    cell.authorLabel.text = [NSString stringWithFormat:@"by %@", mod.author];
    cell.downloadsLabel.text = [NSString stringWithFormat:@"⬇ %@", PCLFormatDownloads(mod.downloads)];
    cell.descriptionLabel.text = mod.descriptionText;
    
    if (cell.iconImageView && mod.iconUrl.length > 0) {
        NSURL *url = [NSURL URLWithString:mod.iconUrl];
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
    
    __weak typeof(self) weakSelf = self;
    cell.onInstall = ^{
        [weakSelf showModDetail:mod];
    };
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == self.mods.count - 5 && self.hasMore && !self.isLoading) {
        [self loadMods];
    }
}

@end
