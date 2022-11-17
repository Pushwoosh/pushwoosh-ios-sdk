//
//  EasyJSWKDataFunction.h
//  EasyJSWKWebView
//
//  Created by Alex Lau on 21/1/13.
//  Copyright (c) 2013 Dukeland. All rights reserved.
//
//  Modified for WKWebview by Zayin Krige on 2016/10/05
//  Copyright (c) 2016 Apex Technology. All rights reserved.
//  zayin@apextechnology.co.za
//

#import <Foundation/Foundation.h>
#import "PWEasyJSWKWebView.h"

@interface PWEasyJSWKDataFunction : NSObject

@property (nonatomic) NSString* funcID;
@property (nonatomic) PWEasyJSWKWebView* webView;
@property (nonatomic) BOOL removeAfterExecute;

- (instancetype)initWithWebView:(PWEasyJSWKWebView*)_webView;
- (NSString *)execute;
- (NSString *)executeWithParam:(NSString*) param;
- (NSString *)executeWithParams:(NSArray*) params;

@end
