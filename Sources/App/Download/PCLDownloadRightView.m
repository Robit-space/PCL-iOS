#import "PCLDownloadRightView.h"
#import "PCLCEPageAnimator.h"
#import "PCLNetworkUtils.h"
#import "PCLVersionManager.h"
#import "PCLDownloadManager.h"
#import "PCLModLoaderAPI.h"
#import "PCLProfileStore.h"
#import <QuartzCore/QuartzCore.h>

static UIColor *PCLColor(NSUInteger rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
                           green:((rgb >> 8) & 255) / 255.0
                            blue:(rgb & 255) / 255.0
                           alpha:1.0];
}

@interface PCLDownloadVersionCell : UITableViewCell
@property (nonatomic, strong) UIImageView *versionIcon;
@property (nonatomic, strong) UILabel *versionLabel;
@property (nonatomic, strong) UILabel *typeLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UIButton *downloadButton;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, copy) void (^onDownload)(void);
@end

@implementation PCLDownloadVersionCell

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
    self.contentView.backgroundColor=[PCLColor(0xFBFBFB) colorWithAlphaComponent:.9];
    self.contentView.clipsToBounds=YES;
    self.versionIcon=[[UIImageView alloc] init];
    self.versionIcon.contentMode=UIViewContentModeScaleAspectFit;
    self.versionIcon.translatesAutoresizingMaskIntoConstraints=NO;
    [self.contentView addSubview:self.versionIcon];

    self.versionLabel = [[UILabel alloc] init];
    self.versionLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.versionLabel.textColor = PCLColor(0x343D4A);
    self.versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.versionLabel];

    self.typeLabel = [[UILabel alloc] init];
    self.typeLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    self.typeLabel.textColor = [UIColor whiteColor];
    self.typeLabel.backgroundColor = PCLColor(0x1370F3);
    self.typeLabel.layer.cornerRadius = 3;
    self.typeLabel.clipsToBounds = YES;
    self.typeLabel.textAlignment = NSTextAlignmentCenter;
    self.typeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.typeLabel]; self.typeLabel.hidden=YES;

    self.dateLabel = [[UILabel alloc] init];
    self.dateLabel.font = [UIFont systemFontOfSize:12];
    self.dateLabel.textColor = PCLColor(0x8C8C8C);
    self.dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.dateLabel];

    self.downloadButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.downloadButton setTitle:@"下载" forState:UIControlStateNormal];
    [self.downloadButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.downloadButton.backgroundColor = PCLColor(0x1370F3);
    self.downloadButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.downloadButton.layer.cornerRadius = 6;
    self.downloadButton.clipsToBounds = YES;
    self.downloadButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.downloadButton addTarget:self action:@selector(downloadTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.downloadButton]; self.downloadButton.hidden=YES;

    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressView.progressTintColor = PCLColor(0x1370F3);
    self.progressView.trackTintColor = PCLColor(0xE0EAFD);
    self.progressView.hidden = YES;
    [self.contentView addSubview:self.progressView];


}

- (void)layoutSubviews{[super layoutSubviews];CGFloat w=self.contentView.bounds.size.width,h=self.contentView.bounds.size.height;

 self.versionIcon.frame=CGRectMake(12,(h-28)/2,28,28);self.versionLabel.frame=CGRectMake(50,3,w-62,19);
 self.dateLabel.frame=CGRectMake(50,21,w-62,16);self.progressView.frame=CGRectMake(50,h-2,w-62,2);}



- (void)downloadTapped {
    if (self.onDownload) self.onDownload();
}

@end

