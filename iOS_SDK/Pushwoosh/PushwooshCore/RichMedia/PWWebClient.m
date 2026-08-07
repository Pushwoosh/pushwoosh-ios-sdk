//
//  PWWebClient.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2017
//

#if TARGET_OS_IOS
#import "PWWebClient.h"
#import "PWPushManagerJSBridge.h"
#import "PWPushwooshJSBridge.h"
#import "PWInAppManager.h"
#import "PWUtils.h"
#import "PWPreferences.h"
#import "PWResource.h"
#import <PushwooshCore/PushwooshCore.h>
#import "PWInAppStorage.h"
#import "PWRichMedia.h"

static NSString* PUSHWOOSH_JS = @"window.pushwoosh = {\
postEvent: function(event, attributes, successCallback, errorCallback) {\
	/* TODO(SDK-XXX): typo 'attribtes' leaks a global and never assigns 'attributes'; */\
	/* postEvent() called with no attributes sends nil to native. Pre-existing, separate ticket. */\
	if (!attributes) {\
		attribtes = {};\
	}\
	\
	if (!successCallback) {\
		successCallback = function() {};\
	}\
	\
	if (!errorCallback) {\
		errorCallback = function(error) {};\
	}\
	\
	pushwooshImpl.postEvent(event, JSON.stringify(attributes), successCallback, errorCallback);\
},\
richMediaAction: function(inAppCode, richMediaCode, actionType, actionAttributes, successCallback, errorCallback) {\
    if (!actionAttributes) {\
        actionAttributes = {};\
    }\
    \
    if (!successCallback) {\
        successCallback = function() {};\
    }\
    \
    if (!errorCallback) {\
        errorCallback = function(error) {};\
    }\
    \
    pushwooshImpl.richMediaAction(inAppCode, richMediaCode, actionType, JSON.stringify(actionAttributes), successCallback, errorCallback);\
},\
\
sendTags: function(tags) {\
	pushwooshImpl.sendTags(JSON.stringify(tags));\
},\
\
getTags: function(successCallback, errorCallback) {\
	if (!errorCallback) {\
		errorCallback = function(error) {};\
	}\
	\
	pushwooshImpl.getTags(function(tagsString) {\
		successCallback(JSON.parse(tagsString));\
	}, errorCallback);\
},\
\
log: function(str) {\
	pushwooshImpl.log(str);\
},\
\
closeInApp: function() {\
	pushwooshImpl.closeInApp();\
},\
\
getHwid: function() {\
return this._hwid;\
},\
\
getVersion: function() {\
	return this._version;\
},\
\
getApplication: function() {\
    return this._application;\
},\
\
getUserId: function() {\
    return this._user_id;\
},\
\
getRichmediaCode: function() {\
    return this._richmedia_code;\
},\
\
getDeviceType: function() {\
    return this._device_type;\
},\
\
getMessageHash: function() {\
    return this._message_hash;\
},\
\
getInAppCode: function() {\
    return this._inapp_code;\
},\
\
registerForPushNotifications: function() {\
    pushwooshImpl.registerForPushNotifications();\
    pushwooshImpl.closeInApp();\
},\
\
openAppSettings: function() {\
    pushwooshImpl.openAppSettings();\
    pushwooshImpl.closeInApp();\
},\
\
unregisterForPushNotifications: function(callback) {\
    pushwooshImpl.unregisterForPushNotifications(callback);\
},\
\
isRegisteredForPushNotifications: function(callback) {\
    pushwooshImpl.isRegisteredForPushNotifications(callback);\
},\
\
getCustomData: function() {\
    return this._customData;\
},\
\
setEmail: function(email) {\
    pushwooshImpl.setEmail(email);\
}\
};\
";


static NSMutableDictionary *sJavaScriptInterfaces;

@interface PWWebClient() <WKNavigationDelegate, PWPushManagerJSBridgeDelegate>

@property (nonatomic, strong) NSDictionary *javascriptInterfaces;

@end

@implementation PWWebClient

/// Renders a value as a JavaScript string literal, quotes included, so a quote or a backslash in a
/// client-supplied value (userId is often an email typed by the end user) cannot escape the literal
/// and execute inside the rich media page.
///
/// Serialization is not guaranteed to succeed: a lone surrogate — `"\ud83d"` from a backend response,
/// or a string truncated in the middle of an emoji — makes `dataWithJSONObject:` return nil without
/// raising. Falling back to the hand-quoted form there would restore the exact injection this method
/// exists to prevent, so an unserializable value renders as an empty literal instead.
+ (NSString *)pw_jsLiteralForString:(NSString *)value {
    NSString *safeValue = @"";
    if ([value isKindOfClass:[NSString class]]) {
        safeValue = value;
    } else if (value != nil) {
        safeValue = [NSString stringWithFormat:@"%@", value];
    }

    NSData *json = [NSJSONSerialization dataWithJSONObject:@[safeValue] options:0 error:nil];
    NSString *serialized = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : nil;

    if (serialized.length > 2) {
        return [serialized substringWithRange:NSMakeRange(1, serialized.length - 2)];
    }

    return @"\"\"";
}

