#import "PCLTopBarView.h"

@interface PCLTopBarView ()
@property (nonatomic, strong) UIStackView *buttonStack;
@property (nonatomic, strong) NSArray<UIButton *> *buttons;
@property (nonatomic, strong) UILabel *pclLabel;
@property (nonatomic, strong) UILabel *iosBadge;
@end

@implementation PCLTopBarView

- (UIColor *)pclThemeColor {
    return [UIColor colorWithRed:19.0/255.0
                           green:112.0/255.0
                            blue:243.0/255.0
                           alpha:1.0];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) [self setupView];
    return self;
}

- (void)setupView {
    self.backgroundColor = [self pclThemeColor];

    self.pclLabel = [[UILabel alloc] init];
    self.pclLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.pclLabel.text = @"PCL";
    self.pclLabel.textColor = UIColor.whiteColor;

    self.pclLabel.font =
        [UIFont systemFontOfSize:26.0
                          weight:UIFontWeightBold];
    [self addSubview:self.pclLabel];

    self.iosBadge = [[UILabel alloc] init];
    self.iosBadge.translatesAutoresizingMaskIntoConstraints = NO;
    self.iosBadge.text = @"iOS";
    self.iosBadge.textAlignment = NSTextAlignmentCenter;
    self.iosBadge.textColor = [self pclThemeColor];

    self.iosBadge.backgroundColor = UIColor.whiteColor;
    self.iosBadge.font =
        [UIFont systemFontOfSize:11.0
                          weight:UIFontWeightBold];
    self.iosBadge.layer.cornerRadius = 5.0;
    self.iosBadge.clipsToBounds = YES;
    [self addSubview:self.iosBadge];

    NSArray<NSString *> *titles =
        @[@"启动", @"下载", @"设置", @"工具"];

    NSArray<NSString *> *symbols =
        @[@"TopBarPlay", @"TopBarDownload",
          @"TopBarSettings", @"TopBarTools"];

    self.buttonStack = [[UIStackView alloc] init];
    self.buttonStack.axis = UILayoutConstraintAxisHorizontal;
    self.buttonStack.alignment = UIStackViewAlignmentCenter;
    self.buttonStack.spacing = 36.0; self.buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.buttonStack];
    NSMutableArray<UIButton *> *buttons =
        [NSMutableArray array];


    for (NSInteger i = 0; i < titles.count; i++) {
        UIButton *button =
            [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = i;

        [button setTitle:titles[i]
                forState:UIControlStateNormal];

        button.titleLabel.font =
            [UIFont systemFontOfSize:17.0
                              weight:UIFontWeightSemibold];

        button.titleLabel.lineBreakMode =
            NSLineBreakByClipping;

        [button setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                forAxis:UILayoutConstraintAxisHorizontal];

        UIImage *image =
            [[UIImage imageNamed:symbols[i]]
                imageWithRenderingMode:
                    UIImageRenderingModeAlwaysTemplate];

        [button setImage:image
                forState:UIControlStateNormal];

        button.imageView.contentMode =
            UIViewContentModeScaleAspectFit;

        [button.imageView.widthAnchor
            constraintEqualToConstant:16.0].active = YES;

        [button.imageView.heightAnchor
            constraintEqualToConstant:16.0].active = YES;

        button.tintColor = UIColor.whiteColor;
        button.semanticContentAttribute =
            UISemanticContentAttributeForceLeftToRight;

        button.layer.cornerRadius = 15.5;
        button.clipsToBounds = YES;
        [button.heightAnchor
            constraintEqualToConstant:31.0].active = YES;

        button.contentEdgeInsets =
            UIEdgeInsetsMake(3.0, 12.0, 3.0, 12.0);

        button.imageEdgeInsets =
            UIEdgeInsetsMake(0.0, 0.0, 0.0, 6.0);

        button.titleEdgeInsets =
            UIEdgeInsetsMake(0.0, 6.0, 0.0, 0.0);

        [button addTarget:self
                   action:@selector(pageButtonPressed:)
         forControlEvents:UIControlEventTouchUpInside];

        [self.buttonStack addArrangedSubview:button];
        [buttons addObject:button];

    }

    self.buttons = buttons;


    [NSLayoutConstraint activateConstraints:@[
        [self.pclLabel.leadingAnchor
            constraintEqualToAnchor:self.leadingAnchor
                           constant:16.0],
        [self.pclLabel.centerYAnchor
            constraintEqualToAnchor:self.centerYAnchor],

        [self.iosBadge.leadingAnchor
            constraintEqualToAnchor:self.pclLabel.trailingAnchor
                           constant:6.0],
        [self.iosBadge.centerYAnchor
            constraintEqualToAnchor:self.pclLabel.centerYAnchor],

        [self.iosBadge.widthAnchor
            constraintEqualToConstant:28.0],
        [self.iosBadge.heightAnchor
            constraintEqualToConstant:20.0],

        [self.buttonStack.centerXAnchor
            constraintEqualToAnchor:self.centerXAnchor],
        [self.buttonStack.centerYAnchor
            constraintEqualToAnchor:self.centerYAnchor]
    ]];

    self.selectedPage = PCLPageTypeLaunch;
    [self updateButtonAppearanceAnimated:NO];
}

- (void)pageButtonPressed:(UIButton *)sender {
    PCLPageType page = (PCLPageType)sender.tag;

    [self selectPage:page animated:YES];

    if ([self.delegate respondsToSelector:
         @selector(topBarView:didSelectPage:)]) {
        [self.delegate topBarView:self
                    didSelectPage:page];
    }
}

- (void)selectPage:(PCLPageType)page
          animated:(BOOL)animated {
    if (page < 0 || page >= self.buttons.count) return;

    _selectedPage = page;
    [self updateButtonAppearanceAnimated:animated];
}

- (void)updateButtonAppearanceAnimated:(BOOL)animated {
    UIColor *blue = [self pclThemeColor];

    for (NSInteger i = 0; i < self.buttons.count; i++) {
        UIButton *button = self.buttons[i];
        BOOL selected = (i == self.selectedPage);

        NSTimeInterval duration =
            selected ? 0.12 : 0.07;
        void (^changes)(void) = ^{
            button.backgroundColor =
                selected ? UIColor.whiteColor
                         : UIColor.clearColor;
            [button setTitleColor:
                selected ? blue : UIColor.whiteColor
                forState:UIControlStateNormal];
            button.tintColor =
                selected ? blue : UIColor.whiteColor;
        };
        if (animated) {
            [UIView animateWithDuration:duration
                                  delay:0.0
                                options:
                UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction |
                UIViewAnimationOptionCurveEaseOut
                             animations:changes
                             completion:nil];
        } else {
            changes();
        }
    }
}


- (CGFloat)launchButtonCenterX {
    [self layoutIfNeeded];
    UIButton *b = self.buttons.firstObject;
    if (!b) return CGRectGetWidth(self.bounds) * 0.37;
    return [b convertPoint:CGPointMake(CGRectGetMidX(b.bounds), 0)
                    toView:self].x;
}


@end
