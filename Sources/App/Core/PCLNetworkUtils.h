#import <Foundation/Foundation.h>

@interface PCLNetworkUtils : NSObject

+ (void)GET:(NSString *)urlString
 parameters:(NSDictionary *)params
    headers:(NSDictionary *)headers
 completion:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completion;

+ (void)POST:(NSString *)urlString
  parameters:(NSDictionary *)params
     headers:(NSDictionary *)headers
  completion:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completion;

+ (void)POSTJSON:(NSString *)urlString
      parameters:(NSDictionary *)params
         headers:(NSDictionary *)headers
      completion:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completion;

+ (NSString *)urlEncodedStringFromParams:(NSDictionary *)params;

@end
