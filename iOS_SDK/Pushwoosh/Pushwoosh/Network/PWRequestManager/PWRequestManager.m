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
#import "Pushwoosh+Internal.h"
#import "PWGDPRManager.h"
#import "PWServerCommunicationManager.h"
#import "PWCachedRequest.h"

#if TARGET_OS_IOS || TARGET_OS_OSX
#import "PWRequestsCacheManager.h"
#endif

#if !__has_feature(objc_arc)
#error "ARC is required to compile Pushwoosh SDK"
#endif

@interface PWRequestManager ()

@property (nonatomic, strong) NSURLSession *session;

@property (nonatomic, strong) NSObject *sendTagsLock;
@property (nonatomic, strong) PWCombinedSetTagsRequest *combinedRequest;
@property (nonatomic, strong) NSMutableArray *sendTagsCompleitons;
@property (nonatomic) BOOL usingReverseProxy;

@end

@implementation PWRequestManager

- (instancetype)init {
	if (self = [super init]) {
		NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
		_session = [NSURLSession sessionWithConfiguration:configuration delegate:nil delegateQueue:[NSOperationQueue mainQueue]];
		_sendTagsLock = [NSObject new];
		_sendTagsCompleitons = [NSMutableArray new];
	}

	return self;
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
    if (![PWGDPRManager sharedManager].isDeviceDataRemoved) {
        if ([request isKindOfClass:[PWSetTagsRequest class]]) {
            PWSetTagsRequest *setTagsRequest = (PWSetTagsRequest *)request;
            [self sendTags:setTagsRequest completion:completion];
        } else {
            [self sendRequestInternal:request completion:completion];
        }
    } else if (completion) {
        completion([PWUtils pushwooshErrorWithCode:PWErrorDeviceDataHasBeenRemoved description:@"Device data was removed from Pushwoosh and all interactions were stopped"]);
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
			[_sendTagsCompleitons addObject:completion];
		}

		if (scheduledSendTags) {
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
				@synchronized(_sendTagsLock) {
					NSArray *completions = [_sendTagsCompleitons copy];
					[self sendRequestInternal:_combinedRequest completion:^void(NSError *error) {
						for (void (^handler)(NSError *error) in completions) {
							handler(error);
						}
					}];
					[_sendTagsCompleitons removeAllObjects];
					_combinedRequest = nil;
				}
			});
		}
	}
}

- (void)sendRequestInternal:(PWRequest *)request completion:(void (^)(NSError *error))completion {
    //check server communication enabled
    if (![[PWServerCommunicationManager sharedInstance] isServerCommunicationAllowed]) {
        NSString *error = @"Communication with Pushwoosh is disabled. To send the request you have to enable the server communication using method startServerCommunication of Pushwoosh class.";
        if (completion) {
            completion([PWUtils pushwooshErrorWithCode:PWErrorCommunicationDisabled description:error]);
        } else {
            PWLogError(error);
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
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:request.requestDictionary options:0 error:nil];
    
    NSString *requestString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSString *requestData =  [NSString stringWithFormat:@"{\"request\":%@}", requestString];

    NSMutableURLRequest *urlRequest = [self prepareRequest:requestUrl jsonRequestData:requestData];
    
    if ([request isKindOfClass:[PWCachedRequest class]] && [self retryCountWith:request]) {
        NSInteger retryCount = [self retryCountWith:request];
        
        if (retryCount >= 0) {
            PWLogDebug(@"Retry count for request %@: %ld", request.methodName, (long)retryCount);
            [urlRequest addValue:[NSString stringWithFormat:@"%ld", [self retryCountWith:request]] forHTTPHeaderField:@"X-Retry-Count"];
        }
    }
    
    NSURLSessionDataTask *postDataTask = [_session dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        
#if TARGET_OS_IOS || TARGET_OS_OSX
        if (([wSelf needToRetry:httpResponse.statusCode] || error) && [wSelf retryCountWith:request] <= 2) {
            
            if (request.cacheable) {
                [[PWRequestsCacheManager sharedInstance] cacheRequest:request];
                
                [wSelf saveRequestTime:request];
                
                [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskId];
                return;
            }
            
            if ([request isKindOfClass:[PWCachedRequest class]]) {
                [wSelf increaseRequestCounter:request];
                [wSelf saveRequestTime:request];

                [wSelf sendRequestWithDelay:[wSelf calculateRetryDelayWith:request] forRequest:request];
                
                [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskId];
                return;
            }
        } else {
            if ([request isKindOfClass:[PWCachedRequest class]]) {
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
    [urlRequest addValue:[NSString stringWithFormat:@"Token %@", [self getApiToken]] forHTTPHeaderField:@"Authorization"];
    [urlRequest setHTTPBody:[jsonRequestData dataUsingEncoding:NSUTF8StringEncoding]];
    
    return urlRequest;
}

- (NSString *)getApiToken {
    return [[PWConfig config] pushwooshApiToken] ? [[PWConfig config] pushwooshApiToken] : [[PWConfig config] apiToken];
}

- (void)processResponse:(NSHTTPURLResponse *)httpResponse responseData:(NSData *)responseData request:(PWRequest *)request url:(NSString *)requestUrl requestData:(NSString *)requestData error:(NSError **)outError {
    
	NSError *error = *outError;
	request.httpCode = httpResponse.statusCode;
        
    if (error == nil) {
        NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        
        PWLogDebug(@"\n"
                  @"x\n"
                  @"|    Pushwoosh request:\n"
                  @"| Url:      %@\n"
                  @"| Payload:  %@\n"
                  @"| Status:   \"%ld %@\"\n"
                  @"| Response: %@\n"
                  @"x",
                  requestUrl, requestData, (long)[httpResponse statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[httpResponse statusCode]], responseString);
        
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
                        PWLogError(@"");
                        PWLogError(@"              |      |");
                        PWLogError(@"              |      |");
                        PWLogError(@"              |      |");
                        PWLogError(@"              |      |");
                        PWLogError(@"              |      |");
                        PWLogError(@"          ====        ====");
                        PWLogError(@"          \\              /");
                        PWLogError(@"           \\            /");
                        PWLogError(@"            \\          /");
                        PWLogError(@"             \\        /");
                        PWLogError(@"              \\      /");
                        PWLogError(@"               \\    /");
                        PWLogError(@"                \\  /");
                        PWLogError(@"                 \\/");
                        PWLogError(@"");
                        PWLogError(@"Fail to parse response: %@", responseDict);
                        PWLogError(@"Catched exception: %@", exception);
                    }
                    #endif
                }
			}
		}
	} else {
		PWLogError(@"Sending %@ failed, %@", request.methodName, error.description);
	}

	*outError = error;
}

- (void)downloadDataFromURL:(NSURL *)url withCompletion:(PWRequestDownloadCompleteBlock)completion {
	NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:nil delegateQueue:[NSOperationQueue mainQueue]];

    PWLogDebug(@"%@", [NSString stringWithFormat:@"Pushwoosh In-App: will download data:%@\n", url.absoluteString]);

	[[session downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
		if (!completion)
			return;

		if (error) {
			PWLogError(@"%@", [NSString stringWithFormat:@"Pushwoosh In-App failed to download data: %@", error.localizedDescription]);
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
