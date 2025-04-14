//
//  PWRichMediaView.m
//  Pushwoosh.ios
//
//  Created by Fectum on 22/10/2018.
//  Copyright © 2018 Pushwoosh. All rights reserved.
//

#import "PWRichMediaView.h"
#import "PWUtils.h"
#import "PWInAppMessagesManager.h"
#import "PWInAppManager+Internal.h"
#import "PWPushManagerJSBridge.h"
#import "PWPushwooshJSBridge.h"
#import "PWRichMediaManager.h"
#import "PWRichMedia+Internal.h"

@interface PWRichMediaView ()

@property (nonatomic) void (^completion)(NSError *error);

@end

@implementation PWRichMediaView

- (instancetype)initWithFrame:(CGRect)frame payload:(NSDictionary *)payload code:(NSString *)code inAppCode:(NSString *)inAppCode {
    if (self = [super initWithFrame:frame]) {
        _webClient = [[PWWebClient alloc] initWithParentView:self payload:payload code:code inAppCode:inAppCode];
        _webClient.delegate = self;
        
        #if TARGET_OS_IOS
        [_webClient.webView.scrollView addObserver:self forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:nil];
        self.backgroundColor = [UIColor clearColor];
        #endif
        
        [self refreshContentSize];
    }
    return self;
}

- (void)loadRichMedia:(PWRichMedia *)richMedia completion:(void (^)(NSError *))completion {
    _richMedia = richMedia;
    _completion = completion;
    
    _webClient.richMedia = richMedia;
    
    if (richMedia) {
        _richMedia.resource.locked = YES;
        [_richMedia.resource getHTMLDataWithCompletion:^(NSString *htmlData, NSError *error) {
            if (!htmlData) {
                NSString *errorString = [NSString stringWithFormat: @"Failed to load InApp: %@", _richMedia.resource.url];
                [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:errorString];
                error = [PWUtils pushwooshError:errorString];
            }
            
            if (error) {
                if (_completion) {
                    _completion(error);
                }
            } else {
                NSString *resPath = [_richMedia.resource localPath];
                NSURL *baseURL = [NSURL fileURLWithPath:resPath isDirectory:YES];
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSURL *htmlDataFile = [[NSURL fileURLWithPath:resPath] URLByAppendingPathComponent:@"pw_prepared_rich_media.html"];
                    NSError *error = nil;
                    [htmlData writeToURL:htmlDataFile atomically:NO encoding:NSUTF8StringEncoding error:&error];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (!error) {
                            if ([_webClient.webView respondsToSelector:@selector(loadFileURL:allowingReadAccessToURL:)]) {
                                [_webClient.webView loadFileURL:htmlDataFile allowingReadAccessToURL:baseURL];
                            } else {
                                [_webClient.webView loadRequest:[NSURLRequest requestWithURL:htmlDataFile]];
                            }
                        } else {
                            if (_completion) {
                                _completion(error);
                            }
                        }
                    });
                });
            }
        }];
    } else {
        [self refreshContentSize];
    }
}

- (void)refreshContentSize {
    #if TARGET_OS_IOS
    _contentSize = _richMedia && !CGSizeEqualToSize(_webClient.webView.scrollView.contentSize, CGSizeZero) ? _webClient.webView.scrollView.contentSize : CGSizeMake(self.bounds.size.width, 1);
    #endif
}

 #if TARGET_OS_IOS
//contentSize is not ready yet on webClientDidFinishLoad: call
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (object == _webClient.webView.scrollView && [keyPath isEqual:@"contentSize"]) {
        [self refreshContentSize];
        
        if (_contentSizeDidChangeBlock && _richMedia) {
            _contentSizeDidChangeBlock();
        }
    }
}
#endif

#pragma mark PWWebClientDelegate

- (void)webClientDidFinishLoad:(PWWebClient *)webClient {
    [self refreshContentSize];
    
    [[PWInAppManager sharedManager].inAppMessagesManager trackInAppWithCode:_richMedia.resource.code action:PW_INAPP_ACTION_SHOW messageHash:[webClient.richMedia.pushPayload objectForKey:@"p"]];
    
    if (_completion) {
        _completion(nil);
    }
}

- (void)webClientDidStartClose:(PWWebClient *)webClient {
    if (_closeActionBlock) {
        _closeActionBlock();
    }
}

#pragma mark Teardown

- (void)dealloc {
    _richMedia.resource.locked = NO;
    #if TARGET_OS_IOS
    [_webClient.webView.scrollView removeObserver:self forKeyPath:@"contentSize"];
    #endif
}

@end
