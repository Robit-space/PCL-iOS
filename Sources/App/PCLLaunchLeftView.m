#import "PCLLaunchLeftView.h"
#import "PCLCEPageAnimator.h"
#import "PCLLoginPanelView.h"
#import "PCLCEProfileTypeDialog.h"
#import "PCLProfileStore.h"
#import "PCLAccountAuthenticator.h"
#import <QuartzCore/QuartzCore.h>

static UIColor *PCLColor(NSUInteger rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
                           green:((rgb >> 8) & 255) / 255.0
                            blue:(rgb & 255) / 255.0
                           alpha:1.0];
}

static NSCache *PCLHeadCache(void) {
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache=[NSCache new]; });
    return cache;
}

static UIImage *PCLHeadFromSkin(UIImage *skin) {
    CGImageRef cg=skin.CGImage;
    if (!cg) return nil;
    CGFloat u=(CGFloat)CGImageGetWidth(cg)/64.0;

    CGImageRef base=CGImageCreateWithImageInRect(
        cg,CGRectMake(8*u,8*u,8*u,8*u));
    CGImageRef hat=CGImageCreateWithImageInRect(
        cg,CGRectMake(40*u,8*u,8*u,8*u));
    if (!base) return nil;

    UIGraphicsBeginImageContextWithOptions(
        CGSizeMake(64,64),NO,0);

    CGContextRef ctx=UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(ctx,kCGInterpolationNone);

    [[UIImage imageWithCGImage:base]
        drawInRect:CGRectMake(0,0,64,64)];

    if (hat)
        [[UIImage imageWithCGImage:hat]
            drawInRect:CGRectMake(0,0,64,64)];

    UIImage *out=UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    CGImageRelease(base);
    if (hat) CGImageRelease(hat);
    return out;
}

@interface PCLCEButton : UIButton
@end

@implementation PCLCEButton

- (instancetype)init {
    self = [super init];
    if (!self) return nil;

    self.layer.cornerRadius = 3.0;
    self.layer.borderWidth = 1.0;

    [self addTarget:self action:@selector(pclPressDown)
     forControlEvents:UIControlEventTouchDown];

    [self addTarget:self action:@selector(pclPressUp)
     forControlEvents:UIControlEventTouchUpInside |
                      UIControlEventTouchUpOutside |
                      UIControlEventTouchCancel];


    return self;
}

- (void)pclPressDown {
    CALayer *p=(CALayer *)self.layer.presentationLayer;
    CGFloat from=p ? p.transform.m11 : 1.0;

    CABasicAnimation *a=
        [CABasicAnimation animationWithKeyPath:@"transform.scale"];

    a.fromValue=@(from);

    a.toValue=@(0.955);

    a.duration=0.09;
    a.fillMode=kCAFillModeForwards;
    a.removedOnCompletion=NO;
    [self.layer addAnimation:a forKey:@"pcl.ce.scale"];
}

- (void)pclPressUp {
    CALayer *p=(CALayer *)self.layer.presentationLayer;
    CGFloat from=p ? p.transform.m11 : 0.955;

    [self.layer removeAnimationForKey:@"pcl.ce.scale"];

    CABasicAnimation *a=
        [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    a.fromValue=@(from);
    a.toValue=@(1.0);
    a.duration=0.16;
    [self.layer addAnimation:a forKey:@"pcl.ce.release"];
}


@end

@interface PCLSkinHeadView : UIView
- (void)loadProfile:(NSDictionary *)profile;
@end

@interface PCLSkinHeadView ()
@property(nonatomic,strong) UIImage *remoteHead;
@property(nonatomic,copy) NSString *loadToken;
@property(nonatomic,copy) NSString *sourceSkinURL;
@end

@implementation PCLSkinHeadView

- (instancetype)init {
    self = [super init];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.layer.shadowColor = PCLColor(0x0B5BCB).CGColor;
    self.layer.shadowOpacity = 0.20;
    self.layer.shadowRadius = 10.0;
    self.layer.shadowOffset = CGSizeZero;

    return self;
}

- (void)pclUseImage:(UIImage *)image
                  token:(NSString *)token {
    if (!image || ![self.loadToken isEqual:token]) return;
    self.remoteHead=image;
    self.layer.shadowOpacity=.16;
    [self setNeedsDisplay];
}

- (void)pclLoadURL:(NSString *)text
              crop:(BOOL)crop
             token:(NSString *)token {

    if (!text.length) return;

    if ([text hasPrefix:
        @"http://textures.minecraft.net/"]) {
        text=[@"https://" stringByAppendingString:
            [text substringFromIndex:7]];
    }
    if (crop)
        self.sourceSkinURL=text;

    NSString *key=[NSString stringWithFormat:
        @"%@|%@",crop?@"skin":@"head",text];

    UIImage *cached=[PCLHeadCache() objectForKey:key];
    if (cached) {
        [self pclUseImage:cached token:token];
        return;
    }

    NSURL *url=[NSURL URLWithString:text];
    if (!url) return;

    if (url.isFileURL) {
        UIImage *image=
            [UIImage imageWithContentsOfFile:url.path];

        if (crop && image)
            image=PCLHeadFromSkin(image);

        if (image)
            [self pclUseImage:image token:token];

        return;
    }

    __weak typeof(self) weakSelf=self;
    [[[NSURLSession sharedSession] dataTaskWithURL:url
        completionHandler:^(NSData *data,
                            NSURLResponse *response,
                            NSError *error) {
        UIImage *image=data.length
            ? [UIImage imageWithData:data] : nil;

        if (crop && image)
            image=PCLHeadFromSkin(image);
        if (!image) return;

        [PCLHeadCache() setObject:image forKey:key];

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf pclUseImage:image token:token];
        });
    }] resume];
}

- (void)pclLoadDefault:(NSDictionary *)profile
                 token:(NSString *)token {
    NSString *uuid=profile[@"uuid"] ?: @"0";
    NSString *last=uuid.length
        ? [uuid substringFromIndex:uuid.length-1] : @"0";

    unsigned value=0;
    [[NSScanner scannerWithString:last] scanHexInt:&value];
    NSString *name=(value&1) ? @"Alex" : @"Steve";

    NSString *url=[NSString stringWithFormat:
        @"https://mc-heads.net/skin/%@",name];

    [self pclLoadURL:url crop:YES token:token];
}


- (void)pclLoadMicrosoft:(NSDictionary *)profile
                    token:(NSString *)token {
    NSString *saved=profile[@"skinURL"];
    if (saved.length)
        [self pclLoadURL:saved crop:YES token:token];

    NSString *prefix=profile[@"credentialPrefix"];
    NSString *key=prefix.length
        ? [prefix stringByAppendingString:@".access"] : nil;

    NSString *access=key.length
        ? [PCLAccountAuthenticator secretForKey:key] : nil;

    if (!access.length) {
        [self pclLoadMicrosoftPublic:profile token:token];
        return;
    }

    NSURL *url=[NSURL URLWithString:
        @"https://api.minecraftservices.com/minecraft/profile"];

    NSMutableURLRequest *r=
        [NSMutableURLRequest requestWithURL:url];

    [r setValue:
        [@"Bearer " stringByAppendingString:access]
        forHTTPHeaderField:@"Authorization"];

    __weak typeof(self) weakSelf=self;

    [[[NSURLSession sharedSession] dataTaskWithRequest:r
        completionHandler:^(NSData *data,
                            NSURLResponse *response,
                            NSError *error) {
        NSDictionary *json=data.length
            ? [NSJSONSerialization JSONObjectWithData:data
                options:0 error:nil] : nil;

        NSArray *skins=json[@"skins"];
        NSString *skinURL=skins.count
            ? skins[0][@"url"] : nil;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (skinURL.length)
                [weakSelf pclLoadURL:skinURL
                                crop:YES
                               token:token];
            else
                [weakSelf pclLoadMicrosoftPublic:profile
                                            token:token];
        });
    }] resume];
}

