//
//  PWDataManager.m
//  PushNotificationManager
//
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWDataManager.common.h"
#import <PushwooshCore/PWManagerBridge.h>
#import "PWCache.h"
#import "PWRequestManager.h"
#import "PWNetworkModule.h"
#import "PWGetTagsRequest.h"
#import "PWSetTagsRequest.h"
#import "PWPushStatRequest.h"
#import "PWAppOpenRequest.h"
#import "PWVersionTracking.h"
#import "PWPlatformModule.h"
#import "PWPreferences.h"
#import "PWConfig.h"
#import "PWSetEmailTagsRequest.h"
#import "PWLiveActivityRequest.h"
#import "PWStartLiveActivityRequest.h"

#if TARGET_OS_IOS || TARGET_OS_OSX
#import "PWBusinessCaseManager.h"
#import "PWGetConfigRequest.h"
#endif

#import "PWAppLifecycleTrackingManager.h"

#if TARGET_OS_IOS || TARGET_OS_TV
#import "PWScreenTrackingManager.h"
#endif

@interface PWDataManagerCommon()

// @Inject
@property (nonatomic, strong) PWRequestManager *requestManager;
@property (nonatomic) BOOL appOpenDidSent;

@end

@implementation PWDataManagerCommon {
    id _communicationStartedHandler;
}

@dynamic requestManager;

- (PWRequestManager *)requestManager {
    return [PWNetworkModule module].requestManager;
}

- (instancetype)init {
	self = [super init];
	if (self) {
        [[NSOperationQueue currentQueue] addOperationWithBlock:^{
            if ([[PWConfig config] isCollectingLifecycleEventsAllowed] == YES) {
                [self defaultEvents];
            }
        }];
	}
	return self;
}

- (void)defaultEvents {
    [PWAppLifecycleTrackingManager sharedManager].defaultAppClosedAllowed = YES;
    [PWAppLifecycleTrackingManager sharedManager].defaultAppOpenAllowed = YES;
    [PWScreenTrackingManager sharedManager].defaultScreenOpenAllowed = YES;
}

- (void)addServerCommunicationStartedObserver {
    if (!_communicationStartedHandler) {
        _communicationStartedHandler = [[NSNotificationCenter defaultCenter] addObserverForName:kPWServerCommunicationStarted object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {

            [[NSNotificationCenter defaultCenter] removeObserver:_communicationStartedHandler];
            _communicationStartedHandler = nil;
        }];
    }
}

- (void)setTags:(NSDictionary *)tags {
	[self setTags:tags withCompletion:nil];
}

- (void)setTags:(NSDictionary *)tags withCompletion:(PushwooshErrorHandler)completion {
	if (![tags isKindOfClass:[NSDictionary class]]) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"tags must be NSDictionary"];
		return;
	}

	[[PWCache cache] addTags:tags];

	PWSetTagsRequest *request = [[PWSetTagsRequest alloc] init];
	request.tags = tags;

	[self.requestManager sendRequest:request completion:^(NSError *error) {
		if (error) {
            [PushwooshLog pushwooshLog:PW_LL_ERROR
                             className:self
                               message:@"setTags failed"];
        } else {
            [PushwooshLog pushwooshLog:PW_LL_INFO
                             className:self
                               message:[NSString stringWithFormat:@"Tags successfully set: %@", tags]];
        }

		if (completion)
			completion(error);
	}];
}

- (void)loadTags {
	[self loadTags:nil error:nil];
}

