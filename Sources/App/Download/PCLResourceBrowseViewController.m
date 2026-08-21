#import "PCLResourceBrowseViewController.h"
#import "PCLModrinthAPI.h"
#import "PCLDownloadManager.h"
#import "PCLPathUtils.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static UIColor *PCLColor(NSUInteger rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
                           green:((rgb >> 8) & 255) / 255.0
                            blue:(rgb & 255) / 255.0
                           alpha:1.0];
}

static NSString *PCLFormatDownloads(NSInteger downloads) {
    if (downloads >= 1000000) {
        return [NSString stringWithFormat:@"%.1fM", downloads / 1000000.0];
    } else if (downloads >= 1000) {
        return [NSString stringWithFormat:@"%.1fK", downloads / 1000.0];
    }
    return [NSString stringWithFormat:@"%ld", (long)downloads];
}

static NSString *PCLFormatSize(NSInteger bytes) {
    if (bytes >= 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f MB", bytes / (1024.0 * 1024.0)];
    } else if (bytes >= 1024) {
        return [NSString stringWithFormat:@"%.1f KB", bytes / 1024.0];
    }
    return [NSString stringWithFormat:@"%ld B", (long)bytes];
}

#pragma mark - Resource Cell

@interface PCLResourceCell : UITableViewCell
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *authorLabel;
@property (nonatomic, strong) UILabel *downloadsLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) UILabel *versionLabel;
@property (nonatomic, strong) UIButton *installButton;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, copy) void (^onInstall)(void);
@property (nonatomic, copy) void (^onDetail)(void);
@end

