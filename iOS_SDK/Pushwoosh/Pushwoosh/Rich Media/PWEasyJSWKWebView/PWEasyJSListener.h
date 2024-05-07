//
//  EasyJSListener.h
//  EasyJSWKWebView
//
//  Created by Lau Alex on 19/1/13.
//  Copyright (c) 2013 Dukeland. All rights reserved.
//
//  Modified for WKWebview by Zayin Krige on 2016/10/05
//  Copyright (c) 2016 Apex Technology. All rights reserved.
//  zayin@apextechnology.co.za
//

#import <Foundation/Foundation.h>
@import WebKit;

@interface PWEasyJSListener : NSObject <WKUIDelegate>

@property (nonatomic) NSDictionary* javascriptInterfaces;
@property (nonatomic) NSMutableDictionary *updatedJavascriptInterfaces;

@end
