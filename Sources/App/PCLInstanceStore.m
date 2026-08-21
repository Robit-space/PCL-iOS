#import "PCLInstanceStore.h"

static NSString *const PCLMinecraftRootKey =

    @"PCLMinecraftRoot";

static NSString *const PCLSelectedInstanceKey =

    @"PCLSelectedInstance";

static NSString *const PCLSelectedInstancePathKey =

    @"PCLSelectedInstancePath";

static NSString *const PCLInstanceFirstScanKey =

    @"PCLInstanceFirstScanFinished";

@implementation PCLInstance

@end

@implementation PCLInstanceStore

+ (NSString *)minecraftRoot {

    NSUserDefaults *d=

        NSUserDefaults.standardUserDefaults;

    NSString *saved=

        [d stringForKey:PCLMinecraftRootKey];

    if (saved.length)

        return saved.stringByStandardizingPath;

    NSString *documents=

        NSSearchPathForDirectoriesInDomains(

            NSDocumentDirectory,

            NSUserDomainMask,

            YES).firstObject;

    if (!documents.length)

        documents=NSHomeDirectory();

    return [[documents

        stringByAppendingPathComponent:@".minecraft"]

        stringByStandardizingPath];

}

+ (void)setMinecraftRoot:(NSString *)root {

    NSUserDefaults *d=

        NSUserDefaults.standardUserDefaults;

    if (!root.length) {

        [d removeObjectForKey:PCLMinecraftRootKey];

        return;

    }

    [d setObject:root.stringByStandardizingPath

          forKey:PCLMinecraftRootKey];

}


+ (NSString *)minecraftRoot {
    NSString *documents=
        NSSearchPathForDirectoriesInDomains(
            NSDocumentDirectory,
            NSUserDomainMask,
            YES).firstObject;

    return [documents
        stringByAppendingPathComponent:@".minecraft"];
}

+ (NSArray<PCLInstance *> *)scanInstances {
    NSString *versions=
        [[self minecraftRoot]
            stringByAppendingPathComponent:@"versions"];

    NSFileManager *fm=
        NSFileManager.defaultManager;

    BOOL isDirectory=NO;

    if (![fm fileExistsAtPath:versions
                  isDirectory:&isDirectory] ||
        !isDirectory)
        return @[];

    NSArray *names=
        [fm contentsOfDirectoryAtPath:versions
                                error:nil];

    if (!names)
        return @[];

    NSMutableArray *result=
        NSMutableArray.array;

    for (NSString *name in names) {
        if ([name hasPrefix:@"."])
            continue;

        NSString *folder=
            [versions stringByAppendingPathComponent:name];

        BOOL folderDirectory=NO;

        if (![fm fileExistsAtPath:folder
                      isDirectory:&folderDirectory] ||
            !folderDirectory)
            continue;

        NSArray *contents=
            [fm contentsOfDirectoryAtPath:folder
                                    error:nil];

        if (!contents.count)
            continue;

        NSString *json=
            [[folder stringByAppendingPathComponent:name]
                stringByAppendingPathExtension:@"json"];

        BOOL hasJson=
            [fm fileExistsAtPath:json];

        if (([name isEqualToString:@"cache"] ||
             [name isEqualToString:@"BLClient"] ||
             [name isEqualToString:@"PCL"]) &&
            !hasJson)
            continue;

        PCLInstance *instance=
            [PCLInstance new];

        instance.name=name;
        instance.path=folder;
        instance.error=!hasJson;

        [result addObject:instance];
    }

    return result.copy;
}

+ (PCLInstance *)selectedInstance:
        (NSArray<PCLInstance *> *)instances {

    NSString *saved=
        [NSUserDefaults.standardUserDefaults
            stringForKey:PCLSelectedInstanceKey];

    for (PCLInstance *instance in instances) {
        if (!instance.error &&
            [instance.name isEqualToString:saved])
            return instance;
    }

    for (PCLInstance *instance in instances) {
        if (!instance.error)
            return instance;
    }

    return nil;
}

+ (void)selectInstance:(PCLInstance *)instance {
    NSUserDefaults *d=
        NSUserDefaults.standardUserDefaults;

    if (instance) {
        [d setObject:instance.name
              forKey:PCLSelectedInstanceKey];
    } else {
        [d removeObjectForKey:PCLSelectedInstanceKey];
    }
}

@end
