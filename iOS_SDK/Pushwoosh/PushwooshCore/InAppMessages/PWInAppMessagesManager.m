//
//  PushNotificationManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#if TARGET_OS_IOS || TARGET_OS_TV
#import "PWInAppMessagesManager.h"

extern NSString * const PWInboxMessagesDidUpdateNotification;

#import "PWPostEventRequest.h"
#import "PWRegisterUserRequest.h"
#import "PWMergeUserRequest.h"
#import "PWUtils.h"
#import "PWPreferences.h"
#import "PWRequestManager.h"
#import "PWConfig.h"
#import "PWNetworkModule.h"
#import <PushwooshCore/PWManagerBridge.h>
#import <PushwooshCore/PWInboxBridge.h>
#import "PWDataManager.h"
#import "PWRichMedia+Internal.h"
#import "PWRegisterEmail.h"
#import "PWRegisterEmailUser.h"
#import "PWRichMediaView.h"
#import "PWModalWindow.h"
#import "PWInteractionDisabledWindow.h"
#import "PWInteractionDisabledView.h"

#if TARGET_OS_IOS || TARGET_OS_OSX
#import "PWTriggerInAppActionRequest.h"
#import "PWRichMediaActionRequest.h"
#import "PWMessageViewController.h"
#import "PWPushManagerJSBridge.h"
#import "PWShowLoading.h"
#import "PWResource.h"
#endif

#if TARGET_OS_TV
#import "PWResource.h"
#import "PWTriggerInAppActionRequest.h"
#import "PWRichMediaActionRequest.h"
#endif

#if TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_TV
#import "PWInAppStorage.h"
#endif

#if TARGET_OS_IOS
#import "PWWebClient.h"
#endif

NSString * const PW_INAPP_ACTION_SHOW = @"com.pushwoosh.PW_INAPP_ACTION_SHOW";
NSString * const PW_DEVICE_RESTORED_KEY = @"device_restored_key";

const NSTimeInterval kRegisterUserUpdateInterval = 24 * 60 * 60;


@interface PWInAppMessagesManager()

@property (nonatomic, strong) PWRequestManager *requestManager;
@property (nonatomic) NSString *trackingAppCode;

#if TARGET_OS_IOS || TARGET_OS_OSX
@property (nonatomic) PWRichMediaView *richMediaView;
@property (nonatomic) PWModalWindow *modalWindow;
@property (nonatomic) NSString *richMediaCode;
@property (nonatomic) NSString *inAppCode;
@property (nonatomic) NSString *postEventInAppCode;
#endif

#if TARGET_OS_TV
@property (nonatomic) NSString *richMediaCode;
@property (nonatomic) NSString *inAppCode;
@property (nonatomic) NSString *postEventInAppCode;
#endif

@end

@implementation PWInAppMessagesManager {
    id _communicationStartedHandler;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [[PWNetworkModule module] inject:self];

        [[PWPreferences preferences] addObserver:self forKeyPath:@"appCode" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:nil];
    }

    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"appCode"]) {
        NSString *appCode = [PWPreferences preferences].appCode;

        if (appCode && ![appCode isEqualToString:@""] && ![[PWPreferences preferences].appCode isEqualToString:_trackingAppCode]) {
            _trackingAppCode = [PWPreferences preferences].appCode;

            dispatch_async(dispatch_get_main_queue(), ^{
                if ([[PWServerCommunicationManager sharedInstance] isServerCommunicationAllowed]) {
                    [self sendInitRequests];
                } else {
                    [self addServerCommunicationStartedObserver];
                }
            });
        }
    }
}

- (void)dealloc {
    [[PWPreferences preferences] removeObserver:self forKeyPath:@"appCode"];
}

- (void)sendInitRequests {
    // resend userId (previous request may be failed)
    [self setUserIdWithDelay:1.0];
#if TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_TV
    if ([[PWServerCommunicationManager sharedInstance] isServerCommunicationAllowed]) {
        [[PWInAppStorage storage] synchronize:^(NSError *error) {}];
    }
#endif
}

