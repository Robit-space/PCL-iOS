#import "PCLModrinthAPI.h"

@implementation PCLModrinthProject
@end

@implementation PCLModrinthFileInfo
@end

@implementation PCLModrinthDependency
@end

@implementation PCLModrinthVersion
@end

@implementation PCLModrinthSearchResult
@end

@implementation PCLModrinthCategory
@end

@interface PCLModrinthAPI ()
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) dispatch_queue_t callbackQueue;
@end

@implementation PCLModrinthAPI

+ (instancetype)sharedAPI {
    static PCLModrinthAPI *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PCLModrinthAPI alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _callbackQueue = dispatch_get_main_queue();
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 30;
        config.HTTPMaximumConnectionsPerHost = 8;
        _session = [NSURLSession sessionWithConfiguration:config];
    }
    return self;
}

#pragma mark - Helpers

+ (NSString *)sortTypeString:(PCLModrinthSortType)sortType {
    switch (sortType) {
        case PCLModrinthSortTypeRelevance: return @"relevance";
        case PCLModrinthSortTypeDownloads: return @"downloads";
        case PCLModrinthSortTypeNewest: return @"newest";
        case PCLModrinthSortTypeUpdated: return @"updated";
        case PCLModrinthSortTypeFollowers: return @"follows";
    }
}

+ (NSString *)projectTypeString:(PCLModrinthProjectType)type {
    switch (type) {
        case PCLModrinthProjectTypeMod: return @"mod";
        case PCLModrinthProjectTypeModpack: return @"modpack";
        case PCLModrinthProjectTypeResourcePack: return @"resourcepack";
        case PCLModrinthProjectTypeShader: return @"shader";
        case PCLModrinthProjectTypeDataPack: return @"datapack";
        case PCLModrinthProjectTypePlugin: return @"plugin";
    }
}

+ (NSString *)loaderString:(PCLModrinthModLoader)loader {
    switch (loader) {
        case PCLModrinthModLoaderForge: return @"forge";
        case PCLModrinthModLoaderFabric: return @"fabric";
        case PCLModrinthModLoaderNeoForge: return @"neoforge";
        case PCLModrinthModLoaderQuilt: return @"quilt";
        case PCLModrinthModLoaderLiteLoader: return @"liteloader";
        case PCLModrinthModLoaderRift: return @"rift";
        case PCLModrinthModLoaderCauldron: return @"cauldron";
        case PCLModrinthModLoaderDatapack: return @"datapack";
    }
}

#pragma mark - Search

- (void)searchProjects:(NSString *)query
            projectType:(PCLModrinthProjectType)projectType
                 loader:(PCLModrinthModLoader)loader
            gameVersion:(NSString *)gameVersion
               category:(NSString *)category
               sortType:(PCLModrinthSortType)sortType
                  limit:(NSInteger)limit
                 offset:(NSInteger)offset
             completion:(void(^)(PCLModrinthSearchResult *result, NSError *error))completion {
    
    NSMutableArray *facetsArray = [NSMutableArray array];
    
    // Project type
    NSString *typeStr = [PCLModrinthAPI projectTypeString:projectType];
    [facetsArray addObject:[NSString stringWithFormat:@"[\"project_type:%@\"]", typeStr]];
    
    // Game version
    if (gameVersion) {
        [facetsArray addObject:[NSString stringWithFormat:@"[\"versions:%@\"]", gameVersion]];
    }
    
    // Loader
    NSString *loaderStr = [PCLModrinthAPI loaderString:loader];
    [facetsArray addObject:[NSString stringWithFormat:@"[\"categories:%@\"]", loaderStr]];
    
    // Category
    if (category) {
        [facetsArray addObject:[NSString stringWithFormat:@"[\"categories:%@\"]", category]];
    }
    
    NSString *facets = [NSString stringWithFormat:@"[%@]", [facetsArray componentsJoinedByString:@","]];
    NSString *sortStr = [PCLModrinthAPI sortTypeString:sortType];
    
    NSString *encodedQuery = [query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:
                          @"https://api.modrinth.com/v2/search?query=%@&facets=%@&sort=%@&limit=%ld&offset=%ld",
                          encodedQuery ?: @"", facets, sortStr, (long)limit, (long)offset];
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [req setValue:@"PCL-iOS/1.0" forHTTPHeaderField:@"User-Agent"];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(self.callbackQueue, ^{ completion(nil, error); });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        PCLModrinthSearchResult *result = [self parseSearchResult:json];
        dispatch_async(self.callbackQueue, ^{ completion(result, nil); });
    }];
    [task resume];
}