/// Normalizes custom push data before it is injected as a raw JavaScript value (rich media templates
/// expect an object there, not a string, so it must not be quoted). The payload is parsed and
/// re-serialized, so anything that is not valid JSON — including a value carrying trailing
/// statements — is rejected instead of being executed.
+ (NSString *)pw_jsJSONValueForString:(NSString *)value {
    if (![value isKindOfClass:[NSString class]] || value.length == 0) {
        return nil;
    }

    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    id parsed = data ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil] : nil;

    if (parsed == nil) {
        return nil;
    }

    NSData *normalized = [NSJSONSerialization dataWithJSONObject:@[parsed] options:0 error:nil];
    NSString *serialized = normalized ? [[NSString alloc] initWithData:normalized encoding:NSUTF8StringEncoding] : nil;

    if (serialized.length > 2) {
        return [serialized substringWithRange:NSMakeRange(1, serialized.length - 2)];
    }

    return nil;
}

+ (void)addJavascriptInterface:(NSObject*)interface withName:(NSString*)name {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sJavaScriptInterfaces = [NSMutableDictionary new];
	});
	
    @synchronized (sJavaScriptInterfaces) {
        sJavaScriptInterfaces[name] = interface;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kJavaScriptUpdated object:nil userInfo:@{kInterface: sJavaScriptInterfaces}];
    }
}

- (void)reloadWebView {
    if (_webView.URL != nil) return;
    [_webView reload];
}

