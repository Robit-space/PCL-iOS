#import "PCLLaunchViewController.h"
#import "PCLLaunchLeftView.h"
#import "PCLLaunchRightView.h"
#import "PCLInstanceSelectViewController.h"
#import "PCLInstanceManager.h"
#import "PCLGameLauncher.h"
#import "PCLProfileStore.h"
#import <QuartzCore/QuartzCore.h>

@interface PCLLaunchViewController ()

@property (nonatomic, strong) PCLLaunchLeftView *leftView;
@property (nonatomic, strong) PCLLaunchRightView *rightView;
@property (nonatomic, strong) PCLInstanceSelectViewController *instanceSelectVC;

@property (nonatomic, copy) NSArray *instances;

@property (nonatomic, strong) CAGradientLayer *backgroundGradient;
@property (nonatomic, strong) UIView *leftShadowView;
@property (nonatomic, strong) CAGradientLayer *leftShadowGradient;

@property(nonatomic) BOOL animatingLeftBackground;
@end

@implementation PCLLaunchViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor =
        [UIColor colorWithRed:251.0/255.0
                        green:251.0/255.0
                         blue:251.0/255.0
                        alpha:1.0];

    [self buildCEBackground];
    [self buildUI];
    [self reloadInstances];
}

- (void)buildCEBackground {
    self.backgroundGradient = [CAGradientLayer layer];
    self.backgroundGradient.colors = @[
        (id)[UIColor colorWithRed:.82 green:.89 blue:1 alpha:1].CGColor,
        (id)[UIColor colorWithRed:.98 green:.99 blue:1 alpha:1].CGColor,
        (id)[UIColor colorWithRed:.88 green:.93 blue:1 alpha:1].CGColor
    ];
    self.backgroundGradient.locations = @[@0,@.52,@1];
    self.backgroundGradient.startPoint = CGPointMake(.9,0);
    self.backgroundGradient.endPoint = CGPointMake(.1,1);
    [self.view.layer insertSublayer:self.backgroundGradient atIndex:0];
}

- (void)buildUI {
    self.leftView =
        [[PCLLaunchLeftView alloc] init];

    self.rightView =
        [[PCLLaunchRightView alloc] init];

    UIView*bg=[UIView new];bg.tag=777;bg.backgroundColor=[UIColor colorWithWhite:.995 alpha:.824];
    [self.view addSubview:bg];self.leftView.backgroundColor=UIColor.clearColor;
    [self.view addSubview:self.leftView];
    [self.view addSubview:self.rightView];
    self.leftShadowView = [[UIView alloc] init];
    self.leftShadowView.userInteractionEnabled = NO;
    self.leftShadowGradient = [CAGradientLayer layer];
    self.leftShadowGradient.colors = @[
        (id)[UIColor colorWithWhite:0 alpha:.04].CGColor,
        (id)[UIColor colorWithWhite:0 alpha:0].CGColor
    ];
    self.leftShadowGradient.startPoint = CGPointMake(0,.5);
    self.leftShadowGradient.endPoint = CGPointMake(1,.5);
    [self.leftShadowView.layer addSublayer:self.leftShadowGradient];
    [self.view addSubview:self.leftShadowView];

    __weak typeof(self) weakSelf = self;

    self.leftView.onSelectInstance = ^{
        [weakSelf selectInstance];
    };

    self.leftView.onInstanceSettings = ^{
        [weakSelf instanceSettings];
    };

    self.leftView.onLaunch = ^{
        [weakSelf launchMinecraft];
    };


    self.leftView.onSkinOptions = ^{
        [weakSelf skinOptions];
    };

    self.leftView.onEditProfile = ^{
        [weakSelf editProfile];
    };

    self.rightView.onCloseHint = ^{
        [NSUserDefaults.standardUserDefaults
            setBool:YES
             forKey:@"PCLLaunchHintHidden"];
    };

    BOOL hintHidden =
        [NSUserDefaults.standardUserDefaults
            boolForKey:@"PCLLaunchHintHidden"];

    [self.rightView
        setHintHidden:hintHidden];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w=CGRectGetWidth(self.view.bounds);
    CGFloat h=CGRectGetHeight(self.view.bounds);
    CGFloat scale=MIN(w/850.0,h/417.2);
    CGFloat pageH=h;
    CGFloat leftW=self.leftPanelWidth>0 ? MIN(self.leftPanelWidth,w) : 300.0*scale;
    CGFloat y=0.0;
    self.backgroundGradient.frame=self.view.bounds;
    self.leftView.frame=CGRectMake(0,y,leftW,pageH);if(!self.animatingLeftBackground)[self.view viewWithTag:777].frame=CGRectMake(0,y,leftW,pageH);
    self.leftView.designScale=scale;
    self.rightView.designScale=scale;
    self.rightView.frame=CGRectMake(leftW,y,MAX(0,w-leftW),pageH);
    if(!self.animatingLeftBackground)self.leftShadowView.frame=CGRectMake(leftW,y,4*scale,pageH);
    self.leftShadowGradient.frame=self.leftShadowView.bounds;
    self.instanceSelectVC.leftPanelWidth=leftW;
    self.instanceSelectVC.view.frame=self.view.bounds;
}

