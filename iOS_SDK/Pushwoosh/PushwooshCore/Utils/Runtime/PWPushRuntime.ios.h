//
//  PWPushRuntime.ios.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import <PushwooshCore/PushwooshLog.h>
#import <PushwooshCore/PWPreferences.h>

@interface PWPushRuntime : NSObject

+ (void)swizzleNotificationSettingsHandler;

/// Installs the device token hook on `delegateClass` once; a repeated call for the same class is a no-op.
+ (void)swizzleDeviceTokenHandlerForDelegateClass:(Class)delegateClass;

@end
