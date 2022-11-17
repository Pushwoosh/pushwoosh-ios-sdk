//
//  WKUserScript+InterfacesScriptGenerator.h
//  EasyJSWKWebView
//
//  Created by Zayin Krige on 2016/10/05.
//  Copyright © 2016 Apex Technology. All rights reserved.
//

#import <WebKit/WebKit.h>

@interface WKUserScript (PWInterfacesScriptGenerator)
//interfaces is a @{@"InterfaceName":InterfaceObjectInstance}
+ (instancetype)pw_generateScriptForInterfaces:(NSDictionary *)interfaces;
+ (instancetype)pw_generateMainScript;
@end
