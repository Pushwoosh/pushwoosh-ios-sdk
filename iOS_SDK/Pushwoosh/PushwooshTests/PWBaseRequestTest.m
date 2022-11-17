//
//  PWBaseRequestTest.m
//  PushwooshTests
//
//  Created by Fectum on 01/03/2018.
//  Copyright © 2018 Pushwoosh. All rights reserved.
//

#import "PWBaseRequestTest.h"

@implementation PWBaseRequestTest

- (NSDictionary *)responseFromString:(NSString *)responseString {
    NSData *responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *response = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:nil];
    
    XCTAssertNotNil(response);
    
    return response;
}

@end