- (void)searchProjects:(NSString *)query
               filters:(NSDictionary *)filters
                 limit:(NSInteger)limit
                offset:(NSInteger)offset
            completion:(void(^)(PCLModrinthSearchResult *result, NSError *error))completion {
    
    NSMutableArray *facetsArray = [NSMutableArray array];
    
    NSString *projectType = filters[@"projectType"];
    if (projectType) {
        [facetsArray addObject:[NSString stringWithFormat:@"[\"project_type:%@\"]", projectType]];
    }
    
    NSString *gameVersion = filters[@"gameVersion"];
    if (gameVersion) {
        [facetsArray addObject:[NSString stringWithFormat:@"[\"versions:%@\"]", gameVersion]];
    }
    
    NSString *loader = filters[@"loader"];
    if (loader) {
        [facetsArray addObject:[NSString stringWithFormat:@"[\"categories:%@\"]", loader]];
    }
    
    NSString *category = filters[@"category"];
    if (category) {
        [facetsArray addObject:[NSString stringWithFormat:@"[\"categories:%@\"]", category]];
    }
    
    NSString *facets = [NSString stringWithFormat:@"[%@]", [facetsArray componentsJoinedByString:@","]];
    NSString *sortStr = filters[@"sortType"] ?: @"relevance";
    
    NSString *encodedQuery = [query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:
                          @"https://api.modrinth.com/v2/search?query=%@&facets=%@&sort=%@&limit=%ld&offset=%ld",
                          encodedQuery ?: @"", facets, sortStr, (long)limit, (long)offset];
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [req setValue:@"PCL-iOS/1.0" forHTTPHeaderField:@"User-Agent"];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(self.callbackQueue, ^{ completion(nil, error); });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        PCLModrinthSearchResult *result = [self parseSearchResult:json];
        dispatch_async(self.callbackQueue, ^{ completion(result, nil); });
    }];
    [task resume];
}

#pragma mark - Parse Helpers

- (PCLModrinthSearchResult *)parseSearchResult:(NSDictionary *)json {
    PCLModrinthSearchResult *result = [[PCLModrinthSearchResult alloc] init];
    NSArray *hits = json[@"hits"] ?: @[];
    result.totalHits = [json[@"total_hits"] integerValue];
    result.offset = [json[@"offset"] integerValue];
    result.limit = [json[@"limit"] integerValue];
    
    NSMutableArray *projects = [NSMutableArray array];
    for (NSDictionary *hit in hits) {
        [projects addObject:[self parseProject:hit]];
    }
    result.hits = projects;
    return result;
}

- (PCLModrinthProject *)parseProject:(NSDictionary *)dict {
    PCLModrinthProject *p = [[PCLModrinthProject alloc] init];
    p.projectID = dict[@"project_id"] ?: @"";
    p.slug = dict[@"slug"] ?: @"";
    p.title = dict[@"title"] ?: @"";
    p.descriptionText = dict[@"description"] ?: @"";
    p.iconUrl = dict[@"icon_url"] ?: @"";
    p.author = dict[@"author"] ?: @"";
    p.downloads = [dict[@"downloads"] integerValue];
    p.followers = [dict[@"follows"] integerValue];
    p.projectType = dict[@"project_type"] ?: @"mod";
    p.updatedAt = dict[@"updated"] ?: @"";
    p.createdAt = dict[@"date_created"] ?: @"";
    p.categories = dict[@"categories"] ?: @[];
    p.gameVersions = dict[@"versions"] ?: @[];
    p.loaders = dict[@"loaders"] ?: @[];
    p.license = dict[@"license"][@"id"] ?: @"";
    p.body = dict[@"body"] ?: @"";
    return p;
}

- (PCLModrinthVersion *)parseVersion:(NSDictionary *)dict {
    PCLModrinthVersion *ver = [[PCLModrinthVersion alloc] init];
    ver.versionID = dict[@"id"] ?: @"";
    ver.versionNumber = dict[@"version_number"] ?: @"";
    ver.name = dict[@"name"] ?: @"";
    ver.gameVersions = dict[@"game_versions"] ?: @[];
    ver.loaders = dict[@"loaders"] ?: @[];
    ver.files = dict[@"files"] ?: @[];
    ver.downloads = [dict[@"downloads"] integerValue];
    ver.datePublished = dict[@"date_published"] ?: @"";
    ver.versionType = dict[@"version_type"] ?: @"release";
    ver.featured = [dict[@"featured"] boolValue];
    
    // Parse files
    NSMutableArray *fileInfos = [NSMutableArray array];
    for (NSDictionary *fileDict in dict[@"files"]) {
        PCLModrinthFileInfo *fi = [[PCLModrinthFileInfo alloc] init];
        fi.fileName = fileDict[@"filename"] ?: @"";
        fi.url = fileDict[@"url"] ?: @"";
        fi.size = [fileDict[@"size"] integerValue];
        fi.isPrimary = [fileDict[@"primary"] boolValue];
        fi.downloads = 0;
        NSDictionary *hashes = fileDict[@"hashes"];
        fi.sha1 = hashes[@"sha1"] ?: @"";
        fi.sha512 = hashes[@"sha512"] ?: @"";
        [fileInfos addObject:fi];
    }
    ver.fileInfos = fileInfos;
    
    // Parse dependencies
    NSMutableArray *deps = [NSMutableArray array];
    for (NSDictionary *depDict in dict[@"dependencies"]) {
        PCLModrinthDependency *dep = [[PCLModrinthDependency alloc] init];
        dep.projectID = depDict[@"project_id"] ?: @"";
        dep.versionID = depDict[@"version_id"] ?: @"";
        dep.dependencyType = depDict[@"dependency_type"] ?: @"required";
        dep.fileName = depDict[@"file_name"] ?: @"";
        [deps addObject:dep];
    }
    ver.dependencies = deps;
    
    return ver;
}

