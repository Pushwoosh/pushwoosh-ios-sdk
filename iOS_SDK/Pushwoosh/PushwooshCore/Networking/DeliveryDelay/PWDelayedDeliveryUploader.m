//
//  PWDelayedDeliveryUploader.m
//  PushwooshCore
//
//  Created by André Kis
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import "PWDelayedDeliveryUploader.h"
#import "PushwooshLog.h"

#if TARGET_OS_IOS

static NSString *const kPWDelayedDeliverySessionIdentifier = @"com.pushwoosh.nse.delayed-delivery";
static NSString *const kPWDelayedDeliveryRetrySessionIdentifier = @"com.pushwoosh.app.delayed-delivery";
static NSString *const kPWDelayedDeliveryBodyDirectory = @"PushwooshDeliveryEvents";
static NSTimeInterval const kPWDelayedDeliveryBodyLifetime = 24 * 60 * 60;
static NSUInteger const kPWDelayedDeliveryMaxAttempts = 5;
static NSTimeInterval const kPWDelayedDeliveryRetryStep = 10;

/// As Android's `ConnectionException.isTransient`: no response at all, or a status an identical later request may survive.
static BOOL PWIsTransientDeliveryStatus(NSInteger statusCode) {
    switch (statusCode) {
        case 0:
        case 408:
        case 429:
        case 500:
        case 502:
        case 503:
        case 504:
            return YES;
        default:
            return NO;
    }
}

@interface PWDelayedDeliveryUploader () <NSURLSessionTaskDelegate>

/// The extension's session opened by the app only to take its events; closed once they are handled,
/// because a background session serves one process at a time and the extension needs it back.
@property (nonatomic, nullable) NSURLSession *extensionEventsSession;
/// The app's own session for the attempts it sends again.
@property (nonatomic, nullable) NSURLSession *retrySession;
@property (nonatomic) NSMutableDictionary<NSString *, void (^)(void)> *completionHandlers;

@end

@implementation PWDelayedDeliveryUploader

+ (instancetype)sharedUploader {
    static PWDelayedDeliveryUploader *uploader;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        uploader = [self new];
    });
    return uploader;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _completionHandlers = [NSMutableDictionary new];
    }
    return self;
}

/// A body stays on disk while its task may still read it; one left after a day is no longer worth sending.
+ (BOOL)scheduleRequest:(NSURLRequest *)urlRequest afterDelay:(NSTimeInterval)delay appGroupsName:(NSString *)appGroupsName {
    NSURL *bodyDirectory = [self bodyDirectoryForAppGroup:appGroupsName];
    if (bodyDirectory == nil || urlRequest.HTTPBody == nil) {
        return NO;
    }

    [self removeBodiesOlderThan:[NSDate dateWithTimeIntervalSinceNow:-kPWDelayedDeliveryBodyLifetime] inDirectory:bodyDirectory];

    NSURL *bodyFileURL = [bodyDirectory URLByAppendingPathComponent:[NSUUID UUID].UUIDString];
    if (![urlRequest.HTTPBody writeToURL:bodyFileURL atomically:YES]) {
        return NO;
    }

    NSMutableURLRequest *uploadRequest = [urlRequest mutableCopy];
    uploadRequest.HTTPBody = nil;

    if (![self uploadBody:bodyFileURL request:uploadRequest attempt:1 afterDelay:delay inSession:[self sessionForAppGroup:appGroupsName]]) {
        [[NSFileManager defaultManager] removeItemAtURL:bodyFileURL error:nil];
        return NO;
    }
    return YES;
}

+ (BOOL)handleEventsForBackgroundURLSession:(NSString *)identifier appGroupsName:(NSString *)appGroupsName completionHandler:(void (^)(void))completionHandler {
    if (![identifier isEqualToString:kPWDelayedDeliverySessionIdentifier] && ![identifier isEqualToString:kPWDelayedDeliveryRetrySessionIdentifier]) {
        return NO;
    }

    [[self sharedUploader] takeEventsOfSession:identifier appGroupsName:appGroupsName completionHandler:completionHandler];
    return YES;
}

/// The attempt number and the body file travel in the task description: the outcome may reach another process.
+ (BOOL)uploadBody:(NSURL *)bodyFileURL request:(NSURLRequest *)request attempt:(NSUInteger)attempt afterDelay:(NSTimeInterval)delay inSession:(NSURLSession *)session {
    NSURLSessionUploadTask *task = [session uploadTaskWithRequest:request fromFile:bodyFileURL];
    if (task == nil) {
        return NO;
    }

    task.taskDescription = [NSString stringWithFormat:@"%lu %@", (unsigned long)attempt, bodyFileURL.lastPathComponent];
    task.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:delay];
    [task resume];
    return YES;
}

- (void)takeEventsOfSession:(NSString *)identifier appGroupsName:(NSString *)appGroupsName completionHandler:(void (^)(void))completionHandler {
    @synchronized (self) {
        self.completionHandlers[identifier] = [completionHandler copy];

        if (![identifier isEqualToString:kPWDelayedDeliverySessionIdentifier]) {
            [self retrySessionForAppGroup:appGroupsName];
        } else if (self.extensionEventsSession == nil) {
            self.extensionEventsSession = [self.class sessionWithIdentifier:identifier appGroupsName:appGroupsName];
        }
    }
}

- (NSURLSession *)retrySessionForAppGroup:(NSString *)appGroupsName {
    @synchronized (self) {
        if (self.retrySession == nil) {
            self.retrySession = [self.class sessionWithIdentifier:kPWDelayedDeliveryRetrySessionIdentifier appGroupsName:appGroupsName];
        }
        return self.retrySession;
    }
}