@implementation PCLResourceCell

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
    
    self.versionLabel = [[UILabel alloc] init];
    self.versionLabel.font = [UIFont systemFontOfSize:11];
    self.versionLabel.textColor = PCLColor(0x27AE60);
    self.versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.versionLabel];
    
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
        
        [self.authorLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:2],
        [self.authorLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        
        [self.downloadsLabel.topAnchor constraintEqualToAnchor:self.authorLabel.bottomAnchor constant:2],
        [self.downloadsLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        
        [self.versionLabel.topAnchor constraintEqualToAnchor:self.downloadsLabel.bottomAnchor constant:2],
        [self.versionLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        
        [self.descriptionLabel.topAnchor constraintEqualToAnchor:self.versionLabel.bottomAnchor constant:4],
        [self.descriptionLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.descriptionLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
        [self.descriptionLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-12],
        
        [self.installButton.centerYAnchor constraintEqualToAnchor:self.nameLabel.centerYAnchor],
        [self.installButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
        [self.installButton.leadingAnchor constraintEqualToAnchor:self.nameLabel.trailingAnchor constant:8],
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

#pragma mark - Detail View

@interface PCLResourceDetailView : UIView
@property (nonatomic, copy) void (^onClose)(void);
@property (nonatomic, copy) void (^onInstallVersion)(PCLModrinthVersion *version);
@property (nonatomic, copy) void (^onInstallDependency)(PCLModrinthProject *dep);

- (void)configureWithProject:(PCLModrinthProject *)project versions:(NSArray<PCLModrinthVersion *> *)versions;

@end

@interface PCLResourceDetailView ()
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *authorLabel;
@property (nonatomic, strong) UILabel *downloadsLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) UILabel *dependenciesTitleLabel;
@property (nonatomic, strong) UIStackView *dependenciesStack;
@property (nonatomic, strong) UILabel *versionsTitleLabel;
@property (nonatomic, strong) UIStackView *versionsStack;
@property (nonatomic, strong) NSArray<PCLModrinthProject *> *dependencyProjects;
@end

@implementation PCLResourceDetailView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
    
    self.cardView = [[UIView alloc] init];
    self.cardView.backgroundColor = [UIColor whiteColor];
    self.cardView.layer.cornerRadius = 16;
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.cardView];
    
    self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.closeButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:PCLColor(0x8C8C8C) forState:UIControlStateNormal];
    self.closeButton.titleLabel.font = [UIFont systemFontOfSize:20];
    self.closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.cardView addSubview:self.closeButton];
    
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.cardView addSubview:self.scrollView];
    
    self.iconImageView = [[UIImageView alloc] init];
    self.iconImageView.layer.cornerRadius = 12;
    self.iconImageView.clipsToBounds = YES;
    self.iconImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconImageView.backgroundColor = PCLColor(0xF0F0F0);
    self.iconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.iconImageView];
    
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    self.titleLabel.textColor = PCLColor(0x343D4A);
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.titleLabel];
    
    self.authorLabel = [[UILabel alloc] init];
    self.authorLabel.font = [UIFont systemFontOfSize:13];
    self.authorLabel.textColor = PCLColor(0x1370F3);
    self.authorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.authorLabel];
    
    self.downloadsLabel = [[UILabel alloc] init];
    self.downloadsLabel.font = [UIFont systemFontOfSize:12];
    self.downloadsLabel.textColor = PCLColor(0x8C8C8C);
    self.downloadsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.downloadsLabel];
    
    self.descriptionLabel = [[UILabel alloc] init];
    self.descriptionLabel.font = [UIFont systemFontOfSize:13];
    self.descriptionLabel.textColor = PCLColor(0x343D4A);
    self.descriptionLabel.numberOfLines = 0;
    self.descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.descriptionLabel];
    
    // Dependencies section (前置依赖)
    self.dependenciesTitleLabel = [[UILabel alloc] init];
    self.dependenciesTitleLabel.text = @"前置依赖";
    self.dependenciesTitleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    self.dependenciesTitleLabel.textColor = PCLColor(0x343D4A);
    self.dependenciesTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.dependenciesTitleLabel.hidden = YES;
    [self.scrollView addSubview:self.dependenciesTitleLabel];
    
    self.dependenciesStack = [[UIStackView alloc] init];
    self.dependenciesStack.axis = UILayoutConstraintAxisVertical;
    self.dependenciesStack.spacing = 8;
    self.dependenciesStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.dependenciesStack];
    
    // Versions section
    self.versionsTitleLabel = [[UILabel alloc] init];
    self.versionsTitleLabel.text = @"可用版本";
    self.versionsTitleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    self.versionsTitleLabel.textColor = PCLColor(0x343D4A);
    self.versionsTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.versionsTitleLabel];
    
    self.versionsStack = [[UIStackView alloc] init];
    self.versionsStack.axis = UILayoutConstraintAxisVertical;
    self.versionsStack.spacing = 8;
    self.versionsStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.versionsStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.cardView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.cardView.widthAnchor constraintEqualToAnchor:self.widthAnchor multiplier:0.9],
        [self.cardView.heightAnchor constraintEqualToAnchor:self.heightAnchor multiplier:0.8],
        
        [self.closeButton.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:12],
        [self.closeButton.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-12],
        [self.closeButton.widthAnchor constraintEqualToConstant:32],
        [self.closeButton.heightAnchor constraintEqualToConstant:32],
        
        [self.scrollView.topAnchor constraintEqualToAnchor:self.closeButton.bottomAnchor constant:4],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:16],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-16],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-16],
        
        [self.iconImageView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.iconImageView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.iconImageView.widthAnchor constraintEqualToConstant:64],
        [self.iconImageView.heightAnchor constraintEqualToConstant:64],
        
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.iconImageView.topAnchor],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.iconImageView.trailingAnchor constant:12],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.scrollView.trailingAnchor],
        
        [self.authorLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
        [self.authorLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.authorLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.scrollView.trailingAnchor],
        
        [self.downloadsLabel.topAnchor constraintEqualToAnchor:self.authorLabel.bottomAnchor constant:4],
        [self.downloadsLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        
        [self.descriptionLabel.topAnchor constraintEqualToAnchor:self.iconImageView.bottomAnchor constant:16],
        [self.descriptionLabel.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.descriptionLabel.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        
        [self.dependenciesTitleLabel.topAnchor constraintEqualToAnchor:self.descriptionLabel.bottomAnchor constant:20],
        [self.dependenciesTitleLabel.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.dependenciesTitleLabel.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        
        [self.dependenciesStack.topAnchor constraintEqualToAnchor:self.dependenciesTitleLabel.bottomAnchor constant:12],
        [self.dependenciesStack.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.dependenciesStack.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        
        [self.versionsTitleLabel.topAnchor constraintEqualToAnchor:self.dependenciesStack.bottomAnchor constant:20],
        [self.versionsTitleLabel.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.versionsTitleLabel.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        
        [self.versionsStack.topAnchor constraintEqualToAnchor:self.versionsTitleLabel.bottomAnchor constant:12],
        [self.versionsStack.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.versionsStack.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.versionsStack.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:-16]
    ]];
}

- (void)configureWithProject:(PCLModrinthProject *)project versions:(NSArray<PCLModrinthVersion *> *)versions {
    self.titleLabel.text = project.title;
    self.authorLabel.text = [NSString stringWithFormat:@"by %@", project.author];
    self.downloadsLabel.text = [NSString stringWithFormat:@"%@ 次下载", PCLFormatDownloads(project.downloads)];
    self.descriptionLabel.text = project.descriptionText;
    
    // 异步加载图标
    if (project.iconUrl.length > 0) {
        NSURL *url = [NSURL URLWithString:project.iconUrl];
        if (url) {
            NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (data) {
                    UIImage *image = [UIImage imageWithData:data];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.iconImageView.image = image;
                    });
                }
            }];
            [task resume];
        }
    }
    
    // 清空旧版本
    [self.versionsStack.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.dependenciesStack.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    // 填充版本列表（显示加载器类型、版本号、大小）
    for (PCLModrinthVersion *version in versions) {
        UIView *versionRow = [self createVersionRow:version];
        [self.versionsStack addArrangedSubview:versionRow];
    }
    
    if (versions.count == 0) {
        UILabel *noVersions = [[UILabel alloc] init];
        noVersions.text = @"暂无可用版本";
        noVersions.font = [UIFont systemFontOfSize:13];
        noVersions.textColor = PCLColor(0x8C8C8C);
        [self.versionsStack addArrangedSubview:noVersions];
    }
    
    // 显示前置依赖
    if (versions.count > 0) {
        NSArray *deps = versions.firstObject.dependencies;
        if (deps.count > 0) {
            self.dependenciesTitleLabel.hidden = NO;
            [self loadDependencyDetails:deps];
        }
    }
}

