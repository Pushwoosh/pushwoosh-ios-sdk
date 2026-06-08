/*
 *  PWSessionRetrySender.m
 *  Pushwoosh
 *
 *  Created by André Kis
 */

#import "PWSessionRetrySender.h"
#import "PWRetryPolicy.h"
#import <PushwooshCore/PWRequest.h>
#import <PushwooshCore/PWRequestManager.h>

@interface PWSessionRetrySender ()
@property (nonatomic, weak) PWRequestManager *requestManager;
@property (nonatomic, strong) PWRetryPolicy *policy;
@end

@implementation PWSessionRetrySender

- (instancetype)initWithRequestManager:(PWRequestManager *)requestManager
                                policy:(PWRetryPolicy *)policy {
    if (self = [super init]) {
        _requestManager = requestManager;
        _policy = policy;
        _retryDelaysSeconds = @[@1, @5, @10];
    }
    return self;
}

- (void)sendWithRetry:(PWRequest *)request completion:(void (^)(NSError *))completion {
    [self attemptSend:request attempt:0 completion:completion];
}

- (void)attemptSend:(PWRequest *)request attempt:(NSUInteger)attempt completion:(void (^)(NSError *))completion {
    request.retryCount = (NSInteger)attempt;
    __weak typeof(self) wSelf = self;
    [self.requestManager sendRequest:request completion:^(NSError *error) {
        typeof(self) sSelf = wSelf;
        if (sSelf == nil) {
            if (completion) completion(error);
            return;
        }

        BOOL shouldRetry = error != nil
            && attempt < sSelf.retryDelaysSeconds.count
            && [sSelf.policy shouldRetryStatusCode:request.httpCode error:error];

        if (!shouldRetry) {
            if (completion) completion(error);
            return;
        }

        NSTimeInterval delay = sSelf.retryDelaysSeconds[attempt].doubleValue;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [wSelf attemptSend:request attempt:attempt + 1 completion:completion];
        });
    }];
}

@end