- (void)addServerCommunicationStartedObserver {
    if (!_communicationStartedHandler) {
        _communicationStartedHandler = [[NSNotificationCenter defaultCenter] addObserverForName:kPWServerCommunicationStarted object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            
            [[NSNotificationCenter defaultCenter] removeObserver:_communicationStartedHandler];
            _communicationStartedHandler = nil;
            
            [self sendInitRequests];
        }];
    }
}

- (void)setUserIdWithDelay:(double)delayInSeconds {
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if ([PWPreferences preferences].userId == nil) {
            [self setUserId:[PWPreferences preferences].hwid completion:^(NSError *error) {}];
        } else {
            [self setUserId:[PWPreferences preferences].userId completion:^(NSError *error) {}];
        }
    });
}

#if TARGET_OS_IOS
- (void)addJavascriptInterface:(NSObject*)interface withName:(NSString*)name {
    [PWWebClient addJavascriptInterface:interface withName:name];
}
#endif

- (void)postEvent:(NSString *)event withAttributes:(NSDictionary *)attributes completion:(void (^)(NSError *error))completion {
    [self postEventInternal:event withAttributes:attributes completion:^(id resource, NSError *error) {
#if TARGET_OS_TV
        if (!error && resource) {
            dispatch_async(dispatch_get_main_queue(), ^{
                Class tvosImplClass = NSClassFromString(@"PushwooshTVOSImplementation");
                if (tvosImplClass) {
                    SEL sharedSelector = NSSelectorFromString(@"shared");
                    if ([tvosImplClass respondsToSelector:sharedSelector]) {
                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        id sharedInstance = [tvosImplClass performSelector:sharedSelector];

                        SEL richMediaManagerSelector = NSSelectorFromString(@"richMediaManager");
                        if ([sharedInstance respondsToSelector:richMediaManagerSelector]) {
                            id tvosManager = [sharedInstance performSelector:richMediaManagerSelector];
                            SEL handleSelector = NSSelectorFromString(@"handleInAppResource:");
                            if ([tvosManager respondsToSelector:handleSelector]) {
                                [tvosManager performSelector:handleSelector withObject:resource];
                            }
                        }
                        #pragma clang diagnostic pop
                    }
                }
            });
        }
#elif TARGET_OS_IOS || TARGET_OS_OSX
        if (!error && resource)
            dispatch_async(dispatch_get_main_queue(), ^{
                PWRichMedia *richMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourceInApp resource:resource];
                [self richMediaTypeWith:richMedia resource:resource];
            });
#endif
        if (completion)
            completion(error);
    }];
}

- (void)reloadInAppsWithCompletion:(void (^)(NSError *error)) completion {
#if TARGET_OS_IOS || TARGET_OS_OSX
    [[PWInAppStorage storage] synchronize:^(NSError *error) {
        if (completion) {
            completion(error);
        }
    }];
#else
    if (completion) {
        completion(nil);
    }
#endif
}

