//
//  EasyJSWKWebView.m
//  EasyJSWKWebView
//
//  Created by Lau Alex on 19/1/13.
//  Copyright (c) 2013 Dukeland. All rights reserved.
//
//  Modified for WKWebview by Zayin Krige on 2016/10/05
//  Copyright (c) 2016 Apex Technology. All rights reserved.
//  zayin@apextechnology.co.za
//

#import "PWEasyJSWKWebView.h"
#import "PWEasyJSListener.h"
#import "PWWebClient.h"
#import "WKUserScript+PWInterfacesScriptGenerator.h"

@interface PWEasyJSWKWebView()
@property (nonatomic, strong) PWEasyJSListener* listener;
@property (nonatomic) WKUserContentController *controller;
@end

@implementation PWEasyJSWKWebView

- (instancetype)initWithFrame:(CGRect)frame
                configuration:(WKWebViewConfiguration *)configuration
     withJavascriptInterfaces:(NSDictionary *)interfaces
                  userScripts:(NSArray<WKUserScript *> *)scripts {
    
    _controller = configuration.userContentController;
    
    if (!_controller) {
        _controller = [WKUserContentController new];
    }
    
    [_controller addUserScript:[WKUserScript pw_generateMainScript]];
    [_controller addUserScript:[WKUserScript pw_generateScriptForInterfaces:interfaces]];
    
    for (WKUserScript *script in scripts) {
        [_controller addUserScript:script];
    }
    
    self = [super initWithFrame:frame configuration:configuration];
    
    _listener = [PWEasyJSListener new];
    _listener.updatedJavascriptInterfaces = [NSMutableDictionary new];
    [_listener.updatedJavascriptInterfaces addEntriesFromDictionary:interfaces];
    _listener.javascriptInterfaces = interfaces;
    
    self.UIDelegate = _listener;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateScript:) name:kJavaScriptUpdated object:nil];
    
    return self;
}

- (void)updateScript:(NSNotification *)notification {
    NSDictionary *interface = [[notification userInfo] objectForKey:kInterface];
    
    [_controller addUserScript:[WKUserScript pw_generateScriptForInterfaces:interface]];
    
    [_listener.updatedJavascriptInterfaces addEntriesFromDictionary:interface];
    _listener.javascriptInterfaces = [NSDictionary dictionaryWithDictionary:_listener.updatedJavascriptInterfaces];
    
    self.UIDelegate = _listener;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kReloadWebView object:nil userInfo:nil];
}

@end
