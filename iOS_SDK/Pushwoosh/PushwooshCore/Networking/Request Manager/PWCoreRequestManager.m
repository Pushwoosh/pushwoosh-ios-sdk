//
//  PWCoreRequestManager.m
//  PushwooshCore
//
//  Created by André Kis on 12.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import "PWCoreRequestManager.h"
#import "PWCConfig.h"
#import "PWCoreUtils.h"
#import "PWCoreServerCommunicationManager.h"
#import "PWCoreGDPRManager.h"

@interface PWCoreRequestManager ()

@property (nonatomic, strong) NSURLSession *session;

@property (nonatomic) BOOL usingReverseProxy;

@end

@implementation PWCoreRequestManager

+ (PWCoreRequestManager *)sharedManager {
    static PWCoreRequestManager *sharedManager = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedManager = [[PWCoreRequestManager alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    if (self = [super init]) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        _session = [NSURLSession sessionWithConfiguration:configuration delegate:nil delegateQueue:[NSOperationQueue mainQueue]];
    }

    return self;
}

- (NSString *)baseUrl {
    return [PWSettings settings].baseUrl;
}

- (void)setReverseProxyUrl:(NSString *)url {
    [self setUsingReverseProxy:YES];
    [PWSettings settings].baseUrl = url;
}

- (void)disableReverseProxy {
    [self setUsingReverseProxy:NO];
}

- (void)sendRequest:(PWCoreRequest *)request completion:(void (^)(NSError *error))completion {
    if (![PWCoreGDPRManager sharedManager].isDeviceDataRemoved) {
        [self sendRequestInternal:request completion:completion];
    } else if (completion) {
        completion([PWCoreUtils pushwooshErrorWithCode:PWCoreErrorDeviceDataHasBeenRemoved description:@"Device data was removed from Pushwoosh and all interactions were stopped"]);
    }
}

- (void)sendRetryRequest:(PWCoreRequest *)request {
    [self sendRequestInternal:request completion:nil];
}

- (void)sendRequestInternal:(PWCoreRequest *)request completion:(void (^)(NSError *error))completion {
    if (![[PWCoreServerCommunicationManager sharedInstance] isServerCommunicationAllowed]) {
        NSString *errorStr = @"Communication with Pushwoosh is disabled. To send the request you have to enable the server communication using method startServerCommunication of Pushwoosh class.";
        if (completion) {
            completion([PWCoreUtils pushwooshErrorWithCode:PWCoreErrorCommunicationDisabled description:errorStr]);
        } else {
            [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:errorStr];
        }
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
    
    NSURLSessionDataTask *postDataTask = [_session dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                        
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

- (void)saveRequestTime:(PWCoreRequest *)request {
    [[NSUserDefaults standardUserDefaults] setDouble:[[NSDate date] timeIntervalSince1970]
                                              forKey:[NSString stringWithFormat:@"%@%@", kPrefixDate, request.requestIdentifier]];
}

- (void)increaseRequestCounter:(PWCoreRequest *)request {
    NSUInteger count = [[NSUserDefaults standardUserDefaults] integerForKey:request.requestIdentifier];
    [[NSUserDefaults standardUserDefaults] setInteger:(count + 1) forKey:request.requestIdentifier];
}

- (NSUInteger)retryCountWith:(PWCoreRequest *)request {
    if (request.requestIdentifier) {
        return [[NSUserDefaults standardUserDefaults] integerForKey:request.requestIdentifier];
    } else {
        // delete cached request
        return 3;
    }
}

- (void)sendRequestWithDelay:(double)delay forRequest:(PWCoreRequest *)request {
    __weak typeof (self) wSelf = self;
    
    NSTimeInterval delayInSeconds = delay;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
        [wSelf sendRetryRequest:request];
    });
}

- (BOOL)isNeedToRetryAfterAppOpenedWith:(PWCoreRequest *)request {
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

- (double)calculateRetryDelayWith:(PWCoreRequest *)request {
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

- (double)initialTime:(PWCoreRequest *)request {
    return [[NSUserDefaults standardUserDefaults] doubleForKey:[NSString stringWithFormat:@"%@%@", kPrefixDelay, request.requestIdentifier]];
}

- (double)remainDelayTime:(PWCoreRequest *)request {
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
    return [[PWCConfig config] pushwooshApiToken] ? [[PWCConfig config] pushwooshApiToken] : [[PWCConfig config] apiToken];
}

- (void)processResponse:(NSHTTPURLResponse *)httpResponse responseData:(NSData *)responseData request:(PWCoreRequest *)request url:(NSString *)requestUrl requestData:(NSString *)requestData error:(NSError **)outError {
    
    NSError *error = *outError;
    request.httpCode = httpResponse.statusCode;
        
    if (error == nil) {
        NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        
        NSString *requestLogStr = [NSString stringWithFormat:@"\n"
                                     @"x\n"
                                     @"| Pushwoosh request:\n"
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
                error = [PWCoreUtils pushwooshError:@"Bad response body"];
            }
        } else {
            // honor base url switch
            if (jsonResult[@"status_code"] == nil) {
                [PWSettings settings].baseUrl = [PWSettings settings].defaultBaseUrl;
            }
            NSString *newBaseUrl = jsonResult[@"base_url"];
            if ([newBaseUrl isKindOfClass:[NSString class]] && !self.usingReverseProxy) {
                [PWSettings settings].baseUrl = newBaseUrl;
            }
            
            // check status
            if (httpResponse.statusCode != 200 || ![jsonResult[@"status_code"] isKindOfClass:[NSNumber class]] || [jsonResult[@"status_code"] intValue] != 200) {
                
                NSString *statusMessage = jsonResult[@"status_message"];
                
                if (statusMessage) {
                    error = [PWCoreUtils pushwooshError:statusMessage];
                } else {
                    error = [PWCoreUtils pushwooshError:[NSString stringWithFormat:@"Bad response status code: (%d, %@)", (int)httpResponse.statusCode, jsonResult[@"status_code"]]];
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
                        [PushwooshLog pushwooshLog:PW_LL_ERROR
                                         className:self
                                           message:[NSString stringWithFormat:@"Fail to parse response: %@", responseDict]];

                        [PushwooshLog pushwooshLog:PW_LL_ERROR
                                         className:self
                                           message:[NSString stringWithFormat:@"Caught exception: %@", exception]];

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
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:nil delegateQueue:[NSOperationQueue mainQueue]];

    [PushwooshLog pushwooshLog:PW_LL_DEBUG
                     className:self
                       message:[NSString stringWithFormat:@"Pushwoosh In-App: will download data:%@\n", url.absoluteString]];

    [[session downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
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
