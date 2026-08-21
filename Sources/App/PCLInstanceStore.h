#import <Foundation/Foundation.h>

@interface PCLInstance : NSObject
@property(nonatomic,copy) NSString *name;
@property(nonatomic,copy) NSString *path;
@property(nonatomic) BOOL error;
@end

@interface PCLInstanceStore : NSObject

+ (NSString *)minecraftRoot;
+ (NSArray<PCLInstance *> *)scanInstances;

+ (PCLInstance *)selectedInstance:
    (NSArray<PCLInstance *> *)instances;

+ (void)selectInstance:(PCLInstance *)instance;

@end
