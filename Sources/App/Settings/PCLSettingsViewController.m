#import "PCLSettingsViewController.h"
#import "PCLSettingsLeftView.h"
#import "PCLSettingsRightView.h"
#import <QuartzCore/QuartzCore.h>

@interface PCLSettingsViewController ()
@property(nonatomic,strong) PCLSettingsLeftView *leftView;
@property(nonatomic,strong) PCLSettingsRightView *rightView;
@property(nonatomic,strong) CAGradientLayer *backgroundGradient;
@property(nonatomic,strong) UIView *shadowView;
@end

@implementation PCLSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.backgroundGradient=[CAGradientLayer layer];
    self.backgroundGradient.colors=@[
        (id)[UIColor colorWithRed:.68 green:.80 blue:.98 alpha:1].CGColor,
        (id)[UIColor colorWithRed:.92 green:.96 blue:1 alpha:1].CGColor,
        (id)[UIColor colorWithRed:.76 green:.84 blue:.99 alpha:1].CGColor
    ];
    [self.view.layer insertSublayer:self.backgroundGradient atIndex:0];

    self.leftView=[[PCLSettingsLeftView alloc] init];
    self.rightView=[[PCLSettingsRightView alloc] init];

    [self.view addSubview:self.leftView];
    [self.view addSubview:self.rightView];

    __weak typeof(self) weakSelf=self;

    self.leftView.onSelectTab=^(PCLSettingsTab tab) {
        weakSelf.currentTab=tab;
        [weakSelf.rightView switchToTab:tab];
    };

    self.currentTab=PCLSettingsTabLaunch;
    [self.rightView switchToTab:self.currentTab];

    self.shadowView=[[UIView alloc] init];
    self.shadowView.backgroundColor=
        [UIColor colorWithWhite:0 alpha:.035];
    self.shadowView.userInteractionEnabled=NO;
    [self.view addSubview:self.shadowView];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat w=CGRectGetWidth(self.view.bounds);
    CGFloat h=CGRectGetHeight(self.view.bounds);
    CGFloat scale=MIN(w/850.0,h/417.2);

    CGFloat leftW=self.leftPanelWidth>0
        ? MIN(self.leftPanelWidth,w)
        : 300.0*scale;

    scale=MIN(scale,leftW/300.0);

    self.backgroundGradient.frame=self.view.bounds;
    self.leftView.designScale=scale;
    self.rightView.designScale=scale;

    self.leftView.frame=CGRectMake(0,0,leftW,h);
    self.rightView.frame=CGRectMake(leftW,0,MAX(0,w-leftW),h);
    self.shadowView.frame=CGRectMake(leftW,0,1,h);
}

- (void)switchToTab:(PCLSettingsTab)tab {
    self.currentTab=tab;
    [self.rightView switchToTab:tab];
}

- (void)dismissTransientUI {
    [self.leftView dismissTransientUI];
    [self.rightView dismissTransientUI];
}

@end