- (void)loadTags:(PushwooshGetTagsHandler)successHandler error:(PushwooshErrorHandler)errorHandler {
	PWGetTagsRequest *request = [[PWGetTagsRequest alloc] init];
	[self.requestManager sendRequest:request completion:^(NSError *error) {
		if (error == nil && [request.tags isKindOfClass:[NSDictionary class]]) {
			[[PWCache cache] setTags:request.tags];

			if ([[PWManagerBridge shared].delegate respondsToSelector:@selector(onTagsReceived:)]) {
				NSDictionary *tags = request.tags;
				NSMethodSignature *signature = [[PWManagerBridge shared].delegate methodSignatureForSelector:@selector(onTagsReceived:)];
				NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
				[invocation setSelector:@selector(onTagsReceived:)];
				[invocation setTarget:[PWManagerBridge shared].delegate];
				[invocation setArgument:&tags atIndex:2];
				[invocation invoke];
			}

			if (successHandler) {
				successHandler(request.tags);
			}

		} else {
			NSDictionary *tags = [[PWCache cache] getTags];
			if (tags) {
                [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"loadTags failed, return cached tags"];

				if ([[PWManagerBridge shared].delegate respondsToSelector:@selector(onTagsReceived:)]) {
					NSMethodSignature *signature = [[PWManagerBridge shared].delegate methodSignatureForSelector:@selector(onTagsReceived:)];
					NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
					[invocation setSelector:@selector(onTagsReceived:)];
					[invocation setTarget:[PWManagerBridge shared].delegate];
					[invocation setArgument:&tags atIndex:2];
					[invocation invoke];
				}

				if (successHandler) {
					successHandler(tags);
				}
			} else {
                [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"loadTags failed"];

				if ([[PWManagerBridge shared].delegate respondsToSelector:@selector(onTagsFailedToReceive:)]) {
					NSMethodSignature *signature = [[PWManagerBridge shared].delegate methodSignatureForSelector:@selector(onTagsFailedToReceive:)];
					NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
					[invocation setSelector:@selector(onTagsFailedToReceive:)];
					[invocation setTarget:[PWManagerBridge shared].delegate];
					[invocation setArgument:&error atIndex:2];
					[invocation invoke];
				}

				if (errorHandler) {
				   errorHandler(error);
				}
			}
		}
	}];
}

- (void)setEmailTags:(NSDictionary *)tags forEmail:(NSString *)email {
    [self setEmailTags:tags forEmail:email withCompletion:nil];
}

- (void)setEmailTags:(NSDictionary *)tags forEmail:(NSString *)email withCompletion:(PushwooshErrorHandler)completion {
    if (![tags isKindOfClass:[NSDictionary class]]) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"tags must be NSDictionary"];
        return;
    }
    
    if (email == nil) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"email cannot be nil"];
        return;
    }
    
    [[PWCache cache] addEmailTags:tags];
    
    PWSetEmailTagsRequest *request = [[PWSetEmailTagsRequest alloc] init];
    request.tags = tags;
    request.email = email;
    
    [self.requestManager sendRequest:request completion:^(NSError *error) {
        if (error == nil) {
            [PushwooshLog pushwooshLog:PW_LL_INFO
                             className:self
                               message:[NSString stringWithFormat:@"Email tags successfully set for email: %@ with tags: %@", email, tags]];
        } else {
            [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"setEmailTags failed"];
        }
        
        if (completion)
            completion(error);
    }];
    [[PWCache cache] getEmailTags];
}

- (void)sendAppOpenWithCompletion:(void (^)(NSError *error))completion {
    if (![[PWServerCommunicationManager sharedInstance] isServerCommunicationAllowed]) {
        return;
    }
    if (_appOpenDidSent) {
        return;
    }
    
    _appOpenDidSent = YES;
    
    [PWVersionTracking track];
    
    #if TARGET_OS_IOS || TARGET_OS_OSX
    
    [[PWBusinessCaseManager sharedManager] startBusinessCase:kPWWelcomeBusinessCase completion:^(PWBusinessCaseResult result) {
        if (result == PWBusinessCaseResultConditionFail) {
            [[PWBusinessCaseManager sharedManager] startBusinessCase:kPWUpdateBusinessCase completion:nil];
        }
    }];
    
    #endif
    
    //it's ok to call this method without push token
    PWAppOpenRequest *request = [[PWAppOpenRequest alloc] init];
    
    [self.requestManager sendRequest:request completion:^(NSError *error) {
        if (error == nil) {
            #if TARGET_OS_IOS || TARGET_OS_OSX
            [[PWBusinessCaseManager sharedManager] handleBusinessCaseResources:request.businessCasesDict];
            #endif
            
            if (!error) {
                if ([PWPreferences preferences].previosHWID) {
                    [self performDeviceMigrationWithCompletion:^(NSError *error) {
                        if (!error) {
                            [[PWPreferences preferences] saveCurrentHWIDtoUserDefaults]; //forget previous HWID
                            
                            if ([PWManagerBridge shared].getPushToken) {
                                [PWPreferences preferences].lastRegTime = nil;
                                [[PWManagerBridge shared] registerForPushNotifications];
                            }
                        }
                    }];
                }
            }
        } else {
            [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"sending appOpen failed"];
        }
        
        if (completion) {
            completion(error);
        }
    }];
    
    [self loadTags]; //we need to initially load and cache tags for personalized in-apps
}

