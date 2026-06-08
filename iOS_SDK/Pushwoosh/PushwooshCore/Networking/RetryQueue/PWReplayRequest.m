/*
 *  PWReplayRequest.m
 *  Pushwoosh
 *
 *  Created by André Kis
 */

#import "PWReplayRequest.h"

@interface PWRequest (PWInternalIdentifier)
- (void)setRequestIdentifier:(NSString *)requestIdentifier;
@end

@implementation PWReplayRequest {
    NSString *_replayMethodName;
    NSDictionary *_replayRequestDictionary;
    BOOL _replayShouldWrapRequest;
    NSString *_replayBaseUrl;
}

- (instancetype)initWithMethodName:(NSString *)methodName
                 requestDictionary:(NSDictionary *)requestDictionary
                 requestIdentifier:(NSString *)requestIdentifier {
    return [self initWithMethodName:methodName
                 requestDictionary:requestDictionary
                 requestIdentifier:requestIdentifier
                 shouldWrapRequest:YES
                           baseUrl:nil];
}

- (instancetype)initWithMethodName:(NSString *)methodName
                 requestDictionary:(NSDictionary *)requestDictionary
                 requestIdentifier:(NSString *)requestIdentifier
                 shouldWrapRequest:(BOOL)shouldWrapRequest
                           baseUrl:(NSString *)baseUrl {
    if (self = [super init]) {
        _replayMethodName = [methodName copy];
        _replayRequestDictionary = [requestDictionary copy];
        _replayShouldWrapRequest = shouldWrapRequest;
        _replayBaseUrl = [baseUrl copy];
        self.requestIdentifier = requestIdentifier;
        self.cacheable = NO;
    }
    return self;
}

- (NSString *)methodName {
    return _replayMethodName;
}

- (NSDictionary *)requestDictionary {
    return _replayRequestDictionary;
}

- (BOOL)shouldWrapRequest {
    return _replayShouldWrapRequest;
}

- (NSString *)baseUrl {
    return _replayBaseUrl;
}

@end