- (void)pclLoadMicrosoftPublic:(NSDictionary *)profile
                          token:(NSString *)token {
    NSString *uuid=[profile[@"uuid"]
        stringByReplacingOccurrencesOfString:@"-" withString:@""];
    if (!uuid.length) return;

    NSString *saved=profile[@"skinURL"];
    if (saved.length)
        [self pclLoadURL:saved crop:YES token:token];

    NSString *text=[NSString stringWithFormat:
        @"https://sessionserver.mojang.com/session/minecraft/profile/%@?unsigned=false",
        uuid];

    NSURL *url=[NSURL URLWithString:text];
    __weak typeof(self) weakSelf=self;

    [[[NSURLSession sharedSession] dataTaskWithURL:url
        completionHandler:^(NSData *data,
                            NSURLResponse *response,
                            NSError *error) {
        NSDictionary *json=data.length
            ? [NSJSONSerialization JSONObjectWithData:data
                options:0 error:nil] : nil;
        NSString *skinURL=nil;

        for (NSDictionary *item in json[@"properties"]) {
            if (![item[@"name"] isEqual:@"textures"]) continue;

            NSData *decoded=[[NSData alloc]
                initWithBase64EncodedString:item[@"value"]
                options:0];

            NSDictionary *textures=decoded.length
                ? [NSJSONSerialization JSONObjectWithData:decoded
                    options:0 error:nil] : nil;

            skinURL=textures[@"textures"][@"SKIN"][@"url"];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (skinURL.length) {
                [weakSelf pclLoadURL:skinURL crop:YES token:token];
                return;
            }

            NSString *who=profile[@"username"] ?: uuid;
            NSString *fallback=[NSString stringWithFormat:
                @"https://mc-heads.net/skin/%@",who];
            [weakSelf pclLoadURL:fallback crop:YES token:token];
        });
    }] resume];
}

- (void)pclLoadAuth:(NSDictionary *)profile
              token:(NSString *)token {
    NSString *root=profile[@"server"];
    NSString *uuid=profile[@"uuid"];

    if (!root.length || !uuid.length) {
        [self pclLoadDefault:profile token:token];
        return;
    }

    while ([root hasSuffix:@"/"])
        root=[root substringToIndex:root.length-1];

    if ([root hasSuffix:@"/authserver"])
        root=[root substringToIndex:
            root.length-@"/authserver".length];

    NSString *text=[NSString stringWithFormat:
        @"%@/sessionserver/session/minecraft/profile/%@?unsigned=false",
        root,uuid];

    __weak typeof(self) weakSelf=self;
    [[[NSURLSession sharedSession]
        dataTaskWithURL:[NSURL URLWithString:text]
        completionHandler:^(NSData *data,
                            NSURLResponse *response,
                            NSError *error) {
        NSDictionary *json=data.length
            ? [NSJSONSerialization JSONObjectWithData:data
                options:0 error:nil] : nil;
        NSString *skinURL=nil;

        for (NSDictionary *property in json[@"properties"]) {
            if (![property[@"name"] isEqual:@"textures"]) continue;

            NSData *decoded=[[NSData alloc]
                initWithBase64EncodedString:property[@"value"]
                options:0];

            NSDictionary *textures=decoded.length
                ? [NSJSONSerialization JSONObjectWithData:decoded
                    options:0 error:nil] : nil;
            skinURL=textures[@"textures"][@"SKIN"][@"url"];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (skinURL.length)
                [weakSelf pclLoadURL:skinURL crop:YES token:token];
            else
                [weakSelf pclLoadDefault:profile token:token];
        });
    }] resume];
}


- (void)loadProfile:(NSDictionary *)profile {
    NSString *token=NSUUID.UUID.UUIDString;
    self.loadToken=token;
    self.remoteHead=nil;
    self.sourceSkinURL=nil;
    self.layer.shadowOpacity=0;
    [self setNeedsDisplay];

    if (!profile) return;

    NSString *type=profile[@"type"];
    NSString *skinURL=profile[@"skinURL"];

    if ([type isEqual:@"microsoft"]) {
        [self pclLoadMicrosoft:profile token:token];
        return;
    }

    if ([type isEqual:@"authlib"]) {
        if (skinURL.length)
            [self pclLoadURL:skinURL crop:YES token:token];
        else
            [self pclLoadAuth:profile token:token];
        return;
    }

    if ([type isEqual:@"offline"] && skinURL.length) {
        [self pclLoadURL:skinURL crop:YES token:token];
        return;
    }

    [self pclLoadDefault:profile token:token];
}

- (void)drawRect:(CGRect)rect {
    CGFloat canvas=MIN(rect.size.width,rect.size.height);

    if (self.remoteHead) {
        CGFloat size=canvas*56.0/64.0;
        CGFloat x=(canvas-size)/2.0;
        [self.remoteHead drawInRect:CGRectMake(x,x,size,size)];
        return;
    }

    CGFloat point=40.0*canvas/64.0;
    UIImageSymbolConfiguration *config=
        [UIImageSymbolConfiguration
            configurationWithPointSize:point
                                weight:UIImageSymbolWeightRegular];

    UIImage *icon=[[UIImage systemImageNamed:@"person"]
        imageByApplyingSymbolConfiguration:config];

    icon=[icon imageWithTintColor:
        [PCLColor(0x4B5D73) colorWithAlphaComponent:.72]
        renderingMode:UIImageRenderingModeAlwaysOriginal];

    CGFloat x=(canvas-icon.size.width)/2.0;
    CGFloat y=(canvas-icon.size.height)/2.0;
    [icon drawAtPoint:CGPointMake(x,y)];
}


@end

@interface PCLLaunchLeftView ()
<UIGestureRecognizerDelegate, UIDocumentPickerDelegate>

@property (nonatomic, strong) UIView *transitionContentView;
@property (nonatomic, strong) UIView *panLogin;

@property (nonatomic, strong) PCLCEButton *launchButton;
@property (nonatomic, strong) UIView *launchContentView;
@property (nonatomic, strong) UILabel *launchTitleLabel;
@property (nonatomic, strong) UILabel *versionLabel;

@property (nonatomic, strong) PCLCEButton *instanceButton;
@property (nonatomic, strong) PCLCEButton *moreButton;

@property (nonatomic, strong) UIView *profileSelectView;
@property (nonatomic, strong) UIView *profileSkinView;

@property (nonatomic, strong) UIView *hintView;
@property (nonatomic, strong) UILabel *hintLabel;

@property (nonatomic, strong) PCLSkinHeadView *skinView;
@property (nonatomic, strong) UILabel *usernameLabel;
@property (nonatomic, strong) UILabel *typeLabel;

@property (nonatomic, strong) UIView *profileButtonsCard;
@property(nonatomic,strong) UIView *profileOptionMenu;
@property(nonatomic) NSInteger profileOptionMode;
@property(nonatomic,strong) NSTimer *profileControlsTimer;
@property(nonatomic,copy) NSString *skinImportProfileIdentifier;
@property(nonatomic,weak) UIButton *profileOptionAnchor;
@property (nonatomic, strong) UIButton *skinButton;
@property (nonatomic, strong) UIButton *editButton;
@property (nonatomic, strong) UIButton *switchButton;

@property (nonatomic, strong) UIButton *createProfileButton;
@property (nonatomic, strong) UIScrollView *profileScrollView;
@property (nonatomic, strong) NSMutableArray<UIButton *> *profileRows;
@property(nonatomic,copy)
    NSString *expandedProfileIdentifier;
@property(nonatomic,copy)
    NSString *pendingDeleteIdentifier;

@property (nonatomic, strong) PCLLoginPanelView *loginPanel;
@property (nonatomic, strong) PCLCEProfileTypeDialog *profileDialog;

@end

