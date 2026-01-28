//
//  PWRequestManager.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWRequestManager.h"
#import "PWPushRuntime.h"
#import "PWSetTagsRequest.h"
#import "Constants.h"
#import "PWConfig.h"
#import "PWCombinedSetTagsRequest.h"
#import "PWPreferences.h"
#import "PWUtils.h"
#import <PushwooshCore/PWManagerBridge.h>
#import "PWCachedRequest.h"
#import "PWServerCommunicationManager.h"
#import "PushwooshLog.h"

#if TARGET_OS_IOS || TARGET_OS_OSX
#import "PWRequestsCacheManager.h"
#endif

#if !__has_feature(objc_arc)
#error "ARC is required to compile Pushwoosh SDK"
#endif

@protocol PWGRPCTransport <NSObject>
+ (BOOL)isAvailable;
+ (void)sendRequest:(PWRequest *)request completion:(void (^)(NSDictionary *, NSError *))completion;
+ (NSString *)transportName;
@end

@interface PWRequestManager ()

@property (nonatomic, strong) NSURLSession *session;

@property (nonatomic, strong) NSObject *sendTagsLock;
@property (nonatomic, strong) PWCombinedSetTagsRequest *combinedRequest;
@property (nonatomic, strong) NSMutableArray *sendTagsCompletions;
@property (nonatomic) BOOL usingReverseProxy;

// gRPC transport class (dynamically loaded)
@property (nonatomic, strong) Class grpcTransportClass;

@end

@implementation PWRequestManager

- (instancetype)init {
	if (self = [super init]) {
		NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
		_session = [NSURLSession sessionWithConfiguration:configuration delegate:nil delegateQueue:[NSOperationQueue mainQueue]];
		_sendTagsLock = [NSObject new];
		_sendTagsCompletions = [NSMutableArray new];

        // Try to load gRPC transport class
        // gRPC is used automatically when PushwooshGRPC module is linked
        _grpcTransportClass = NSClassFromString(@"PushwooshGRPC.PushwooshGRPCImplementation");
	}

	return self;
}

- (BOOL)isGRPCAvailable {
    if (_grpcTransportClass == nil) {
        _grpcTransportClass = NSClassFromString(@"PushwooshGRPC.PushwooshGRPCImplementation");
    }

    if (_grpcTransportClass) {
        SEL isAvailableSel = @selector(isAvailable);
        if ([_grpcTransportClass respondsToSelector:isAvailableSel]) {
            return ((BOOL (*)(Class, SEL))[(id)_grpcTransportClass methodForSelector:isAvailableSel])(_grpcTransportClass, isAvailableSel);
        }
    }

    return NO;
}

- (BOOL)grpcSupportsMethod:(NSString *)methodName {
    if (_grpcTransportClass == nil) {
        return NO;
    }

    SEL supportsMethodSelector = NSSelectorFromString(@"supportsMethod:");
    if ([_grpcTransportClass respondsToSelector:supportsMethodSelector]) {
        typedef BOOL (*SupportsMethodIMP)(Class, SEL, NSString *);
        SupportsMethodIMP supportsMethod = (SupportsMethodIMP)[_grpcTransportClass methodForSelector:supportsMethodSelector];
        return supportsMethod(_grpcTransportClass, supportsMethodSelector, methodName);
    }

    return NO;
}

- (NSString *)baseUrl {
	return [PWPreferences preferences].baseUrl;
}

- (void)setReverseProxyUrl:(NSString *)url {
    [self setUsingReverseProxy:YES];
    [PWPreferences preferences].baseUrl = url;
}

- (void)disableReverseProxy {
    [self setUsingReverseProxy:NO];
}

- (void)sendRequest:(PWRequest *)request completion:(void (^)(NSError *error))completion {
    // Use gRPC automatically when module is linked and supports this method
    if ([self isGRPCAvailable] && [self grpcSupportsMethod:request.methodName]) {
        [self sendRequestViaGRPC:request completion:completion];
        return;
    }

    // Default REST transport
    if ([request isKindOfClass:[PWSetTagsRequest class]]) {
        PWSetTagsRequest *setTagsRequest = (PWSetTagsRequest *)request;
        [self sendTags:setTagsRequest completion:completion];
    } else {
        [self sendRequestInternal:request completion:completion];
    }
}