@interface PCLDownloadRightView () <UITableViewDelegate, UITableViewDataSource, UIPickerViewDelegate, UIPickerViewDataSource>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *cardStackView;
@property (nonatomic, strong) UIView *filterCard;
@property (nonatomic, strong) UISegmentedControl *typeFilter;
@property (nonatomic, strong) UITableView *versionTableView;
@property (nonatomic, strong) UIPickerView *versionPicker;
@property (nonatomic, strong) UIView *versionPickerContainer;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *allVersions;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *filteredVersions;
@property (nonatomic, strong) NSMutableArray<NSString *> *gameVersions;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *loadingView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic) PCLDownloadTab currentTab;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *downloadProgress;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *expandedSections;
- (NSArray*)versionsForSection:(NSInteger)n{

 BOOL mc=self.currentTab==PCLDownloadTabMinecraft||self.currentTab==PCLDownloadTabClientInstall;

 if(!mc)return self.filteredVersions;

 NSMutableArray*r=[NSMutableArray array],*q=[NSMutableArray array],*o=[NSMutableArray array],*f=[NSMutableArray array];

 for(NSDictionary*v in self.filteredVersions){
  NSString*t=v[@"type"]?:@"",*i=v[@"id"]?:@"";

  BOOL fool=[i containsString:@"w14"]||[i containsString:@"oneBlock"]||[i containsString:@"_or_b"]||[i containsString:@"3D Shareware"]||[i isEqualToString:@"1.RV-Pre1"];

  if([t isEqualToString:@"release"])[r addObject:v];else if(fool)[f addObject:v];

  else if([t isEqualToString:@"snapshot"])[q addObject:v];else [o addObject:v];

 }

 if(!n){NSMutableArray*a=[NSMutableArray array];if(r.count)[a addObject:r[0]];

  if(q.count&&(!r.count||[q[0][@"releaseTime"] compare:r[0][@"releaseTime"]]>=0))[a addObject:q[0]];return a;}

 NSArray*g=@[r,q,o,f];return g[n-1];

}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)t {

    return self.currentTab==PCLDownloadTabMinecraft||

      self.currentTab==PCLDownloadTabClientInstall?5:1;

}

- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s {

    if([self numberOfSectionsInTableView:t]==1)return nil;

    return @[@"最新版本",@"正式版",@"预览版",@"远古版",@"愚人节版"][s];

}

- (CGFloat)tableView:(UITableView *)t heightForHeaderInSection:(NSInteger)s {

 return [self numberOfSectionsInTableView:t]>1?55:.01;

}

- (UIView *)tableView:(UITableView *)t viewForHeaderInSection:(NSInteger)n {

 if([self numberOfSectionsInTableView:t]==1)return nil;

 CGFloat w=CGRectGetWidth(t.bounds); BOOL open=[self.expandedSections containsObject:@(n)];
UIView *v=[[UIView alloc]initWithFrame:CGRectMake(0,0,w,55)];

 UIView *c=[[UIView alloc]initWithFrame:CGRectMake(0,15,w,40)];

 c.backgroundColor=[PCLColor(0xFBFBFB) colorWithAlphaComponent:.9];c.layer.cornerRadius=5;

 c.layer.maskedCorners=open?(kCALayerMinXMinYCorner|kCALayerMaxXMinYCorner):

 (kCALayerMinXMinYCorner|kCALayerMaxXMinYCorner|kCALayerMinXMaxYCorner|kCALayerMaxXMaxYCorner);

 c.layer.shadowColor=UIColor.blackColor.CGColor;c.layer.shadowOpacity=.06;c.layer.shadowRadius=4;c.autoresizingMask=UIViewAutoresizingFlexibleWidth;[v addSubview:c];

 NSArray *a=[self versionsForSection:n],*names=@[@"最新版本",@"正式版",@"预览版",@"远古版",@"愚人节版"];

 UILabel *l=[[UILabel alloc]initWithFrame:CGRectMake(16,0,w-64,40)];

 l.text=n?[NSString stringWithFormat:@"%@ (%ld)",names[n],(long)a.count]:names[n];

 l.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];[c addSubview:l];

 if(n==0)return v;
 UIButton *b=[[UIButton alloc]initWithFrame:c.bounds];b.tag=n;

 [b setImage:[UIImage systemImageNamed:open?@"chevron.down":@"chevron.right"]

    forState:UIControlStateNormal];

 b.contentHorizontalAlignment=UIControlContentHorizontalAlignmentRight;

 b.contentEdgeInsets=UIEdgeInsetsMake(0,0,0,16);
 [b addTarget:self action:@selector(toggleVersionSection:)

    forControlEvents:UIControlEventTouchUpInside];[c addSubview:b];return v;

}

