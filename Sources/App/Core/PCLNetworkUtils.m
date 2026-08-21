#import "PCLNetworkUtils.h"

@implementation PCLNetworkUtils

+ (void)GET:(NSString *)urlString
 parameters:(NSDictionary *)params
    headers:(NSDictionary *)headers
 completion:(void (^)(NSData *, NSURLResponse *, NSError *))completion {
    
    if (params.count > 0) {
        NSString *query = [self urlEncodedStringFromParams:params];
        urlString = [urlString stringByAppendingFormat:[urlString containsString:@"?"] ? @"&%@" : @"?%@", query];
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    request.timeoutInterval = 15;
    
    [request setValue:@"PCL-iOS/0.1" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    for (NSString *key in headers) {
        [request setValue:headers[key] forHTTPHeaderField:key];
    }
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(data, response, error);
        });
    }];
    [task resume];
}

+ (void)POST:(NSString *)urlString
  parameters:(NSDictionary *)params
     headers:(NSDictionary *)headers
  completion:(void (^)(NSData *, NSURLResponse *, NSError *))completion {
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    request.timeoutInterval = 30;
    
    [request setValue:@"PCL-iOS/0.1" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    for (NSString *key in headers) {
        [request setValue:headers[key] forHTTPHeaderField:key];
    }
    
    if (params) {
        NSString *query = [self urlEncodedStringFromParams:params];
        request.HTTPBody = [query dataUsingEncoding:NSUTF8StringEncoding];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    }
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(data, response, error);
        });
    }];
    [task resume];
}

+ (void)POSTJSON:(NSString *)urlString
      parameters:(NSDictionary *)params
         headers:(NSDictionary *)headers
      completion:(void (^)(NSData *, NSURLResponse *, NSError *))completion {
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    request.timeoutInterval = 30;
    
    [request setValue:@"PCL-iOS/0.1" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    for (NSString *key in headers) {
        [request setValue:headers[key] forHTTPHeaderField:key];
    }
    
    if (params) {
        NSError *error = nil;
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:params options:0 error:&error];
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, nil, error);
            });
            return;
        }
    }
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(data, response, error);
        });
    }];
    [task resume];
}

+ (NSString *)urlEncodedStringFromParams:(NSDictionary *)params {
    NSMutableArray *parts = [NSMutableArray array];
    for (NSString *key in params) {
        NSString *value = [params[key] description];
        NSString *encodedKey = [self urlEncode:key];
        NSString *encodedValue = [self urlEncode:value];
        [parts addObject:[NSString stringWithFormat:@"%@=%@", encodedKey, encodedValue]];
    }
    return [parts componentsJoinedByString:@"&"];
}

+ (NSString *)urlEncode:(NSString *)string {
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"];
    return [string stringByAddingPercentEncodingWithAllowedCharacters:allowed];
}

@end