- (void)sendRequestViaGRPC:(PWRequest *)request completion:(void (^)(NSError *error))completion {
    if (!_grpcTransportClass) {
        // Fallback to REST
        if ([request isKindOfClass:[PWSetTagsRequest class]]) {
            PWSetTagsRequest *setTagsRequest = (PWSetTagsRequest *)request;
            [self sendTags:setTagsRequest completion:completion];
        } else {
            [self sendRequestInternal:request completion:completion];
        }
        return;
    }

    __weak typeof(self) wSelf = self;

    SEL sendRequestSelector = NSSelectorFromString(@"sendRequest:completion:");
    if ([_grpcTransportClass respondsToSelector:sendRequestSelector]) {
        // Use performSelector or direct invocation via IMP
        typedef void (*SendRequestIMP)(Class, SEL, PWRequest*, void (^)(NSDictionary*, NSError*));
        SendRequestIMP sendRequest = (SendRequestIMP)[_grpcTransportClass methodForSelector:sendRequestSelector];

        sendRequest(_grpcTransportClass, sendRequestSelector, request, ^(NSDictionary *response, NSError *error) {
            if (error) {
                // Log gRPC error and optionally fallback to REST
                [PushwooshLog pushwooshLog:PW_LL_WARN
                                 className:wSelf
                                   message:[NSString stringWithFormat:@"gRPC request failed: %@, falling back to REST", error.localizedDescription]];

                // Fallback to REST on error
                if ([request isKindOfClass:[PWSetTagsRequest class]]) {
                    PWSetTagsRequest *setTagsRequest = (PWSetTagsRequest *)request;
                    [wSelf sendTags:setTagsRequest completion:completion];
                } else {
                    [wSelf sendRequestInternal:request completion:completion];
                }
                return;
            }

            // Process gRPC response
            request.httpCode = [response[@"status_code"] integerValue];

            if (request.httpCode != 200) {
                NSString *statusMessage = response[@"status_message"];
                NSError *statusError = [PWUtils pushwooshError:statusMessage ?: @"gRPC request failed"];
                if (completion) {
                    completion(statusError);
                }
                return;
            }

            // Parse response if present
            NSDictionary *responseDict = response[@"response"];
            if ([responseDict isKindOfClass:[NSDictionary class]]) {
                [request parseResponse:responseDict];
            }

            // Handle base_url switch
            NSString *newBaseUrl = response[@"base_url"];
            if ([newBaseUrl isKindOfClass:[NSString class]] && !wSelf.usingReverseProxy) {
                [PWPreferences preferences].baseUrl = newBaseUrl;
            }

            if (completion) {
                completion(nil);
            }
        });
    } else {
        // Fallback to REST if method not available
        if ([request isKindOfClass:[PWSetTagsRequest class]]) {
            PWSetTagsRequest *setTagsRequest = (PWSetTagsRequest *)request;
            [self sendTags:setTagsRequest completion:completion];
        } else {
            [self sendRequestInternal:request completion:completion];
        }
    }
}

- (void)sendRetryRequest:(PWRequest *)request {
    [self sendRequestInternal:request completion:nil];
}

- (void)sendTags:(PWSetTagsRequest *)request completion:(void (^)(NSError *error))completion {
	@synchronized(_sendTagsLock) {
		BOOL scheduledSendTags = NO;
		if (!_combinedRequest) {
			_combinedRequest = [PWCombinedSetTagsRequest new];
			scheduledSendTags = YES;
		}

		[_combinedRequest addRequest:request];

		if (completion) {
			[_sendTagsCompletions addObject:completion];
		}

		if (scheduledSendTags) {
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
				@synchronized(_sendTagsLock) {
					NSArray *completions = [_sendTagsCompletions copy];
					[self sendRequestInternal:_combinedRequest completion:^void(NSError *error) {
						for (void (^handler)(NSError *error) in completions) {
							handler(error);
						}
					}];
					[_sendTagsCompletions removeAllObjects];
					_combinedRequest = nil;
				}
			});
		}
	}
}

