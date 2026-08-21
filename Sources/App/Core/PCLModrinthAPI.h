#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Enums

typedef NS_ENUM(NSInteger, PCLModrinthProjectType) {
    PCLModrinthProjectTypeMod = 0,
    PCLModrinthProjectTypeModpack,
    PCLModrinthProjectTypeResourcePack,
    PCLModrinthProjectTypeShader,
    PCLModrinthProjectTypeDataPack,
    PCLModrinthProjectTypePlugin
};

typedef NS_ENUM(NSInteger, PCLModrinthModLoader) {
    PCLModrinthModLoaderForge = 0,
    PCLModrinthModLoaderFabric,
    PCLModrinthModLoaderNeoForge,
    PCLModrinthModLoaderQuilt,
    PCLModrinthModLoaderLiteLoader,
    PCLModrinthModLoaderRift,
    PCLModrinthModLoaderCauldron,
    PCLModrinthModLoaderDatapack
};

typedef NS_ENUM(NSInteger, PCLModrinthSortType) {
    PCLModrinthSortTypeRelevance = 0,
    PCLModrinthSortTypeDownloads,
    PCLModrinthSortTypeNewest,
    PCLModrinthSortTypeUpdated,
    PCLModrinthSortTypeFollowers
};

typedef NS_ENUM(NSInteger, PCLModrinthDependencyType) {
    PCLModrinthDependencyTypeRequired = 0,
    PCLModrinthDependencyTypeOptional,
    PCLModrinthDependencyTypeIncompatible,
    PCLModrinthDependencyTypeEmbedded
};

#pragma mark - Models

@interface PCLModrinthProject : NSObject
@property (nonatomic, strong) NSString *projectID;
@property (nonatomic, strong) NSString *slug;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *descriptionText;
@property (nonatomic, strong) NSString *iconUrl;
@property (nonatomic, strong) NSString *author;
@property (nonatomic, assign) NSInteger downloads;
@property (nonatomic, assign) NSInteger followers;
@property (nonatomic, strong) NSString *projectType;
@property (nonatomic, strong) NSString *updatedAt;
@property (nonatomic, strong) NSString *createdAt;
@property (nonatomic, strong) NSArray<NSString *> *categories;
@property (nonatomic, strong) NSArray<NSString *> *gameVersions;
@property (nonatomic, strong) NSArray<NSString *> *loaders;
@property (nonatomic, strong) NSString *license;
@property (nonatomic, strong) NSString *body; // 完整描述 (Markdown)
@end

@interface PCLModrinthFileInfo : NSObject
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *url;
@property (nonatomic, assign) NSInteger size;
@property (nonatomic, assign) BOOL isPrimary;
@property (nonatomic, strong) NSString *sha1;
@property (nonatomic, strong) NSString *sha512;
@property (nonatomic, assign) NSInteger downloads;
@end

@interface PCLModrinthDependency : NSObject
@property (nonatomic, strong) NSString *projectID;
@property (nonatomic, strong) NSString *versionID;
@property (nonatomic, strong) NSString *dependencyType; // required, optional, incompatible, embedded
@property (nonatomic, strong) NSString *fileName;
@end

@interface PCLModrinthVersion : NSObject
@property (nonatomic, strong) NSString *versionID;
@property (nonatomic, strong) NSString *versionNumber;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSArray<NSString *> *gameVersions;
@property (nonatomic, strong) NSArray<NSString *> *loaders;
@property (nonatomic, strong) NSArray<NSDictionary *> *files;
@property (nonatomic, strong) NSArray<PCLModrinthFileInfo *> *fileInfos;
@property (nonatomic, strong) NSArray<PCLModrinthDependency *> *dependencies;
@property (nonatomic, assign) NSInteger downloads;
@property (nonatomic, strong) NSString *datePublished;
@property (nonatomic, strong) NSString *versionType; // release, beta, alpha
@property (nonatomic, assign) BOOL featured;
@end

@interface PCLModrinthSearchResult : NSObject
@property (nonatomic, strong) NSArray<PCLModrinthProject *> *hits;
@property (nonatomic, assign) NSInteger totalHits;
@property (nonatomic, assign) NSInteger offset;
@property (nonatomic, assign) NSInteger limit;
@end

@interface PCLModrinthCategory : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *icon;
@property (nonatomic, strong) NSString *projectType;
@end

#pragma mark - API Interface

@interface PCLModrinthAPI : NSObject

+ (instancetype)sharedAPI;

#pragma mark - Search

// 完整搜索 (PCL-CE风格)
- (void)searchProjects:(NSString *)query
            projectType:(PCLModrinthProjectType)projectType
                 loader:(PCLModrinthModLoader)loader
            gameVersion:(NSString *)gameVersion
               category:(nullable NSString *)category
               sortType:(PCLModrinthSortType)sortType
                  limit:(NSInteger)limit
                 offset:(NSInteger)offset
             completion:(void(^)(PCLModrinthSearchResult *result, NSError *error))completion;

// 搜索 (filters字典方式)
- (void)searchProjects:(NSString *)query
               filters:(NSDictionary *)filters
                 limit:(NSInteger)limit
                offset:(NSInteger)offset
            completion:(void(^)(PCLModrinthSearchResult *result, NSError *error))completion;

#pragma mark - Project

- (void)getProject:(NSString *)slugOrID
        completion:(void(^)(PCLModrinthProject *project, NSError *error))completion;

- (void)getProjects:(NSArray<NSString *> *)projectIDs
         completion:(void(^)(NSArray<PCLModrinthProject *> *projects, NSError *error))completion;

#pragma mark - Versions

- (void)versionsForProject:(NSString *)projectID
                    facets:(NSDictionary *)facets
                completion:(void(^)(NSArray<PCLModrinthVersion *> *versions, NSError *error))completion;

- (void)getVersion:(NSString *)versionID
        completion:(void(^)(PCLModrinthVersion *version, NSError *error))completion;

- (void)getVersions:(NSArray<NSString *> *)versionIDs
         completion:(void(^)(NSArray<PCLModrinthVersion *> *versions, NSError *error))completion;

- (void)getLatestVersionForProject:(NSString *)slugOrID
                       gameVersion:(NSString *)gameVersion
                            loader:(NSString *)loader
                        completion:(void(^)(PCLModrinthVersion *version, NSError *error))completion;

#pragma mark - Dependencies

- (void)dependenciesForProject:(NSString *)projectID
                    completion:(void(^)(NSArray<PCLModrinthDependency *> *dependencies, NSError *error))completion;

#pragma mark - Categories & Tags

- (void)loadCategories:(void(^)(NSArray<PCLModrinthCategory *> *categories, NSError *error))completion;

- (void)loadGameVersions:(void(^)(NSArray<NSString *> *versions, NSError *error))completion;

#pragma mark - Download

- (void)downloadFile:(PCLModrinthFileInfo *)file
              toPath:(NSString *)path
            progress:(void(^ _Nullable)(double progress))progress
          completion:(void(^)(BOOL success, NSError *error))completion;

#pragma mark - Helpers

+ (NSString *)sortTypeString:(PCLModrinthSortType)sortType;
+ (NSString *)projectTypeString:(PCLModrinthProjectType)type;
+ (NSString *)loaderString:(PCLModrinthModLoader)loader;

@end

NS_ASSUME_NONNULL_END