- (void)postEventInternal:(NSString *)event withAttributes:(NSDictionary *)attributes completion:(void (^)(id resource, NSError *error))completion {
    if (event.length == 0) {
        [PushwooshLog pushwooshLog:PW_LL_WARN
                         className:self
                           message:@"Pushwoosh: Event is missing"];
        completion(nil, [PWUtils pushwooshError:@"Pushwoosh: Event is missing"]);
        return;
    }
    
    if ([[PWPreferences preferences].appCode isEqualToString:@""]) {
        [PushwooshLog pushwooshLog:PW_LL_WARN
                         className:self
                           message:@"Pushwoosh App code is missing. Initialize Pushwoosh manager in application:didFinishLaunchingWithOptions:"];
        completion(nil, [PWUtils pushwooshError:@"Pushwoosh App code is missing"]);
        return;
    }
    
    if (![PWPreferences preferences].userId) {
        [PushwooshLog pushwooshLog:PW_LL_WARN
                         className:self
                           message:@"Pushwoosh: You need to setup UserId, [PWManagerBridge shared] setUserId:]"];
        completion(nil, [PWUtils pushwooshError:@"Pushwoosh User Id is missing"]);
        return;
    }
    
    PWPostEventRequest *request = [PWPostEventRequest new];
    request.event = event;
    NSMutableDictionary *attributesDictionary = [NSMutableDictionary new];
    
    if ([PWManagerBridge shared].dataManager.lastHash) {
        attributesDictionary[@"msgHash"] = [PWManagerBridge shared].dataManager.lastHash;
    }

#if TARGET_OS_IOS || TARGET_OS_OSX
    if ([PWManagerBridge shared].dataManager.richMediaCode) {
        attributesDictionary[@"richMediaCode"] = [PWManagerBridge shared].dataManager.richMediaCode;
    }

    if (self.postEventInAppCode) {
        attributesDictionary[@"inAppCode"] = self.postEventInAppCode;
    }
#endif
    
    if (attributes) {
        [attributesDictionary addEntriesFromDictionary:attributes];
    }
    
    request.attributes = attributesDictionary;
    
    __weak typeof(self) wself = self;
    [_requestManager sendRequest:request completion:^(NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
#if TARGET_OS_IOS || TARGET_OS_OSX
        if ([request.resultCode length] != 0) {
            [self setPostEventInAppCode:request.resultCode];

            PWResource *resource = [[PWInAppStorage storage] resourceForCode:request.resultCode];

            void (^loadResource)(void) = ^{
                RichMediaStyleType style = [[PWConfig config] richMediaStyle];

                if (style != PWRichMediaStyleTypeModal) {
                    [PWShowLoading showLoadingWithCancelBlock:^{
                        [[PWInAppStorage storage] resetBlocks];
                    }];
                }

                [[PWInAppStorage storage] resourcesForCode:request.resultCode
                                           completionBlock:^(PWResource *resource) {
                    if (style != PWRichMediaStyleTypeModal) {
                        [PWShowLoading hideLoading];
                    }
                    [wself processingResource:resource withRequest:request completion:completion];
                }];
            };

            if (resource == nil) {
                [[PWInAppStorage storage] synchronize:^(NSError *error) {
                    if (!error) {
                        loadResource();
                    }
                }];
            } else {
                [wself processingResource:resource withRequest:request completion:completion];
            }
        } else if (request.richMedia) {
            PWResource *resource = [[PWInAppStorage storage] resourceForDictionary:request.richMedia];
            [resource getHTMLDataWithCompletion:^(NSString *htmlData, NSError *error){
                [wself processingResource:resource withRequest:request completion:completion];
            }];
        } else {
            completion(nil, nil);
        }
#elif TARGET_OS_TV
        if ([request.resultCode length] != 0) {
            [self setPostEventInAppCode:request.resultCode];
            PWResource *resource = [[PWInAppStorage storage] resourceForCode:request.resultCode];

            void (^loadResource)(void) = ^{
                [[PWInAppStorage storage] resourcesForCode:request.resultCode
                                           completionBlock:^(PWResource *resource) {
                    [wself processingResource:resource withRequest:request completion:completion];
                }];
            };

            if (resource == nil) {
                [[PWInAppStorage storage] synchronize:^(NSError *error) {
                    if (!error) {
                        loadResource();
                    } else {
                        completion(nil, error);
                    }
                }];
            } else {
                [wself processingResource:resource withRequest:request completion:completion];
            }
        } else if (request.richMedia) {
            PWResource *resource = [[PWInAppStorage storage] resourceForDictionary:request.richMedia];
            [resource getHTMLDataWithCompletion:^(NSString *htmlData, NSError *error){
                [wself processingResource:resource withRequest:request completion:completion];
            }];
        } else {
            completion(nil, nil);
        }
#else
        completion(nil, nil);
#endif
    }];
}