@implementation PCLLaunchLeftView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor =
        [UIColor colorWithWhite:0.995 alpha:0.824];

    self.transitionContentView=[[UIView alloc] init];
    self.transitionContentView.backgroundColor=
        UIColor.clearColor;

    self.transitionContentView.layer.anchorPoint=
        CGPointMake(.5,.5);

    [self addSubview:self.transitionContentView];

    [self buildMainUI];
    [self buildProfileSelectUI];
    [self buildProfileSkinUI];
    [self buildLoginPanelUI];

    [self reloadState];

    return self;
}

- (PCLCEButton *)pclButton:(NSString *)title
                 highlight:(BOOL)highlight {

    PCLCEButton *button = [[PCLCEButton alloc] init];

    UIColor *color =
        PCLColor(highlight ? 0x0B5BCB : 0x343D4A);

    button.layer.borderColor = color.CGColor;
    button.backgroundColor =
        [UIColor colorWithWhite:1 alpha:0x55 / 255.0];

    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:color forState:UIControlStateNormal];

    button.titleLabel.font =
        [UIFont systemFontOfSize:13.0];

    return button;
}

- (void)buildMainUI {
    self.panLogin = [[UIView alloc] init];
    [self.transitionContentView addSubview:self.panLogin];

    self.launchButton =
        [self pclButton:@"" highlight:YES];

    [self.launchButton addTarget:self
                          action:@selector(launchPressed)
                forControlEvents:UIControlEventTouchUpInside];

    [self.transitionContentView addSubview:self.launchButton];

    self.launchContentView = [[UIView alloc] init];
    self.launchContentView.userInteractionEnabled = NO;
    [self.launchButton addSubview:self.launchContentView];

    self.launchTitleLabel = [[UILabel alloc] init];
    self.launchTitleLabel.textAlignment = NSTextAlignmentCenter;
    [self.launchContentView addSubview:self.launchTitleLabel];

    self.versionLabel = [[UILabel alloc] init];
    self.versionLabel.textAlignment = NSTextAlignmentCenter;
    self.versionLabel.font = [UIFont systemFontOfSize:11.0];
    self.versionLabel.textColor = PCLColor(0x8C8C8C);

    [self.launchContentView addSubview:self.versionLabel];

    self.instanceButton =
        [self pclButton:@"实例选择" highlight:NO];

    [self.instanceButton addTarget:self
                            action:@selector(instancePressed)
                  forControlEvents:UIControlEventTouchUpInside];

    [self.transitionContentView addSubview:self.instanceButton];

    self.moreButton =
        [self pclButton:@"实例设置" highlight:NO];

    [self.moreButton addTarget:self
                        action:@selector(morePressed)
              forControlEvents:UIControlEventTouchUpInside];

    [self.transitionContentView addSubview:self.moreButton];
}

- (void)buildProfileSelectUI {
    self.profileSelectView = [[UIView alloc] init];
    [self.panLogin addSubview:self.profileSelectView];

    self.hintView = [[UIView alloc] init];
    self.hintView.backgroundColor =
        [PCLColor(0xEAF2FE) colorWithAlphaComponent:0.72];

    self.hintView.layer.cornerRadius = 2.0;
    [self.profileSelectView addSubview:self.hintView];

    UIView *bar = [[UIView alloc] init];
    bar.tag = 9201;
    bar.backgroundColor =
        [PCLColor(0x1370F3) colorWithAlphaComponent:0.60
        ];

    [self.hintView addSubview:bar];

    self.hintLabel = [[UILabel alloc] init];
    self.hintLabel.numberOfLines = 0;
    self.hintLabel.font =
        [UIFont systemFontOfSize:13.0];
    self.hintLabel.textColor =
        PCLColor(0x343D4A);

    self.hintLabel.text =
        @"新建并选择一个档案以启动游戏";

    [self.hintView addSubview:self.hintLabel];

    self.profileScrollView=[[UIScrollView alloc] init];
    self.profileScrollView.showsVerticalScrollIndicator=NO;
    [self.profileSelectView addSubview:self.profileScrollView];

    self.profileRows=[NSMutableArray array];
    UIView *newCard = [[UIView alloc] init];
    newCard.tag = 9202;

    newCard.backgroundColor = [UIColor colorWithWhite:0.995 alpha:0.824];
    newCard.layer.cornerRadius = 5.0;
    newCard.layer.shadowColor =
        UIColor.blackColor.CGColor;

    newCard.layer.shadowOpacity = 0.07;
    newCard.layer.shadowRadius = 3.0;
    newCard.layer.shadowOffset = CGSizeZero;

    [self.profileSelectView addSubview:newCard];
    self.createProfileButton =
        [UIButton buttonWithType:UIButtonTypeCustom];

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration
            configurationWithPointSize:14.0
                                weight:UIImageSymbolWeightRegular];

    UIImage *icon =
        [[UIImage systemImageNamed:@"person.badge.plus"]
            imageByApplyingSymbolConfiguration:config];
    [self.createProfileButton
        setImage:icon
        forState:UIControlStateNormal];

    self.createProfileButton.tintColor =
        PCLColor(0x343D4A);

    [self.createProfileButton
        addTarget:self
           action:@selector(newProfilePressed)
 forControlEvents:UIControlEventTouchUpInside];

    [newCard addSubview:self.createProfileButton];
}

- (NSString *)profileInfo:(NSDictionary *)profile {
    NSString *type=profile[@"type"];

    if ([type isEqual:@"microsoft"])
        return @"正版验证";
    if ([type isEqual:@"offline"])
        return @"离线验证";

    NSString *server=profile[@"server"];
    NSURLComponents *url=
        [NSURLComponents componentsWithString:server];

    return url.host.length
        ? [NSString stringWithFormat:@"第三方验证 / %@",url.host]
        : @"第三方验证";
}


- (void)reloadProfileList {
    NSArray *profiles=[PCLProfileStore profiles];

    for (UIButton *row in self.profileRows)
        [row removeFromSuperview];
    [self.profileRows removeAllObjects];

    self.hintLabel.text=profiles.count
        ? @"选择一个档案以启动游戏"
        : @"新建并选择一个档案以启动游戏";

    for (NSDictionary *profile in profiles) {
        UIButton *row=[UIButton buttonWithType:UIButtonTypeCustom];
        row.accessibilityIdentifier=profile[@"identifier"];
        row.layer.cornerRadius=6;
        row.clipsToBounds=YES;

        PCLSkinHeadView *icon=[[PCLSkinHeadView alloc] init];
        icon.tag=9300;
        icon.userInteractionEnabled=NO;
        [icon loadProfile:profile];
        [row addSubview:icon];

        UILabel *title=[[UILabel alloc] init];
        title.tag=9301;
        title.text=profile[@"username"];
        title.textColor=PCLColor(0x343D4A);
        title.font=[UIFont systemFontOfSize:14];
        [row addSubview:title];

        UILabel *info=[[UILabel alloc] init];
        info.tag=9302;

        info.text=[self profileInfo:profile];
        info.textColor=PCLColor(0x8C8C8C);
        info.font=[UIFont systemFontOfSize:11];
        [row addSubview:info];

        UIView *actions=[[UIView alloc] init];
        actions.tag=9303;
        actions.hidden=YES;
        actions.alpha=0;
        actions.userInteractionEnabled=YES;

        UIButton *aux=
            [UIButton buttonWithType:UIButtonTypeCustom];
        aux.tag=9310;
        aux.accessibilityIdentifier=
            profile[@"identifier"];

        BOOL offline=
            [profile[@"type"] isEqual:@"offline"];

        NSString *symbol=
            offline ? @"pencil" : @"doc.on.doc";

        [aux setImage:[UIImage systemImageNamed:symbol]
             forState:UIControlStateNormal];
        aux.tintColor=PCLColor(0x343D4A);

        UIButton *del=
            [UIButton buttonWithType:UIButtonTypeCustom];
        del.tag=9311;
        del.accessibilityIdentifier=
            profile[@"identifier"];
        [del setImage:[UIImage systemImageNamed:@"trash"]
             forState:UIControlStateNormal];
        del.tintColor=PCLColor(0x343D4A);

        [aux addTarget:self action:@selector(profileAuxPressed:)
       forControlEvents:UIControlEventTouchUpInside];

        [del addTarget:self action:@selector(profileDeletePressed:)
       forControlEvents:UIControlEventTouchUpInside];

        [actions addSubview:aux];
        [actions addSubview:del];
        [row addSubview:actions];

        [row addTarget:self
                action:@selector(profileRowPressed:)
      forControlEvents:UIControlEventTouchUpInside];

        [self.profileScrollView addSubview:row];
        [self.profileRows addObject:row];
    }
    [self setNeedsLayout];
}