- (void)sendRequestInternal:(PWRequest *)request completion:(void (^)(NSError *error))completion {
    //check server communication enabled
    if (![[PWServerCommunicationManager sharedInstance] isServerCommunicationAllowed]) {
        NSString *errorStr = @"Communication with Pushwoosh is disabled. To send the request you have to enable the server communication using method startServerCommunication of Pushwoosh class.";
        if (completion) {
            completion([PWUtils pushwooshErrorWithCode:PWErrorCommunicationDisabled description:errorStr]);
        } else {
            [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:errorStr];
        }
        return;
    }
    
    if ([request isKindOfClass:[PWCachedRequest class]] && ![self isNeedToRetryAfterAppOpenedWith:request]) {
        [self sendRequestWithDelay:[self remainDelayTime:request] forRequest:request];
        return;
    }
    
    __weak typeof (self) wSelf = self;
#if TARGET_OS_IOS
    __block NSInteger backgroundTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskId];
        backgroundTaskId = UIBackgroundTaskInvalid;
    }];
#endif
    
    //request part
    NSString *requestUrl = [[self baseUrl] stringByAppendingString:[request methodName]];

    [request setStartTime:[[NSDate date] timeIntervalSince1970]];

    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:request.requestDictionary options:0 error:&jsonError];

    if (!jsonData || jsonError) {
        NSString *errorStr = [NSString stringWithFormat:@"Failed to serialize request: %@", jsonError.localizedDescription ?: @"unknown error"];
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:errorStr];
        if (completion) {
            completion([PWUtils pushwooshError:errorStr]);
        }
#if TARGET_OS_IOS
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskId];
#endif
        return;
    }

    NSString *requestString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSString *requestData =  [NSString stringWithFormat:@"{\"request\":%@}", requestString];

    NSMutableURLRequest *urlRequest = [self prepareRequest:requestUrl jsonRequestData:requestData];

    if (!urlRequest || !urlRequest.URL) {
        NSString *errorStr = [NSString stringWithFormat:@"Invalid request URL: %@", requestUrl];
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:errorStr];
        if (completion) {
            completion([PWUtils pushwooshError:errorStr]);
        }
#if TARGET_OS_IOS
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskId];
#endif
        return;
    }
    
    if ([request isKindOfClass:[PWCachedRequest class]] && [self retryCountWith:request]) {
        NSInteger retryCount = [self retryCountWith:request];
        
        if (retryCount >= 0) {
            [PushwooshLog pushwooshLog:PW_LL_DEBUG
                             className:self
                               message:[NSString stringWithFormat:@"Retry count for request %@: %ld", request.methodName, (long)retryCount]];
            [urlRequest addValue:[NSString stringWithFormat:@"%ld", [self retryCountWith:request]] forHTTPHeaderField:@"X-Retry-Count"];
        }
    }
    
    NSURLSessionDataTask *postDataTask = [_session dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

#if TARGET_OS_IOS || TARGET_OS_OSX
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        if (([wSelf needToRetry:httpResponse.statusCode] || error) && [wSelf retryCountWith:request] <= 2) {
            
            if (request.cacheable) {
                [[PWRequestsCacheManager sharedInstance] cacheRequest:request];

                [wSelf saveRequestTime:request];

#if TARGET_OS_IOS
                [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskId];
#endif
                return;
            }

            if ([request isKindOfClass:[PWCachedRequest class]]) {
                [wSelf increaseRequestCounter:request];
                [wSelf saveRequestTime:request];

                [wSelf sendRequestWithDelay:[wSelf calculateRetryDelayWith:request] forRequest:request];

#if TARGET_OS_IOS
                [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskId];
#endif
                return;
            }
        } else {
            // Success - reset retry counter and delete cached request
            if ([request isKindOfClass:[PWCachedRequest class]]) {
                [wSelf resetRequestCounter:request];
                [[PWRequestsCacheManager sharedInstance] deleteCachedRequest:request];
            }
        }
#endif
                
        [wSelf processResponse:(NSHTTPURLResponse *)response responseData:data request:request url:requestUrl requestData:requestData error:&error];
        
		if (completion)
			completion(error);
		
#if TARGET_OS_IOS
		[[UIApplication sharedApplication] endBackgroundTask:backgroundTaskId];
#endif
		}
	];

	[postDataTask resume];
}