- (void)toggleVersionSection:(UIButton *)b {

 NSNumber *n=@(b.tag);

 if([self.expandedSections containsObject:n])[self.expandedSections removeObject:n];

 else [self.expandedSections addObject:n];

 [self.versionTableView reloadSections:[NSIndexSet indexSetWithIndex:b.tag]

    withRowAnimation:UITableViewRowAnimationFade];

 [self updateVersionTableHeight];

}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if([self numberOfSectionsInTableView:tableView]>1&&

       ![self.expandedSections containsObject:@(section)])return 0;

    return [self versionsForSection:section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PCLDownloadVersionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"VersionCell" forIndexPath:indexPath];

    NSDictionary *version = [self versionsForSection:indexPath.section][indexPath.row];
    NSString *versionId = version[@"id"] ?: version[@"version"] ?: @"";
    NSString *type = version[@"type"] ?: @"";
    NSString *releaseTime = version[@"releaseTime"] ?: @"";

    cell.versionLabel.text=versionId;

    BOOL last=indexPath.row+1==[tableView numberOfRowsInSection:indexPath.section];

    cell.contentView.layer.cornerRadius=last?5:0;

    cell.contentView.layer.maskedCorners=kCALayerMinXMaxYCorner|kCALayerMaxXMaxYCorner;
    cell.versionIcon.image=[UIImage imageNamed:[type isEqualToString:@"release"]?@"CEGrass":([type isEqualToString:@"snapshot"]?@"CECommandBlock":@"CEGoldBlock")];

    if ([type isEqualToString:@"release"]) {
        cell.typeLabel.text = @"正式版";
        cell.typeLabel.backgroundColor = PCLColor(0x1370F3);
    } else if ([type isEqualToString:@"snapshot"]) {
        cell.typeLabel.text = @"快照";
        cell.typeLabel.backgroundColor = PCLColor(0xF39C12);
    } else if ([type isEqualToString:@"old_alpha"]) {
        cell.typeLabel.text = @"Alpha";
        cell.typeLabel.backgroundColor = PCLColor(0x8C8C8C);
    } else if ([type isEqualToString:@"old_beta"]) {
        cell.typeLabel.text = @"Beta";
        cell.typeLabel.backgroundColor = PCLColor(0x8C8C8C);
    } else if ([type isEqualToString:@"forge"]) {
        cell.typeLabel.text = @"Forge";
        cell.typeLabel.backgroundColor = PCLColor(0xE67E22);
    } else if ([type isEqualToString:@"fabric"]) {
        cell.typeLabel.text = @"Fabric";
        cell.typeLabel.backgroundColor = PCLColor(0x9B59B6);
    } else if ([type isEqualToString:@"neoforge"]) {
        cell.typeLabel.text = @"NeoForge";
        cell.typeLabel.backgroundColor = PCLColor(0xE74C3C);
    } else if ([type isEqualToString:@"optifine"]) {
        cell.typeLabel.text = @"OptiFine";
        cell.typeLabel.backgroundColor = PCLColor(0x27AE60);
    } else if ([type isEqualToString:@"liteloader"]) {
        cell.typeLabel.text = @"LiteLoader";
        cell.typeLabel.backgroundColor = PCLColor(0x3498DB);
    } else if ([type isEqualToString:@"fabric-api"]) {
        cell.typeLabel.text = @"Fabric API";
        cell.typeLabel.backgroundColor = PCLColor(0x9B59B6);
    } else {
        cell.typeLabel.text = type;
        cell.typeLabel.backgroundColor = PCLColor(0x8C8C8C);
    }

    if (releaseTime.length > 10) {
        cell.dateLabel.text = [releaseTime substringToIndex:10];
    } else {
        cell.dateLabel.text = releaseTime;
    }

    NSString *urlString = version[@"url"] ?: version[@"downloadURL"] ?: version[@"jar"] ?: @"";

    // 检查是否正在下载
    BOOL isDownloading = (self.downloadProgress[versionId] != nil);
    double progress = [self.downloadProgress[versionId] doubleValue];

    if (isDownloading) {
        cell.progressView.hidden = NO;
        cell.progressView.progress = progress;
        [cell.downloadButton setTitle:@"取消" forState:UIControlStateNormal];
    } else {
        cell.progressView.hidden = YES;
        [cell.downloadButton setTitle:@"下载" forState:UIControlStateNormal];
    }

    cell.onDownload = ^{
        if (isDownloading) {
            // 取消下载
            [self.downloadProgress removeObjectForKey:versionId];
            [self.versionTableView reloadData];
        } else {
            [self downloadVersion:versionId url:urlString type:type];
        }
    };

    return cell;
}
- (void)tableView:(UITableView*)t didSelectRowAtIndexPath:(NSIndexPath*)p{PCLDownloadVersionCell*c=[t cellForRowAtIndexPath:p];if(c.onDownload)c.onDownload();}