- (void)performDeviceMigrationWithCompletion:(void (^)(NSError *error))completion {
    PWGetTagsRequest *request = [PWGetTagsRequest new];
    request.usePreviousHWID = YES;
    [self.requestManager sendRequest:request completion:^(NSError *error) {
        if (error) {
            if (completion) {
                completion(error);
            }
        } else if (request.tags) {
            [self setTags:request.tags withCompletion:completion];
        }
    }];
}

- (void)sendStatsForPush:(NSDictionary *)pushDict {
    NSDictionary *apsDict = [pushDict pw_dictionaryForKey:@"aps"];
    BOOL isContentAvailable = [[apsDict objectForKey:@"content-available"] boolValue];
    
    NSString *alert = pushDict[@"alert"];
    
    if (isContentAvailable && !alert) { //is silent push
        return;
    }
    
    if (pushDict[@"pw_msg"] == nil) { // not Pushwoosh push
        return;
    }
    
    if ([_lastHash isEqualToString:pushDict[@"p"]]){
        return;
    }
    
    _lastHash = pushDict[@"p"];
    
    NSDictionary *richMedia = pushDict[@"rm"];
    NSString *url = richMedia[@"url"];
    
    if (url) {
        NSString *code = [[url lastPathComponent] stringByDeletingPathExtension];
        _richMediaCode = code;
    }
    
    dispatch_block_t sendPushStatBlock = ^{
        PWPushStatRequest *request = [[PWPushStatRequest alloc] init];
        request.pushDict = pushDict;

        [self.requestManager sendRequest:request completion:^(NSError *error) {
            if (error) {
                [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"sendStats failed"];
            } else {
                [PushwooshLog pushwooshLog:PW_LL_INFO
                                 className:self
                                   message:[NSString stringWithFormat:@"sendStats executed with parameters: %@", pushDict]];
            }
        }];
    };

#if TARGET_OS_IOS
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), sendPushStatBlock);
    }
    else
#endif
    {
        sendPushStatBlock();
    }
}

- (void)sendPushToStartLiveActivityToken:(NSString *)token completion:(void (^)(NSError * _Nullable))completion {
    [self.requestManager sendRequest:[self sendStartLiveActivityRequestWithToken:token] completion:^(NSError *error) {
        if (error) {
            [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"Start Live Activity request failed"];
        }
        
        if (completion)
            completion(error);
    }];
}

- (void)startLiveActivityWithToken:(NSString *)token activityId:(NSString *)activityId completion:(void (^)(NSError * _Nullable))completion {
    [self.requestManager sendRequest:[self sendLiveActivityRequestWithToken:token activityId:activityId] completion:^(NSError *error) {
        if (error) {
            [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"Live Activity request failed"];
        }
        
        if (completion)
            completion(error);
    }];
}

- (void)stopLiveActivityWith:(NSString * _Nullable)activityId completion:(void (^)(NSError * _Nullable))completion {
    NSString *activityIdentifier = activityId == nil ? nil : activityId;
    [self.requestManager sendRequest:[self sendLiveActivityRequestWithToken:nil activityId:activityIdentifier] completion:^(NSError *error) {
        if (error) {
            [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"Live Activity request failed"];
        }
        
        if (completion)
            completion(error);
    }];
}

- (PWLiveActivityRequest *)sendLiveActivityRequestWithToken:(NSString *)token activityId:(NSString *)activityId {
    PWLiveActivityRequest *request = [[PWLiveActivityRequest alloc] init];
    request.token = token;
    request.activityId = activityId;
    
    return request;
}

- (PWStartLiveActivityRequest *)sendStartLiveActivityRequestWithToken:(NSString *)token {
    PWStartLiveActivityRequest *request = [[PWStartLiveActivityRequest alloc] init];
    request.token = token;
    
    return request;
}

@end
