//
//  PushNotificationManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2016
//

#if TARGET_OS_IOS || TARGET_OS_TV
#import <Foundation/Foundation.h>
#import <PushwooshCore/PushwooshLog.h>
#import <PushwooshCore/PWPreferences.h>

FOUNDATION_EXPORT NSString * const PW_INAPP_ACTION_SHOW;

@interface PWInAppMessagesManager : NSObject

#if TARGET_OS_IOS || TARGET_OS_OSX
- (void)resetBusinessCasesFrequencyCapping;
#endif

- (void)setUserId:(NSString*)userId completion:(void (^)(NSError* error))completion;

- (void)mergeUserId:(NSString*)oldUserId to:(NSString*)newUserId doMerge:(BOOL)doMerge completion:(void (^)(NSError* error))completion;

- (void)setUser:(NSString *)userId emails:(NSArray *)emails completion:(void(^)(NSError * error))completion;

- (void)setEmails:(NSArray *)emails completion:(void(^)(NSError * error))completion;

- (void)postEvent:(NSString*)event withAttributes:(NSDictionary*)attributes completion:(void (^)(NSError* error))completion;

- (void)postEventInternal:(NSString *)event withAttributes:(NSDictionary *)attributes isInlineInApp:(BOOL)isInlineInApp completion:(void (^)(id resource, NSError *error))completion;

- (void)reloadInAppsWithCompletion:(void (^)(NSError *error)) completion;

#if TARGET_OS_IOS || TARGET_OS_OSX
- (void)presentRichMediaFromPush:(NSDictionary*)userInfo;
#endif

#if TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_TV
- (void)trackInAppWithCode:(NSString *)inAppCode action:(NSString *)action messageHash:(NSString *)messageHash;

- (void)richMediaAction:(NSString *)inAppCode richMediaCode:(NSString *)richMediaCode actionType:(NSNumber *)actionType actionAttributes:(NSString *)actionAttributes messageHash:(NSString *)messageHash completion:(void (^)(NSError *error))completion;
#endif

#if TARGET_OS_IOS
- (void)addJavascriptInterface:(NSObject*)interface withName:(NSString*)name;
#endif

@end
#endif
