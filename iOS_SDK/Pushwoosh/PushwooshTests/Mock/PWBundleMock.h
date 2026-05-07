//
//  NSBundle+PWNSBundleMock.h
//  PushwooshTests
//
//  Created by Fectum on 20/09/2018.
//  Copyright © 2018 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PWBundleMock : NSBundle

@property (nonatomic) BOOL sendPushStatIfAlertsDisabled;
@property (nonatomic) BOOL sendPurchaseTrackingEnabled;
@property (nonatomic, strong, nullable) NSNumber *idleTimeoutSeconds;
@property (nonatomic, strong, nullable) NSNumber *applicationExitTimeoutSeconds;
@property (nonatomic) BOOL allowCollectingEventsSet;
@property (nonatomic) BOOL allowCollectingEvents;

@property (nonatomic, copy, nullable) NSString *appId;
@property (nonatomic, copy, nullable) NSString *apiToken;
@property (nonatomic, copy, nullable) NSString *pushwooshApiToken;
@property (nonatomic, copy, nullable) NSString *appIdDev;
@property (nonatomic, copy, nullable) NSString *appName;
@property (nonatomic, copy, nullable) NSString *appGroupsName;
@property (nonatomic, copy, nullable) NSString *requestUrl;
@property (nonatomic, copy, nullable) NSString *grpcHost;
@property (nonatomic, copy, nullable) NSString *logLevel;
@property (nonatomic, copy, nullable) NSString *richMediaStyle;

@property (nonatomic, strong, nullable) id appIdRaw;

@end