- (void)processingResource:(PWResource *)resource withRequest:(PWPostEventRequest *)request completion:(void (^)(PWResource *resource, NSError *error))completion {
    if (!resource) {
        NSString *message = [NSString stringWithFormat:@"Pushwoosh In-App Resource with code %@ is not found", request.resultCode];
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:message];
        completion(nil, [PWUtils pushwooshError:message]);
        return;
    }

    if (!resource.isDownloaded) {
        NSString *message = [NSString stringWithFormat:@"Pushwoosh In-App: Resource with code %@ is not downloaded yet", request.resultCode];
        [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:message];
        completion(nil, [PWUtils pushwooshError:message]);
        return;
    }
    completion(resource, nil);
}

- (void)setUserId:(NSString *)userId completion:(void(^)(NSError * error))completion {
    NSDate *lastRegDate = [PWPreferences preferences].lastRegisterUserDate;
    NSTimeInterval lastRegPeriod = kRegisterUserUpdateInterval + 1;
    if (lastRegDate) {
        lastRegPeriod = [[NSDate date] timeIntervalSinceDate:lastRegDate];
    }
    
    if ([self isDeviceRestored]) {
        [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"Device is restored from iCloud backup"];
    } else if ([[PWPreferences preferences].userId isEqualToString:userId] && (lastRegPeriod < kRegisterUserUpdateInterval)) {
        [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"/registerUser with same id already sent this day"];
        if (completion)
            completion(nil);
        
        return;
    }
    NSString *previousUserId = [PWPreferences preferences].userId;
    [PWPreferences preferences].userId = userId;
    NSDate *previousRegisterUserDate = [PWPreferences preferences].lastRegisterUserDate;
    [PWPreferences preferences].lastRegisterUserDate = [NSDate date];
    
    PWRegisterUserRequest *request = [PWRegisterUserRequest new];
    [_requestManager sendRequest:request completion:^(NSError *error) {
        if (error == nil) {
            [PushwooshLog pushwooshLog:PW_LL_INFO className:self message:[NSString stringWithFormat:@"User \"%@\" was successfully registered", userId]];
            
            [[PWManagerBridge shared].inboxBridge updateInboxForNewUserId:^(NSUInteger messagesCount) {
                if (messagesCount == 0) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:PWInboxMessagesDidUpdateNotification
                                                                        object:self
                                                                      userInfo:@{@"messagesAdded" : @[] ?: @[],
                                                                                 @"messagesDeleted" : @[] ?: @[],
                                                                                 @"messagesUpdated" : @[] ?: @[]
                                                                               }];
                }
            }];
        } else {
            [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:[NSString stringWithFormat:@"Failed to update inbox for a new user. error: %@", error.localizedDescription]];
            [PWPreferences preferences].userId = previousUserId;
            [PWPreferences preferences].lastRegisterUserDate = previousRegisterUserDate;
        }
        if (completion)
            completion(error);
    }];
}

- (BOOL)isDeviceRestored {
    NSString *currentHWID = [PWPreferences preferences].hwid;
    NSString *previousHWID = [[NSUserDefaults standardUserDefaults] valueForKey:PW_DEVICE_RESTORED_KEY];
    if ([currentHWID isEqualToString:previousHWID]) {
        return NO;
    } else {
        [[NSUserDefaults standardUserDefaults] setValue:currentHWID forKey:PW_DEVICE_RESTORED_KEY];
        return YES;
    }
}

- (void)mergeUserId:(NSString *)oldUserId to:(NSString *)newUserId doMerge:(BOOL)doMerge completion:(void (^)(NSError *error))completion {
    PWMergeUserRequest *request = [[PWMergeUserRequest alloc] init];
    request.srcUserId = oldUserId;
    request.dstUserId = newUserId;
    request.doMerge = doMerge;
    
    [_requestManager sendRequest:request completion:^(NSError *error) {
        if (completion)
            completion(error);
    }];
}

