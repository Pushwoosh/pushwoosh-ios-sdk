//
//  EasyJSDataFunction.m
//  EasyJSWKWebView
//
//  Created by Alex Lau on 21/1/13.
//  Copyright (c) 2013 Dukeland. All rights reserved.
//
//  Modified for WKWebview by Zayin Krige on 2016/10/05
//  Copyright (c) 2016 Apex Technology. All rights reserved.
//  zayin@apextechnology.co.za
//

#import "PWEasyJSWKDataFunction.h"
#import "WKWebView+PWSynchronousEvaluateJavaScript.h"

@implementation PWEasyJSWKDataFunction

@synthesize funcID;
@synthesize webView;
@synthesize removeAfterExecute;

- (instancetype)initWithWebView:(PWEasyJSWKWebView *)_webView{
	self = [super init];
    if (self) {
		self.webView = _webView;
    }
    return self;
}

- (NSString *)execute{
	return [self executeWithParams:nil];
}

- (NSString *)executeWithParam: (NSString*) param{
	NSMutableArray* params = [[NSMutableArray alloc] initWithObjects:param, nil];
	return [self executeWithParams:params];
}

- (NSString *)executeWithParams: (NSArray*) params{
	NSMutableString* injection = [[NSMutableString alloc] init];
	
	[injection appendFormat:@"EasyJS.invokeCallback(\"%@\", %@", self.funcID, self.removeAfterExecute ? @"true" : @"false"];
	
	if (params){
		for (unsigned long i = 0, l = params.count; i < l; i++){
			NSString* arg = [params objectAtIndex:i];
            NSCharacterSet *chars = [NSCharacterSet characterSetWithCharactersInString:@"!*'();:@&=+$,/?%#[]"];
            NSString *encodedArg = [arg stringByAddingPercentEncodingWithAllowedCharacters:chars];
			[injection appendFormat:@", \"%@\"", encodedArg];
		}
	}
	
	[injection appendString:@");"];
	
	if (self.webView){
        return [self.webView pw_stringByEvaluatingJavaScriptFromString:injection error:nil];
	}else{
		return nil;
	}
}

@end