- (void)reloadInstances {
    PCLInstanceManager *m=[PCLInstanceManager sharedManager];
    self.instances=[m allInstances];
    PCLInstance *i=[m currentInstance];
    if(i.name.length)[NSUserDefaults.standardUserDefaults
        setObject:i.name forKey:@"PCLSelectedInstance"];
    else [NSUserDefaults.standardUserDefaults
        removeObjectForKey:@"PCLSelectedInstance"];
    [self.leftView reloadState];
}

- (void)selectInstance {
    if(self.instanceSelectVC)return;
    PCLInstanceSelectViewController *v=
        [[PCLInstanceSelectViewController alloc]init];
    v.leftPanelWidth=self.leftPanelWidth;
    __weak typeof(self) w=self;
    v.onBack=^{[w closeInstanceSelector];};
    v.onSelect=^(PCLInstance *i){
        [w reloadInstances];
        [w closeInstanceSelector];
    };
    v.onDownload=^{
        [w closeInstanceSelector];
        if(w.onOpenDownload)w.onOpenDownload();
    };
    self.instanceSelectVC=v;
    [self addChildViewController:v];
    v.view.frame=self.view.bounds;
    [self.view addSubview:v.view];
    [v didMoveToParentViewController:self];
    [NSNotificationCenter.defaultCenter postNotificationName:@"PCLShowInstanceBar" object:nil];
}

- (void)closeInstanceSelector {
    PCLInstanceSelectViewController *v=self.instanceSelectVC;
    if(!v)return;
    [v willMoveToParentViewController:nil];
    [v.view removeFromSuperview];
    [v removeFromParentViewController];
    self.instanceSelectVC=nil;
    [NSNotificationCenter.defaultCenter postNotificationName:@"PCLHideInstanceBar" object:nil];
    [self reloadInstances];
}

- (void)instanceSettings {
    NSString *instance =
        [NSUserDefaults.standardUserDefaults
            stringForKey:@"PCLSelectedInstance"];

    if (!instance.length) {
        [self temporaryMessage:@"请先选择实例。"];
        return;
    }

    [self temporaryMessage:
        [NSString stringWithFormat:
            @"当前实例：%@",
            instance]];
}




- (void)skinOptions {
    [self temporaryMessage:
        @"皮肤与披风功能将在账号系统阶段接入。"];
}

- (void)editProfile {
    NSString *name =
        [NSUserDefaults.standardUserDefaults
            stringForKey:@"PCLProfileUsername"];

    if (!name.length)
        return;

    [self temporaryMessage:
        [NSString stringWithFormat:
            @"当前档案：%@",
            name]];
}

- (void)animateLeftBackgroundFrom:(CGFloat)a to:(CGFloat)b{UIView*v=[self.view viewWithTag:777];self.animatingLeftBackground=YES;CGRect f=v.frame;f.size.width=a;v.frame=f;f=self.leftShadowView.frame;f.origin.x=a;self.leftShadowView.frame=f;[UIView animateWithDuration:.32 delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseInOut animations:^{CGRect x=v.frame;x.size.width=b;v.frame=x;x=self.leftShadowView.frame;x.origin.x=b;self.leftShadowView.frame=x;} completion:^(BOOL d){self.animatingLeftBackground=NO;}];}

- (void)dismissTransientUI {
    [self.leftView dismissTransientUI];
    [self closeInstanceSelector];
}

- (void)prepareCEEnterAnimation {
    [self.leftView prepareCEEnterAnimation];
    [self.rightView prepareCEEnterAnimation];

    self.view.userInteractionEnabled=NO;
}

- (void)playCEEnterAnimation {
    [self.leftView playCEEnterAnimation];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.13*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self.rightView playCEEnterAnimation];});

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
            (int64_t)(.400*NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            self.view.userInteractionEnabled=YES;
        });
}

- (void)playCEExitWithCompletion:
        (dispatch_block_t)completion {

    [self dismissTransientUI];
    self.view.userInteractionEnabled=NO;

    [self.leftView playCEExitAnimation];
    [self.rightView playCEExitAnimation];

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
            (int64_t)(.180*NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            if (completion)
                completion();
        });
}

- (void)launchMinecraft {
    NSString *profile =
        [NSUserDefaults.standardUserDefaults
            stringForKey:@"PCLProfileUsername"];

    NSString *instance =
        [NSUserDefaults.standardUserDefaults
            stringForKey:@"PCLSelectedInstance"];

    if (!instance.length) {
        if (self.onOpenDownload)
            self.onOpenDownload();
        return;
    }

    if (!profile.length)
        return;
    NSString *message =
        [NSString stringWithFormat:
            @"档案：%@\n实例：%@",
            profile,
            instance];

    [self temporaryMessage:message];
}

- (void)openURL:(NSString *)text {
    NSURL *url=[NSURL URLWithString:text];
    if (!url) return;
    [UIApplication.sharedApplication openURL:url
        options:@{} completionHandler:nil];
}

- (void)temporaryMessage:(NSString *)message {
    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:@"PCL [iOS]"
                             message:message
                      preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"确定"
                      style:UIAlertActionStyleDefault
                    handler:nil]];

    [self presentViewController:alert
                       animated:YES
                     completion:nil];
}

@end
