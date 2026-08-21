#import "PCLLogger.h"

NSString *const PCLLogDidAppendNotification = @"PCLLogDidAppendNotification";

static const NSInteger kPCLLogMaxEntries = 1000;

@implementation PCLLogEntry
@end

@interface PCLLogger ()
@property (nonatomic, strong) NSMutableArray<PCLLogEntry *> *logEntries;
@property (nonatomic, strong) dispatch_queue_t logQueue;
@end

@implementation PCLLogger

+ (instancetype)sharedLogger {
    static PCLLogger *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PCLLogger alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _logEntries = [NSMutableArray arrayWithCapacity:kPCLLogMaxEntries];
        _logQueue = dispatch_queue_create("com.pcl.logger", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)log:(NSString *)message level:(PCLLogLevel)level {
    if (!message || message.length == 0) return;

    dispatch_async(self.logQueue, ^{
        PCLLogEntry *entry = [[PCLLogEntry alloc] init];
        entry.timestamp = [NSDate date];
        entry.level = level;
        entry.message = message;
        entry.levelString = [self levelStringForLevel:level];

        [self.logEntries addObject:entry];

        if (self.logEntries.count > kPCLLogMaxEntries) {
            [self.logEntries removeObjectsInRange:NSMakeRange(0, self.logEntries.count - kPCLLogMaxEntries)];
        }

        NSLog(@"[%@] %@", entry.levelString, message);

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:PCLLogDidAppendNotification object:entry];
        });
    });
}

- (void)debug:(NSString *)message {
    [self log:message level:PCLLogLevelDebug];
}

- (void)info:(NSString *)message {
    [self log:message level:PCLLogLevelInfo];
}

- (void)warning:(NSString *)message {
    [self log:message level:PCLLogLevelWarning];
}

- (void)error:(NSString *)message {
    [self log:message level:PCLLogLevelError];
}

- (NSArray<PCLLogEntry *> *)recentLogs:(NSInteger)count {
    if (count <= 0) return @[];
    __block NSArray<PCLLogEntry *> *result;
    dispatch_sync(self.logQueue, ^{
        NSInteger actualCount = MIN(count, (NSInteger)self.logEntries.count);
        if (actualCount == 0) {
            result = @[];
            return;
        }
        NSRange range = NSMakeRange(self.logEntries.count - actualCount, actualCount);
        result = [self.logEntries subarrayWithRange:range];
    });
    return result;
}

- (NSString *)allLogsString {
    __block NSString *result;
    dispatch_sync(self.logQueue, ^{
        result = [self formatLogs:self.logEntries];
    });
    return result;
}

- (NSString *)exportLogsToFile {
    NSString *logString = [self allLogsString];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMdd_HHmmss";
    NSString *fileName = [NSString stringWithFormat:@"PCL_iOS_Log_%@.txt", [formatter stringFromDate:[NSDate date]]];
    NSString *docsDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *filePath = [docsDir stringByAppendingPathComponent:fileName];
    NSError *error = nil;
    [logString writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"[PCLLogger] Failed to export logs: %@", error.localizedDescription);
        return nil;
    }
    return filePath;
}

#pragma mark - Private

- (NSString *)levelStringForLevel:(PCLLogLevel)level {
    switch (level) {
        case PCLLogLevelDebug:   return @"DEBUG";
        case PCLLogLevelInfo:    return @"INFO";
        case PCLLogLevelWarning: return @"WARN";
        case PCLLogLevelError:   return @"ERROR";
    }
    return @"UNKNOWN";
}

- (NSString *)formatLogs:(NSArray<PCLLogEntry *> *)entries {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    NSMutableString *result = [NSMutableString string];
    for (PCLLogEntry *entry in entries) {
        NSString *timestamp = [formatter stringFromDate:entry.timestamp];
        [result appendFormat:@"[%@] [%@] %@\n", timestamp, entry.levelString, entry.message];
    }
    return result;
}

@end
