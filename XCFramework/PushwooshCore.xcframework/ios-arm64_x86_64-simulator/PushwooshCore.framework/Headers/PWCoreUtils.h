//
//  PWCUtils.h
//  PushwooshCore
//
//  Created by André Kis on 10.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const PWCoreErrorDomain;

NS_ERROR_ENUM(PWCoreErrorDomain)
{
    PWCoreErrorUnknown = -1,
    PWCoreErrorCommunicationDisabled = -2,
    PWCoreErrorDeviceDataHasBeenRemoved = -3,
    PWCoreErrorGDPRNotAvailable = -4
};

@interface PWCoreUtils : NSObject

+ (NSString *)uniqueGlobalDeviceIdentifier;

+ (BOOL)isValidHwid:(NSString*)hwid;

+ (BOOL)isSystemVersionGreaterOrEqualTo:(NSString *)systemVersion;

+ (NSString *)preferredLanguage;

+ (BOOL)getAPSProductionStatus:(BOOL)canShowAlert;

+ (NSError *)pushwooshError:(NSString *)description;

+ (NSError *)pushwooshErrorWithCode:(NSInteger)errorCode description:(NSString *)description;

+ (NSString *)timezone;

@end

NS_ASSUME_NONNULL_END
