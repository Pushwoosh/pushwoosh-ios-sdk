//
//  PWRequestsCacheManager.m
//  Pushwoosh
//
//  Created by Anton Kaizer on 21.08.17.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWRequestsCacheManager.h"
#import "PWCachedRequest.h"
#import "PWNetworkModule.h"
#import "PWUtils.h"
#import "PWUnarchiver.h"

#if TARGET_OS_IOS || TARGET_OS_OSX
#import "PWReachability.h"
#endif

@interface PWRequestsCacheManager ()
// @Inject
@property (nonatomic, strong) PWRequestManager *requestManager;

@property (nonatomic) NSMutableArray *requestsQueue;
@property (nonatomic) NSOperationQueue *saveDataQueue;
@property (nonatomic) BOOL sending;

@property (nonatomic) PWReachability *reachability;

@end

@implementation PWRequestsCacheManager

+ (instancetype)sharedInstance {
    static id instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        [[PWNetworkModule module] inject:self];
        
        _saveDataQueue = [[NSOperationQueue alloc] init];
        _saveDataQueue.maxConcurrentOperationCount = 1;
        _saveDataQueue.qualityOfService = NSQualityOfServiceUtility;
        
        _reachability = [PWReachability reachabilityForInternetConnection];
        if (_reachability.currentReachabilityStatus != NotReachable) {
            [self trySend];
        }
        __weak typeof(self) wSelf = self;
        _reachability.reachableBlock = ^(PWReachability *reachability) {
            if (reachability.currentReachabilityStatus != NotReachable) {
                [wSelf trySend];
            }
        };
        [_reachability startNotifier];
    }
    return self;
}

- (NSMutableArray *)requestsQueue {
    if (!_requestsQueue) {
        NSFileManager *fileManager = [NSFileManager new];
        NSString *cachePath = [self cachePath:fileManager];
        if ([fileManager fileExistsAtPath:cachePath]) {
            if (TARGET_OS_IOS) {
                NSURL *url = [NSURL fileURLWithPath:cachePath];
                NSData *data = [NSData dataWithContentsOfURL:url];

                NSSet *set = [NSSet setWithObjects:[PWCachedRequest class], [NSMutableArray class], [NSURL class], nil];
                
                PWUnarchiver *unarchiver = [[PWUnarchiver alloc] init];
                _requestsQueue = [unarchiver unarchivedObjectOfClasses:set data:data];
            }
        }
        if (!_requestsQueue) {
            _requestsQueue = [NSMutableArray array];
        }
    }
    return _requestsQueue;
}

- (void)cacheRequest:(PWRequest *)request {
    __weak typeof(self) wSelf = self;
    
    PWCachedRequest *cachedRequest = [[PWCachedRequest alloc] initWithRequest:request];

    [_saveDataQueue addOperationWithBlock:^{
        [self.requestsQueue addObject:cachedRequest];
        [self save:self.requestsQueue withPath:[self getCachePath]];
        
        if (_reachability.currentReachabilityStatus != NotReachable) {
            [wSelf trySend];
        }
    }];
}

- (void)trySend {
    __weak typeof(self) wSelf = self;

    [_saveDataQueue addOperationWithBlock:^{
        for (PWCachedRequest *request in self.requestsQueue) {
            [wSelf.requestManager sendRequest:request completion:nil];
        }
    }];
}

- (void)deleteCachedRequest:(PWRequest *)request {
    __weak typeof(self) wSelf = self;

    [_saveDataQueue addOperationWithBlock:^{
        [_requestsQueue removeObject:request];
        [wSelf save:self.requestsQueue withPath:[self getCachePath]];
        [wSelf removeRequestFromUserDefaults:request key:@""];
        [wSelf removeRequestFromUserDefaults:request key:kPrefixDelay];
        [wSelf removeRequestFromUserDefaults:request key:kPrefixDate];
    }];
}

- (void)removeRequestFromUserDefaults:(PWRequest *)request key:(NSString *)key {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"%@%@", key, request.requestIdentifier]];
}

- (NSString *)cachePath:(NSFileManager *)fileManager {
    NSArray *urls = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSString *directory = [(NSURL *)urls[0] path];
    return [directory stringByAppendingPathComponent:@"PWRequestCache"];
}

- (void)save:(NSMutableArray *)requestsQueue withPath:(NSString *)path {
    if (TARGET_OS_IOS && [PWUtils isSystemVersionGreaterOrEqualTo:@"11.0"]) {
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:requestsQueue requiringSecureCoding:YES error:&error];
        [data writeToFile:path options:NSDataWritingAtomic error:&error];
        if (error != nil) {
            PWLogError(@"Write to file failed: %@", error);
        }
    } else {
        [NSKeyedArchiver archiveRootObject:requestsQueue toFile:path];
    }
}

- (NSString *)getCachePath {
    NSFileManager *fileManager = [NSFileManager new];
    return [self cachePath:fileManager];
}

@end
