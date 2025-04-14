//
//  PWWebClient.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2017
//


#import "PWResource.h"
#import "PWEasyJSWKWebView.h"
#import <Foundation/Foundation.h>
#import "PWRichMediaManager.h"
#import <PushwooshCore/PushwooshLog.h>

#import <WebKit/WebKit.h>

#define kJavaScriptUpdated @"keyJavaScriptUpdate"
#define kReloadWebView @"keyReloadWebView"
#define kInterface @"keyInterface"

@class PWWebClient;

@protocol PWWebClientDelegate <NSObject>

- (void)webClientDidFinishLoad:(PWWebClient *)webClient;

- (void)webClientDidStartClose:(PWWebClient *)webClient;

@end


@interface PWWebClient : NSObject

@property (nonatomic, weak) NSObject<PWWebClientDelegate> *delegate;

@property (nonatomic, strong, readonly) WKWebView *webView;

@property (nonatomic) PWRichMedia *richMedia;
@property (nonatomic) NSString *messageHash;
@property (nonatomic) NSString *richMediaCode;
@property (nonatomic) NSString *inAppCode;

+ (void)addJavascriptInterface:(NSObject *)interface withName:(NSString *)name;

#if TARGET_OS_IOS
- (id)initWithParentView:(UIView *)parentView payload:(NSDictionary *)payload code:(NSString *)code inAppCode:(NSString *)inAppCode;
#else
- (id)initWithParentView:(UIView *)parentView payload:(NSDictionary *)payload code:(NSString *)code inAppCode:(NSString *)inAppCode;
#endif

- (void)close;

@end