- (void)saveRequestTime:(PWRequest *)request {
    [[NSUserDefaults standardUserDefaults] setDouble:[[NSDate date] timeIntervalSince1970]
                                              forKey:[NSString stringWithFormat:@"%@%@", kPrefixDate, request.requestIdentifier]];
}

- (void)increaseRequestCounter:(PWRequest *)request {
    NSUInteger count = [[NSUserDefaults standardUserDefaults] integerForKey:request.requestIdentifier];
    [[NSUserDefaults standardUserDefaults] setInteger:(count + 1) forKey:request.requestIdentifier];
}

- (void)resetRequestCounter:(PWRequest *)request {
    if (request.requestIdentifier) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:request.requestIdentifier];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"%@%@", kPrefixDelay, request.requestIdentifier]];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"%@%@", kPrefixDate, request.requestIdentifier]];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"%@%@", kPrefixRemainDelay, request.requestIdentifier]];
    }
}

- (NSUInteger)retryCountWith:(PWRequest *)request {
    if (request.requestIdentifier) {
        return [[NSUserDefaults standardUserDefaults] integerForKey:request.requestIdentifier];
    } else {
        // delete cached request
        return 3;
    }
}

- (void)sendRequestWithDelay:(double)delay forRequest:(PWRequest *)request {
    __weak typeof (self) wSelf = self;
    
    NSTimeInterval delayInSeconds = delay;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
        [wSelf sendRetryRequest:request];
    });
}

- (BOOL)isNeedToRetryAfterAppOpenedWith:(PWRequest *)request {
    double savedDelay = [[NSUserDefaults standardUserDefaults]
                         doubleForKey:[NSString stringWithFormat:@"%@%@", kPrefixDelay, request.requestIdentifier]];
    double requestTime = [[NSUserDefaults standardUserDefaults]
                          doubleForKey:[NSString stringWithFormat:@"%@%@", kPrefixDate, request.requestIdentifier]];
    double currentTime = [[NSDate date] timeIntervalSince1970];
    
    if (currentTime > requestTime + savedDelay) {
        return YES;
    } else {
        double timeRemain = savedDelay - (currentTime - requestTime);
        [[NSUserDefaults standardUserDefaults] setDouble:timeRemain forKey:[NSString stringWithFormat:@"%@%@", kPrefixRemainDelay, request.requestIdentifier]];
        return NO;
    }
}

- (double)calculateRetryDelayWith:(PWRequest *)request {
    double initialTime = [self initialTime:request];
    
    if (initialTime == 0) {
        initialTime = 25.f;
        [[NSUserDefaults standardUserDefaults] setDouble:(initialTime * log2(initialTime))
                                                  forKey:[NSString stringWithFormat:@"%@%@", kPrefixDelay, request.requestIdentifier]];
    } else {
        [[NSUserDefaults standardUserDefaults] setDouble:(initialTime * log2(initialTime))
                                                  forKey:[NSString stringWithFormat:@"%@%@", kPrefixDelay, request.requestIdentifier]];
    }

    return initialTime * log2(initialTime);
}

- (double)initialTime:(PWRequest *)request {
    return [[NSUserDefaults standardUserDefaults] doubleForKey:[NSString stringWithFormat:@"%@%@", kPrefixDelay, request.requestIdentifier]];
}

- (double)remainDelayTime:(PWRequest *)request {
    return [[NSUserDefaults standardUserDefaults] doubleForKey:[NSString stringWithFormat:@"%@%@", kPrefixRemainDelay, request.requestIdentifier]];
}

- (BOOL)needToRetry:(NSInteger)statusCode {
    return statusCode >= 499 && statusCode < 600;
}

- (NSMutableURLRequest *)prepareRequest:(NSString *)requestUrl jsonRequestData:(NSString *)jsonRequestData {
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:requestUrl]];
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest addValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    NSString *apiToken = [self getApiToken] ?: [self getConfigApiToken];
    [urlRequest addValue:[NSString stringWithFormat:@"Token %@", apiToken] forHTTPHeaderField:@"Authorization"];
    [urlRequest setHTTPBody:[jsonRequestData dataUsingEncoding:NSUTF8StringEncoding]];
    
    return urlRequest;
}

- (NSString *)getApiToken {
    return [[PWConfig config] pushwooshApiToken] ? [[PWConfig config] pushwooshApiToken] : [[PWConfig config] apiToken];
}