#pragma mark - Project

- (void)getProject:(NSString *)slugOrID completion:(void(^)(PCLModrinthProject *project, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"https://api.modrinth.com/v2/project/%@", slugOrID];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [req setValue:@"PCL-iOS/1.0" forHTTPHeaderField:@"User-Agent"];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(self.callbackQueue, ^{ completion(nil, error); });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        PCLModrinthProject *project = [self parseProject:json];
        dispatch_async(self.callbackQueue, ^{ completion(project, nil); });
    }];
    [task resume];
}

- (void)getProjects:(NSArray<NSString *> *)projectIDs completion:(void(^)(NSArray<PCLModrinthProject *> *projects, NSError *error))completion {
    if (projectIDs.count == 0) {
        dispatch_async(self.callbackQueue, ^{ completion(@[], nil); });
        return;
    }
    
    NSString *ids = [projectIDs componentsJoinedByString:@","];
    NSString *encodedIDs = [ids stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"https://api.modrinth.com/v2/projects?ids=[%@]", encodedIDs];
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [req setValue:@"PCL-iOS/1.0" forHTTPHeaderField:@"User-Agent"];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(self.callbackQueue, ^{ completion(nil, error); });
            return;
        }
        NSArray *arr = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSMutableArray *projects = [NSMutableArray array];
        for (NSDictionary *dict in arr) {
            [projects addObject:[self parseProject:dict]];
        }
        dispatch_async(self.callbackQueue, ^{ completion(projects, nil); });
    }];
    [task resume];
}

#pragma mark - Versions

- (void)versionsForProject:(NSString *)projectID facets:(NSDictionary *)facets completion:(void(^)(NSArray<PCLModrinthVersion *> *versions, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"https://api.modrinth.com/v2/project/%@/version", projectID];
    
    NSMutableArray *params = [NSMutableArray array];
    NSString *gameVersion = facets[@"gameVersion"];
    if (gameVersion) {
        [params addObject:[NSString stringWithFormat:@"game_versions=[\"%@\"]", gameVersion]];
    }
    
    NSString *loader = facets[@"loader"];
    if (loader) {
        [params addObject:[NSString stringWithFormat:@"loaders=[\"%@\"]", loader]];
    }
    
    if (params.count > 0) {
        urlString = [urlString stringByAppendingFormat:@"?%@", [params componentsJoinedByString:@"&"]];
    }
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [req setValue:@"PCL-iOS/1.0" forHTTPHeaderField:@"User-Agent"];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(self.callbackQueue, ^{ completion(nil, error); });
            return;
        }
        NSArray *arr = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSMutableArray *versions = [NSMutableArray array];
        for (NSDictionary *v in arr) {
            [versions addObject:[self parseVersion:v]];
        }
        dispatch_async(self.callbackQueue, ^{ completion(versions, nil); });
    }];
    [task resume];
}

- (void)getVersion:(NSString *)versionID completion:(void(^)(PCLModrinthVersion *version, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"https://api.modrinth.com/v2/version/%@", versionID];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [req setValue:@"PCL-iOS/1.0" forHTTPHeaderField:@"User-Agent"];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(self.callbackQueue, ^{ completion(nil, error); });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        PCLModrinthVersion *version = [self parseVersion:json];
        dispatch_async(self.callbackQueue, ^{ completion(version, nil); });
    }];
    [task resume];
}

