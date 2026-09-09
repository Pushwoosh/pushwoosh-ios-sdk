//
//  PWEasyJSListener.m
//  EasyJSWKWebView
//
//  Created by Lau Alex on 19/1/13.
//  Copyright (c) 2013 Dukeland. All rights reserved.
//
//  Modified for WKWebview by Zayin Krige on 2016/10/05
//  Copyright (c) 2016 Apex Technology. All rights reserved.
//  zayin@apextechnology.co.za
//

#if TARGET_OS_IOS
#import "PWEasyJSListener.h"
#import "PWEasyJSWKDataFunction.h"
#import <objc/runtime.h>
#import "WKWebView+PWSynchronousEvaluateJavaScript.h"

@implementation PWEasyJSListener

- (void)webView:(PWEasyJSWKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(nullable NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable result))completionHandler {
    NSMutableArray <PWEasyJSWKDataFunction *>* _funcs = [NSMutableArray new];
    NSMutableArray <NSString *>* _args = [NSMutableArray new];

    NSString *requestString = prompt;
    NSArray *components = [requestString componentsSeparatedByString:@":"];

    if (components.count < 2) {
        completionHandler(nil);
        return;
    }

    NSString* obj = (NSString*)[components objectAtIndex:0];
    NSString* method = [(NSString*)[components objectAtIndex:1] stringByRemovingPercentEncoding];
    NSObject* interface = [self.javascriptInterfaces objectForKey:obj];

    // execute the interfacing method
    SEL selector = NSSelectorFromString(method);
    NSMethodSignature* sig = [interface methodSignatureForSelector:selector];
    if (!sig) {
        completionHandler(nil);
        return;
    }
    NSInvocation* invoker = [NSInvocation invocationWithMethodSignature:sig];
    invoker.selector = selector;
    invoker.target = interface;

    if ([components count] > 2){
        NSString *argsAsString = [(NSString*)[components objectAtIndex:2] stringByRemovingPercentEncoding];
        NSArray* formattedArgs = [argsAsString componentsSeparatedByString:@":"];
        NSUInteger argCount = [formattedArgs count];

        for (unsigned long i = 0, j = 0; i + 1 < argCount; i += 2, j++){
            NSUInteger argumentIndex = j + 2;
            if (argumentIndex >= sig.numberOfArguments) {
                break;
            }
            NSString* type = ((NSString*) [formattedArgs objectAtIndex:i]);
            NSString* argStr = ((NSString*) [formattedArgs objectAtIndex:i + 1]);

            if ([@"f" isEqualToString:type]){
                PWEasyJSWKDataFunction *func = [[PWEasyJSWKDataFunction alloc] initWithWebView:webView];
                func.funcID = argStr;
                //do this to force retain a reference to it
                [_funcs addObject:func];
                [invoker setArgument:&func atIndex:argumentIndex];
            }else if ([@"s" isEqualToString:type]){
                NSString* arg = [argStr stringByRemovingPercentEncoding];
                //do this to force retain a reference to it
                [_args addObject:arg];
                [invoker setArgument:&arg atIndex:argumentIndex];
            }
        }
    }

    BOOL methodReturnsValue = [sig methodReturnLength] > 0;

    if (!methodReturnsValue) {
        completionHandler(nil);
    }

    [invoker retainArguments];
    [invoker invoke];

    //return the value by using javascript
    if (methodReturnsValue){
        NSString *retValue = nil;
        const char *returnType = [sig methodReturnType];
        if (returnType != NULL && returnType[0] == '@') {
            __unsafe_unretained id tmpRetValue = nil;
            [invoker getReturnValue:&tmpRetValue];
            if ([tmpRetValue isKindOfClass:[NSString class]]) {
                retValue = tmpRetValue;
            }
        }

        if (retValue != nil) {
            retValue = [retValue stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]]; //trick for fallback: in previous versions strings must be returned as @"\"Hamburger\""
            retValue = [retValue stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet letterCharacterSet]];
        }

        completionHandler(retValue);
    }

    //clean up any retained funcs
    [_funcs removeAllObjects];
    //clean up any retained args
    [_args removeAllObjects];
}

@end
#endif