- (UIView *)createVersionRow:(PCLModrinthVersion *)version {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = PCLColor(0xF8F9FA);
    row.layer.cornerRadius = 8;
    
    // 版本名称和类型
    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    nameLabel.textColor = PCLColor(0x343D4A);
    NSString *typeBadge = @"";
    if ([version.versionType isEqualToString:@"release"]) typeBadge = @" [正式版]";
    else if ([version.versionType isEqualToString:@"beta"]) typeBadge = @" [測試版]";
    else if ([version.versionType isEqualToString:@"alpha"]) typeBadge = @" [預覽版]";
    nameLabel.text = [NSString stringWithFormat:@"%@%@", version.name, typeBadge];
    [row addSubview:nameLabel];
    
    // 游戏版本、加载器、文件大小
    UILabel *infoLabel = [[UILabel alloc] init];
    infoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    infoLabel.font = [UIFont systemFontOfSize:12];
    infoLabel.textColor = PCLColor(0x8C8C8C);
    
    NSMutableArray *infoParts = [NSMutableArray array];
    if (version.gameVersions.count > 0) {
        [infoParts addObject:[NSString stringWithFormat:@"MC %@", [version.gameVersions componentsJoinedByString:@", "]]];
    }
    if (version.loaders.count > 0) {
        [infoParts addObject:[version.loaders.firstObject capitalizedString]];
    }
    if (version.fileInfos.count > 0) {
        [infoParts addObject:PCLFormatSize(version.fileInfos.firstObject.size)];
    }
    infoLabel.text = [infoParts componentsJoinedByString:@" · "];
    [row addSubview:infoLabel];
    
    // 安装按钮
    UIButton *installBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    installBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [installBtn setTitle:@"▼" forState:UIControlStateNormal];
    [installBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    installBtn.backgroundColor = PCLColor(0x1370F3);
    installBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    installBtn.layer.cornerRadius = 4;
    [installBtn addTarget:self action:@selector(versionInstallTapped:) forControlEvents:UIControlEventTouchUpInside];
    objc_setAssociatedObject(installBtn, "version", version, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [row addSubview:installBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:70],
        [nameLabel.topAnchor constraintEqualToAnchor:row.topAnchor constant:10],
        [nameLabel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12],
        [nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:installBtn.leadingAnchor constant:-8],
        [infoLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:4],
        [infoLabel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12],
        [infoLabel.trailingAnchor constraintLessThanOrEqualToAnchor:installBtn.leadingAnchor constant:-8],
        [infoLabel.bottomAnchor constraintLessThanOrEqualToAnchor:row.bottomAnchor constant:-10],
        [installBtn.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [installBtn.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12],
        [installBtn.widthAnchor constraintEqualToConstant:36],
        [installBtn.heightAnchor constraintEqualToConstant:36]
    ]];
    
    return row;
}

- (void)versionInstallTapped:(UIButton *)sender {
    PCLModrinthVersion *version = objc_getAssociatedObject(sender, "version");
    if (self.onInstallVersion) self.onInstallVersion(version);
}

- (void)loadDependencyDetails:(NSArray<PCLModrinthDependency *> *)deps {
    [self.dependenciesStack.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    for (PCLModrinthDependency *dep in deps) {
        if (![dep.dependencyType isEqualToString:@"required"]) continue;
        
        UIView *depRow = [[UIView alloc] init];
        depRow.translatesAutoresizingMaskIntoConstraints = NO;
        depRow.backgroundColor = PCLColor(0xFEF3C7);
        depRow.layer.cornerRadius = 6;
        
        UILabel *depLabel = [[UILabel alloc] init];
        depLabel.translatesAutoresizingMaskIntoConstraints = NO;
        depLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        depLabel.textColor = PCLColor(0x92400E);
        depLabel.text = [NSString stringWithFormat:@"📦 %@", dep.projectID];
        [depRow addSubview:depLabel];
        
        // 尝试获取依赖项目信息
        [[PCLModrinthAPI sharedAPI] getProject:dep.projectID completion:^(PCLModrinthProject *project, NSError *error) {
            if (project) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    depLabel.text = [NSString stringWithFormat:@"📦 %@", project.title];
                });
            }
        }];
        
        [depLabel.topAnchor constraintEqualToAnchor:depRow.topAnchor constant:8].active = YES;
        [depLabel.leadingAnchor constraintEqualToAnchor:depRow.leadingAnchor constant:10].active = YES;
        [depLabel.trailingAnchor constraintEqualToAnchor:depRow.trailingAnchor constant:-10].active = YES;
        [depLabel.bottomAnchor constraintEqualToAnchor:depRow.bottomAnchor constant:-8].active = YES;
        
        [self.dependenciesStack addArrangedSubview:depRow];
    }
}

