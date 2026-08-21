#import "PCLModLoaderAPI.h"
#import "PCLNetworkUtils.h"
#import "PCLDownloadManager.h"

@implementation PCLFabricVersion
@end
@implementation PCLForgeVersion
@end
@implementation PCLNeoForgeVersion
@end

@implementation PCLModLoaderAPI

+ (instancetype)sharedAPI {
    static PCLModLoaderAPI *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PCLModLoaderAPI alloc] init];
    });
    return instance;
}

- (void)fetchFabricVersions:(NSString *)mcVersion
                 completion:(void (^)(NSArray<PCLFabricVersion *> *, NSError *))completion {
    
    NSString *url = [NSString stringWithFormat:@"https://meta.fabricmc.net/v2/versions/loader/%@", mcVersion];
    url = [[PCLDownloadManager sharedManager] replaceURLWithDownloadSource:url];
    
    [PCLNetworkUtils GET:url parameters:nil headers:nil completion:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSError *jsonError = nil;
        NSArray *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError) {
            if (completion) completion(nil, jsonError);
            return;
        }
        
        NSMutableArray *versions = [NSMutableArray array];
        for (NSDictionary *dict in json) {
            PCLFabricVersion *v = [[PCLFabricVersion alloc] init];
            NSDictionary *loader = dict[@"loader"];
            v.version = loader[@"version"] ?: @"";
            v.stable = [loader[@"stable"] boolValue];
            v.maven = [@"net.fabricmc:fabric-loader:" stringByAppendingString:v.version];
            v.url = [NSString stringWithFormat:@"https://maven.fabricmc.net/net/fabricmc/fabric-loader/%@/fabric-loader-%@.jar", v.version, v.version];
            [versions addObject:v];
        }
        
        if (completion) completion(versions, nil);
    }];
}

- (void)fetchForgeVersions:(NSString *)mcVersion
                completion:(void (^)(NSArray<PCLForgeVersion *> *, NSError *))completion {
    
    NSString *url = [NSString stringWithFormat:@"https://files.minecraftforge.net/net/minecraftforge/forge/index_%@.html", mcVersion];
    
    [PCLNetworkUtils GET:url parameters:nil headers:nil completion:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSMutableArray *versions = [NSMutableArray array];
        
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"forge[/-](\\d+\\.\\d+\\.\\d+[\\w.-]*)[/-](\\d+\\.\\d+\\.\\d+[\\w.-]*)" options:0 error:nil];
        NSArray *matches = [regex matchesInString:html options:0 range:NSMakeRange(0, html.length)];
        
        for (NSTextCheckingResult *match in matches) {
            if (match.numberOfRanges >= 3) {
                NSString *version = [html substringWithRange:[match rangeAtIndex:2]];
                PCLForgeVersion *v = [[PCLForgeVersion alloc] init];
                v.version = version;
                v.mcVersion = mcVersion;
                v.modified = version;
                [versions addObject:v];
            }
        }
        
        if (versions.count == 0) {
            PCLForgeVersion *v = [[PCLForgeVersion alloc] init];
            v.version = @"recommended";
            v.mcVersion = mcVersion;
            [versions addObject:v];
        }
        
        if (completion) completion(versions, nil);
    }];
}

- (void)fetchNeoForgeVersions:(NSString *)mcVersion
                   completion:(void (^)(NSArray<PCLNeoForgeVersion *> *, NSError *))completion {
    
    NSString *url = @"https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/neoforge";
    url = [[PCLDownloadManager sharedManager] replaceURLWithDownloadSource:url];
    
    [PCLNetworkUtils GET:url parameters:nil headers:nil completion:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSError *jsonError = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError) {
            if (completion) completion(nil, jsonError);
            return;
        }
        
        NSArray *versions = json[@"versions"] ?: @[];
        NSMutableArray *result = [NSMutableArray array];
        NSString *prefix = [mcVersion stringByAppendingString:@".0"];
        
        for (NSString *version in versions) {
            if ([version hasPrefix:prefix] || [version hasPrefix:@"20.4"] || [version hasPrefix:@"20.5"] || [version hasPrefix:@"20.6"] || [version hasPrefix:@"21."]) {
                PCLNeoForgeVersion *v = [[PCLNeoForgeVersion alloc] init];
                v.version = version;
                v.mcVersion = mcVersion;
                [result addObject:v];
                if (result.count >= 10) break;
            }
        }
        
        if (completion) completion(result, nil);
    }];
}

- (void)fetchOptiFineVersions:(void (^)(NSArray<NSDictionary *> *, NSError *))completion {
    
    NSString *url = @"https://optifine.net/downloads";
    
    [PCLNetworkUtils GET:url parameters:nil headers:nil completion:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSMutableArray *versions = [NSMutableArray array];
        
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"OptiFine\\s+(\\d+\\.\\d+\\.\\d+[\\w_]*)\\s*(\\w*)" options:0 error:nil];
        NSArray *matches = [regex matchesInString:html options:0 range:NSMakeRange(0, html.length)];
        
        for (NSTextCheckingResult *match in matches) {
            if (match.numberOfRanges >= 2) {
                NSString *version = [html substringWithRange:[match rangeAtIndex:1]];
                NSString *type = match.numberOfRanges >= 3 ? [html substringWithRange:[match rangeAtIndex:2]] : @"";
                [versions addObject:@{@"version": version, @"type": type}];
            }
        }
        
        if (completion) completion(versions, nil);
    }];
}

@end
