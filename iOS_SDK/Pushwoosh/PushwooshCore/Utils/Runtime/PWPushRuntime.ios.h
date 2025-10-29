//
//  PushRuntime.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import <PushwooshCore/PushwooshLog.h>
#import <PushwooshCore/PWPreferences.h>

@interface PWPushRuntime : NSObject

+ (void)swizzleNotificationSettingsHandler;

+ (BOOL)isSelfTestEnabled;

@end
