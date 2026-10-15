//  PWGetFeatureFlagsRequest.m
//  Created by André Kis

#import "PWGetFeatureFlagsRequest.h"

#if TARGET_OS_IOS

#import "PWFeatureFlag+Internal.h"
#import "PWNetworkModule.h"
#import "PWPreferences.h"
#import "PWRequest+Internal.h"
#import "PushwooshLog.h"

static NSString *const kPWLegacyApiPath = @"json/1.3/";
static NSString *const kPWDeviceApiPath = @"api/v2/device-api/";

@interface PWFeatureFlagsResponse ()

@property (nonatomic, readwrite) NSDictionary<NSString *, PWFeatureFlag *> *flags;
@property (nonatomic, readwrite) NSString *flagsJSON;
@property (nonatomic, readwrite) NSString *etag;
@property (nonatomic, readwrite) BOOL notModified;
@property (nonatomic, readwrite) BOOL partial;

@end

@implementation PWFeatureFlagsResponse

+ (instancetype)responseWithDictionary:(NSDictionary *)dictionary {
    BOOL notModified = [self boolValue:dictionary[@"not_modified"]];
    id flagsObject = dictionary[@"flags"];
    if (![flagsObject isKindOfClass:[NSDictionary class]]) {
        if (!notModified) {
            return nil;
        }
        flagsObject = @{};
    }

    NSDictionary<NSString *, PWFeatureFlag *> *flags = [PWFeatureFlag flagsWithJSONObject:flagsObject];
    NSData *flagsData = flags ? [NSJSONSerialization dataWithJSONObject:flagsObject options:0 error:nil] : nil;
    if (!flagsData) {
        return nil;
    }

    PWFeatureFlagsResponse *response = [self new];
    response.flags = flags;
    response.flagsJSON = [[NSString alloc] initWithData:flagsData encoding:NSUTF8StringEncoding];
    id etag = dictionary[@"etag"];
    response.etag = [etag isKindOfClass:[NSString class]] ? etag : @"";
    response.notModified = notModified;
    response.partial = [self boolValue:dictionary[@"partial"]];
    return response;
}

+ (BOOL)boolValue:(id)value {
    return [value isKindOfClass:[NSNumber class]] && [value boolValue];
}

@end

@interface PWGetFeatureFlagsRequest ()

@property (nonatomic, readwrite) PWFeatureFlagsResponse *response;

@end

@implementation PWGetFeatureFlagsRequest

+ (NSString *)endpointForBaseUrl:(NSString *)baseUrl viaReverseProxy:(BOOL)viaReverseProxy appCode:(NSString *)appCode {
    NSString *base = baseUrl ?: @"";
    if (base.length > 0 && ![base hasSuffix:@"/"]) {
        base = [base stringByAppendingString:@"/"];
    }
    if ([base hasSuffix:kPWLegacyApiPath]) {
        return [[base substringToIndex:base.length - kPWLegacyApiPath.length] stringByAppendingString:kPWDeviceApiPath];
    }
    if (viaReverseProxy) {
        return nil;
    }
    NSString *fallback = [NSString stringWithFormat:@"https://%@.api.pushwoosh.com/%@", appCode, kPWDeviceApiPath];
    [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:[NSString stringWithFormat:@"Base URL does not end with %@, feature flags use %@", kPWLegacyApiPath, fallback]];
    return fallback;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _etag = @"";
    }
    return self;
}

- (NSString *)methodName {
    return @"getFeatureFlags";
}

- (BOOL)shouldWrapRequest {
    return NO;
}

- (BOOL)followsServerBaseUrl {
    return NO;
}

- (NSString *)appCode {
    return self.pinnedAppCode ?: [PWPreferences preferences].appCode ?: @"";
}

- (NSString *)baseUrl {
    PWRequestManager *requestManager = [PWNetworkModule module].requestManager;
    NSString *endpoint = [PWGetFeatureFlagsRequest endpointForBaseUrl:self.pinnedBaseUrl ?: [requestManager baseUrl]
                                                      viaReverseProxy:[requestManager isUsingReverseProxy]
                                                              appCode:self.appCode];
    return endpoint ?: @"";
}

- (NSDictionary *)requestDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"application"] = self.appCode;
    dict[@"hwid"] = [PWPreferences preferences].hwid;
    if (_etag.length > 0) {
        dict[@"etag"] = _etag;
    }
    return dict;
}

- (void)parseResponse:(NSDictionary *)response {
    _response = [PWFeatureFlagsResponse responseWithDictionary:response];
}

@end

#endif
