#import <Foundation/Foundation.h>

@interface PCLVersionInfo : NSObject
@property (nonatomic, copy) NSString *versionId;
@property (nonatomic, copy) NSString *versionType;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *releaseTime;
@property (nonatomic, copy) NSString *jsonPath;
@property (nonatomic, assign) BOOL isInstalled;
@property (nonatomic, copy) NSString *mainClass;
@property (nonatomic, copy) NSString *minecraftArguments;
@property (nonatomic, copy) NSString *javaVersion;
@property (nonatomic, copy) NSString *assetIndex;
@property (nonatomic, copy) NSString *assets;
@property (nonatomic, copy) NSArray<NSDictionary *> *libraries;
@property (nonatomic, copy) NSString *inheritsFrom;
@property (nonatomic, copy) NSString *jar;
@end

@interface PCLVersionManager : NSObject

+ (instancetype)sharedManager;

- (NSString *)gamesDirectory;
- (NSString *)versionsDirectory;
- (NSString *)librariesDirectory;
- (NSString *)assetsDirectory;
- (NSString *)javaDirectory;
- (NSString *)instancesDirectory;
- (NSString *)instanceDirectoryWithName:(NSString *)name;

- (NSArray<PCLVersionInfo *> *)localVersions;
- (NSArray<NSDictionary *> *)remoteVersionManifest;
- (void)fetchRemoteManifest:(void (^)(NSArray<NSDictionary *> *versions, NSError *error))completion;

- (PCLVersionInfo *)versionInfoForId:(NSString *)versionId;
- (PCLVersionInfo *)parseVersionJson:(NSDictionary *)dict;
- (BOOL)isVersionInstalled:(NSString *)versionId;
- (BOOL)createInstanceWithName:(NSString *)name baseVersion:(NSString *)versionId;
- (NSArray<NSDictionary *> *)localInstances;
- (NSDictionary *)instanceConfig:(NSString *)name;
- (BOOL)saveInstanceConfig:(NSString *)name config:(NSDictionary *)config;

- (void)downloadManifest:(void (^)(BOOL success, NSError *error))completion;
- (void)loadVersionJson:(NSString *)versionId completion:(void (^)(PCLVersionInfo *info, NSError *error))completion;

@end
