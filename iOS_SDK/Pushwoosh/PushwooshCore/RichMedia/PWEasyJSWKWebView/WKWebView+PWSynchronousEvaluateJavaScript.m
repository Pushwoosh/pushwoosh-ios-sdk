//
//  WKWebView+PWSynchronousEvaluateJavaScript.m
//  EasyJSWKWebView
//
//  Created by Zayin Krige on 2016/09/15.
//  Copyright © 2016 Apex Technology. All rights reserved.
//

#if TARGET_OS_IOS
#import "WKWebView+PWSynchronousEvaluateJavaScript.h"
#import "PWUtils.h"

@implementation WKWebView (PWSynchronousEvaluateJavaScript)

//execute the JS and wait for a response
- (NSString *)pw_stringByEvaluatingJavaScriptFromString:(NSString *)script error:(NSError **)error {
    __block NSString *resultString = @"";
    __block BOOL finished = NO;
    __block NSError *tmpError = nil;

    /**
     Starting with iOS 14, we use WKContentWorld to run injected JavaScript in a secure sandboxed environment,
     isolating it from untrusted web JavaScript. More details: https://developer.apple.com/documentation/webkit/wkcontentworld
     */
    void (^completion)(id, NSError *) = ^(id result, NSError *jsError) {
        if (jsError == nil) {
            if (result != nil) {
                resultString = [NSString stringWithFormat:@"%@", result];
            }
        } else {
            tmpError = [jsError copy];
        }
        finished = YES;
    };

    if (TARGET_OS_IOS && [PWUtils isSystemVersionGreaterOrEqualTo:@"14.0"]) {
        WKContentWorld* sandbox = [WKContentWorld pageWorld];
        [self evaluateJavaScript:script
                         inFrame:nil
                  inContentWorld:sandbox
               completionHandler:completion];
    } else {
        [self evaluateJavaScript:script completionHandler:completion];
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
#endif
