//
//  PWRequestManagerMock.m
//  PushNotificationManager
//
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWRequestManagerMock.h"

@interface PWRequestManagerMock ()

@property (nonatomic, strong) NSMutableArray<dispatch_block_t> *parkedRequests;
@property (nonatomic, strong) NSMutableArray<PWRequestDownloadCompleteBlock> *parkedDownloads;

@end

@implementation PWRequestManagerMock

- (instancetype)init {
    self = [super init];
    if (self) {
        _parkedRequests = [NSMutableArray new];
        _parkedDownloads = [NSMutableArray new];
    }
    return self;
}

- (void)sendRequest:(PWRequest *)request completion:(void (^)(NSError *error))completion {
    if (self.onSendRequest) {
        self.onSendRequest(request);
    }

    dispatch_block_t deliver = ^{
        if (!completion) {
            return;
        }
        if (self.failed) {
            completion([NSError errorWithDomain:@"pushwoosh" code:-1 userInfo:@{NSLocalizedDescriptionKey : @"Testing error"}]);
            return;
        }
        NSDictionary *response = self.responsesByMethod[[request methodName]] ?: self.response;
        [request parseResponse:response];
        completion(nil);
    };

    if ([self.deferredMethods containsObject:[request methodName]]) {
        [self.parkedRequests addObject:deliver];
        return;
    }

    deliver();
}

- (NSUInteger)deferredRequestCount {
    return self.parkedRequests.count;
}

- (void)releaseDeferredRequests {
    NSArray<dispatch_block_t> *parked = [self.parkedRequests copy];
    [self.parkedRequests removeAllObjects];
    for (dispatch_block_t block in parked) {
        block();
    }
}

- (void)downloadDataFromURL:(NSURL *)url withCompletion:(PWRequestDownloadCompleteBlock)completion {
    _downloadRequestCount++;

    if (!completion) {
        return;
    }

    if (self.defersDownloads) {
        [self.parkedDownloads addObject:completion];
        return;
    }

    completion(nil, [NSError errorWithDomain:@"pushwoosh" code:-2 userInfo:@{NSLocalizedDescriptionKey : @"Testing download error"}]);
}

- (void)releaseDownloadsWithLocation:(NSString *)location error:(NSError *)error {
    NSArray<PWRequestDownloadCompleteBlock> *parked = [self.parkedDownloads copy];
    [self.parkedDownloads removeAllObjects];
    for (PWRequestDownloadCompleteBlock block in parked) {
        block(location, error);
    }
}

@end
