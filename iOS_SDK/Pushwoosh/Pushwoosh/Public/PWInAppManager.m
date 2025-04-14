//
//  InAppManager.m
//  PushNotificationManager
//
//  Created by Dmitry Malugin on 30/01/17.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWInAppManager.h"
#import "PWInAppMessagesManager.h"
#import "PWInAppManager+Internal.h"

#if TARGET_OS_IOS || TARGET_OS_OSX

#import "PWInAppStorage.h"
#import "PWMessageViewController.h"

#endif

#if TARGET_OS_IOS

#import "PWRichMediaStyle.h"

#endif

#if TARGET_OS_IOS
@implementation PWJavaScriptCallback

- (NSString*) execute {
    [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"STUB!"];
	return nil;
}

- (NSString*) executeWithParam: (NSString*) param {
    [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"STUB!"];
	return nil;
}
- (NSString*) executeWithParams: (NSArray*) params {
    [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"STUB!"];
	return nil;
}

@end
#endif

@implementation PWInAppManager

static PWInAppManager *inAppManagerInstance;
static dispatch_once_t inAppManagerOnceToken;

+ (instancetype)sharedManager {
	
	dispatch_once(&inAppManagerOnceToken, ^{
		inAppManagerInstance = [PWInAppManager new];
	});
	
	return inAppManagerInstance;
}

- (id)init {
	self = [super init];
	if (self) {
		self.inAppMessagesManager = [PWInAppMessagesManager new];
	}
	return self;
}

// used only to update instance when app code changes dynamically, so we can still keep dispatch_once in sharedManager
+ (void)updateInAppManagerInstance {
    [PWInAppManager destroy];
    [PWInAppManager sharedManager];
}

- (void)resetBusinessCasesFrequencyCapping {
    [self.inAppMessagesManager resetBusinessCasesFrequencyCapping];
}

- (void)setUserId:(NSString *)userId {
    [self setUserId:userId completion:nil];
}

- (void)setUserId:(NSString *)userId completion:(void(^)(NSError * error))completion {
	[self.inAppMessagesManager setUserId:userId completion:completion];
}

- (void)mergeUserId:(NSString *)oldUserId to:(NSString *)newUserId doMerge:(BOOL)doMerge completion:(void (^)(NSError *error))completion {
	[self.inAppMessagesManager mergeUserId:oldUserId to:newUserId doMerge:doMerge completion:completion];
}

- (void)setUser:(NSString *)userId emails:(NSArray *)emails completion:(void(^)(NSError * error))completion {
    [self.inAppMessagesManager setUser:userId emails:emails completion:completion];
}

- (void)setEmails:(NSArray *)emails completion:(void(^)(NSError * error))completion {
    [self.inAppMessagesManager setEmails:emails completion:completion];
}

- (void)postEvent:(NSString *)event withAttributes:(NSDictionary *)attributes completion:(void (^)(NSError *error))completion {
	[self.inAppMessagesManager postEvent:event withAttributes:attributes completion:completion];
}

- (void)postEvent:(NSString *)event withAttributes:(NSDictionary *)attributes {
	[self postEvent:event withAttributes:attributes completion:nil];
}

#if TARGET_OS_IOS
- (void)addJavascriptInterface:(NSObject*)interface withName:(NSString*)name {
	[self.inAppMessagesManager addJavascriptInterface:interface withName:name];
}
#endif

- (void)reloadInAppsWithCompletion: (void (^)(NSError *error))completion {
    [self.inAppMessagesManager reloadInAppsWithCompletion: completion];
}

+ (void)destroy {
	inAppManagerOnceToken = 0;
	inAppManagerInstance = nil;
}

@end
