/*
 *  PWRetryQueueStorage.m
 *  Pushwoosh
 *
 *  Created by André Kis
 */

#import "PWRetryQueueStorage.h"
#import "PWRetryEntry.h"
#import <PushwooshCore/PushwooshLog.h>

static NSUInteger const kPWRetryQueueSchemaVersion = 2;
static NSString *const kKeyVersion = @"version";
static NSString *const kKeyEntries = @"entries";

@interface PWRetryQueueStorage ()
@property (nonatomic, copy) NSURL *fileURL;
@end

@implementation PWRetryQueueStorage

+ (instancetype)defaultStorage {
    NSURL *dir = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
                                                        inDomain:NSUserDomainMask
                                               appropriateForURL:nil
                                                          create:YES
                                                           error:nil];
    NSURL *fileURL = [dir URLByAppendingPathComponent:@"PWRetryQueue"];
    [self removeLegacyCacheFile];
    return [[self alloc] initWithFileURL:fileURL];
}

+ (void)removeLegacyCacheFile {
    NSURL *documents = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                              inDomain:NSUserDomainMask
                                                     appropriateForURL:nil
                                                                create:NO
                                                                 error:nil];
    NSURL *legacy = [documents URLByAppendingPathComponent:@"PWRequestCache"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:legacy.path]) {
        [[NSFileManager defaultManager] removeItemAtURL:legacy error:nil];
    }
}

- (instancetype)initWithFileURL:(NSURL *)fileURL {
    if (self = [super init]) {
        _fileURL = [fileURL copy];
    }
    return self;
}

- (NSArray<PWRetryEntry *> *)loadEntries {
    NSData *data = [NSData dataWithContentsOfURL:_fileURL];
    if (data.length == 0) {
        return @[];
    }

    NSSet *classes = [NSSet setWithObjects:
                      [NSDictionary class], [NSArray class],
                      [NSNumber class], [NSString class],
                      [PWRetryEntry class], nil];
    NSError *error = nil;
    id root = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:data error:&error];
    if (error || ![root isKindOfClass:[NSDictionary class]]) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self
                           message:[NSString stringWithFormat:@"Retry queue load failed: %@", error.localizedDescription ?: @"bad root"]];
        return @[];
    }

    NSNumber *version = root[kKeyVersion];
    if (![version isKindOfClass:[NSNumber class]] || version.unsignedIntegerValue != kPWRetryQueueSchemaVersion) {
        [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self
                           message:@"Retry queue schema version mismatch, dropping persisted queue"];
        return @[];
    }

    NSArray *entries = root[kKeyEntries];
    return [entries isKindOfClass:[NSArray class]] ? entries : @[];
}

- (BOOL)saveEntries:(NSArray<PWRetryEntry *> *)entries {
    if (_fileURL == nil) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self
                           message:@"Retry queue save skipped: storage file URL is nil"];
        return NO;
    }

    NSDictionary *root = @{ kKeyVersion: @(kPWRetryQueueSchemaVersion),
                            kKeyEntries: entries ?: @[] };

    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:root requiringSecureCoding:YES error:&error];
    if (!data || error) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self
                           message:[NSString stringWithFormat:@"Retry queue archive failed: %@", error.localizedDescription]];
        return NO;
    }

    NSDataWritingOptions options = NSDataWritingAtomic;
#if TARGET_OS_IOS
    options |= NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication;
#endif

    BOOL ok = [data writeToURL:_fileURL options:options error:&error];
    if (!ok) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self
                           message:[NSString stringWithFormat:@"Retry queue write failed: %@", error.localizedDescription]];
    }
    return ok;
}

- (void)deleteStorage {
    [[NSFileManager defaultManager] removeItemAtURL:_fileURL error:nil];
}

@end
