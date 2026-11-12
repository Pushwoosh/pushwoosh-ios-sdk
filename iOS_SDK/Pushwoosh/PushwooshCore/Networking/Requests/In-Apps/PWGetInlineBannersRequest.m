//
//  PWGetInlineBannersRequest.m
//  PushwooshCore
//
//  Created by André Kis on 30.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import "PWGetInlineBannersRequest.h"

#if TARGET_OS_IOS

#import "PWConfig.h"
#import "PWGetFeatureFlagsRequest.h"
#import "PWNetworkModule.h"
#import "PWPreferences.h"
#import "PWRequest+Internal.h"

@implementation PWGetInlineBannersRequest

- (instancetype)initWithSlots:(NSArray<NSString *> *)slots formats:(NSArray<NSString *> *)formats {
    self = [super init];
    if (self) {
        _slots = [slots copy];
        _formats = [formats copy];
    }
    return self;
}

- (NSString *)methodName {
    return @"getInlineBanners";
}

- (BOOL)shouldWrapRequest {
    return NO;
}

- (BOOL)followsServerBaseUrl {
    return NO;
}

+ (NSString *)endpointForRequest:(PWRequest *)request {
    NSString *inlineUrl = [PWConfig config].inlineUrl;
    if (inlineUrl.length > 0) {
        return [inlineUrl hasSuffix:@"/"] ? inlineUrl : [inlineUrl stringByAppendingString:@"/"];
    }
    PWRequestManager *requestManager = [PWNetworkModule module].requestManager;
    NSString *endpoint = [PWGetFeatureFlagsRequest endpointForBaseUrl:request.pinnedBaseUrl ?: [requestManager baseUrl]
                                                      viaReverseProxy:[requestManager isUsingReverseProxy]
                                                              appCode:request.pinnedAppCode ?: [PWPreferences preferences].appCode ?: @""];
    return endpoint ?: @"";
}

- (NSString *)baseUrl {
    return [PWGetInlineBannersRequest endpointForRequest:self];
}

- (NSDictionary *)requestDictionary {
    NSMutableDictionary *dict = [self baseDictionary];
    dict[@"slots"] = _slots;
    dict[@"formats"] = _formats;
    dict[@"nativeVersion"] = @1;
    return dict;
}

- (void)parseResponse:(NSDictionary *)response {
    id slots = response[@"slots"];
    _slotsResponse = [slots isKindOfClass:[NSDictionary class]] ? slots : nil;
}

@end

#endif