- (void)closeTapped {
    if (self.onClose) self.onClose();
}

@end

#pragma mark - Main View Controller

@interface PCLResourceBrowseViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>

@property (nonatomic, strong) UIScrollView *tabScrollView;
@property (nonatomic, strong) UIStackView *tabStackView;
@property (nonatomic, strong) NSMutableArray<UIButton *> *tabButtons;
@property (nonatomic, strong) UIView *indicatorView;

@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIView *filterBar;
@property (nonatomic, strong) UISegmentedControl *loaderFilter;
@property (nonatomic, strong) UIButton *versionFilterButton;
@property (nonatomic, strong) UISegmentedControl *sortFilter;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<PCLModrinthProject *> *resources;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) PCLResourceDetailView *detailView;

@property (nonatomic, assign) PCLResourceTab currentTab;
@property (nonatomic, assign) NSInteger currentOffset;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL hasMore;
@property (nonatomic, copy) NSString *currentQuery;
@property (nonatomic, assign) PCLModrinthModLoader currentLoader;
@property (nonatomic, assign) PCLModrinthSortType currentSort;
@property (nonatomic, copy) NSString *currentGameVersion;
@property (nonatomic, strong) NSArray<NSString *> *gameVersions;

@property (nonatomic, strong) PCLModrinthProject *selectedResource;
@property (nonatomic, strong) NSArray<PCLModrinthVersion *> *selectedVersions;

@property (nonatomic, strong) NSMutableArray<PCLDownloadTask *> *downloadTasks;

- (NSArray<NSString *> *)tabTitles;

@end

@implementation PCLResourceBrowseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = [self titleForType:self.currentTab];
    self.view.backgroundColor = PCLColor(0xF5F7FA);
    
    self.resources = [NSMutableArray array];
    self.downloadTasks = [NSMutableArray array];
    self.currentOffset = 0;
    self.hasMore = YES;
    self.currentQuery = @"";
    self.currentLoader = PCLModrinthModLoaderForge;
    self.currentSort = PCLModrinthSortTypeRelevance;
    self.currentGameVersion = @"1.20.4";
    self.gameVersions = @[@"1.21.1", @"1.21", @"1.20.4", @"1.20.2", @"1.20.1", @"1.20", @"1.19.4", @"1.18.2", @"1.16.5"];
    
    [self setupUI];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.resources.count == 0) [self loadResources];
}

- (NSString *)titleForType:(PCLResourceTab)tab {
    switch (tab) {
        case PCLResourceTabMod: return @"模组";
        case PCLResourceTabModpack: return @"整合包";
        case PCLResourceTabResourcePack: return @"资源包";
        case PCLResourceTabShader: return @"光影";
        case PCLResourceTabDataPack: return @"数据包";
    }
}

- (NSArray<NSString *> *)tabTitles {
    return @[@"模组", @"整合包", @"资源包", @"光影", @"数据包"];
}

- (PCLModrinthProjectType)projectTypeForTab:(PCLResourceTab)tab {
    switch (tab) {
        case PCLResourceTabMod: return PCLModrinthProjectTypeMod;
        case PCLResourceTabModpack: return PCLModrinthProjectTypeModpack;
        case PCLResourceTabResourcePack: return PCLModrinthProjectTypeResourcePack;
        case PCLResourceTabShader: return PCLModrinthProjectTypeShader;
        case PCLResourceTabDataPack: return PCLModrinthProjectTypeDataPack;
    }
}

#pragma mark - UI Setup

