#import <Foundation/Foundation.h>

typedef void(^PCLJITTCompletion)(BOOL success, NSError *error);

@interface PCLJITManager : NSObject

+ (BOOL)isJTTAvailable;
+ (void)enableJITTWithCompletion:(PCLJITTCompletion)completion;
+ (void)checkJTTAvailability:(void(^)(BOOL available))completion;

@end
