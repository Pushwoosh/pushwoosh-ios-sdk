//
//  PWDataManager.h
//  PushNotificationManager
//
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PushwooshLog.h>
#import <PushwooshCore/PWPreferences.h>
#import <PushwooshCore/PWServerCommunicationManager.h>
#import <PushwooshCore/PWTypes.h>

NS_ASSUME_NONNULL_BEGIN

@interface PWDataManager : NSObject

@property (nonatomic, readonly, nullable) NSString *lastHash;
@property (nonatomic, readonly, nullable) NSString *richMediaCode;
@property (nonatomic, readonly, nullable) NSArray<NSString *> *events;
@property (nonatomic, readonly) BOOL isLoggerActive;

- (void)setTags:(NSDictionary *)tags;

- (void)setTags:(NSDictionary *)tags withCompletion:(nullable PushwooshErrorHandler)completion;

- (void)loadTags;

- (void)loadTags:(nullable PushwooshGetTagsHandler)successHandler error:(nullable PushwooshErrorHandler)errorHandler;

- (void)setEmailTags:(NSDictionary *)tags forEmail:(NSString *)email;

- (void)setEmailTags:(NSDictionary *)tags forEmail:(NSString *)email withCompletion:(nullable PushwooshErrorHandler)completion;

- (void)sendAppOpenWithCompletion:(nullable void (^)(NSError * _Nullable error))completion;

- (void)sendStatsForPush:(NSDictionary *)pushDict;

/// The same statistics, with an answer: completion runs once the request has been answered, success or
/// error — the error path having already queued the request for retry — or right away when there is
/// nothing to send. A caller with a completion is a notification response that iOS ends as soon as its
/// own handler returns, so the one-second background delay is skipped for it.
- (void)sendStatsForPush:(NSDictionary *)pushDict completion:(nullable void (^)(void))completion;

- (void)sendPushToStartLiveActivityToken:(nullable NSString *)token completion:(nullable void (^)(NSError * _Nullable))completion;

- (void)startLiveActivityWithToken:(nullable NSString *)token activityId:(nullable NSString *)activityId completion:(nullable void (^)(NSError * _Nullable error))completion;

- (void)stopLiveActivityWith:(nullable NSString *)activityId completion:(nullable void (^)(NSError * _Nullable))completion;

@end

NS_ASSUME_NONNULL_END