- (void)setupUI {
    NSArray *tabTitles = @[@"模组", @"整合包", @"资源包", @"光影", @"数据包"];
    self.tabButtons = [NSMutableArray array];
    
    // 标签栏
    self.tabScrollView = [[UIScrollView alloc] init];
    self.tabScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabScrollView.showsHorizontalScrollIndicator = NO;
    self.tabScrollView.backgroundColor = [UIColor whiteColor];
    self.tabScrollView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.tabScrollView.layer.shadowOpacity = 0.05;
    self.tabScrollView.layer.shadowRadius = 4;
    self.tabScrollView.layer.shadowOffset = CGSizeMake(0, 2);
    [self.view addSubview:self.tabScrollView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tabScrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tabScrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tabScrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tabScrollView.heightAnchor constraintEqualToConstant:44]
    ]];
    
    self.tabStackView = [[UIStackView alloc] init];
    self.tabStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabStackView.axis = UILayoutConstraintAxisHorizontal;
    self.tabStackView.spacing = 0;
    self.tabStackView.alignment = UIStackViewAlignmentCenter;
    [self.tabScrollView addSubview:self.tabStackView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tabStackView.topAnchor constraintEqualToAnchor:self.tabScrollView.topAnchor],
        [self.tabStackView.leadingAnchor constraintEqualToAnchor:self.tabScrollView.leadingAnchor constant:8],
        [self.tabStackView.trailingAnchor constraintEqualToAnchor:self.tabScrollView.trailingAnchor constant:-8],
        [self.tabStackView.bottomAnchor constraintEqualToAnchor:self.tabScrollView.bottomAnchor],
        [self.tabStackView.heightAnchor constraintEqualToAnchor:self.tabScrollView.heightAnchor]
    ]];
    
    for (NSInteger i = 0; i < tabTitles.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        [btn setTitle:tabTitles[i] forState:UIControlStateNormal];
        [btn setTitleColor:PCLColor(0x8C8C8C) forState:UIControlStateNormal];
        [btn setTitleColor:PCLColor(0x1370F3) forState:UIControlStateSelected];
        btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        btn.tag = i;
        btn.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
        [btn addTarget:self action:@selector(resourceTabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.tabStackView addArrangedSubview:btn];
        [self.tabButtons addObject:btn];
        [btn.heightAnchor constraintEqualToConstant:44].active = YES;
        if (i == self.currentTab) btn.selected = YES;
    }
    
    // 指示器
    self.indicatorView = [[UIView alloc] init];
    self.indicatorView.backgroundColor = PCLColor(0x1370F3);
    self.indicatorView.layer.cornerRadius = 1.5;
    [self.tabScrollView addSubview:self.indicatorView];
    
    // 搜索栏
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchBar.placeholder = [NSString stringWithFormat:@"搜索%@...", tabTitles[self.currentTab]];
    self.searchBar.delegate = self;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.searchBar];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.searchBar.topAnchor constraintEqualToAnchor:self.tabScrollView.bottomAnchor],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.searchBar.heightAnchor constraintEqualToConstant:44]
    ]];
    
    // 筛选栏
    self.filterBar = [[UIView alloc] init];
    self.filterBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.filterBar.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.filterBar];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.filterBar.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor],
        [self.filterBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.filterBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.filterBar.heightAnchor constraintEqualToConstant:40]
    ]];
    
    // 加载器筛选
    self.loaderFilter = [[UISegmentedControl alloc] initWithItems:@[@"Forge", @"Fabric", @"NeoForge", @"Quilt"]];
    self.loaderFilter.selectedSegmentIndex = 0;
    self.loaderFilter.translatesAutoresizingMaskIntoConstraints = NO;
    [self.loaderFilter addTarget:self action:@selector(loaderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.filterBar addSubview:self.loaderFilter];
    
    // 游戏版本筛选
    self.versionFilterButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.versionFilterButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.versionFilterButton setTitle:self.currentGameVersion forState:UIControlStateNormal];
    [self.versionFilterButton setTitleColor:PCLColor(0x343D4A) forState:UIControlStateNormal];
    self.versionFilterButton.backgroundColor = PCLColor(0xF0F0F0);
    self.versionFilterButton.titleLabel.font = [UIFont systemFontOfSize:12];
    self.versionFilterButton.layer.cornerRadius = 4;
    [self.versionFilterButton addTarget:self action:@selector(versionFilterTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.filterBar addSubview:self.versionFilterButton];
    
    // 排序筛选
    self.sortFilter = [[UISegmentedControl alloc] initWithItems:@[@"相关", @"下载", @"最新"]];
    self.sortFilter.selectedSegmentIndex = 0;
    self.sortFilter.translatesAutoresizingMaskIntoConstraints = NO;
    [self.sortFilter addTarget:self action:@selector(sortChanged:) forControlEvents:UIControlEventValueChanged];
    [self.filterBar addSubview:self.sortFilter];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.loaderFilter.leadingAnchor constraintEqualToAnchor:self.filterBar.leadingAnchor constant:8],
        [self.loaderFilter.centerYAnchor constraintEqualToAnchor:self.filterBar.centerYAnchor],
        [self.loaderFilter.widthAnchor constraintEqualToConstant:150],
        [self.loaderFilter.heightAnchor constraintEqualToConstant:30],
        
        [self.versionFilterButton.leadingAnchor constraintEqualToAnchor:self.loaderFilter.trailingAnchor constant:6],
        [self.versionFilterButton.centerYAnchor constraintEqualToAnchor:self.filterBar.centerYAnchor],
        [self.versionFilterButton.widthAnchor constraintEqualToConstant:70],
        [self.versionFilterButton.heightAnchor constraintEqualToConstant:28],
        
        [self.sortFilter.leadingAnchor constraintEqualToAnchor:self.versionFilterButton.trailingAnchor constant:6],
        [self.sortFilter.centerYAnchor constraintEqualToAnchor:self.filterBar.centerYAnchor],
        [self.sortFilter.widthAnchor constraintEqualToConstant:110],
        [self.sortFilter.heightAnchor constraintEqualToConstant:30]
    ]];
    
    // 表格
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = 130;
    [self.tableView registerClass:[PCLResourceCell class] forCellReuseIdentifier:@"ResourceCell"];
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.filterBar.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    
    // 加载指示器
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.loadingIndicator];
    [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
    [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor].active = YES;
    
    // 空状态
    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.font = [UIFont systemFontOfSize:14];
    self.emptyLabel.textColor = PCLColor(0x8C8C8C);
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];
    [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
    [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor].active = YES;
    
    [self updateIndicatorPosition];
}

