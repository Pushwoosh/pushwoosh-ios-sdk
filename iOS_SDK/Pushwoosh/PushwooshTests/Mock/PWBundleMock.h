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

@end