- (void)setUser:(NSString *)userId emails:(NSArray *)emails completion:(void (^)(NSError * error))completion {
    if (userId != nil && ![userId isEqualToString:@""]) {
        __weak typeof(self) wself = self;
        [self setUserId:userId completion:^(NSError *error) {
            if (error) {
                if (completion)
                    completion(error);
            } else {
                if (emails != nil && emails.count != 0) {
                    [wself requestEmails:emails withCompletion:^(NSError *error) {
                        if (completion)
                            completion(error);
                    }];
                }
            }
        }];
    }
}

- (void)requestEmails:(NSArray *)emails withCompletion:(void(^)(NSError * error))completion {
    for (NSString *email in emails) {
        __weak typeof(self) wself = self;
        [self registerEmail:email completion:^(NSError *error) {
            if (error) {
                if (completion)
                    completion(error);
                return;
            } else {
                [wself registerEmailUser:email userId:nil];
            }
            if (completion)
                completion(error);
        }];
    }
}

- (void)setEmails:(NSArray *)emails completion:(void(^)(NSError * error))completion {
    if (emails == nil || emails.count == 0) {
        [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:@"Email cannot be a nil or empty"];
        return;
    }
    for (NSString *email in emails) {
        __weak typeof(self) wself = self;
        [self registerEmail:email completion:^(NSError *error) {
            if (error) {
                if (completion)
                    completion(error);
                else
                    [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:@"Something went wrong with setEmail. Use completion handler to handle the error"];
                
                return;
            } else {
                [PushwooshLog pushwooshLog:PW_LL_INFO className:self message:[NSString stringWithFormat:@"Email %@ was successfully registered", email]];
                [wself registerEmailUser:email userId:nil];
            }
            if (completion)
                completion(error);
        }];
    }
}

- (void)registerEmail:(NSString *)email completion:(void(^)(NSError * error))completion {
    PWRegisterEmail *request = [PWRegisterEmail new];
    request.email = email;
    [_requestManager sendRequest:request completion:^(NSError *error) {
        if (completion)
            completion(error);
    }];
}

- (void)registerEmailUser:(NSString *)email userId:(NSString *)userId {
    if (userId != nil) {
        [PWPreferences preferences].userId = userId;
    }
    PWRegisterEmailUser *request = [PWRegisterEmailUser new];
    request.email = email;
    if (userId == nil) {
        request.userId = [PWPreferences preferences].userId;
    } else {
        request.userId = userId;
    }
    [_requestManager sendRequest:request completion:^(NSError *error) {
        if (error) {
            [PushwooshLog pushwooshLog:PW_LL_WARN
                             className:self
                               message:[NSString stringWithFormat:@"Error registering email: %@, with userId: %@. Error: %@", email, request.userId, error.localizedDescription]];
        }
    }];
}

#if TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_TV
- (void)trackInAppWithCode:(NSString *)inAppCode action:(NSString *)action messageHash:(NSString *)messageHash {
    PWTriggerInAppActionRequest *request = [PWTriggerInAppActionRequest new];
    request.inAppCode = [inAppCode hasPrefix:@"r-"] ? @"" : inAppCode;
    request.messageHash = messageHash;

    if ([inAppCode hasPrefix:@"r-"]) {
        request.richMediaCode = [inAppCode substringFromIndex:2];
        [self setRichMediaCode:[inAppCode substringFromIndex:2]];
        [self setInAppCode:nil];
    } else {
        [self setInAppCode:inAppCode];
        [self setRichMediaCode:nil];
    }

    [self.requestManager sendRequest:request completion:nil];
}

