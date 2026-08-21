#import <Foundation/Foundation.h>
#import "PCLRendererManager.h"

@interface PCLInstance : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *versionId;
@property (nonatomic, copy) NSString *gameDir;
@property (nonatomic, copy) NSString *javaArgs;
@property (nonatomic, assign) NSInteger resolutionWidth;
@property (nonatomic, assign) NSInteger resolutionHeight;
@property (nonatomic, copy) NSString *javaVersion;
@property (nonatomic, copy) NSString *created;
@property (nonatomic, assign) NSInteger memoryMaxMB;
@property (nonatomic, assign) BOOL autoSelectJava;
@property (nonatomic, copy) NSString *gameArguments;

// 渲染器选择 (参考PCL2-CE)
@property (nonatomic, assign) PCLRenderRenderer renderer;

// 版本隔离 (参考PCL2-CE)
@property (nonatomic, assign) BOOL versionIsolation;

// 高级设置
@property (nonatomic, copy) NSString *javaPathOverride;
@property (nonatomic, copy) NSString *serverAddress;
@property (nonatomic, assign) BOOL autoJoinServer;
@property (nonatomic, assign) NSInteger memoryMinMB;

- (NSDictionary *)toDictionary;
+ (instancetype)instanceFromDictionary:(NSDictionary *)dict;

@end

extern NSString *const PCLCurrentInstanceNameKey;

@interface PCLInstanceManager : NSObject

+ (instancetype)sharedManager;

- (NSArray<PCLInstance *> *)allInstances;
- (BOOL)createInstanceWithName:(NSString *)name versionId:(NSString *)versionId;
- (BOOL)deleteInstanceWithName:(NSString *)name;
- (PCLInstance *)instanceWithName:(NSString *)name;
- (void)selectInstance:(PCLInstance *)instance;
- (PCLInstance *)currentInstance;
- (BOOL)saveInstance:(PCLInstance *)instance;

// 版本隔离: 根据实例配置返回游戏目录 (参考PCL2-CE)
- (NSString *)gameDirectoryForInstance:(PCLInstance *)instance;
- (NSString *)sharedGameDirectory;
- (NSString *)modsDirectoryForInstance:(PCLInstance *)instance;
- (NSString *)configDirectoryForInstance:(PCLInstance *)instance;
- (NSString *)savesDirectoryForInstance:(PCLInstance *)instance;
- (NSString *)screenshotsDirectoryForInstance:(PCLInstance *)instance;
- (NSString *)logsDirectoryForInstance:(PCLInstance *)instance;
- (NSString *)resourcePacksDirectoryForInstance:(PCLInstance *)instance;
- (NSString *)shaderPacksDirectoryForInstance:(PCLInstance *)instance;
- (NSString *)nativesDirectoryForInstance:(PCLInstance *)instance;

@end
