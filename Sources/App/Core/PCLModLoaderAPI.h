#import <Foundation/Foundation.h>

@interface PCLFabricVersion : NSObject
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *maven;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, assign) BOOL stable;
@end

@interface PCLForgeVersion : NSObject
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *mcVersion;
@property (nonatomic, copy) NSString *modified;
@property (nonatomic, copy) NSString *branch;
@end

@interface PCLNeoForgeVersion : NSObject
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *mcVersion;
@end

@interface PCLModLoaderAPI : NSObject

+ (instancetype)sharedAPI;

- (void)fetchFabricVersions:(NSString *)mcVersion
                 completion:(void (^)(NSArray<PCLFabricVersion *> *versions, NSError *error))completion;

- (void)fetchForgeVersions:(NSString *)mcVersion
                completion:(void (^)(NSArray<PCLForgeVersion *> *versions, NSError *error))completion;

- (void)fetchNeoForgeVersions:(NSString *)mcVersion
                   completion:(void (^)(NSArray<PCLNeoForgeVersion *> *versions, NSError *error))completion;

- (void)fetchOptiFineVersions:(void (^)(NSArray<NSDictionary *> *versions, NSError *error))completion;

@end
