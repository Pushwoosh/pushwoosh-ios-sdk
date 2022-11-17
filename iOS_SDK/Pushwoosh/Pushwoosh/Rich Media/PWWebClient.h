//
//  PWWebClient.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2017
//


#import "PWResource.h"
#import "PWEasyJSWKWebView.h"
#import <Foundation/Foundation.h>
#import "PWRichMediaManager.h"

#import <WebKit/WebKit.h>

@class PWWebClient;

@protocol PWWebClientDelegate <NSObject>

- (void)webClientDidFinishLoad:(PWWebClient *)webClient;

- (void)webClientDidStartClose:(PWWebClient *)webClient;

@end


@interface PWWebClient : NSObject

@property (nonatomic, weak) NSObject<PWWebClientDelegate> *delegate;

@property (nonatomic, strong, readonly) WKWebView *webView;

@property (nonatomic) PWRichMedia *richMedia;

+ (void)addJavascriptInterface:(NSObject *)interface withName:(NSString *)name;

#if TARGET_OS_IOS
- (id)initWithParentView:(UIView *)parentView;
#else
- (id)initWithParentView:(NSView *)parentView;
#endif

- (void)close;

@end