#pragma mark - Tab Switching

- (void)resourceTabTapped:(UIButton *)sender {
    self.currentTab = (PCLResourceTab)sender.tag;
    
    // 更新按钮状态
    for (UIButton *btn in self.tabButtons) {
        btn.selected = (btn.tag == self.currentTab);
        btn.titleLabel.font = btn.selected ?
            [UIFont systemFontOfSize:14 weight:UIFontWeightBold] :
            [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    }
    
    // 更新搜索占位符和标题
    self.searchBar.placeholder = [NSString stringWithFormat:@"搜索%@...", sender.titleLabel.text];
    self.title = sender.titleLabel.text;
    
    // 重置筛选器
    if (self.currentTab == PCLResourceTabModpack || self.currentTab == PCLResourceTabResourcePack ||
        self.currentTab == PCLResourceTabShader || self.currentTab == PCLResourceTabDataPack) {
        self.loaderFilter.hidden = YES;
    } else {
        self.loaderFilter.hidden = NO;
    }
    
    // 重新加载
    [self reloadResources];
    [self updateIndicatorPosition];
}

- (void)updateIndicatorPosition {
    UIButton *selectedBtn = self.tabButtons[self.currentTab];
    CGRect btnFrame = [self.tabScrollView convertRect:selectedBtn.frame fromView:self.tabStackView];
    
    [UIView animateWithDuration:0.25 animations:^{
        self.indicatorView.frame = CGRectMake(btnFrame.origin.x + btnFrame.size.width / 2 - 15,
                                             self.tabScrollView.bounds.size.height - 3,
                                             30, 3);
        // 滚动标签
        CGFloat targetX = selectedBtn.center.x - self.tabScrollView.bounds.size.width / 2;
        targetX = MAX(0, MIN(targetX, self.tabScrollView.contentSize.width - self.tabScrollView.bounds.size.width));
        [self.tabScrollView setContentOffset:CGPointMake(targetX, 0) animated:YES];
    }];
}

#pragma mark - Data Loading

- (void)loadResources {
    if (self.isLoading) return;
    self.isLoading = YES;
    self.emptyLabel.hidden = YES;
    
    if (self.currentOffset == 0) {
        [self.loadingIndicator startAnimating];
    }
    
    [[PCLModrinthAPI sharedAPI] searchProjects:self.currentQuery
                                    projectType:[self projectTypeForTab:self.currentTab]
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
            NSLog(@"[ResourceBrowse] Search failed: %@", error);
            if (self.resources.count == 0) {
                self.emptyLabel.hidden = NO;
                self.emptyLabel.text = @"加载失败，请稍后再试";
            }
            return;
        }
        
        if (self.currentOffset == 0) {
            [self.resources removeAllObjects];
        }
        
        [self.resources addObjectsFromArray:result.hits];
        self.hasMore = (self.currentOffset + result.hits.count) < result.totalHits;
        self.currentOffset += result.hits.count;
        
        self.emptyLabel.hidden = (self.resources.count > 0);
        self.emptyLabel.text = self.currentQuery.length > 0 ? [NSString stringWithFormat:@"未找到匹配的%@", self.tabTitles[self.currentTab]] : [NSString stringWithFormat:@"暂无%@", self.tabTitles[self.currentTab]];
        [self.tableView reloadData];
    }];
}

