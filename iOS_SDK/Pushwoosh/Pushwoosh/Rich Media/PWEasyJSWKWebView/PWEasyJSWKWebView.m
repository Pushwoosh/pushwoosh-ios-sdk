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
#import "WKUserScript+PWInterfacesScriptGenerator.h"

@interface PWEasyJSWKWebView()
@property (nonatomic, strong) PWEasyJSListener* listener;
@end

@implementation PWEasyJSWKWebView

- (instancetype)initWithFrame:(CGRect)frame
                configuration:(WKWebViewConfiguration *)configuration
     withJavascriptInterfaces:(NSDictionary *)interfaces
                  userScripts:(NSArray<WKUserScript *> *)scripts {
    
    WKUserContentController *controller = configuration.userContentController;
    
    if (!controller) {
        controller = [WKUserContentController new];
    }
    
    [controller addUserScript:[WKUserScript pw_generateMainScript]];
    [controller addUserScript:[WKUserScript pw_generateScriptForInterfaces:interfaces]];
    
    for (WKUserScript *script in scripts) {
        [controller addUserScript:script];
    }
    
    self = [super initWithFrame:frame configuration:configuration];
    
    _listener = [PWEasyJSListener new];
    _listener.javascriptInterfaces = interfaces;
    
    self.UIDelegate = _listener;
    
    return self;
}

@end
