#import "PCLAppDelegate.h"
#import "PCLRootViewController.h"
#import "PCLMouseSupport.h"
#import "PCLGlobalButtonHover.h"

@implementation PCLAppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    PCLStartMouseMonitoring();
    self.window = [[UIWindow alloc]
        initWithFrame:[UIScreen mainScreen].bounds];

    PCLRootViewController *root =
        [[PCLRootViewController alloc] init];

    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];
    PCLInstallGlobalButtonHover(self.window);
    UIView *splash =
        [[UIView alloc] initWithFrame:self.window.bounds];

    splash.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    splash.backgroundColor =
        [UIColor colorWithRed:24.0/255.0
                        green:111.0/255.0
                         blue:232.0/255.0
                        alpha:1.0];

    CGFloat w = CGRectGetWidth(splash.bounds);
    CGFloat h = CGRectGetHeight(splash.bounds);
    CGFloat shortSide = MIN(w, h);

    splash.backgroundColor =
        [UIColor colorWithRed:24.0/255.0
                        green:111.0/255.0
                         blue:232.0/255.0
                        alpha:1.0];

    CGFloat pixel = shortSide * 0.062;

    NSArray *topPattern = @[
        @[@0, @0, @0.10],
        @[@1, @0, @0.18],
        @[@2, @0, @0.10],
        @[@0, @1, @0.18],
        @[@1, @1, @0.10],
        @[@2, @1, @0.06],
        @[@0, @2, @0.08],
        @[@1, @2, @0.16]
    ];

    for (NSArray *item in topPattern) {
        UIView *v = [[UIView alloc] init];

        v.backgroundColor =
            [UIColor colorWithWhite:1.0
                              alpha:[item[2] doubleValue]];

        v.frame = CGRectMake(
            [item[0] doubleValue] * pixel,
            [item[1] doubleValue] * pixel,
            pixel,
            pixel
        );

        [splash addSubview:v];
    }

    NSArray *bottomPattern = @[
        @[@0, @2, @0.05],
        @[@1, @1, @0.07],
        @[@1, @2, @0.12],
        @[@2, @0, @0.10],
        @[@2, @1, @0.16],
        @[@2, @2, @0.09],
        @[@3, @0, @0.05],
        @[@3, @1, @0.10],
        @[@3, @2, @0.15]
    ];

    for (NSArray *item in bottomPattern) {
        UIView *v = [[UIView alloc] init];

        v.backgroundColor =
            [UIColor colorWithWhite:1.0
                              alpha:[item[2] doubleValue]];

        CGFloat x =
            w - pixel * 4.0 +
            [item[0] doubleValue] * pixel;

        CGFloat y =
            h - pixel * 3.0 +
            [item[1] doubleValue] * pixel;

        v.frame = CGRectMake(x, y, pixel, pixel);
        [splash addSubview:v];
    }

    NSArray *dots = @[
        @[@0.24, @0.26, @0.018],
        @[@0.80, @0.22, @0.016],
        @[@0.16, @0.68, @0.016],
        @[@0.74, @0.64, @0.017],
        @[@0.61, @0.80, @0.016]
    ];

    for (NSArray *dot in dots) {
        CGFloat size =
            shortSide * [dot[2] doubleValue];

        UIView *v = [[UIView alloc] init];

        v.backgroundColor =
            [UIColor colorWithWhite:1.0 alpha:0.20];

        v.frame = CGRectMake(
            w * [dot[0] doubleValue],
            h * [dot[1] doubleValue],
            size,
            size
        );

        [splash addSubview:v];
    }


    CGFloat unit = shortSide * 0.052;

    CGFloat logoW = unit * 8.10;
    CGFloat logoH = unit * 3.35;

    UIView *logoView = [[UIView alloc] initWithFrame:
        CGRectMake((w - logoW) / 2.0,
                   (h - logoH) / 2.0,
                   logoW,
                   logoH)];

    [splash addSubview:logoView];

    CGFloat mainLogoW = unit * 8.28;

    UIView *mainLogoView = [[UIView alloc] initWithFrame:
        CGRectMake((logoW - mainLogoW) / 2.0,
                   0.0,
                   mainLogoW,
                   unit * 2.25)];

    [logoView addSubview:mainLogoView];

    void (^addShape)(UIBezierPath *) =
    ^(UIBezierPath *path) {
        CAShapeLayer *layer = [CAShapeLayer layer];
        layer.path = path.CGPath;
        layer.fillColor = UIColor.whiteColor.CGColor;
        layer.fillRule = kCAFillRuleEvenOdd;
        [mainLogoView.layer addSublayer:layer];
    };

    // Reference P
    CGFloat pStroke = unit * 0.43;

    // P - measured from reference
    UIView *pLeft = [[UIView alloc] initWithFrame:
        CGRectMake(0.00 * unit, 0.00 * unit,
                   0.45 * unit, 2.25 * unit)];
    pLeft.backgroundColor = UIColor.whiteColor;
    [mainLogoView addSubview:pLeft];

    UIView *pTop = [[UIView alloc] initWithFrame:
        CGRectMake(0.00 * unit, 0.00 * unit,
                   1.90 * unit, 0.45 * unit)];
    pTop.backgroundColor = UIColor.whiteColor;
    [mainLogoView addSubview:pTop];

    UIView *pRight = [[UIView alloc] initWithFrame:
        CGRectMake(1.45 * unit, 0.00 * unit,
                   0.45 * unit, 1.59 * unit)];
    pRight.backgroundColor = UIColor.whiteColor;
    [mainLogoView addSubview:pRight];

    UIView *pMiddle = [[UIView alloc] initWithFrame:
        CGRectMake(0.86 * unit, 1.15 * unit,
                   1.04 * unit, 0.45 * unit)];
    pMiddle.backgroundColor = UIColor.whiteColor;
    [mainLogoView addSubview:pMiddle];

    UIColor *markBlue =
        [UIColor colorWithRed:24.0/255.0
                        green:111.0/255.0
                         blue:232.0/255.0
                        alpha:1.0];

    CGFloat mark = unit * 0.225;

    UIView *markTR = [[UIView alloc] initWithFrame:
        CGRectMake(0.45 * unit, 0.225 * unit,
                   mark, mark)];
    markTR.backgroundColor = markBlue;
    [mainLogoView addSubview:markTR];

    UIView *markBL = [[UIView alloc] initWithFrame:
        CGRectMake(0.225 * unit, 0.45 * unit,
                   mark, mark)];
    markBL.backgroundColor = markBlue;
    [mainLogoView addSubview:markBL];

    UIView *markBR = [[UIView alloc] initWithFrame:
        CGRectMake(0.45 * unit, 0.45 * unit,
                   mark, mark)];
    markBR.backgroundColor = UIColor.whiteColor;
    [mainLogoView addSubview:markBR];

    UIBezierPath *cPath = [UIBezierPath bezierPath];

    [cPath moveToPoint:CGPointMake(2.25 * unit, 0.00 * unit)];
    [cPath addLineToPoint:CGPointMake(4.15 * unit, 0.00 * unit)];
    [cPath addLineToPoint:CGPointMake(4.15 * unit, 0.45 * unit)];
    [cPath addLineToPoint:CGPointMake(2.70 * unit, 0.45 * unit)];

    [cPath addLineToPoint:CGPointMake(2.70 * unit, 1.80 * unit)];
    [cPath addLineToPoint:CGPointMake(4.15 * unit, 1.80 * unit)];
    [cPath addLineToPoint:CGPointMake(4.15 * unit, 2.25 * unit)];
    [cPath addLineToPoint:CGPointMake(2.25 * unit, 2.25 * unit)];
    [cPath closePath];

    addShape(cPath);

    UIBezierPath *lPath = [UIBezierPath bezierPath];

    [lPath moveToPoint:CGPointMake(4.55 * unit, 0.00 * unit)];
    [lPath addLineToPoint:CGPointMake(5.00 * unit, 0.00 * unit)];
    [lPath addLineToPoint:CGPointMake(5.00 * unit, 1.80 * unit)];
    [lPath addLineToPoint:CGPointMake(6.35 * unit, 1.80 * unit)];
    [lPath addLineToPoint:CGPointMake(6.35 * unit, 2.25 * unit)];
    [lPath addLineToPoint:CGPointMake(4.55 * unit, 2.25 * unit)];
    [lPath closePath];

    addShape(lPath);

    UILabel *ios = [[UILabel alloc] initWithFrame:
        CGRectMake(6.58 * unit,
                   1.42 * unit,
                   1.70 * unit,
                   0.78 * unit)];

    ios.text = @"iOS";
    ios.textAlignment = NSTextAlignmentCenter;
    ios.backgroundColor = UIColor.whiteColor;

    ios.textColor =
        [UIColor colorWithRed:24.0/255.0
                        green:111.0/255.0
                         blue:232.0/255.0
                        alpha:1.0];

    ios.font =
        [UIFont systemFontOfSize:unit * 0.57
                          weight:UIFontWeightSemibold];

    ios.layer.cornerRadius = unit * 0.14;
    ios.clipsToBounds = YES;

    [mainLogoView addSubview:ios];

    CGFloat mainContentWidth = CGRectGetMaxX(ios.frame);
    CGRect mainFrame = mainLogoView.frame;
    mainFrame.origin.x =
        (logoW - mainContentWidth) / 2.0
        + 0.58 * unit;
    mainLogoView.frame = mainFrame;

    UILabel *subtitle = [[UILabel alloc] initWithFrame:
        CGRectMake(0.0,
                   2.63 * unit,
                   logoW,
                   0.58 * unit)];

    subtitle.text = @"P C L - i O S";
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.textColor = UIColor.whiteColor;

    subtitle.font =
        [UIFont monospacedSystemFontOfSize:unit * 0.33
                                    weight:UIFontWeightRegular];

    [logoView addSubview:subtitle];

    [self.window addSubview:splash];

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(3.0 * NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{
        [UIView animateWithDuration:0.55
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{

            splash.transform =
                CGAffineTransformMakeScale(1.04, 1.04);

            splash.alpha = 0.0;
        } completion:^(BOOL finished) {

            [splash removeFromSuperview];
        }];
    });

    return YES;
}
@end
