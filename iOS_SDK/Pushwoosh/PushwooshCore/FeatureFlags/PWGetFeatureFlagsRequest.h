//  PWGetFeatureFlagsRequest.h
//  Created by André Kis

#import <PushwooshCore/PWRequest.h>
#import <PushwooshCore/PWRequestManager.h>

#if TARGET_OS_IOS

@class PWFeatureFlag;

NS_ASSUME_NONNULL_BEGIN

@interface PWRequestManager (FeatureFlags)

- (NSString *)baseUrl;

@end

@interface PWFeatureFlagsResponse : NSObject

@property (nonatomic, readonly) NSDictionary<NSString *, PWFeatureFlag *> *flags;
@property (nonatomic, readonly) NSString *flagsJSON;
@property (nonatomic, readonly) NSString *etag;
@property (nonatomic, readonly) BOOL notModified;
@property (nonatomic, readonly) BOOL partial;

@end

/// `getFeatureFlags` of the device API v2: flat body, sent to the base URL with `json/1.3/` replaced by `api/v2/device-api/`.
@interface PWGetFeatureFlagsRequest : PWRequest

/// `nil` when a reverse proxy URL does not end with `json/1.3/`: flags are never requested past the proxy.
+ (nullable NSString *)endpointForBaseUrl:(nullable NSString *)baseUrl viaReverseProxy:(BOOL)viaReverseProxy appCode:(nullable NSString *)appCode;

@property (nonatomic, copy) NSString *etag;

/// `application` of the body: the pinned application, else the current one.
@property (nonatomic, readonly) NSString *appCode;

/// Set when the response envelope succeeded and its body is a usable flags response.
@property (nonatomic, readonly, nullable) PWFeatureFlagsResponse *response;

@end

NS_ASSUME_NONNULL_END

#endif
