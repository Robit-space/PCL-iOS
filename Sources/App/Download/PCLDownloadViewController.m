#import "PCLDownloadViewController.h"
#import "PCLDownloadLeftView.h"
#import "PCLDownloadRightView.h"
#import <QuartzCore/QuartzCore.h>

@interface PCLDownloadViewController ()
@property(nonatomic,strong) PCLDownloadLeftView *leftView;
@property(nonatomic,strong) PCLDownloadRightView *rightView;
@property(nonatomic,strong) CAGradientLayer *backgroundGradient;
@property(nonatomic,strong) UIView *shadowView;
@end

@implementation PCLDownloadViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=[UIColor colorWithRed:.918 green:.949 blue:.996 alpha:1];

    self.backgroundGradient=[CAGradientLayer layer];
    self.backgroundGradient.colors=@[
        (id)[UIColor colorWithRed:.918 green:.949 blue:.996 alpha:1].CGColor,
        (id)[UIColor colorWithRed:.973 green:.984 blue:.996 alpha:1].CGColor,
        (id)[UIColor colorWithRed:.878 green:.918 blue:.992 alpha:1].CGColor
    ];
    [self.view.layer insertSublayer:self.backgroundGradient atIndex:0];

    self.leftView=[[PCLDownloadLeftView alloc] init];
    self.rightView=[[PCLDownloadRightView alloc] init];
    self.leftView.backgroundColor=[[UIColor whiteColor] colorWithAlphaComponent:.82];

    [self.view addSubview:self.leftView];
    [self.view addSubview:self.rightView];

    __weak typeof(self) weakSelf=self;

    self.leftView.onSelectTab=^(PCLDownloadTab tab) {
        [weakSelf.rightView switchToTab:tab];
    };

    [self.rightView switchToTab:PCLDownloadTabMinecraft];

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

- (void)dismissTransientUI {
    [self.leftView dismissTransientUI];
    [self.rightView dismissTransientUI];
}

- (void)prepareCEEnterAnimation {
 [self.leftView prepareCEEnterAnimation];
 [self.rightView prepareCEEnterAnimation];
}
- (void)playCEEnterAnimation {
 [self.leftView playCEEnterAnimation];
 [self.rightView playCEEnterAnimation];
}
- (void)playCEExitAnimation {
 [self.leftView playCEExitAnimation];
 [self.rightView playCEExitAnimation];
}

@end