- (void)scheduleProfileControlsAutoHide {
    [self cancelProfileControlsTimer];

    if (self.profileButtonsCard.alpha<0.5 ||
        !self.profileOptionMenu.hidden)
        return;

    self.profileControlsTimer=
        [NSTimer scheduledTimerWithTimeInterval:4.0
            target:self
            selector:@selector(hideProfileControlsAutomatically)
            userInfo:nil
            repeats:NO];
}

- (void)hideProfileControlsAutomatically {
    self.profileControlsTimer=nil;

    if (!self.profileOptionMenu.hidden)
        return;

    [UIView animateWithDuration:.12
        delay:0
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionCurveEaseOut
        animations:^{
            self.profileButtonsCard.alpha=0;
        }
        completion:nil];
}

- (void)cancelProfileControlsTimer {
    [self.profileControlsTimer invalidate];
    self.profileControlsTimer=nil;
}

- (void)dismissTransientUI {
    [self cancelProfileControlsTimer];

    self.profileButtonsCard.alpha=0;

    [self.profileOptionMenu.layer removeAllAnimations];

    self.profileOptionMenu.alpha=0;
    self.profileOptionMenu.hidden=YES;
    self.profileOptionMenu.transform=
        CGAffineTransformIdentity;

    [self.loginPanel dismissTransientUI];
}

- (void)pclLoginTransition:(dispatch_block_t)changes {
    [self dismissTransientUI];

    [self.panLogin.layer removeAllAnimations];
    self.userInteractionEnabled=NO;

    UIViewAnimationOptions out=
        UIViewAnimationOptionBeginFromCurrentState |
        UIViewAnimationOptionCurveEaseOut;

    [UIView animateWithDuration:.10 delay:0 options:out animations:^{
        self.panLogin.alpha=0;
    } completion:^(BOOL done) {
        if (changes) changes();
        self.panLogin.alpha=0;
        [self.panLogin layoutIfNeeded];

        [UIView animateWithDuration:.10 delay:.02
            options:UIViewAnimationOptionCurveEaseIn
            animations:^{ self.panLogin.alpha=1; }
            completion:^(BOOL finished) {
                self.userInteractionEnabled=YES;
            }];
    }];
}

- (void)buildLoginPanelUI {
    self.loginPanel=[[PCLLoginPanelView alloc] init];
    self.loginPanel.hidden=YES;
    [self.panLogin addSubview:self.loginPanel];

    __weak typeof(self) weakSelf=self;
    self.loginPanel.onClose=^{
        [weakSelf reloadProfileList];
        [weakSelf pclLoginTransition:^{
            weakSelf.loginPanel.hidden=YES;
            weakSelf.profileSkinView.hidden=YES;
            weakSelf.profileSelectView.hidden=NO;
            [weakSelf grayLaunchForProfileSelection];
            [weakSelf setNeedsLayout];
        }];
    };

    self.loginPanel.onProfileCreated=^{
        [weakSelf pclLoginTransition:^{
            [weakSelf reloadState];
        }];
    };
}



- (void)buildProfileSkinUI {
    self.profileSkinView = [[UIView alloc] init];
    [self.panLogin addSubview:self.profileSkinView];

    self.skinView = [[PCLSkinHeadView alloc] init];
    [self.profileSkinView addSubview:self.skinView];

    self.usernameLabel = [[UILabel alloc] init];
    self.usernameLabel.textAlignment =
        NSTextAlignmentCenter;

    self.usernameLabel.font =
        [UIFont systemFontOfSize:16.0];

    self.usernameLabel.textColor =
        PCLColor(0x343D4A);

    [self.profileSkinView
        addSubview:self.usernameLabel];

    self.typeLabel = [[UILabel alloc] init];

    self.typeLabel.textAlignment =
        NSTextAlignmentCenter;

    self.typeLabel.font =
        [UIFont systemFontOfSize:12.0];

    self.typeLabel.textColor =
        PCLColor(0xA6A6A6);

    [self.profileSkinView addSubview:self.typeLabel];

    self.profileButtonsCard =
        [[UIView alloc] init];

    self.profileButtonsCard.backgroundColor = [UIColor colorWithWhite:0.995 alpha:0.824];

    self.profileButtonsCard.layer.cornerRadius = 5.0;

    self.profileButtonsCard.layer.shadowColor =
        UIColor.blackColor.CGColor;

    self.profileButtonsCard.layer.shadowOpacity = 0.07;
    self.profileButtonsCard.layer.shadowRadius = 3.0;
    self.profileButtonsCard.layer.shadowOffset = CGSizeZero;

    [self.profileSkinView
        addSubview:self.profileButtonsCard];

    self.profileOptionMenu=[[UIView alloc] init];
    self.profileOptionMenu.hidden=YES;
    self.profileOptionMenu.alpha=0;
    self.profileOptionMenu.backgroundColor=
        PCLColor(0xFBFBFB);
    self.profileOptionMenu.layer.cornerRadius=4;
    self.profileOptionMenu.layer.borderWidth=1;
    self.profileOptionMenu.layer.borderColor=
        PCLColor(0xEBEBEB).CGColor;
    self.profileOptionMenu.layer.shadowColor=
        UIColor.blackColor.CGColor;
    self.profileOptionMenu.layer.shadowOpacity=.14;
    self.profileOptionMenu.layer.shadowRadius=6;
    self.profileOptionMenu.layer.shadowOffset=
        CGSizeMake(0,2);

    [self addSubview:self.profileOptionMenu];

    self.skinButton =
        [UIButton buttonWithType:UIButtonTypeCustom];

    self.editButton =
        [UIButton buttonWithType:UIButtonTypeCustom];

    self.switchButton =
        [UIButton buttonWithType:UIButtonTypeCustom];

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration
            configurationWithPointSize:13.0
                                weight:UIImageSymbolWeightRegular];

    [self.skinButton
        setImage:[[UIImage systemImageNamed:@"tshirt"]
            imageByApplyingSymbolConfiguration:config]
        forState:UIControlStateNormal];

    [self.editButton
        setImage:[[UIImage systemImageNamed:@"pencil"]
            imageByApplyingSymbolConfiguration:config]
        forState:UIControlStateNormal];

    [self.switchButton
        setImage:[[UIImage systemImageNamed:
            @"arrow.left.arrow.right"]
            imageByApplyingSymbolConfiguration:config]
        forState:UIControlStateNormal];

    NSArray *buttons = @[
        self.skinButton,
        self.editButton,
        self.switchButton
    ];

    for (UIButton *button in buttons) {
        button.tintColor = PCLColor(0x343D4A);
        [self.profileButtonsCard addSubview:button];
    }

    [self.skinButton
        addTarget:self
           action:@selector(skinPressed)
 forControlEvents:UIControlEventTouchUpInside];

    [self.editButton
        addTarget:self
           action:@selector(editPressed)
 forControlEvents:UIControlEventTouchUpInside];

    [self.switchButton
        addTarget:self
           action:@selector(switchPressed)
 forControlEvents:UIControlEventTouchUpInside];

    self.profileButtonsCard.alpha = 0.0;

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(profileTapped)];

    tap.delegate=self;
    tap.cancelsTouchesInView=NO;

    [self.profileSkinView addGestureRecognizer:tap];
}