- (void)downloadVersion:(NSString *)versionId url:(NSString *)urlString type:(NSString *)type {
    if (urlString.length == 0) {
        NSLog(@"[Download] No URL for version %@", versionId);
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法下载" message:[NSString stringWithFormat:@"%@ %@ 暂无下载地址", type, versionId] preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        [rootVC presentViewController:alert animated:YES completion:nil];
        return;
    }

    NSString *displayName = [NSString stringWithFormat:@"%@ %@", type, versionId];
    self.downloadProgress[versionId] = @(0.0);
    [self.versionTableView reloadData];

    // 使用PCLDownloadManager下载
    PCLDownloadTask *task = [[PCLDownloadTask alloc] init];
    task.url = urlString;
    task.targetPath = [self targetPathForLoader:versionId type:type];
    task.displayName = displayName;
    task.resourceType = [self resourceTypeForType:type];

    __weak typeof(self) weakSelf = self;
    [[PCLDownloadManager sharedManager] addTask:task];
    [[PCLDownloadManager sharedManager] startDownload:task progress:^(double progress, NSString *status) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.downloadProgress[versionId] = @(progress);
        [self updateCellProgress:versionId progress:progress status:status];
    } completion:^(BOOL success, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self.downloadProgress removeObjectForKey:versionId];
        [self.versionTableView reloadData];

        NSString *title = success ? @"下载完成" : @"下载失败";
        NSString *msg = success ? [NSString stringWithFormat:@"%@ 安装成功", displayName] : error.localizedDescription;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        [rootVC presentViewController:alert animated:YES completion:nil];
    }];
}

- (NSString *)targetPathForLoader:(NSString *)versionId type:(NSString *)type {
    NSString *versionsDir = [[PCLVersionManager sharedManager] versionsDirectory];
    NSString *versionDir = [versionsDir stringByAppendingPathComponent:versionId];

    if ([type isEqualToString:@"forge"]) {
        return [versionDir stringByAppendingPathComponent:[NSString stringWithFormat:@"forge-%@.jar", versionId]];
    } else if ([type isEqualToString:@"fabric"]) {
        return [versionDir stringByAppendingPathComponent:[NSString stringWithFormat:@"fabric-loader-%@.jar", versionId]];
    } else if ([type isEqualToString:@"neoforge"]) {
        return [versionDir stringByAppendingPathComponent:[NSString stringWithFormat:@"neoforge-%@.jar", versionId]];
    } else if ([type isEqualToString:@"optifine"]) {
        return [versionDir stringByAppendingPathComponent:[NSString stringWithFormat:@"OptiFine_%@.jar", versionId]];
    } else if ([type isEqualToString:@"liteloader"]) {
        return [versionDir stringByAppendingPathComponent:[NSString stringWithFormat:@"liteloader-%@.jar", versionId]];
    } else if ([type isEqualToString:@"fabric-api"]) {
        return [versionDir stringByAppendingPathComponent:[NSString stringWithFormat:@"fabric-api-%@.jar", versionId]];
    }
    return [versionDir stringByAppendingPathComponent:[versionId stringByAppendingString:@".jar"]];
}

- (PCLResourceType)resourceTypeForType:(NSString *)type {
    if ([type isEqualToString:@"forge"]) return PCLResourceTypeForge;
    if ([type isEqualToString:@"fabric"]) return PCLResourceTypeFabric;
    if ([type isEqualToString:@"neoforge"]) return PCLResourceTypeNeoForge;
    if ([type isEqualToString:@"optifine"]) return PCLResourceTypeOptiFine;
    if ([type isEqualToString:@"liteloader"]) return PCLResourceTypeLiteLoader;
    if ([type isEqualToString:@"fabric-api"]) return PCLResourceTypeFabric;
    return PCLResourceTypeClient;
}

- (void)updateCellProgress:(NSString *)versionId progress:(double)progress status:(NSString *)status {
    for (NSInteger i = 0; i < self.filteredVersions.count; i++) {
        NSDictionary *v = self.filteredVersions[i];
        NSString *vid = v[@"id"] ?: v[@"version"] ?: @"";
        if ([vid isEqualToString:versionId]) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
            PCLDownloadVersionCell *cell = [self.versionTableView cellForRowAtIndexPath:indexPath];
            if (cell) {
                cell.progressView.hidden = NO;
                cell.progressView.progress = progress;
                [cell.downloadButton setTitle:@"取消" forState:UIControlStateNormal];
            }
            break;
        }
    }
}

#pragma mark - Animation

- (void)dismissTransientUI {
}

- (void)prepareCEEnterAnimation {
 [self.scrollView setContentOffset:CGPointZero animated:NO];

 for(UIView*v in self.cardStackView.arrangedSubviews){[v.layer removeAllAnimations];v.alpha=1;v.transform=CGAffineTransformIdentity;}

}

- (void)playCEEnterAnimation {

 [PCLCEPageAnimator showRightItems:self.cardStackView.arrangedSubviews scrollView:self.scrollView];

}

- (void)playCEExitAnimation {

 [PCLCEPageAnimator hideRightItems:self.cardStackView.arrangedSubviews scrollView:self.scrollView];

}

- (void)reloadState {
    [self refreshData];
}

@end
