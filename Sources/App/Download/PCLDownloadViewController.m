#import "PCLDownloadViewController.h"
#import "PCLDownloadLeftView.h"
#import "PCLDownloadRightView.h"
#import "PCLResourceBrowseViewController.h"
#import <QuartzCore/QuartzCore.h>

@interface PCLDownloadViewController ()
@property(nonatomic,strong) PCLDownloadLeftView *leftView;
@property(nonatomic,strong) PCLDownloadRightView *rightView;
@property(nonatomic,strong) PCLResourceBrowseViewController *resourceVC;
@property(nonatomic,strong) CAGradientLayer *backgroundGradient;
@property(nonatomic,strong) UIView *shadowView;
@property(nonatomic) BOOL animatingLeftBackground;
@end

@implementation PCLDownloadViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=[UIColor colorWithRed:.918 green:.949 blue:.996 alpha:1];

    self.backgroundGradient=[CAGradientLayer layer];
    self.backgroundGradient.colors=@[
        (id)[UIColor colorWithRed:.68 green:.80 blue:.98 alpha:1].CGColor,
        (id)[UIColor colorWithRed:.92 green:.96 blue:1 alpha:1].CGColor,
        (id)[UIColor colorWithRed:.76 green:.84 blue:.99 alpha:1].CGColor
    ];
    self.backgroundGradient.locations=@[@0,@.4,@1];
    self.backgroundGradient.startPoint=CGPointMake(.9,0);
    self.backgroundGradient.endPoint=CGPointMake(.1,1);
    [self.view.layer insertSublayer:self.backgroundGradient atIndex:0];

    self.leftView=[[PCLDownloadLeftView alloc] init];
    self.rightView=[[PCLDownloadRightView alloc] init];
    self.leftView.backgroundColor=[UIColor colorWithWhite:.995 alpha:.824];

    UIView*bg=[UIView new];bg.tag=777;bg.backgroundColor=[UIColor colorWithWhite:.995 alpha:.824];
    [self.view addSubview:bg];self.leftView.backgroundColor=UIColor.clearColor;
    [self.view addSubview:self.leftView];
    [self.view addSubview:self.rightView];

    self.resourceVC=[PCLResourceBrowseViewController new];[self addChildViewController:self.resourceVC];

    [self.view addSubview:self.resourceVC.view];[self.resourceVC didMoveToParentViewController:self];self.resourceVC.view.hidden=YES;

    __weak typeof(self) weakSelf=self;

    self.leftView.onSelectTab=^(PCLDownloadTab tab){

     UIView*old=weakSelf.rightView.hidden?weakSelf.resourceVC.view:weakSelf.rightView;

     [UIView animateWithDuration:.11 animations:^{old.alpha=0;old.transform=CGAffineTransformMakeTranslation(-40,0);}

      completion:^(BOOL d){BOOL r=tab>=PCLDownloadTabMod&&tab<=PCLDownloadTabShader;

       weakSelf.rightView.hidden=r;weakSelf.resourceVC.view.hidden=!r;
       if(r){PCLResourceTab t=tab==PCLDownloadTabModpack?PCLResourceTabModpack:tab==PCLDownloadTabDataPack?PCLResourceTabDataPack:tab==PCLDownloadTabResourcePack?PCLResourceTabResourcePack:tab==PCLDownloadTabShader?PCLResourceTabShader:PCLResourceTabMod;[weakSelf.resourceVC showTab:t];}

       else [weakSelf.rightView switchToTab:tab];

       UIView*n=r?weakSelf.resourceVC.view:weakSelf.rightView;n.alpha=0;n.transform=CGAffineTransformMakeTranslation(40,0);

       [UIView animateWithDuration:.16 delay:.03 options:UIViewAnimationOptionCurveEaseOut animations:^{n.alpha=1;n.transform=CGAffineTransformIdentity;} completion:nil];

     }];

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


    self.backgroundGradient.frame=self.view.bounds;
    self.leftView.designScale=scale;
    self.rightView.designScale=scale;

    self.leftView.frame=CGRectMake(0,0,leftW,h);if(!self.animatingLeftBackground)[self.view viewWithTag:777].frame=CGRectMake(0,0,leftW,h);
    self.rightView.frame=CGRectMake(leftW,0,MAX(0,w-leftW),h);
    self.resourceVC.view.frame=self.rightView.frame;
    if(!self.animatingLeftBackground)self.shadowView.frame=CGRectMake(leftW,0,1,h);
}

- (void)animateLeftBackgroundFrom:(CGFloat)a to:(CGFloat)b{UIView*v=[self.view viewWithTag:777];self.animatingLeftBackground=YES;CGRect f=v.frame;f.size.width=a;v.frame=f;f=self.shadowView.frame;f.origin.x=a;self.shadowView.frame=f;[UIView animateWithDuration:.18 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{CGRect x=v.frame;x.size.width=b;v.frame=x;x=self.shadowView.frame;x.origin.x=b;self.shadowView.frame=x;} completion:^(BOOL d){self.animatingLeftBackground=NO;}];}

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
