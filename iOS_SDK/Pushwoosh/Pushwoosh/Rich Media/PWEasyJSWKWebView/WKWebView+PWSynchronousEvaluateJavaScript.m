//
//  WKWebView+SynchronousEvaluateJavaScript.m
//  EasyJSWKWebView
//
//  Created by Zayin Krige on 2016/09/15.
//  Copyright © 2016 Apex Technology. All rights reserved.
//

#import "WKWebView+PWSynchronousEvaluateJavaScript.h"
#import "PWUtils.h"

@implementation WKWebView (PWSynchronousEvaluateJavaScript)

//execute the JS and wait for a response
- (NSString *)pw_stringByEvaluatingJavaScriptFromString:(NSString *)script error:(NSError **)error {
    __block NSString *resultString = @"";
    __block BOOL finished = NO;
    __block NSError *tmpError = nil;
    __weak typeof(self) wself = self;

    /**
     Starting with iOS 14, we use WKContentWorld to run injected JavaScript in a secure sandboxed environment,
     isolating it from untrusted web JavaScript. More details: https://developer.apple.com/documentation/webkit/wkcontentworld
     */
    if (TARGET_OS_IOS && [PWUtils isSystemVersionGreaterOrEqualTo:@"14.0"]) {
        WKContentWorld* sandbox = [WKContentWorld pageWorld];
        [self evaluateJavaScript:script
                         inFrame:nil
                  inContentWorld:sandbox
               completionHandler:^(id result, NSError * _Nullable jsError) {
            [wself jsErrorHandlingWithResult:result jsError:jsError tmpError:tmpError resultString:resultString];
            finished = YES;
        }];
    } else {
        [self evaluateJavaScript:script completionHandler:^(id result, NSError *jsError) {
            [wself jsErrorHandlingWithResult:result jsError:jsError tmpError:tmpError resultString:resultString];
            finished = YES;
        }];
    }

    
    //max 5 seconds for script to run
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:5];
    
    while (!finished && [[NSDate date] compare:date] == NSOrderedAscending){
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
    
    if (!finished) {
        [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"Timed out"];
    }

    
    if (tmpError && error != NULL) {
        *error = [tmpError copy];
    }
    
    return resultString;
}

- (void)jsErrorHandlingWithResult:(id)result
                          jsError:(NSError *)jsError
                         tmpError:(NSError *)tmpError
                     resultString:(NSString *)resultString {
    if (jsError == nil) {
        if (result != nil) {
            resultString = [NSString stringWithFormat:@"%@", result];
        }
    } else {
        tmpError = [jsError copy];
    }
}

//just execute the JS, dont wait for a response
- (void)pw_executeJavaScriptFromString:(NSString *)script {
    /**
     Starting with iOS 14, we use WKContentWorld to run injected JavaScript in a secure sandboxed environment,
     isolating it from untrusted web JavaScript. More details: https://developer.apple.com/documentation/webkit/wkcontentworld
     */
    if (TARGET_OS_IOS && [PWUtils isSystemVersionGreaterOrEqualTo:@"14.0"]) {
        WKContentWorld* sandbox = [WKContentWorld pageWorld];
        [self evaluateJavaScript:script
                         inFrame:nil
                  inContentWorld:sandbox
               completionHandler:nil];
    } else {
        [self evaluateJavaScript:script completionHandler:nil];
    }
}
@end
