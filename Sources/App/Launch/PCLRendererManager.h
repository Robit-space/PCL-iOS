#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PCLRenderRenderer) {
    PCLRenderRendererNone = -1,
    PCLRenderRendererGL4ES = 0,
    PCLRenderRendererMetalANGLE,
    PCLRenderRendererMobileGlues,
    PCLRenderRendererZinkVK
};

@interface PCLRendererManager : NSObject

+ (NSArray<NSDictionary *> *)availableRenderers;
+ (PCLRenderRenderer)selectedRenderer;
+ (void)setSelectedRenderer:(PCLRenderRenderer)renderer;
+ (NSString *)rendererLibPath;
+ (NSDictionary *)rendererEnvVars;
+ (BOOL)isRendererAvailable:(PCLRenderRenderer)renderer;
+ (NSString *)nameForRenderer:(PCLRenderRenderer)renderer;
+ (NSString *)dylibNameForRenderer:(PCLRenderRenderer)renderer;

@end