- (void)getVersions:(NSArray<NSString *> *)versionIDs completion:(void(^)(NSArray<PCLModrinthVersion *> *versions, NSError *error))completion {
    if (versionIDs.count == 0) {
        dispatch_async(self.callbackQueue, ^{ completion(@[], nil); });
        return;
    }
    
    NSString *ids = [versionIDs componentsJoinedByString:@","];
    NSString *encodedIDs = [ids stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"https://api.modrinth.com/v2/versions?ids=[%@]", encodedIDs];
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [req setValue:@"PCL-iOS/1.0" forHTTPHeaderField:@"User-Agent"];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(self.callbackQueue, ^{ completion(nil, error); });
            return;
        }
        NSArray *arr = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSMutableArray *versions = [NSMutableArray array];
        for (NSDictionary *dict in arr) {
            [versions addObject:[self parseVersion:dict]];
        }
        dispatch_async(self.callbackQueue, ^{ completion(versions, nil); });
    }];
    [task resume];
}

- (void)getLatestVersionForProject:(NSString *)slugOrID
                       gameVersion:(NSString *)gameVersion
                            loader:(NSString *)loader
                        completion:(void(^)(PCLModrinthVersion *version, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"https://api.modrinth.com/v2/project/%@/version?game_versions=[\"%@\"]&loaders=[\"%@\"]",
                          slugOrID, gameVersion, loader];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [req setValue:@"PCL-iOS/1.0" forHTTPHeaderField:@"User-Agent"];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(self.callbackQueue, ^{ completion(nil, error); });
            return;
        }
        NSArray *arr = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (arr.count == 0) {
            dispatch_async(self.callbackQueue, ^{ completion(nil, nil); });
            return;
        }
        PCLModrinthVersion *version = [self parseVersion:arr.firstObject];
        dispatch_async(self.callbackQueue, ^{ completion(version, nil); });
    }];
    [task resume];
}

#pragma mark - Dependencies

- (void)dependenciesForProject:(NSString *)projectID completion:(void(^)(NSArray<PCLModrinthDependency *> *dependencies, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"https://api.modrinth.com/v2/project/%@/dependencies", projectID];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [req setValue:@"PCL-iOS/1.0" forHTTPHeaderField:@"User-Agent"];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(self.callbackQueue, ^{ completion(nil, error); });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSArray *depsArr = json[@"projects"] ?: @[];
        NSMutableArray *deps = [NSMutableArray array];
        for (NSDictionary *dict in depsArr) {
            PCLModrinthDependency *dep = [[PCLModrinthDependency alloc] init];
            dep.projectID = dict[@"id"] ?: @"";
            dep.dependencyType = dict[@"project_type"] ?: @"required";
            [deps addObject:dep];
        }
        dispatch_async(self.callbackQueue, ^{ completion(deps, nil); });
    }];
    [task resume];
}

#pragma mark - Categories & Tags

- (void)loadCategories:(void(^)(NSArray<PCLModrinthCategory *> *categories, NSError *error))completion {
    NSString *urlString = @"https://api.modrinth.com/v2/tag/category";
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [req setValue:@"PCL-iOS/1.0" forHTTPHeaderField:@"User-Agent"];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(self.callbackQueue, ^{ completion(nil, error); });
            return;
        }
        NSArray *arr = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSMutableArray *categories = [NSMutableArray array];
        for (NSDictionary *dict in arr) {
            PCLModrinthCategory *cat = [[PCLModrinthCategory alloc] init];
            cat.name = dict[@"name"] ?: @"";
            cat.icon = dict[@"icon"] ?: @"";
            cat.projectType = dict[@"project_type"] ?: @"";
            [categories addObject:cat];
        }
        dispatch_async(self.callbackQueue, ^{ completion(categories, nil); });
    }];
    [task resume];
}

- (void)loadGameVersions:(void(^)(NSArray<NSString *> *versions, NSError *error))completion {
    NSString *urlString = @"https://api.modrinth.com/v2/tag/game_version";
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [req setValue:@"PCL-iOS/1.0" forHTTPHeaderField:@"User-Agent"];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(self.callbackQueue, ^{ completion(nil, error); });
            return;
        }
        NSArray *arr = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSMutableArray *versions = [NSMutableArray array];
        for (NSDictionary *dict in arr) {
            NSString *version = dict[@"version"];
            if (version) [versions addObject:version];
        }
        dispatch_async(self.callbackQueue, ^{ completion(versions, nil); });
    }];
    [task resume];
}

#pragma mark - Download

- (void)downloadFile:(PCLModrinthFileInfo *)file
              toPath:(NSString *)path
            progress:(void(^)(double progress))progress
          completion:(void(^)(BOOL success, NSError *error))completion {
    
    if (!file.url) {
        completion(NO, [NSError errorWithDomain:@"PCLModrinthAPI" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"No download URL"}]);
        return;
    }
    
    NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:file.url]];
    NSURLSessionDownloadTask *task = [self.session downloadTaskWithRequest:req completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(NO, error);
            return;
        }
        NSError *moveError;
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:[NSURL fileURLWithPath:path] error:&moveError];
        completion(moveError == nil, moveError);
    }];
    [task resume];
}

@end