#if TARGET_OS_IOS
- (id)initWithParentView:(UIView *)parentView payload:(NSDictionary *)payload code:(NSString *)code inAppCode:(NSString *)inAppCode {
#else
- (id)initWithParentView:(NSView *)parentView payload:(NSDictionary *)payload code:(NSString *)code inAppCode:(NSString *)inAppCode {
#endif
    
    self = [super init];
    
	if (self) {
        @synchronized (sJavaScriptInterfaces) {
            _javascriptInterfaces = [sJavaScriptInterfaces copy];
        }
        
        WKPreferences *prefs = [WKPreferences new];
        prefs.javaScriptEnabled = YES;
#if TARGET_OS_IOS
#ifdef DEBUG
        if ([WKWebView respondsToSelector:@selector(handlesURLScheme:)]) {
            [prefs setValue:@"YES" forKey:@"developerExtrasEnabled"]; //this enables debugging with safari developer
        }
#endif
#endif
        
        WKWebViewConfiguration *config = [WKWebViewConfiguration new];
        config.preferences = prefs;
#if TARGET_OS_IOS
        config.allowsInlineMediaPlayback = YES;
#endif
        NSString *messageHash = [payload objectForKey:@"p"];
        [self setMessageHash:messageHash ? messageHash : @""];
        [self setRichMediaCode:code];
        [self setInAppCode:inAppCode];
        
        WKUserScript *pushwooshInject = [[WKUserScript alloc] initWithSource:PUSHWOOSH_JS injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
        
        WKUserScript *hwidInject = [[WKUserScript alloc] initWithSource:[NSString stringWithFormat:@"window.pushwoosh._hwid = %@;", [PWWebClient pw_jsLiteralForString:[[PWManagerBridge shared] getHWID]]]
                                                          injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                       forMainFrameOnly:NO];
        
        WKUserScript *versionInject = [[WKUserScript alloc] initWithSource:[NSString stringWithFormat:@"window.pushwoosh._version = \"%@\";", PUSHWOOSH_VERSION]
                                                             injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                          forMainFrameOnly:NO];
        
        WKUserScript *applicationInject = [[WKUserScript alloc] initWithSource:[NSString stringWithFormat:@"window.pushwoosh._application = %@;", [PWWebClient pw_jsLiteralForString:[[PWManagerBridge shared] appCode]]]
                                                                 injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                              forMainFrameOnly:NO];
        
        WKUserScript *userIdInject = [[WKUserScript alloc] initWithSource:[NSString stringWithFormat:@"window.pushwoosh._user_id = %@;", [PWWebClient pw_jsLiteralForString:[[PWPreferences preferences] userId]]]
                                                                 injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                              forMainFrameOnly:NO];
        
        WKUserScript *deviceTypeInject = [[WKUserScript alloc] initWithSource:[NSString stringWithFormat:@"window.pushwoosh._device_type = \"%@\";", @(DEVICE_TYPE)]
                                                                 injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                              forMainFrameOnly:NO];
        
        WKUserScript *messageHashInject = [[WKUserScript alloc] initWithSource:[NSString stringWithFormat:@"window.pushwoosh._message_hash = %@;", [PWWebClient pw_jsLiteralForString:_messageHash]]
                                                                 injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                              forMainFrameOnly:NO];
        
        WKUserScript *richMediaCodeInject = [[WKUserScript alloc] initWithSource:[NSString stringWithFormat:@"window.pushwoosh._richmedia_code = %@;", [PWWebClient pw_jsLiteralForString:_richMediaCode]]
                                                                 injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                              forMainFrameOnly:NO];
                
        WKUserScript *inAppCodeInject = [[WKUserScript alloc] initWithSource:[NSString stringWithFormat:@"window.pushwoosh._inapp_code = %@;", [PWWebClient pw_jsLiteralForString:_inAppCode]]
                                                                 injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                              forMainFrameOnly:NO];
        
        WKUserScript *disableSelectionInject = [[WKUserScript alloc] initWithSource:@"\
                                                (function() {\
                                                var pw_style = document.createElement(\"style\");\
                                                document.getElementsByTagName('body')[0].appendChild(pw_style);\
                                                pw_style.innerHTML = '*:not(input,textarea) {-webkit-touch-callout: none; -webkit-user-select: none;}'\
                                                })();"
                                                                      injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                                                                   forMainFrameOnly:NO];
        
        WKUserScript *addViewPortInject = [[WKUserScript alloc] initWithSource:@"\
                                           var meta = document.createElement('meta'); \
                                           meta.setAttribute('name', 'viewport'); \
                                           meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no'); \
                                           document.getElementsByTagName('head')[0].appendChild(meta);"
                                                                      injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                                                                   forMainFrameOnly:NO];
        
        WKUserScript *removeSelectionInject = [[WKUserScript alloc] initWithSource:@"window.getSelection().removeAllRanges();"
                                                                     injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                                                                  forMainFrameOnly:NO];
        
        PWPushManagerJSBridge *pushManagerJS = [[PWPushManagerJSBridge alloc] initWithClient:self];
        pushManagerJS.delegate = self;
        
        PWPushwooshJSBridge *pushwooshJS = [[PWPushwooshJSBridge alloc] initWithClient:self];
        
        NSMutableDictionary *interfaces = @{@"pushManager" : pushManagerJS,
                                            @"pushwooshImpl" : pushwooshJS
                                            }.mutableCopy;
        
        if (_javascriptInterfaces) {
            [interfaces addEntriesFromDictionary:_javascriptInterfaces];
        }
                
        _webView = [[PWEasyJSWKWebView alloc] initWithFrame:parentView.bounds
                                              configuration:config
                                   withJavascriptInterfaces:interfaces
                                                userScripts:@[addViewPortInject, pushwooshInject, hwidInject, versionInject, applicationInject, userIdInject, deviceTypeInject, messageHashInject, richMediaCodeInject, inAppCodeInject, disableSelectionInject, removeSelectionInject]];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadWebView) name:kReloadWebView object:_webView];
                
#if TARGET_OS_IOS
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
        if ([_webView.scrollView respondsToSelector:@selector(setContentInsetAdjustmentBehavior:)]) {
            _webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }
#pragma clang diagnostic pop
#endif
        
        for (UIView *view in _webView.scrollView.subviews) {
            for (UIGestureRecognizer *gestureRecognizer in view.gestureRecognizers) {
                if ([gestureRecognizer isKindOfClass:UITapGestureRecognizer.class]) {
                    UITapGestureRecognizer *tapRecognizer = (UITapGestureRecognizer *)gestureRecognizer;
                    
                    if (tapRecognizer.numberOfTapsRequired == 2 && tapRecognizer.numberOfTouchesRequired == 1) {
                        tapRecognizer.enabled = NO;
                    }
                }
            }
        }
        
        _webView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        _webView.backgroundColor = [UIColor clearColor];
        _webView.opaque = NO;
        _webView.scrollView.bounces = NO;
#else
        _webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
#endif
		_webView.navigationDelegate = self;
        
        [parentView addSubview:_webView];
	}
    
	return self;
}

- (BOOL)loadPushwooshUrl:(NSURL *)url {
	if ([url.host isEqualToString:@"close"]) {
		[self.delegate webClientDidStartClose:self];
	} else {
        [PushwooshLog pushwooshLog:PW_LL_ERROR
                         className:self
                           message:[NSString stringWithFormat:@"Unrecognized pushwoosh url: %@", url.absoluteString]];
		return NO;
	}
	
	return YES;
}

