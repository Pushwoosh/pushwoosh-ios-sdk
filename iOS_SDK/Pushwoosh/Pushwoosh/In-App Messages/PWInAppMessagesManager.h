//
//  PushNotificationManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2016
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PushwooshLog.h>

FOUNDATION_EXPORT NSString * const PW_INAPP_ACTION_SHOW;

@interface PWInAppMessagesManager : NSObject

- (void)resetBusinessCasesFrequencyCapping;

- (void)setUserId:(NSString*)userId completion:(void (^)(NSError* error))completion;

- (void)mergeUserId:(NSString*)oldUserId to:(NSString*)newUserId doMerge:(BOOL)doMerge completion:(void (^)(NSError* error))completion;

- (void)setUser:(NSString *)userId emails:(NSArray *)emails completion:(void(^)(NSError * error))completion;

- (void)setEmails:(NSArray *)emails completion:(void(^)(NSError * error))completion;

- (void)postEvent:(NSString*)event withAttributes:(NSDictionary*)attributes completion:(void (^)(NSError* error))completion;

- (void)postEventInternal:(NSString *)event withAttributes:(NSDictionary *)attributes isInlineInApp:(BOOL)isInlineInApp completion:(void (^)(id resource, NSError *error))completion;

- (void)reloadInAppsWithCompletion:(void (^)(NSError *error)) completion;

#if TARGET_OS_IOS || TARGET_OS_OSX
- (void)presentRichMediaFromPush:(NSDictionary*)userInfo;

- (void)trackInAppWithCode:(NSString *)inAppCode action:(NSString *)action messageHash:(NSString *)messageHash;
#endif

#if TARGET_OS_IOS
- (void)addJavascriptInterface:(NSObject*)interface withName:(NSString*)name;
#endif

@end