- (void)reloadState {
    NSUserDefaults *defaults =
        NSUserDefaults.standardUserDefaults;

    [self reloadProfileList];

    NSDictionary *profile=
        [PCLProfileStore selectedProfile];

    NSString *username=profile[@"username"];

    NSString *instance =
        [defaults stringForKey:@"PCLSelectedInstance"];

    BOOL hasProfile =
        username.length > 0;

    BOOL hasInstance =
        instance.length > 0;

    self.profileSelectView.hidden =
        hasProfile;

    self.profileSkinView.hidden =
        !hasProfile;

    if (hasProfile)
        self.loginPanel.hidden=YES;

    self.usernameLabel.text =
        hasProfile
        ? username
        : @"";

    NSString *type=profile[@"type"];
    NSString *info=@"离线验证";
    if ([type isEqual:@"microsoft"]) info=@"正版验证";
    if ([type isEqual:@"authlib"]) {
        NSString *host=[NSURLComponents
            componentsWithString:profile[@"server"]].host;
        info=host.length
            ? [NSString stringWithFormat:@"第三方验证 / %@",host]
            : @"第三方验证";
    }
    self.typeLabel.text=hasProfile ? info : @"";

    self.editButton.hidden=
        [type isEqualToString:@"offline"];

    [self.skinView loadProfile:
        hasProfile ? profile : nil];

    self.versionLabel.text =
        hasInstance
        ? instance
        : @"未找到可用的游戏实例";

    self.launchTitleLabel.text =
        hasInstance ? @"启动游戏" : @"下载游戏";

    BOOL canLaunch =
        hasInstance ? hasProfile : YES;

    self.launchButton.enabled =
        canLaunch;

    self.instanceButton.enabled = YES;

    self.moreButton.hidden =
        !hasInstance;

    UIColor *launchColor =
        canLaunch
        ? PCLColor(0x0B5BCB)
        : PCLColor(0xA6A6A6);

    self.launchButton.layer.borderColor =
        launchColor.CGColor;

    self.launchTitleLabel.textColor =
        launchColor;

    [self.launchButton
        setTitleColor:launchColor
             forState:UIControlStateNormal];

    [self setNeedsLayout];
}

- (void)launchPressed {
    if (self.onLaunch)
        self.onLaunch();
}

- (void)instancePressed {
    if (self.onSelectInstance)
        self.onSelectInstance();
}

- (void)morePressed {
    if (self.onInstanceSettings)
        self.onInstanceSettings();
}

- (void)openAuthType:(PCLProfileAuthType)type {
    [self pclLoginTransition:^{
        self.profileSelectView.hidden=YES;
        self.profileSkinView.hidden=YES;
        self.loginPanel.hidden=NO;

        if (type==PCLProfileAuthMicrosoft)
            [self.loginPanel showMicrosoft];
        else if (type==PCLProfileAuthOffline)
            [self.loginPanel showOffline];
        else
            [self.loginPanel showThirdParty];

        [self setNeedsLayout];
    }];
}


- (void)newProfilePressed {
    if (!self.window) return;

    PCLCEProfileTypeDialog *dialog=
        [[PCLCEProfileTypeDialog alloc] init];

    self.profileDialog=dialog;

    __weak typeof(self) weakSelf=self;

    dialog.onSelect=^(PCLProfileAuthType type) {
        [weakSelf openAuthType:type];
        weakSelf.profileDialog=nil;
    };

    dialog.onCancel=^{
        weakSelf.profileDialog=nil;
    };

    [dialog presentInView:self.window];
}



- (NSDictionary *)profileForIdentifier:(NSString *)identifier {

    for (NSDictionary *p in [PCLProfileStore profiles])

        if ([p[@"identifier"] isEqual:identifier])

            return p;

    return nil;

}

- (void)profileRowPressed:(UIButton *)sender {
    NSString *pid=sender.accessibilityIdentifier;

    if ([self.expandedProfileIdentifier isEqual:pid]) {
        self.expandedProfileIdentifier=nil;
        [PCLProfileStore selectProfileWithIdentifier:pid];

        [self pclLoginTransition:^{
            [self reloadState];
        }];
        return;
    }

    self.expandedProfileIdentifier=pid;
    self.pendingDeleteIdentifier=nil;

    for (UIButton *row in self.profileRows) {
        BOOL open=[row.accessibilityIdentifier isEqual:pid];
        UIView *actions=[row viewWithTag:9303];

        row.backgroundColor=open
            ? [PCLColor(0x1370F3) colorWithAlphaComponent:.055]
            : UIColor.clearColor;

        if (open) {
            actions.hidden=NO;
            actions.alpha=0;
        }

        NSDictionary *p=
            [self profileForIdentifier:
                row.accessibilityIdentifier];

        UILabel *info=[row viewWithTag:9302];
        info.text=[self profileInfo:p];

        [UIView animateWithDuration:.10 animations:^{
            actions.alpha=open ? 1 : 0;
        } completion:^(BOOL done) {
            actions.hidden=!open;
        }];
    }

    [self setNeedsLayout];
}

- (void)profileAuxPressed:(UIButton *)sender {
    NSDictionary *profile=
        [self profileForIdentifier:
            sender.accessibilityIdentifier];
    if (!profile) return;

    if ([profile[@"type"] isEqual:@"offline"]) {
        [self pclLoginTransition:^{
            self.profileSelectView.hidden=YES;
            self.profileSkinView.hidden=YES;
            self.loginPanel.hidden=NO;
            [self.loginPanel editOfflineProfile:profile];
            [self setNeedsLayout];
        }];
        return;
    }


    UIPasteboard.generalPasteboard.string=

        profile[@"uuid"] ?: @"";

    UIButton *row=(UIButton *)sender.superview.superview;

    UILabel *info=[row viewWithTag:9302];

    info.text=@"UUID 已复制";

    dispatch_after(

        dispatch_time(DISPATCH_TIME_NOW,

            (int64_t)(1.1*NSEC_PER_SEC)),

        dispatch_get_main_queue(), ^{

            NSDictionary *p=

                [self profileForIdentifier:

                    row.accessibilityIdentifier];

            if (p) info.text=[self profileInfo:p];

        });

}

- (void)profileDeletePressed:(UIButton *)sender {
    NSString *pid=sender.accessibilityIdentifier;

    if ([self.pendingDeleteIdentifier isEqual:pid]) {
        self.pendingDeleteIdentifier=nil;
        self.expandedProfileIdentifier=nil;
        [PCLProfileStore removeProfileWithIdentifier:pid];
        [self reloadProfileList];
        return;
    }

    self.pendingDeleteIdentifier=pid;
    sender.tintColor=PCLColor(0xD84A4A);

    UIButton *row=(UIButton *)sender.superview.superview;
    UILabel *info=[row viewWithTag:9302];
    info.text=@"再次点击删除档案";

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
            (int64_t)(2*NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            if (![self.pendingDeleteIdentifier isEqual:pid])
                return;

            self.pendingDeleteIdentifier=nil;
            sender.tintColor=PCLColor(0x343D4A);

            NSDictionary *p=
                [self profileForIdentifier:pid];
            if (p) info.text=[self profileInfo:p];
        });
}

- (void)grayLaunchForProfileSelection {
    if (![self.launchTitleLabel.text
        isEqualToString:@"启动游戏"]) return;

    UIColor *gray=PCLColor(0xA6A6A6);
    self.launchButton.enabled=NO;
    self.launchButton.layer.borderColor=gray.CGColor;
    self.launchTitleLabel.textColor=gray;

    [self.launchButton setTitleColor:gray
        forState:UIControlStateNormal];
}

- (void)switchPressed {
    [self reloadProfileList];

    [self pclLoginTransition:^{
        self.profileSkinView.hidden=YES;
        self.loginPanel.hidden=YES;
        self.profileSelectView.hidden=NO;
        [self grayLaunchForProfileSelection];
        [self setNeedsLayout];
    }];
}


