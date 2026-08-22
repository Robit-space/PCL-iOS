#import "PCLLaunchRightView.h"
#import "PCLCEPageAnimator.h"
#import <math.h>

static UIColor *PCLRightColor(NSUInteger rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
                           green:((rgb >> 8) & 255) / 255.0
                            blue:(rgb & 255) / 255.0
                           alpha:1.0];
}

@interface PCLCardView : UIView

@property (nonatomic, strong) UILabel *titleLabel;

@end

@implementation PCLCardView

- (instancetype)init {
    self = [super init];
    if (!self) return nil;

    self.backgroundColor =
        [UIColor colorWithRed:251.0/255.0
                        green:251.0/255.0
                         blue:251.0/255.0
                        alpha:210.0/255.0];

    self.layer.cornerRadius = 5.0;

    self.layer.shadowColor =
        UIColor.blackColor.CGColor;

    self.layer.shadowOpacity = 0.07;
    self.layer.shadowRadius = 3.0;
    self.layer.shadowOffset = CGSizeZero;

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font =
        [UIFont boldSystemFontOfSize:13.0];

    self.titleLabel.textColor =
        PCLRightColor(0x343D4A);

    [self addSubview:self.titleLabel];

    return self;
}

@end

@interface PCLLaunchRightView ()

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *mainView;
@property (nonatomic, strong) UIView *customHost;

@property (nonatomic, strong) PCLCardView *hintCard;
@property (nonatomic, strong) UIButton *hintCloseButton;

@property (nonatomic, strong) UILabel *hintLine1;
@property (nonatomic, strong) UILabel *hintLine2;

@property (nonatomic, strong) PCLCardView *logCard;
@property (nonatomic, strong) UILabel *logLabel;

@end

@implementation PCLLaunchRightView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.designScale = 1.0;

    [self buildUI];

    return self;
}

- (void)buildUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.backgroundColor = UIColor.clearColor;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.alwaysBounceHorizontal = NO;

    [self addSubview:self.scrollView];

    self.mainView = [[UIView alloc] init];
    [self.scrollView addSubview:self.mainView];

    self.customHost = [[UIView alloc] init];
    self.customHost.backgroundColor = UIColor.clearColor;
    [self.mainView addSubview:self.customHost];

    [self buildHintCard];
    [self buildLogCard];
}

- (void)buildHintCard {
    self.hintCard = [[PCLCardView alloc] init];
    self.hintCard.titleLabel.text = @"正在开发";

    [self.mainView addSubview:self.hintCard];

    self.hintCloseButton =
        [UIButton buttonWithType:UIButtonTypeCustom];

    self.hintCloseButton.backgroundColor =
        UIColor.clearColor;

    CALayer *line1 = [CALayer layer];
    line1.name = @"PCLCloseLine1";
    line1.backgroundColor =
        PCLRightColor(0x343D4A).CGColor;

    CALayer *line2 = [CALayer layer];
    line2.name = @"PCLCloseLine2";
    line2.backgroundColor =
        PCLRightColor(0x343D4A).CGColor;

    [self.hintCloseButton.layer addSublayer:line1];
    [self.hintCloseButton.layer addSublayer:line2];

    [self.hintCloseButton
        addTarget:self
           action:@selector(closeHintPressed)
 forControlEvents:UIControlEventTouchUpInside];

    [self.hintCard addSubview:self.hintCloseButton];

    self.hintLine1 = [[UILabel alloc] init];
    self.hintLine2 = [[UILabel alloc] init];

    NSArray *labels = @[
        self.hintLine1,
        self.hintLine2
    ];

    for (UILabel *label in labels) {
        label.numberOfLines = 0;
        label.textColor = PCLRightColor(0x343D4A);
        [self.hintCard addSubview:label];
    }

    self.hintLine1.text =
        @"PCL [iOS] 目前仍处于开发阶段，部分功能尚未完成。";

    self.hintLine2.text =
        @"你可以使用右上角的按钮隐藏此提示。";
}

- (void)buildLogCard {
    self.logCard = [[PCLCardView alloc] init];
    self.logCard.titleLabel.text = @"启动日志";
    self.logCard.hidden = YES;

    [self.mainView addSubview:self.logCard];

    self.logLabel = [[UILabel alloc] init];

    self.logLabel.numberOfLines = 0;
    self.logLabel.textColor = PCLRightColor(0x343D4A);

    [self.logCard addSubview:self.logLabel];
}

- (void)closeHintPressed {
    [UIView animateWithDuration:0.20 animations:^{
        self.hintCard.alpha = 0.0;
    } completion:^(__unused BOOL finished) {

        self.hintCard.hidden = YES;
        self.hintCard.alpha = 1.0;

        [self setNeedsLayout];

        if (self.onCloseHint) {
            self.onCloseHint();
        }
    }];
}

- (void)setHintHidden:(BOOL)hidden {
    self.hintCard.hidden = hidden;
    [self setNeedsLayout];
}

