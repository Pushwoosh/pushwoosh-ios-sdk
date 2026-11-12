//
//  PWWebClient.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2017
//

#if TARGET_OS_IOS

#import <PushwooshCore/PWResource.h>
#import <PushwooshCore/PWEasyJSWKWebView.h>
#import <Foundation/Foundation.h>
#import <PushwooshCore/PushwooshLog.h>
#import <PushwooshCore/PWPreferences.h>
#import <WebKit/WebKit.h>

@class PWRichMediaManager;
@class PWRichMedia;

#define kJavaScriptUpdated @"keyJavaScriptUpdate"
#define kReloadWebView @"keyReloadWebView"
#define kInterface @"keyInterface"

@class PWWebClient;

typedef NS_ENUM(NSInteger, PWLinkAction) {
    PWLinkActionBridge,
    PWLinkActionIgnore,
    PWLinkActionCloseOnly,
    PWLinkActionCloseAndOpen
};

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

/// Links open without closing the content; local file links are consumed.
@property (nonatomic) BOOL opensLinksWithoutClosing;

/// Called when the page runs `pushwoosh.registerForPushNotifications()` or `pushwoosh.openAppSettings()`,
/// which close the content right after.
@property (nonatomic, copy) dispatch_block_t closingActionBlock;

/// Asked before `pushwoosh.postEvent()` or `pushManager.postEvent()` of the page is sent; NO drops the event.
@property (nonatomic, copy) BOOL (^shouldPostEventBlock)(void);

/// NO while `shouldPostEventBlock` holds the page's events back.
- (BOOL)allowsPostEvent;

+ (void)addJavascriptInterface:(NSObject *)interface withName:(NSString *)name;

#if TARGET_OS_IOS
- (id)initWithParentView:(UIView *)parentView payload:(NSDictionary *)payload code:(NSString *)code inAppCode:(NSString *)inAppCode;
#else
- (id)initWithParentView:(UIView *)parentView payload:(NSDictionary *)payload code:(NSString *)code inAppCode:(NSString *)inAppCode;
#endif

- (void)close;

@end
#endif