- (void)openProfileURL:(NSString *)text {
    NSURL *url=[NSURL URLWithString:text];
    if (!url) return;

    [UIApplication.sharedApplication
        openURL:url options:@{} completionHandler:nil];
}

- (void)profileMessage:(NSString *)message {
    NSDictionary *profile=[PCLProfileStore selectedProfile];
    NSString *pid=profile[@"identifier"];

    self.typeLabel.text=message;

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
            (int64_t)(1.6*NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            NSDictionary *now=[PCLProfileStore selectedProfile];
            if ([now[@"identifier"] isEqual:pid])
                self.typeLabel.text=[self profileInfo:now];
        });
}

- (NSString *)profileAuthWebRoot:(NSDictionary *)profile {
    NSString *root=profile[@"server"] ?: @"";

    NSRange r=[root rangeOfString:@"/api/yggdrasil"];
    if (r.location!=NSNotFound)
        root=[root substringToIndex:r.location];

    while ([root hasSuffix:@"/"])
        root=[root substringToIndex:root.length-1];

    return root;
}

- (void)showProfileOptionMenu:(NSInteger)mode {
    [self cancelProfileControlsTimer];

    self.profileOptionMode=mode;
    self.profileOptionAnchor=
        mode==1 ? self.skinButton : self.editButton;

    for (UIView *v in self.profileOptionMenu.subviews)
        [v removeFromSuperview];

    NSArray *items=mode==1
        ? @[@"修改皮肤",@"保存皮肤",@"刷新皮肤",@"修改披风"]
        : @[@"修改密码",@"修改玩家 ID"];

    for (NSInteger i=0;i<items.count;i++) {
        UIButton *b=[UIButton buttonWithType:UIButtonTypeCustom];
        b.tag=9500+i;
        [b setTitle:items[i] forState:UIControlStateNormal];
        [b setTitleColor:PCLColor(0x343D4A)
                forState:UIControlStateNormal];
        b.contentHorizontalAlignment=
            UIControlContentHorizontalAlignmentLeft;
        b.contentEdgeInsets=UIEdgeInsetsMake(0,10,0,0);
        [b addTarget:self action:@selector(profileOptionPressed:)
            forControlEvents:UIControlEventTouchUpInside];
        [self.profileOptionMenu addSubview:b];
    }

    [self bringSubviewToFront:self.profileOptionMenu];

    self.profileOptionMenu.hidden=NO;
    self.profileOptionMenu.alpha=0;
    self.profileOptionMenu.transform=
        CGAffineTransformIdentity;

    [self setNeedsLayout];
    [self layoutIfNeeded];

    [UIView animateWithDuration:.12 animations:^{
        self.profileOptionMenu.alpha=1;
        self.profileOptionMenu.transform=
            CGAffineTransformIdentity;
    }];
}

- (void)hideProfileOptionMenu {
    [UIView animateWithDuration:.10 animations:^{
        self.profileOptionMenu.alpha=0;
    } completion:^(BOOL done) {
        self.profileOptionMenu.hidden=YES;

        if (self.profileButtonsCard.alpha>0.5)
            [self scheduleProfileControlsAutoHide];
    }];
}

- (UIViewController *)profileHostController {
    UIResponder *r=self;

    while (r) {
        if ([r isKindOfClass:UIViewController.class])
            return (UIViewController *)r;
        r=r.nextResponder;
    }

    return nil;
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
        didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {

    NSURL *source=urls.firstObject;
    if (!source) return;

    NSData *data=[NSData dataWithContentsOfURL:source];
    UIImage *image=data.length
        ? [UIImage imageWithData:data] : nil;

    if (!image) {
        [self profileMessage:@"无法读取皮肤图片"];
        return;
    }

    CGFloat w=CGImageGetWidth(image.CGImage);
    CGFloat h=CGImageGetHeight(image.CGImage);

    BOOL valid=
        (w==64 && h==64) ||
        (w==64 && h==32);

    if (!valid) {
        [self profileMessage:@"皮肤必须为 64×64 或 64×32 PNG"];
        return;
    }

    NSURL *documents=[NSFileManager.defaultManager
        URLsForDirectory:NSDocumentDirectory
        inDomains:NSUserDomainMask].firstObject;

    NSURL *dir=[[documents
        URLByAppendingPathComponent:@"PCL-iOS"]
        URLByAppendingPathComponent:@"Skins"];

    [NSFileManager.defaultManager
        createDirectoryAtURL:dir
        withIntermediateDirectories:YES
        attributes:nil error:nil];

    NSDictionary *profile=[self profileForIdentifier:
        self.skinImportProfileIdentifier];

    if (!profile) return;

    NSString *uuid=profile[@"uuid"] ?: NSUUID.UUID.UUIDString;

    NSURL *file=[dir URLByAppendingPathComponent:
        [uuid stringByAppendingString:@".png"]];

    if (![data writeToURL:file atomically:YES]) {
        [self profileMessage:@"皮肤导入失败"];
        return;
    }

    NSMutableDictionary *updated=profile.mutableCopy;
    updated[@"skinURL"]=file.absoluteString;

    [PCLProfileStore
        replaceProfileWithIdentifier:
            self.skinImportProfileIdentifier
        profile:updated
        select:YES];

    self.skinImportProfileIdentifier=nil;

    [self reloadState];
    [self profileMessage:@"离线皮肤已更新"];
}

- (void)importOfflineSkin:(NSDictionary *)profile {
    self.skinImportProfileIdentifier=
        profile[@"identifier"];

    UIDocumentPickerViewController *picker=
        [[UIDocumentPickerViewController alloc]
            initWithDocumentTypes:@[@"public.png"]
            inMode:UIDocumentPickerModeImport];

    picker.delegate=self;

    UIViewController *host=
        [self profileHostController];

    [host presentViewController:picker
        animated:YES completion:nil];
}

- (void)exportCurrentSkin {
    NSString *text=self.skinView.sourceSkinURL;

    if (!text.length) {
        [self profileMessage:@"皮肤尚未加载完成"];
        return;
    }

    NSURL *url=[NSURL URLWithString:text];
    __weak typeof(self) weakSelf=self;

    [[[NSURLSession sharedSession] dataTaskWithURL:url
        completionHandler:^(NSData *data,
                            NSURLResponse *response,
                            NSError *error) {

        UIImage *image=data.length
            ? [UIImage imageWithData:data] : nil;

        if (!image) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf profileMessage:@"皮肤保存失败"];
            });
            return;
        }

        NSDictionary *profile=
            [PCLProfileStore selectedProfile];

        NSString *name=
            profile[@"username"] ?: @"skin";

        NSString *fileName=
            [name stringByAppendingString:@".png"];

        NSURL *file=[NSURL fileURLWithPath:
            [NSTemporaryDirectory()
                stringByAppendingPathComponent:fileName]];

        [data writeToURL:file atomically:YES];

        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *host=
                [weakSelf profileHostController];

            if (!host) return;

            UIDocumentPickerViewController *picker=
                [[UIDocumentPickerViewController alloc]
                    initForExportingURLs:@[file]
                    asCopy:YES];

            [host presentViewController:picker
                animated:YES completion:nil];
        });
    }] resume];
}

