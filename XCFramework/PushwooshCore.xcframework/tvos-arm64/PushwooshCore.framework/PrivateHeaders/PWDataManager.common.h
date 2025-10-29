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
#import <PushwooshCore/PWChannel.h>
#import <PushwooshCore/PWTypes.h>

@interface PWDataManagerCommon : NSObject

@property (nonatomic, readonly) NSString *lastHash;
@property (nonatomic, readonly) NSString *richMediaCode;
@property (nonatomic, readonly) NSArray<PWChannel *> *channels;
@property (nonatomic, readonly) NSArray<NSString *> *events;
@property (nonatomic, readonly) BOOL isLoggerActive;

- (void)setTags:(NSDictionary *)tags;

- (void)setTags:(NSDictionary *)tags withCompletion:(PushwooshErrorHandler)completion;

- (void)loadTags;

- (void)loadTags:(PushwooshGetTagsHandler)successHandler error:(PushwooshErrorHandler)errorHandler;

- (void)setEmailTags:(NSDictionary *)tags forEmail:(NSString *)email;

- (void)setEmailTags:(NSDictionary *)tags forEmail:(NSString *)email withCompletion:(PushwooshErrorHandler)completion;

- (void)sendAppOpenWithCompletion:(void (^)(NSError *error))completion;

- (void)sendStatsForPush:(NSDictionary *)pushDict;

- (void)sendPushToStartLiveActivityToken:(NSString *_Nullable)token completion:(void (^ _Nullable)(NSError * _Nullable))completion;

- (void)startLiveActivityWithToken:(NSString *_Nullable)token activityId:(NSString *_Nullable)activityId completion:(void (^ _Nullable)(NSError * _Nullable error))completion;

- (void)stopLiveActivityWith:(NSString * _Nullable)activityId completion:(void (^_Nullable)(NSError * _Nullable))completion;

@end
