#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PCLLogLevel) {
    PCLLogLevelDebug = 0,
    PCLLogLevelInfo,
    PCLLogLevelWarning,
    PCLLogLevelError
};

@interface PCLLogEntry : NSObject
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic) PCLLogLevel level;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, copy) NSString *levelString;
@end

extern NSString *const PCLLogDidAppendNotification;

@interface PCLLogger : NSObject

+ (instancetype)sharedLogger;

- (void)log:(NSString *)message level:(PCLLogLevel)level;
- (void)debug:(NSString *)message;
- (void)info:(NSString *)message;
- (void)warning:(NSString *)message;
- (void)error:(NSString *)message;

- (NSArray<PCLLogEntry *> *)recentLogs:(NSInteger)count;
- (NSString *)allLogsString;
- (NSString *)exportLogsToFile;

@end