- (void)profileOptionPressed:(UIButton *)sender {
    NSDictionary *profile=
        [PCLProfileStore selectedProfile];

    NSString *type=profile[@"type"];
    NSInteger mode=self.profileOptionMode;
    NSInteger tag=sender.tag;

    [self hideProfileOptionMenu];

    if (mode==1 && tag==9501) {
        [self exportCurrentSkin];
        return;
    }

    if (mode==1 && tag==9502) {
        [PCLHeadCache() removeAllObjects];
        [self.skinView loadProfile:profile];
        [self profileMessage:@"正在刷新皮肤"];
        return;
    }

    if (mode==1 && (tag==9500 || tag==9503)) {
        if ([type isEqual:@"microsoft"]) {
            [self openProfileURL:
                @"https://www.minecraft.net/msaprofile/mygames/editprofile"];
        } else if ([type isEqual:@"authlib"]) {
            NSString *root=[self profileAuthWebRoot:profile];
            [self openProfileURL:
                [root stringByAppendingString:@"/user/closet"]];
        } else {
            if (tag==9500)
                [self importOfflineSkin:profile];
            else
                [self profileMessage:@"离线披风等待游戏运行层接入"];
        }
        return;
    }

    if (mode==2 && tag==9500) {
        if ([type isEqual:@"microsoft"]) {
            [self openProfileURL:
                @"https://account.live.com/password/Change"];
        } else if ([type isEqual:@"authlib"]) {
            NSString *root=[self profileAuthWebRoot:profile];
            [self openProfileURL:
                [root stringByAppendingString:@"/user/profile"]];
        }
        return;
    }

    if (mode==2 && tag==9501) {
        if ([type isEqual:@"microsoft"]) {
            [self openProfileURL:
                @"https://www.minecraft.net/msaprofile/mygames/editprofile"];
        } else if ([type isEqual:@"authlib"]) {
            NSString *root=[self profileAuthWebRoot:profile];
            [self openProfileURL:
                [root stringByAppendingString:@"/user/profile"]];
        }
        return;
    }
}

- (void)skinPressed {
    if (!self.profileOptionMenu.hidden &&
        self.profileOptionMode==1) {
        [self hideProfileOptionMenu];
        return;
    }
    [self showProfileOptionMenu:1];
}