- (void)setDebugLog:(NSString *)text
            visible:(BOOL)visible {

    self.logLabel.text = text ?: @"";
    self.logCard.hidden = !visible;

    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width =
        CGRectGetWidth(self.bounds);

    CGFloat height =
        CGRectGetHeight(self.bounds);

    CGFloat scale =
        self.designScale > 0
        ? self.designScale
        : 1.0;

    self.scrollView.frame = self.bounds;

    self.hintCard.titleLabel.font =
        [UIFont boldSystemFontOfSize:13.0 * scale];

    self.logCard.titleLabel.font =
        [UIFont boldSystemFontOfSize:13.0 * scale];

    self.hintLine1.font =
        [UIFont systemFontOfSize:13.5 * scale];

    self.hintLine2.font =
        [UIFont systemFontOfSize:13.5 * scale];

    self.logLabel.font =
        [UIFont systemFontOfSize:13.0 * scale];

    self.hintCard.layer.cornerRadius =
        5.0 * scale;

    self.logCard.layer.cornerRadius =
        5.0 * scale;

    self.hintCard.layer.shadowRadius =
        3.0 * scale;

    self.logCard.layer.shadowRadius =
        3.0 * scale;

    CGFloat left = 25.0 * scale;
    CGFloat right = 25.0 * scale;
    CGFloat top = 25.0 * scale;
    CGFloat bottom = 10.0 * scale;

    CGFloat contentWidth =
        width - left - right;

    CGFloat y = top;

    self.customHost.frame =
        CGRectMake(left,
                   y,
                   contentWidth,
                   0);

    y = CGRectGetMaxY(self.customHost.frame);

    if (!self.hintCard.hidden) {
        CGFloat bodyWidth =
            contentWidth
            - 48.0 * scale;

        CGSize line1Size =
            [self.hintLine1
                sizeThatFits:
                    CGSizeMake(bodyWidth,
                               CGFLOAT_MAX)];

        CGSize line2Size =
            [self.hintLine2
                sizeThatFits:
                    CGSizeMake(bodyWidth,
                               CGFLOAT_MAX)];

        CGFloat bodyHeight =
            line1Size.height
            + 2.0 * scale
            + line2Size.height;

        CGFloat cardHeight =
            38.0 * scale
            + bodyHeight
            + 15.0 * scale;

        self.hintCard.frame =
            CGRectMake(left,
                       y,
                       contentWidth,
                       cardHeight);

        self.hintCard.titleLabel.frame =
            CGRectMake(15.0 * scale,
                       12.0 * scale,
                       contentWidth
                           - 55.0 * scale,
                       20.0 * scale);

        self.hintCloseButton.frame =
            CGRectMake(contentWidth
                           - 30.0 * scale,
                       10.0 * scale,
                       20.0 * scale,
                       20.0 * scale);

        for (CALayer *layer
             in self.hintCloseButton.layer.sublayers) {

            if (![layer.name
                    hasPrefix:@"PCLCloseLine"]) {
                continue;
            }

            layer.bounds =
                CGRectMake(0,
                           0,
                           10.0 * scale,
                           1.2 * scale);

            layer.position =
                CGPointMake(10.0 * scale,
                            10.0 * scale);

            if ([layer.name
                    isEqualToString:@"PCLCloseLine1"]) {
                layer.affineTransform =
                    CGAffineTransformMakeRotation(
                        M_PI_4);
            } else {
                layer.affineTransform =
                    CGAffineTransformMakeRotation(
                        -M_PI_4);
            }
        }

        CGFloat bodyX =
            25.0 * scale;

        CGFloat bodyY =
            38.0 * scale;

        self.hintLine1.frame =
            CGRectMake(bodyX,
                       bodyY,
                       bodyWidth,
                       line1Size.height);

        self.hintLine2.frame =
            CGRectMake(bodyX,
                       CGRectGetMaxY(
                           self.hintLine1.frame)
                           + 2.0 * scale,
                       bodyWidth,
                       line2Size.height);

        y += cardHeight
             + 15.0 * scale;
    }

    if (!self.logCard.hidden) {
        CGFloat logWidth =
            contentWidth
            - 40.0 * scale;

        CGSize logSize =
            [self.logLabel
                sizeThatFits:
                    CGSizeMake(logWidth,
                               CGFLOAT_MAX)];

        CGFloat logHeight =
            38.0 * scale
            + logSize.height
            + 18.0 * scale;

        self.logCard.frame =
            CGRectMake(left,
                       y,
                       contentWidth,
                       logHeight);

        self.logCard.titleLabel.frame =
            CGRectMake(15.0 * scale,
                       12.0 * scale,
                       contentWidth
                           - 30.0 * scale,
                       20.0 * scale);

        self.logLabel.frame =
            CGRectMake(20.0 * scale,
                       38.0 * scale,
                       logWidth,
                       logSize.height);

        y += logHeight
             + 15.0 * scale;
    }

    CGFloat contentHeight =
        MAX(height,
            y + bottom);

    self.mainView.frame =
        CGRectMake(0,
                   0,
                   width,
                   contentHeight);

    self.scrollView.contentSize =
        CGSizeMake(width,
                   contentHeight);
}


- (NSArray<UIView *> *)ceAnimatedViews {
    NSMutableArray *views =
        [NSMutableArray array];

    if (!self.hintCard.hidden)
        [views addObject:self.hintCard];

    if (!self.logCard.hidden)
        [views addObject:self.logCard];

    return views;
}

- (void)prepareCEEnterAnimation {
    for (UIView *view in [self ceAnimatedViews]) {
        [view.layer removeAllAnimations];
        view.alpha=1.0;

        view.layer.opacity=0.0;
        [view.layer setValue:@(-16.0)
            forKeyPath:@"transform.translation.y"];
    }

    [self.scrollView.layer removeAllAnimations];
    [self.scrollView.layer setValue:@10.0
        forKeyPath:@"transform.translation.x"];
}

- (void)playCEEnterAnimation {
    [PCLCEPageAnimator
        showRightItems:[self ceAnimatedViews]
        scrollView:self.scrollView];
}

- (void)playCEExitAnimation {
    [PCLCEPageAnimator
        hideRightItems:[self ceAnimatedViews]
        scrollView:self.scrollView];
}


@end
