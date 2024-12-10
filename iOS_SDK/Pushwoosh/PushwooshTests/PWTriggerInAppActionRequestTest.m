//
//  PWTriggerInAppActionRequestTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 25.01.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <OCHamcrest/OCHamcrest.h>

#import "PWTriggerInAppActionRequest.h"
#import "PWInAppMessagesManager.h"

@interface PWTriggerInAppActionRequestTest : XCTestCase

@property (nonatomic) PWTriggerInAppActionRequest *request;

@end

@implementation PWTriggerInAppActionRequestTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.request = [[PWTriggerInAppActionRequest alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testRequestDictionaryHasParameters {
    [self.request setInAppCode:@"code"];
    
    NSDictionary *parameters = [self.request requestDictionary];
    
    assertThat(parameters, hasKey(@"action"));
    assertThat(parameters, hasKey(@"code"));
    assertThat(parameters, hasKey(@"timestampUTC"));
    assertThat(parameters, hasKey(@"timestampCurrent"));
}

- (void)testRequestDictionaryHasParameterRichMediaCode {
    [self.request setRichMediaCode:@"r-XXXXX-XXXXX"];
    
    NSDictionary *parameters = [self.request requestDictionary];
    
    assertThat(parameters, hasKey(@"action"));
    assertThat(parameters, hasKey(@"richMediaCode"));
    assertThat(parameters, hasKey(@"timestampUTC"));
    assertThat(parameters, hasKey(@"timestampCurrent"));
}

- (void)testRequestDictionaryHasParameterMessageHash {
    [self.request setMessageHash:@"__some_message_hash"];
    
    NSDictionary *parameters = [self.request requestDictionary];
    
    assertThat(parameters, hasKey(@"action"));
    assertThat(parameters, hasKey(@"messageHash"));
    assertThat(parameters, hasKey(@"timestampUTC"));
    assertThat(parameters, hasKey(@"timestampCurrent"));
}

- (void)testMethodNameIsCorret {
    NSString *methodName = [self.request methodName];
    
    XCTAssertEqualObjects(methodName, @"triggerInAppAction");
}

@end