/// The extension sends its attempts again in its own session; the app in its own, never in the extension's it closes.
- (NSURLSession *)sessionToRetryTaskOf:(NSURLSession *)session {
    @synchronized (self) {
        if (session != self.extensionEventsSession) {
            return session;
        }
    }
    return [self retrySessionForAppGroup:session.configuration.sharedContainerIdentifier];
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSArray<NSString *> *attemptAndBody = [task.taskDescription componentsSeparatedByString:@" "];
    if (attemptAndBody.count != 2) {
        return;
    }

    NSUInteger attempt = (NSUInteger)attemptAndBody[0].integerValue;
    NSURL *bodyFileURL = [[self.class bodyDirectoryForAppGroup:session.configuration.sharedContainerIdentifier] URLByAppendingPathComponent:attemptAndBody[1]];
    if (attempt == 0 || bodyFileURL == nil) {
        return;
    }

    NSInteger statusCode = 0;
    if (error == nil && [task.response isKindOfClass:[NSHTTPURLResponse class]]) {
        statusCode = ((NSHTTPURLResponse *)task.response).statusCode;
    }

    if (!PWIsTransientDeliveryStatus(statusCode)) {
        [[NSFileManager defaultManager] removeItemAtURL:bodyFileURL error:nil];
        [PushwooshLog pushwooshLog:PW_LL_INFO
                         className:self
                           message:[NSString stringWithFormat:@"messageDeliveryEvent attempt %lu answered HTTP %ld", (unsigned long)attempt, (long)statusCode]];
        return;
    }

    if (attempt >= kPWDelayedDeliveryMaxAttempts) {
        [[NSFileManager defaultManager] removeItemAtURL:bodyFileURL error:nil];
        [PushwooshLog pushwooshLog:PW_LL_WARN
                         className:self
                           message:[NSString stringWithFormat:@"messageDeliveryEvent not delivered after %lu attempts (HTTP %ld, error %ld), giving up", (unsigned long)attempt, (long)statusCode, (long)error.code]];
        return;
    }

    NSTimeInterval delay = kPWDelayedDeliveryRetryStep * attempt;
    if (![self.class uploadBody:bodyFileURL request:task.originalRequest attempt:attempt + 1 afterDelay:delay inSession:[self sessionToRetryTaskOf:session]]) {
        [[NSFileManager defaultManager] removeItemAtURL:bodyFileURL error:nil];
        return;
    }

    [PushwooshLog pushwooshLog:PW_LL_INFO
                     className:self
                       message:[NSString stringWithFormat:@"messageDeliveryEvent attempt %lu failed (HTTP %ld, error %ld), next attempt in %.0f s", (unsigned long)attempt, (long)statusCode, (long)error.code, delay]];
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    NSString *identifier = session.configuration.identifier;
    void (^completionHandler)(void) = nil;
    BOOL borrowedFromExtension = NO;

    @synchronized (self) {
        completionHandler = identifier ? self.completionHandlers[identifier] : nil;
        if (identifier) {
            [self.completionHandlers removeObjectForKey:identifier];
        }
        borrowedFromExtension = session == self.extensionEventsSession;
    }

    if (borrowedFromExtension) {
        [session finishTasksAndInvalidate];
    }

    if (completionHandler) {
        dispatch_async(dispatch_get_main_queue(), completionHandler);
    }
}

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error {
    @synchronized (self) {
        if (session == self.extensionEventsSession) {
            self.extensionEventsSession = nil;
        }
    }
}

#pragma mark - Storage and sessions

+ (NSURL *)bodyDirectoryForAppGroup:(NSString *)appGroupsName {
    NSURL *containerURL = [self containerURLForAppGroup:appGroupsName];
    if (containerURL == nil) {
        return nil;
    }

    NSURL *directory = [containerURL URLByAppendingPathComponent:kPWDelayedDeliveryBodyDirectory isDirectory:YES];
    if (![[NSFileManager defaultManager] createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:nil]) {
        return nil;
    }
    return directory;
}

+ (void)removeBodiesOlderThan:(NSDate *)date inDirectory:(NSURL *)directory {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray<NSURL *> *files = [fileManager contentsOfDirectoryAtURL:directory includingPropertiesForKeys:@[NSURLContentModificationDateKey] options:0 error:nil];

    for (NSURL *file in files) {
        NSDate *modified = nil;
        [file getResourceValue:&modified forKey:NSURLContentModificationDateKey error:nil];
        if (modified != nil && [modified compare:date] == NSOrderedAscending) {
            [fileManager removeItemAtURL:file error:nil];
        }
    }
}

+ (NSURL *)containerURLForAppGroup:(NSString *)appGroupsName {
    if (![appGroupsName isKindOfClass:[NSString class]] || appGroupsName.length == 0) {
        return nil;
    }
    return [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:appGroupsName];
}

+ (NSURLSession *)sessionForAppGroup:(NSString *)appGroupsName {
    static NSURLSession *session;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        session = [self sessionWithIdentifier:kPWDelayedDeliverySessionIdentifier appGroupsName:appGroupsName];
    });
    return session;
}

+ (NSURLSession *)sessionWithIdentifier:(NSString *)identifier appGroupsName:(NSString *)appGroupsName {
    return [NSURLSession sessionWithConfiguration:[self sessionConfigurationWithIdentifier:identifier appGroupsName:appGroupsName]
                                         delegate:[self sharedUploader]
                                    delegateQueue:nil];
}

/// Launch events: an attempt that ends after the extension is gone wakes the app to judge it.
+ (NSURLSessionConfiguration *)sessionConfigurationWithIdentifier:(NSString *)identifier appGroupsName:(NSString *)appGroupsName {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
    configuration.sharedContainerIdentifier = appGroupsName;
    configuration.sessionSendsLaunchEvents = YES;
    return configuration;
}

@end

#endif