- (void)reloadResources {
    self.currentOffset = 0;
    self.hasMore = YES;
    [self loadResources];
}

#pragma mark - Actions

- (void)loaderChanged:(UISegmentedControl *)sender {
    self.currentLoader = (PCLModrinthModLoader)sender.selectedSegmentIndex;
    [self reloadResources];
}

- (void)sortChanged:(UISegmentedControl *)sender {
    self.currentSort = (PCLModrinthSortType)sender.selectedSegmentIndex;
    [self reloadResources];
}

- (void)versionFilterTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择游戏版本" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (NSString *version in self.gameVersions) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:version style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            self.currentGameVersion = version;
            [self.versionFilterButton setTitle:version forState:UIControlStateNormal];
            [self reloadResources];
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

#pragma mark - Detail View

- (void)showResourceDetail:(PCLModrinthProject *)resource {
    self.selectedResource = resource;
    
    self.detailView = [[PCLResourceDetailView alloc] initWithFrame:self.view.bounds];
    self.detailView.alpha = 0;
    [self.view addSubview:self.detailView];
    
    __weak typeof(self) weakSelf = self;
    self.detailView.onClose = ^{
        [weakSelf hideDetailView];
    };
    
    self.detailView.onInstallVersion = ^(PCLModrinthVersion *version) {
        [weakSelf installVersion:version forResource:resource];
    };
    
    [UIView animateWithDuration:0.2 animations:^{
        self.detailView.alpha = 1;
    }];
    
    // 加载版本信息
    [self loadVersionsForResource:resource];
}

- (void)hideDetailView {
    [UIView animateWithDuration:0.2 animations:^{
        self.detailView.alpha = 0;
    } completion:^(BOOL finished) {
        [self.detailView removeFromSuperview];
        self.detailView = nil;
    }];
}

- (void)loadVersionsForResource:(PCLModrinthProject *)resource {
    [[PCLModrinthAPI sharedAPI] versionsForProject:resource.projectID
                                           facets:@{@"gameVersion": self.currentGameVersion ?: @"",
                                                    @"loader": [[PCLModrinthAPI loaderString:self.currentLoader] stringByReplacingOccurrencesOfString:@"\"" withString:@""]}
                                       completion:^(NSArray<PCLModrinthVersion *> *versions, NSError *error) {
        if (error) {
            NSLog(@"[ResourceBrowse] Failed to load versions: %@", error);
            return;
        }
        self.selectedVersions = versions;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.detailView configureWithProject:resource versions:versions];
        });
    }];
}

#pragma mark - Install

- (void)installVersion:(PCLModrinthVersion *)version forResource:(PCLModrinthProject *)resource {
    PCLModrinthFileInfo *primaryFile = nil;
    for (PCLModrinthFileInfo *file in version.fileInfos) {
        if (file.isPrimary) {
            primaryFile = file;
            break;
        }
    }
    if (!primaryFile && version.fileInfos.count > 0) {
        primaryFile = version.fileInfos[0];
    }
    
    if (!primaryFile) {
        [self showAlertWithTitle:@"安装失败" message:@"无法获取文件信息"];
        return;
    }
    
    // 检查前置依赖
    NSArray *requiredDeps = [version.dependencies filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"dependencyType == %@", "required"]];
    if (requiredDeps.count > 0) {
        [self showDependencyAlert:requiredDeps resource:resource version:version file:primaryFile];
        return;
    }
    
    [self startInstallVersion:version resource:resource file:primaryFile];
}

- (void)showDependencyAlert:(NSArray<PCLModrinthDependency *> *)deps resource:(PCLModrinthProject *)resource version:(PCLModrinthVersion *)version file:(PCLModrinthFileInfo *)file {
    NSMutableString *depNames = [NSMutableString string];
    for (PCLModrinthDependency *dep in deps) {
        [depNames appendFormat:@"• %@\n", dep.projectID];
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"前置依赖"
                                                                  message:[NSString stringWithFormat:@"此%@需要以下前置依赖：\n\n%@\n是否继续安装？", self.tabTitles[self.currentTab], depNames]
                                                           preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"安装" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self startInstallVersion:version resource:resource file:file];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)startInstallVersion:(PCLModrinthVersion *)version resource:(PCLModrinthProject *)resource file:(PCLModrinthFileInfo *)file {
    // 确定目标目录
    NSString *targetDir;
    switch (self.currentTab) {
        case PCLResourceTabMod:
            targetDir = [self modsDirectory];
            break;
        case PCLResourceTabModpack:
            targetDir = [self modpacksDirectory];
            break;
        case PCLResourceTabResourcePack:
            targetDir = [self resourcePacksDirectory];
            break;
        case PCLResourceTabShader:
            targetDir = [self shadersDirectory];
            break;
        case PCLResourceTabDataPack:
            targetDir = [self datapacksDirectory];
            break;
    }
    
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:targetDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *targetPath = [targetDir stringByAppendingPathComponent:file.fileName];
    
    // 创建下载任务
    PCLDownloadTask *task = [[PCLDownloadTask alloc] init];
    task.displayName = resource.title;
    task.url = file.url;
    task.targetPath = targetPath;
    task.sha1 = file.sha1;
    task.resourceType = (PCLResourceType)self.currentTab;
    task.state = PCLDownloadStatePending;
    
    [self.downloadTasks addObject:task];
    [[PCLDownloadManager sharedManager] addTask:task];
    [[PCLDownloadManager sharedManager] startDownload:task];
    
    // 更新UI
    [self updateCellForTask:task];
    
    // 显示安装进度
    [self showAlertWithTitle:@"开始安装" message:[NSString stringWithFormat:@"%@ 正在下载...", resource.title]];
    [self.tableView reloadData];
}