#pragma mark WKWebViewNavigationDelegate

- (void)webView:(PWEasyJSWKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
#if TARGET_OS_IOS
    for (NSString* name in _javascriptInterfaces) {
        NSObject<PWJavaScriptInterface> *jsInterface = _javascriptInterfaces[name];
        if ([jsInterface respondsToSelector:@selector(onWebViewStartLoad:)]) {
            [jsInterface onWebViewStartLoad:webView];
        }
    }
#endif
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"webViewDidFinishLoad"];
#if TARGET_OS_IOS
    for (NSString* name in _javascriptInterfaces) {
        NSObject<PWJavaScriptInterface> *jsInterface = _javascriptInterfaces[name];
        if ([jsInterface respondsToSelector:@selector(onWebViewFinishLoad:)]) {
            [jsInterface onWebViewFinishLoad:webView];
        }
    }
#endif
    
    if (_richMedia.pushPayload) {
        NSString *customData = [[PWManagerBridge shared] getCustomPushData:_richMedia.pushPayload];
        NSString *customDataValue = [PWWebClient pw_jsJSONValueForString:customData];

        if (customData != nil && customDataValue == nil) {
            [PushwooshLog pushwooshLog:PW_LL_WARN
                             className:self
                               message:@"Custom push data is not valid JSON and was not injected into the rich media page"];
        }

        if (customDataValue) {
            /**
             Starting with iOS 14, we use WKContentWorld to run injected JavaScript in a secure sandboxed environment,
             isolating it from untrusted web JavaScript. More details: https://developer.apple.com/documentation/webkit/wkcontentworld
             */
            if (TARGET_OS_IOS && [PWUtils isSystemVersionGreaterOrEqualTo:@"14.0"]) {
                WKContentWorld* sandbox = [WKContentWorld pageWorld];
                [webView evaluateJavaScript:[NSString stringWithFormat:@"window.pushwoosh._customData = %@;", customDataValue]
                                                   inFrame:nil
                                            inContentWorld:sandbox
                          completionHandler:^(id _Nullable result, NSError * _Nullable error) {
                    [self.delegate webClientDidFinishLoad:self];
                }];
            } else {
                [webView evaluateJavaScript:[NSString stringWithFormat:@"window.pushwoosh._customData = %@;", customDataValue]
                          completionHandler:^(id _Nullable result, NSError * _Nullable error) {
                    [self.delegate webClientDidFinishLoad:self];
                }];
            }

        } else {
            [self.delegate webClientDidFinishLoad:self];
        }
    } else {
        [self.delegate webClientDidFinishLoad:self];
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if (navigationAction.navigationType == WKNavigationTypeLinkActivated || navigationAction.navigationType == WKNavigationTypeFormSubmitted) {
        
        BOOL isPushwooshURLScheme = [navigationAction.request.URL.scheme isEqualToString:@"pushwoosh"];
#if TARGET_OS_IOS
        if (![[UIApplication sharedApplication] canOpenURL:navigationAction.request.URL] && !isPushwooshURLScheme) {
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }
#endif
        
        if (isPushwooshURLScheme) {
            [self loadPushwooshUrl:navigationAction.request.URL];
            decisionHandler(WKNavigationActionPolicyCancel);
        } else {
            [self.delegate webClientDidStartClose:self];
            
#if TARGET_OS_IOS
            //If url has custom scheme like facebook:// or itms:// we need to open it directly:
            //small fix to prevent app freeezes on iOS7
            //see: http://stackoverflow.com/questions/19356488/openurl-freezes-app-for-over-10-seconds
            dispatch_async(dispatch_get_main_queue(), ^{
                [PWUtils openUrl:navigationAction.request.URL];
            });
#else
            [[NSWorkspace sharedWorkspace] openURL:navigationAction.request.URL];
#endif
            
            decisionHandler(WKNavigationActionPolicyCancel);
        }
    } else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [PushwooshLog pushwooshLog:PW_LL_ERROR
                     className:self
                       message:[NSString stringWithFormat:@"webView: didFailLoadWithError: %@", [error description]]];
}

#pragma mark PWMessageJSBridgeDelegate

- (void)onMessageClose {
	[self close];
}

- (void)close {
#if TARGET_OS_IOS
	for (NSString* name in _javascriptInterfaces) {
		NSObject<PWJavaScriptInterface> *jsInterface = _javascriptInterfaces[name];
		if ([jsInterface respondsToSelector:@selector(onWebViewStartClose:)]) {
			[jsInterface onWebViewStartClose:_webView];
		}
	}

    [self.delegate webClientDidStartClose:self];
#endif
}

@end
#endif
