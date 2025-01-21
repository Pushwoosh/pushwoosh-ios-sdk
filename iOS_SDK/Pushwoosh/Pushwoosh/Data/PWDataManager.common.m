//
//  PWDataManager.m
//  PushNotificationManager
//
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWDataManager.common.h"
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
#import "PWServerCommunicationManager.h"
#import "PWLiveActivityRequest.h"
#import "PWStartLiveActivityRequest.h"

#if TARGET_OS_IOS || TARGET_OS_OSX
#import "PWBusinessCaseManager.h"
#import "PWGetConfigRequest.h"
#endif

#if TARGET_OS_IOS
#import "PWAppLifecycleTrackingManager.h"
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

- (instancetype)init {
	self = [super init];
	if (self) {
		[[PWNetworkModule module] inject:self];
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
		PWLogError(@"tags must be NSDictionary");
		return;
	}

	[[PWCache cache] addTags:tags];

	PWSetTagsRequest *request = [[PWSetTagsRequest alloc] init];
	request.tags = tags;

	[_requestManager sendRequest:request completion:^(NSError *error) {
		if (error) {
			PWLogError(@"setTags failed");
        } else {
            PWLogInfo(@"Tags successfully set: %@", tags);
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
	[_requestManager sendRequest:request completion:^(NSError *error) {
		if (error == nil && [request.tags isKindOfClass:[NSDictionary class]]) {
			[[PWCache cache] setTags:request.tags];

			if ([[PushNotificationManager pushManager].delegate respondsToSelector:@selector(onTagsReceived:)]) {
				[[PushNotificationManager pushManager].delegate onTagsReceived:request.tags];
			}

			if (successHandler) {
				successHandler(request.tags);
			}

		} else {
			NSDictionary *tags = [[PWCache cache] getTags];
			if (tags) {
                PWLogError(@"loadTags failed, return cached tags");

				if ([[PushNotificationManager pushManager].delegate respondsToSelector:@selector(onTagsReceived:)]) {
					[[PushNotificationManager pushManager].delegate onTagsReceived:tags];
				}

				if (successHandler) {
					successHandler(tags);
				}
			} else {
				PWLogError(@"loadTags failed");

				if ([[PushNotificationManager pushManager].delegate respondsToSelector:@selector(onTagsFailedToReceive:)]) {
				   [[PushNotificationManager pushManager].delegate onTagsFailedToReceive:error];
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
        PWLogError(@"tags must be NSDictionary");
        return;
    }
    
    if (email == nil) {
        PWLogError(@"email cannot be nil");
        return;
    }
    
    [[PWCache cache] addEmailTags:tags];
    
    PWSetEmailTagsRequest *request = [[PWSetEmailTagsRequest alloc] init];
    request.tags = tags;
    request.email = email;
    
    [_requestManager sendRequest:request completion:^(NSError *error) {
        if (error == nil) {
            PWLogInfo(@"Email tags successfully set for email: %@ with tags: %@", email, tags);
        } else {
            PWLogError(@"setEmailTags failed");
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
    
    [_requestManager sendRequest:request completion:^(NSError *error) {
        if (error == nil) {
            #if TARGET_OS_IOS || TARGET_OS_OSX
            [[PWBusinessCaseManager sharedManager] handleBusinessCaseResources:request.businessCasesDict];
            #endif
            
            if (!error) {
                if ([PWPreferences preferences].previosHWID) {
                    [self performDeviceMigrationWithCompletion:^(NSError *error) {
                        if (!error) {
                            [[PWPreferences preferences] saveCurrentHWIDtoUserDefaults]; //forget previous HWID
                            
                            if ([PushNotificationManager pushManager].getPushToken) {
                                [PWPreferences preferences].lastRegTime = nil;
                                [[PushNotificationManager pushManager] registerForPushNotifications];
                            }
                        }
                    }];
                }
            }
        } else {
            PWLogError(@"sending appOpen failed");
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
    [_requestManager sendRequest:request completion:^(NSError *error) {
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
        
        [_requestManager sendRequest:request completion:^(NSError *error) {
            if (error) {
                PWLogError(@"sendStats failed");
            } else {
                PWLogInfo(@"sendStats executed with parameters: %@", pushDict);
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
    [_requestManager sendRequest:[self sendStartLiveActivityRequestWithToken:token] completion:^(NSError *error) {
        if (error) {
            PWLogError(@"Start Live Activity request failed");
        }
        
        if (completion)
            completion(error);
    }];
}

- (void)startLiveActivityWithToken:(NSString *)token activityId:(NSString *)activityId completion:(void (^)(NSError * _Nullable))completion {
    [_requestManager sendRequest:[self sendLiveActivityRequestWithToken:token activityId:activityId] completion:^(NSError *error) {
        if (error) {
            PWLogError(@"Live Activity request failed");
        }
        
        if (completion)
            completion(error);
    }];
}

- (void)stopLiveActivityWith:(NSString * _Nullable)activityId completion:(void (^)(NSError * _Nullable))completion {
    NSString *activityIdentifier = activityId == nil ? nil : activityId;
    [_requestManager sendRequest:[self sendLiveActivityRequestWithToken:nil activityId:activityIdentifier] completion:^(NSError *error) {
        if (error) {
            PWLogError(@"Live Activity request failed");
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