- (void)richMediaAction:(NSString *)inAppCode richMediaCode:(NSString *)richMediaCode actionType:(NSNumber *)actionType actionAttributes:(NSString *)actionAttributes messageHash:(NSString *)messageHash completion:(void (^)(NSError *error))completion {
    PWRichMediaActionRequest *request = [[PWRichMediaActionRequest alloc] init];
    request.richMediaCode = richMediaCode;
    request.inAppCode = inAppCode;
    request.actionType = actionType;
    request.messageHash = messageHash;
    request.actionAttributes = actionAttributes;

    [self.requestManager sendRequest:request completion:^(NSError *error) {
        if (completion) {
            completion(error);
        }
    }];
}
#endif

#if TARGET_OS_IOS || TARGET_OS_OSX

- (void)presentRichMediaFromPush:(NSDictionary *)userInfo {
    NSDictionary *richMedia = userInfo[@"rm"];
    
    if (![richMedia isKindOfClass:[NSDictionary class]]) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR
                         className:self
                           message:[NSString stringWithFormat:@"Invalid json type: %@, %@", [richMedia class], richMedia]];
        return;
    }
    
    NSString *url = richMedia[@"url"];
    if (!url) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR
                         className:self
                           message:@"Url is missing"];
        return;
    }
    
    NSDictionary *tags = richMedia[@"tags"];
    if (!tags)
        tags = @{};
    
    tags = [self convertTags:tags];
    
    NSString *ts = richMedia[@"ts"];
    if (!ts) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR
                         className:self
                           message:@"Timestamp is missing"];
        return;
    }
    
    NSString *code = [[url lastPathComponent] stringByDeletingPathExtension];
    code = [@"r-" stringByAppendingString:code];  // avoid inapp and richmedia code conflicts
    
    NSDictionary *dict = @{ @"code" : code,
                            @"url" : url,
                            @"closeButtonType" : @"YES",
                            @"layout" : @"topbanner",
                            @"updated" : ts,
                            @"tags" : tags };
    
    PWResource *resource = [[PWInAppStorage storage] resourceForDictionary:dict];
    
    [resource getHTMLDataWithCompletion:^(NSString *htmlData, NSError *error) {
        if (!error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                PWRichMedia *richMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourcePush resource:resource pushPayload:userInfo];
                [self richMediaTypeWith:richMedia resource:resource];
            });
        }
    }];
}

- (void)richMediaTypeWith:(PWRichMedia *)richMedia resource:(PWResource *)resource {
    UIWindow *window = [self keyWindow];
    _modalWindow = [[PWModalWindow alloc] initWithFrame:CGRectMake(0, 0, window.bounds.size.width, 0)];
    
    switch ([[PWConfig config] richMediaStyle]) {
        case PWRichMediaStyleTypeModal:
            [_modalWindow createModalWindowWith:resource
                                      richMedia:richMedia
                                    modalWindow:_modalWindow
                                         window:window];
            break;
        case PWRichMediaStyleTypeLegacy:
        case PWRichMediaStyleTypeDefault:
            [PWMessageViewController presentWithRichMedia:richMedia];
            break;
        default:
            [PWMessageViewController presentWithRichMedia:richMedia];
            break;
    }
}

- (UIWindow *)keyWindow {
    NSArray<UIWindow *> *windows = [[UIApplication sharedApplication] windows];
    for (UIWindow *window in windows) {
        if (window.isKeyWindow) {
            return window;
        }
    }
    return nil;
}

#endif

// tags must be NSString -> NSString dictionary
- (NSDictionary *)convertTags:(NSDictionary *)tags {
    if (![tags isKindOfClass:[NSDictionary class]]) {
        return @{};
    }
    
    NSMutableDictionary *result = [tags mutableCopy];
    for (NSString *key in [tags keyEnumerator]) {
        id value = tags[key];
        
        if (![key isKindOfClass:[NSString class]]) {
            [result removeObjectForKey:key];
            continue;
        }
        
        if ([value isKindOfClass:[NSNumber class]]) {
            result[key] = [(NSNumber *)value stringValue];
            continue;
        }
        
        if (![value isKindOfClass:[NSString class]]) {
            [result removeObjectForKey:key];
        }
    }
    
    return result;
}

@end
#endif
