#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PCLCurseForgeFile : NSObject
@property (nonatomic, assign) NSInteger fileId;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *downloadUrl;
@property (nonatomic, assign) NSInteger fileSize;
@property (nonatomic, strong) NSString *gameVersion;
@property (nonatomic, strong) NSString *fileType;
@end

@interface PCLCurseForgeMod : NSObject
@property (nonatomic, assign) NSInteger modId;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *summary;
@property (nonatomic, strong) NSString *iconUrl;
@property (nonatomic, strong) NSString *websiteUrl;
@property (nonatomic, assign) NSInteger downloadCount;
@property (nonatomic, strong) NSArray<PCLCurseForgeFile *> *latestFiles;
@end

@interface PCLCurseForgeAPI : NSObject

@property (nonatomic, assign) NSInteger gameId;

+ (instancetype)sharedAPI;

// Search mods (no API key required for public endpoints)
- (void)searchModsWithQuery:(NSString *)query
                gameVersion:(nullable NSString *)gameVersion
                   category:(nullable NSString *)category
                       page:(NSInteger)page
                   pageSize:(NSInteger)pageSize
                 completion:(void(^)(NSArray<PCLCurseForgeMod *> *mods, NSError *error))completion;

// Get mod details
- (void)getModWithId:(NSInteger)modId
          completion:(void(^)(PCLCurseForgeMod *mod, NSError *error))completion;

// Get mod files
- (void)getFilesForMod:(NSInteger)modId
            completion:(void(^)(NSArray<PCLCurseForgeFile *> *files, NSError *error))completion;

// Download file
- (void)downloadFile:(PCLCurseForgeFile *)file
              toPath:(NSString *)path
            progress:(void(^)(double progress))progress
          completion:(void(^)(BOOL success, NSError *error))completion;

@end

NS_ASSUME_NONNULL_END
