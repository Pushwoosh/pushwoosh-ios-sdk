//
//  PWRequestManagerMock.h
//  PushNotificationManager
//
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWRequestManager.h"

#import <Foundation/Foundation.h>

@interface PWRequestManagerMock : PWRequestManager

@property (atomic, strong) void (^onSendRequest)(PWRequest*);

/// Fallback response for any request that has no entry in responsesByMethod.
@property (nonatomic, strong) NSDictionary *response;

/// Response per `-[PWRequest methodName]`, e.g. @{ @"postEvent": @{@"code": @"inapp-1"} }.
@property (nonatomic, strong) NSDictionary<NSString *, NSDictionary *> *responsesByMethod;

@property (nonatomic, assign) BOOL failed;

/// Requests whose methodName is in this set are parked until -releaseDeferredRequests.
@property (nonatomic, strong) NSSet<NSString *> *deferredMethods;
@property (nonatomic, readonly) NSUInteger deferredRequestCount;
- (void)releaseDeferredRequests;

/// Zip downloads: parked until -releaseDownloadsWithLocation:error: when YES,
/// failed immediately otherwise (never a real network call from a unit test).
@property (nonatomic, assign) BOOL defersDownloads;
@property (nonatomic, readonly) NSUInteger downloadRequestCount;
- (void)releaseDownloadsWithLocation:(NSString *)location error:(NSError *)error;

@end
