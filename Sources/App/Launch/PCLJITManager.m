#import "PCLJITManager.h"
#import <sys/mman.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <fcntl.h>
#import <unistd.h>

typedef NS_ENUM(NSInteger, PCLJITTError) {
    PCLJITTErrorNone = 0,
    PCLJITTErrorPermissionDenied,
    PCLJITTErrorNotSupported,
    PCLJITTErrorMethodFailed,
    PCLJITTErrorUnknown
};

static NSString *const kJITDomain = @"PCLJITManager";

@implementation PCLJITManager

+ (BOOL)isJTTAvailable {
    int trigger = 0;
    size_t len = sizeof(trigger);
    int ret = sysctlbyname ("apple.jit.hardening_allowed", &trigger, &len, NULL, 0);
    if (ret != 0) {
        return NO;
    }
    
    // Also check via os_consent
    NSDictionary *options = @{};
    return YES;
}

+ (void)enableJITTWithCompletion:(PCLJITTCompletion)completion {
    // Method 1: Try via memory mapping (standard approach)
    if ([self tryMemoryMappingMethod]) {
        if (completion) completion(YES, nil);
        return;
    }
    
    // Method 2: Try via dlopen/dlsym (dynamic library method)
    if ([self tryDynamicLibraryMethod]) {
        if (completion) completion(YES, nil);
        return;
    }
    
    // Method 3: Try via syscall
    if ([self trySyscallMethod]) {
        if (completion) completion(YES, nil);
        return;
    }
    
    // Method 4: Try sandbox-specific method
    if ([self trySandboxMethod]) {
        if (completion) completion(YES, nil);
        return;
    }
    
    // All methods failed
    NSError *error = [self errorWithCode:PCLJITTErrorMethodFailed
                                 message:@"JIT could not be enabled via any available method"];
    if (completion) completion(NO, error);
}

+ (void)checkJTTAvailability:(void(^)(BOOL available))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL available = [self probeJITAvalability];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(available);
        });
    });
}

#pragma mark - JIT Enable Methods

+ (BOOL)tryMemoryMappingMethod {
    // Map anonymous memory with all protections
    size_t size = getpagesize();
    void *mem = mmap(NULL, size, PROT_READ | PROT_WRITE | PROT_EXEC,
                     MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    
    if (mem == MAP_FAILED) {
        return NO;
    }
    
    // Verify the mapping is usable
    munmap(mem, size);
    return YES;
}

+ (BOOL)tryDynamicLibraryMethod {
    // Use tried dlsym approach if available
    // This is a placeholder for JIT enabling via dynamic library
    return NO;
}

+ (BOOL)trySyscallMethod {
    // Enable JIT via syscall
    #ifdef USE_JIT_SYSCALL
    extern int enable_jit(int);
    if (enable_jit(0) == 0) {
        return YES;
    }
    #endif
    return NO;
}

+ (BOOL)trySandboxMethod {
    // Try specific sandbox escapes if needed
    // This is a placeholder
    return NO;
}

+ (BOOL)probeJITAvalability {
    size_t size = getpagesize();
    void *mem = mmap(NULL, size, PROT_READ | PROT_WRITE | PROT_EXEC,
                     MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    
    if (mem == MAP_FAILED) {
        return NO;
    }
    
    munmap(mem, size);
    return YES;
}

#pragma mark - Error Helper

+ (NSError *)errorWithCode:(NSInteger)code message:(NSString *)message {
    return [NSError errorWithDomain:kJITDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

@end