- (NSString *)modsDirectory {
    return [[PCLPathUtils gameDirectory] stringByAppendingPathComponent:@"mods"];
}

- (NSString *)modpacksDirectory {
    return [[PCLPathUtils gameDirectory] stringByAppendingPathComponent:@"modpacks"];
}

- (NSString *)resourcePacksDirectory {
    return [[PCLPathUtils gameDirectory] stringByAppendingPathComponent:@"resourcepacks"];
}

- (NSString *)shadersDirectory {
    return [[PCLPathUtils gameDirectory] stringByAppendingPathComponent:@"shaderpacks"];
}

- (NSString *)datapacksDirectory {
    return [[PCLPathUtils gameDirectory] stringByAppendingPathComponent:@"datapacks"];
}

- (void)updateCellForTask:(PCLDownloadTask *)task {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

#pragma mark - Alerts

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.resources.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PCLResourceCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ResourceCell" forIndexPath:indexPath];
    
    PCLModrinthProject *resource = self.resources[indexPath.row];
    
    cell.nameLabel.text = resource.title;
    cell.authorLabel.text = [NSString stringWithFormat:@"by %@", resource.author];
    cell.downloadsLabel.text = [NSString stringWithFormat:@"⬇ %@", PCLFormatDownloads(resource.downloads)];
    cell.descriptionLabel.text = resource.descriptionText;
    
    // 显示支持的游戏版本和加载器
    NSMutableArray *infoParts = [NSMutableArray array];
    if (resource.gameVersions.count > 0) {
        [infoParts addObject:[NSString stringWithFormat:@"MC %@", [resource.gameVersions subarrayWithRange:NSMakeRange(0, MIN(3, resource.gameVersions.count))]]];
    }
    if (resource.loaders.count > 0) {
        [infoParts addObject:resource.loaders.firstObject];
    }
    cell.versionLabel.text = [infoParts componentsJoinedByString:@" · "];
    cell.versionLabel.hidden = (infoParts.count == 0);
    
    // 加载图标
    if (resource.iconUrl.length > 0) {
        NSURL *url = [NSURL URLWithString:resource.iconUrl];
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
    
    // 查找此资源的下载任务
    PCLDownloadTask *task = [self taskForResource:resource];
    if (task && (task.state == PCLDownloadStateDownloading || task.state == PCLDownloadStatePending)) {
        cell.installButton.hidden = YES;
        cell.progressView.hidden = NO;
        cell.progressView.progress = task.progress;
    } else if (task && task.state == PCLDownloadStateCompleted) {
        cell.installButton.hidden = NO;
        [cell.installButton setTitle:@"✓" forState:UIControlStateNormal];
        cell.installButton.backgroundColor = PCLColor(0x27AE60);
        cell.progressView.hidden = YES;
    } else {
        cell.installButton.hidden = NO;
        [cell.installButton setTitle:@"安装" forState:UIControlStateNormal];
        cell.installButton.backgroundColor = PCLColor(0x1370F3);
        cell.progressView.hidden = YES;
    }
    
    __weak typeof(self) weakSelf = self;
    cell.onInstall = ^{
        [weakSelf showResourceDetail:resource];
    };
    
    return cell;
}

- (PCLDownloadTask *)taskForResource:(PCLModrinthProject *)resource {
    for (PCLDownloadTask *task in self.downloadTasks) {
        if ([task.displayName isEqualToString:resource.title]) {
            return task;
        }
    }
    return nil;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == self.resources.count - 5 && self.hasMore && !self.isLoading) {
        [self loadResources];
    }
}

#pragma mark - UISearchBarDelegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    self.currentQuery = searchBar.text ?: @"";
    [self reloadResources];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        self.currentQuery = @"";
        [self reloadResources];
    }
}

@end