- (NSString *)getConfigApiToken {
    return [PushwooshConfig getApiToken];
}

- (void)processResponse:(NSHTTPURLResponse *)httpResponse responseData:(NSData *)responseData request:(PWRequest *)request url:(NSString *)requestUrl requestData:(NSString *)requestData error:(NSError **)outError {
    
	NSError *error = *outError;
	request.httpCode = httpResponse.statusCode;
        
    if (error == nil) {
        NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        
        NSString *requestLogStr = [NSString stringWithFormat:@"\n"
                                     @"x\n"
                                     @"|    Pushwoosh request:\n"
                                     @"| Url:      %@\n"
                                     @"| Payload:  %@\n"
                                     @"| Status:   \"%ld %@\"\n"
                                     @"| Response: %@\n"
                                     @"x",
                                     requestUrl, requestData, (long)[httpResponse statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[httpResponse statusCode]], responseString];
        
        
        [PushwooshLog pushwooshLog:PW_LL_DEBUG
                         className:self
                           message:requestLogStr];
        
        NSDictionary *jsonResult = [NSJSONSerialization JSONObjectWithData:[responseString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
        
        if (![jsonResult isKindOfClass:[NSDictionary class]]) {
			if (error == nil) {
				error = [PWUtils pushwooshError:@"Bad response body"];
			}
		} else {
			// honor base url switch
			if (jsonResult[@"status_code"] == nil) {
				[PWPreferences preferences].baseUrl = [PWPreferences preferences].defaultBaseUrl;
			}
			NSString *newBaseUrl = jsonResult[@"base_url"];
            if ([newBaseUrl isKindOfClass:[NSString class]] && !self.usingReverseProxy) {
				[PWPreferences preferences].baseUrl = newBaseUrl;
			}
            
			// check status
			if (httpResponse.statusCode != 200 || ![jsonResult[@"status_code"] isKindOfClass:[NSNumber class]] || [jsonResult[@"status_code"] intValue] != 200) {
                
                NSString *statusMessage = jsonResult[@"status_message"];
                
                if (statusMessage) {
                    error = [PWUtils pushwooshError:statusMessage];
                } else {
                    error = [PWUtils pushwooshError:[NSString stringWithFormat:@"Bad response status code: (%d, %@)", (int)httpResponse.statusCode, jsonResult[@"status_code"]]];
                }
			} else {
				// optional response parsing
				NSDictionary *responseDict = jsonResult[@"response"];
                
                if ([responseDict isKindOfClass:[NSDictionary class]]) {
                    #ifdef DEBUG
                    [request parseResponse:responseDict];
                    #else
                    @try {
                        [request parseResponse:responseDict];
                    }
                    @catch (NSException *exception) {
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@""];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"              |      |"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"              |      |"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"              |      |"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"              |      |"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"              |      |"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"          ====        ===="];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"          \\              /"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"           \\            /"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"            \\          /"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"             \\        /"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"              \\      /"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"               \\    /"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"                \\  /"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"                 \\/"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@""];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:[NSString stringWithFormat:@"Fail to parse response: %@", responseDict]];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:[NSString stringWithFormat:@"Catched exception: %@", exception]];
                    }
                    #endif
                }
			}
		}
	} else {
        [PushwooshLog pushwooshLog:PW_LL_ERROR
                         className:self
                           message:[NSString stringWithFormat:@"Sending %@ failed, %@", request.methodName, error.description]];
	}

	*outError = error;
}

- (void)downloadDataFromURL:(NSURL *)url withCompletion:(PWRequestDownloadCompleteBlock)completion {
    [PushwooshLog pushwooshLog:PW_LL_DEBUG
                     className:self
                       message:[NSString stringWithFormat:@"Pushwoosh In-App: will download data:%@\n", url.absoluteString]];

	[[_session downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
		if (!completion)
			return;

		if (error) {
            [PushwooshLog pushwooshLog:PW_LL_ERROR
                             className:self
                               message:[NSString stringWithFormat:@"Pushwoosh In-App failed to download data: %@", error.localizedDescription]];
			completion(nil, error);
		} else {
			completion(location.path, nil);
		}
	}] resume];
}

- (NSString *)getStringOrEmpty:(NSString *)string {
    return string != nil ? string : @"";
}

@end
