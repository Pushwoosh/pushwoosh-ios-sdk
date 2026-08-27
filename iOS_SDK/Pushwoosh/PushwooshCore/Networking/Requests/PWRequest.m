//
//  PWRequest.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWRequest.h"

#import "Constants.h"
#import "PWUtils.h"
#import <PushwooshCore/PushwooshCore.h>

@interface PWRequest ()

@property (nonatomic, copy) NSString *requestIdentifier;
@property (nonatomic, copy) NSString *pinnedAppCode;
@property (nonatomic, copy) NSString *pinnedBaseUrl;
@property (nonatomic, copy) NSString *pinnedUserId;
@property (nonatomic, assign) BOOL survivesApplicationChange;

@end

@implementation PWRequest

- (NSString *)uid {
    return [self methodName];
}

- (NSString *)methodName {
	return @"";
}

- (NSString *)baseUrl {
	return _pinnedBaseUrl;
}

- (BOOL)shouldWrapRequest {
	return YES;
}

- (NSString *)requestIdentifier {
    @synchronized (self) {
        if (!_requestIdentifier) {
            _requestIdentifier = [[NSUUID UUID] UUIDString];
        }
        return _requestIdentifier;
    }
}

//Please note that all values will be processed as strings
- (NSDictionary *)requestDictionary {
	return nil;
}

- (NSMutableDictionary *)baseDictionary {
	NSMutableDictionary *dict = [NSMutableDictionary new];

	dict[@"userId"] = _pinnedUserId ?: [PWPreferences preferences].userId;
	dict[@"application"] = _pinnedAppCode ?: [PWPreferences preferences].appCode;

    if (_usePreviousHWID && [PWUtils isValidHwid:[PWPreferences preferences].previosHWID]) {
        dict[@"hwid"] = [PWPreferences preferences].previosHWID;
    } else {
        dict[@"hwid"] = [PWPreferences preferences].hwid;
    }

	dict[@"v"] = PUSHWOOSH_VERSION;
	dict[@"device_type"] = @(DEVICE_TYPE);

	return dict;
}

- (void)parseResponse:(NSDictionary *)response {
}

@end