- (void)editPressed {
    if (!self.profileOptionMenu.hidden &&
        self.profileOptionMode==2) {
        [self hideProfileOptionMenu];
        return;
    }
    [self showProfileOptionMenu:2];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture
        shouldReceiveTouch:(UITouch *)touch {
    UIView *v=touch.view;

    while (v && v!=self.profileSkinView) {
        if ([v isKindOfClass:UIControl.class])
            return NO;
        v=v.superview;
    }

    return YES;
}

- (void)profileTapped {
    if (!self.profileOptionMenu.hidden) {
        [self hideProfileOptionMenu];
        return;
    }

    CGFloat target =
        self.profileButtonsCard.alpha > 0.5
        ? 0.0
        : 1.0;

    [self cancelProfileControlsTimer];

    [UIView animateWithDuration:.12
        delay:0
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionCurveEaseOut
        animations:^{
        self.profileButtonsCard.alpha=target;
    } completion:^(BOOL finished) {
        if (target>0.5)
            [self scheduleProfileControlsAutoHide];
    }];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width =
        CGRectGetWidth(self.bounds);

    CGFloat height =
        CGRectGetHeight(self.bounds);

    CGRect contentBounds=
        CGRectMake(0,0,width,height);

    CGPoint contentCenter=
        CGPointMake(width*0.5,height*0.5);

    [UIView performWithoutAnimation:^{
        self.transitionContentView.bounds=
            contentBounds;

        self.transitionContentView.center=
            contentCenter;
    }];

    CGFloat scale =
        self.designScale > 0.0
        ? self.designScale
        : 1.0;

    for (PCLCEButton *b in @[self.launchButton,self.instanceButton,self.moreButton]) {
        b.layer.cornerRadius = 3.0 * scale;
        b.layer.borderWidth = 1.0 * scale;
    }

    self.skinView.layer.shadowRadius = 10.0 * scale;
    self.profileButtonsCard.layer.cornerRadius = 5.0 * scale;
    self.profileButtonsCard.layer.shadowRadius = 3.0 * scale;
    self.hintView.layer.cornerRadius = 2.0 * scale;

    CGFloat designWidth =
        300.0 * scale;


    CGFloat ox =
        (width - designWidth) / 2.0;

    CGFloat launchHeight = 54.0 * scale;
    CGFloat smallHeight = 35.0 * scale;

    CGFloat instanceY =
        height - 20.0 * scale - smallHeight;

    CGFloat launchY =
        instanceY - 10.0 * scale - launchHeight;

    CGFloat loginAreaHeight = launchY;
    BOOL hasStoredProfiles=
        [PCLProfileStore profiles].count>0;

    CGFloat wantedLoginHeight =
        ((!self.profileSelectView.hidden && !hasStoredProfiles)
            ? 114.0 : 235.0) * scale;
    CGFloat loginHeight =
        MIN(loginAreaHeight,wantedLoginHeight);
    CGFloat loginY =
        MAX(0.0,(loginAreaHeight-loginHeight)/2.0);

    self.panLogin.frame =
        CGRectMake(ox + 20.0 * scale,
                   loginY,
                   250.0 * scale,
                   loginHeight);

    self.launchButton.frame =
        CGRectMake(ox + 20.0 * scale,
                   launchY,
                   260.0 * scale,
                   launchHeight);

    self.launchContentView.frame =
        self.launchButton.bounds;

    self.launchTitleLabel.font =
        [UIFont systemFontOfSize:13.0 * scale];

    CGFloat launchWidth =
        CGRectGetWidth(self.launchContentView.bounds);

    self.launchTitleLabel.frame =
        CGRectMake(0,
                   7.0 * scale,
                   launchWidth,
                   20.0 * scale);

    self.versionLabel.font =
        [UIFont systemFontOfSize:10.0 * scale];

    self.versionLabel.frame =
        CGRectMake(0,
                   30.0 * scale,
                   launchWidth,
                   14.0 * scale);

    self.instanceButton.titleLabel.font =
        [UIFont systemFontOfSize:
            13.0 * scale];

    self.moreButton.titleLabel.font =
        [UIFont systemFontOfSize:
            13.0 * scale];

    if (self.moreButton.hidden) {
        self.instanceButton.frame =
            CGRectMake(ox + 20.0 * scale,
                       instanceY,
                       260.0 * scale,
                       smallHeight);

    } else {
        CGFloat moreWidth =
            92.0 * scale;

        self.moreButton.frame =
            CGRectMake(ox + 300.0 * scale
                           - 20.0 * scale
                           - moreWidth,
                       instanceY,
                       moreWidth,
                       smallHeight);

        CGFloat instanceRight =
            CGRectGetMinX(self.moreButton.frame)
            - 10.0 * scale;

        self.instanceButton.frame =
            CGRectMake(ox + 20.0 * scale,
                       instanceY,
                       instanceRight
                           - (ox + 20.0 * scale),
                       smallHeight);
    }

    self.profileSelectView.frame =
        self.panLogin.bounds;

    self.loginPanel.designScale=scale;
    self.loginPanel.frame=self.panLogin.bounds;

    CGFloat loginWidth =
        CGRectGetWidth(self.panLogin.bounds);

    self.hintView.frame =
        CGRectMake(0,
                   10.0 * scale,
                   loginWidth,
                   34.0 * scale);

    UIView *hintBar =
        [self.hintView viewWithTag:9201];

    hintBar.frame =
        CGRectMake(0,
                   0,
                   3.0 * scale,
                   CGRectGetHeight(
                       self.hintView.bounds));

    self.hintLabel.font =
        [UIFont systemFontOfSize:
            13.0 * scale];

    self.hintLabel.frame =
        CGRectMake(15.0 * scale,
                   9.0 * scale,
                   loginWidth
                       - 27.0 * scale,
                   16.0 * scale);

    UIView *newCard =
        [self.profileSelectView
            viewWithTag:9202];

    newCard.layer.cornerRadius = 5.0 * scale;
    newCard.layer.shadowRadius = 3.0 * scale;

    CGFloat cardWidth =
        44.0 * scale;

    CGFloat cardHeight =
        30.0 * scale;

    newCard.frame =
        CGRectMake((loginWidth - cardWidth) / 2.0,
                   CGRectGetHeight(
                       self.profileSelectView.bounds)
                       - 20.0 * scale
                       - cardHeight,
                   cardWidth,
                   cardHeight);

    CGFloat listTop=50.0*scale;
    CGFloat listBottom=CGRectGetMinY(newCard.frame)-8.0*scale;

    self.profileScrollView.frame=
        CGRectMake(0,listTop,loginWidth,
                   MAX(0,listBottom-listTop));

    CGFloat rowY=0;
    for (UIButton *row in self.profileRows) {
        row.frame=CGRectMake(8*scale,rowY,
            loginWidth-18*scale,42*scale);

        PCLSkinHeadView *icon=
            (PCLSkinHeadView *)[row viewWithTag:9300];
        icon.frame=CGRectMake(4*scale,5*scale,
                              32*scale,32*scale);


        UILabel *title=[row viewWithTag:9301];
        UILabel *info=[row viewWithTag:9302];

        title.font=[UIFont systemFontOfSize:14*scale];
        info.font=[UIFont systemFontOfSize:11*scale];

        title.frame=CGRectMake(44*scale,4*scale,
            CGRectGetWidth(row.bounds)-112*scale,19*scale);
        info.frame=CGRectMake(44*scale,23*scale,
            CGRectGetWidth(row.bounds)-112*scale,15*scale);

        UIView *actions=[row viewWithTag:9303];
        actions.frame=CGRectMake(
            CGRectGetWidth(row.bounds)-62*scale,
            0,62*scale,42*scale);

        UIButton *aux=(UIButton *)
            [actions viewWithTag:9310];
        UIButton *del=(UIButton *)
            [actions viewWithTag:9311];

        aux.frame=CGRectMake(
            0,0,31*scale,42*scale);

        del.frame=CGRectMake(
            31*scale,0,31*scale,42*scale);

        UIImageSymbolConfiguration *actionCfg=
            [UIImageSymbolConfiguration
                configurationWithPointSize:12.5*scale
                                    weight:UIImageSymbolWeightRegular];

        NSDictionary *profile=
            [self profileForIdentifier:
                row.accessibilityIdentifier];

        NSString *auxIcon=
            [profile[@"type"] isEqual:@"offline"]
                ? @"pencil" : @"doc.on.doc";

        [aux setImage:
            [[UIImage systemImageNamed:auxIcon]
                imageByApplyingSymbolConfiguration:actionCfg]
            forState:UIControlStateNormal];

        [del setImage:
            [[UIImage systemImageNamed:@"trash"]
                imageByApplyingSymbolConfiguration:actionCfg]
            forState:UIControlStateNormal];


        rowY+=44*scale;
    }

    self.profileScrollView.contentSize=
        CGSizeMake(loginWidth,rowY);


    self.createProfileButton.frame =
        CGRectMake(10.0 * scale,
                   3.0 * scale,
                   24.0 * scale,
                   24.0 * scale);

    UIImageSymbolConfiguration *newIcon =
        [UIImageSymbolConfiguration configurationWithPointSize:14.0*scale
                                                        weight:UIImageSymbolWeightRegular];

    [self.createProfileButton
        setImage:[[UIImage systemImageNamed:@"person.badge.plus"]
        imageByApplyingSymbolConfiguration:newIcon]
        forState:UIControlStateNormal];

    self.profileSkinView.frame =
        self.panLogin.bounds;

    CGFloat profileWidth =
        CGRectGetWidth(
            self.profileSkinView.bounds);

    CGFloat skinSize =
        64.0 * scale;

    self.skinView.frame =
        CGRectMake((profileWidth - skinSize) / 2.0,
                   60.0 * scale,
                   skinSize,
                   skinSize);

    self.usernameLabel.font =
        [UIFont systemFontOfSize:
            16.0 * scale];

    self.usernameLabel.frame =
        CGRectMake(8.0 * scale,
                   124.0 * scale,
                   profileWidth
                       - 16.0 * scale,
                   21.0 * scale);

    self.typeLabel.font =
        [UIFont systemFontOfSize:
            12.0 * scale];

    self.typeLabel.frame =
        CGRectMake(8.0 * scale,
                   149.0 * scale,
                   profileWidth
                       - 16.0 * scale,
                   18.0 * scale);

    CGFloat buttonsWidth =
        (self.editButton.hidden ? 76.0 : 109.0) * scale;

    CGFloat buttonsHeight =
        30.0 * scale;

    self.profileButtonsCard.frame =
        CGRectMake((profileWidth
                    - buttonsWidth) / 2.0,
                   175.0 * scale,
                   buttonsWidth,
                   buttonsHeight);
    CGFloat menuFont=13.0*scale;
    CGFloat menuW=96.0*scale;
    CGFloat rowH=28.0*scale;

    for (UIButton *b in self.profileOptionMenu.subviews) {
        b.titleLabel.font=
            [UIFont systemFontOfSize:menuFont];

        CGSize size=[b.currentTitle sizeWithAttributes:@{
            NSFontAttributeName:b.titleLabel.font
        }];

        menuW=MAX(menuW,size.width+24.0*scale);
    }

    menuW=MIN(menuW,150.0*scale);

    NSInteger rows=self.profileOptionMenu.subviews.count;
    CGFloat menuH=8.0*scale+rows*rowH;

    UIButton *anchor=
        self.profileOptionAnchor ?: self.skinButton;

    CGRect anchorRect=
        [anchor convertRect:anchor.bounds toView:self];

    CGFloat menuX=
        CGRectGetMinX(anchorRect)+10.0*scale;
    CGFloat menuY=
        CGRectGetMaxY(anchorRect)+6.0*scale;

    menuX=MAX(6.0*scale,menuX);
    menuX=MIN(menuX,width-menuW-6.0*scale);

    self.profileOptionMenu.frame=
        CGRectMake(menuX,menuY,menuW,menuH);

    for (NSInteger i=0;i<rows;i++) {
        UIButton *b=
            (UIButton *)self.profileOptionMenu.subviews[i];

        b.frame=CGRectMake(
            4.0*scale,
            (4.0+i*28.0)*scale,
            menuW-8.0*scale,
            rowH);

        b.layer.cornerRadius=3.0*scale;
    }




    self.skinButton.frame =
        CGRectMake(10.0 * scale,
                   3.0 * scale,
                   24.0 * scale,
                   24.0 * scale);

    self.editButton.frame =
        CGRectMake(43.0 * scale,
                   3.0 * scale,
                   24.0 * scale,
                   24.0 * scale);

    CGFloat switchX=
        self.editButton.hidden ? 43.0 : 76.0;

    self.switchButton.frame =
        CGRectMake(switchX * scale,
                   3.0 * scale,
                   24.0 * scale,
                   24.0 * scale);

    UIImageSymbolConfiguration *icons =
        [UIImageSymbolConfiguration configurationWithPointSize:13.0*scale
                                                        weight:UIImageSymbolWeightRegular];

    [self.skinButton setImage:[[UIImage systemImageNamed:@"tshirt"]
        imageByApplyingSymbolConfiguration:icons] forState:UIControlStateNormal];

    [self.editButton setImage:[[UIImage systemImageNamed:@"pencil"]
        imageByApplyingSymbolConfiguration:icons] forState:UIControlStateNormal];

    [self.switchButton setImage:[[UIImage systemImageNamed:@"arrow.left.arrow.right"]
        imageByApplyingSymbolConfiguration:icons] forState:UIControlStateNormal];
}


- (void)prepareCEEnterAnimation {
    CALayer *layer=self.transitionContentView.layer;

    [layer removeAllAnimations];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    layer.transform=
        CATransform3DMakeScale(.96,.96,1.0);
    layer.opacity=0.0;

    [CATransaction commit];
}

- (void)playCEEnterAnimation {
    [PCLCEPageAnimator
        showSimpleLeftPage:self.transitionContentView];
}

- (void)playCEExitAnimation {
    [self dismissTransientUI];
    [PCLCEPageAnimator
        hideSimpleLeftPage:self.transitionContentView];
}


@end
