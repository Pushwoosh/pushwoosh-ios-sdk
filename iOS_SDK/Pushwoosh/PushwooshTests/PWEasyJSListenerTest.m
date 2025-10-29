#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <WebKit/WebKit.h>
#import "PWEasyJSListener.h"

@interface PWEasyJSListenerTestInterface : NSObject
@property (nonatomic, strong) NSString *lastMethodCalled;
@property (nonatomic, strong) NSString *lastStringArg;
@property (nonatomic, strong) NSString *lastStringArg2;
@property (nonatomic, assign) BOOL methodWithoutReturnCalled;
@end

@implementation PWEasyJSListenerTestInterface

- (void)methodWithoutReturn {
    self.methodWithoutReturnCalled = YES;
    self.lastMethodCalled = @"methodWithoutReturn";
}

- (void)methodWithString:(NSString *)arg {
    self.lastMethodCalled = @"methodWithString:";
    self.lastStringArg = arg;
}

- (void)methodWithTwoStrings:(NSString *)arg1 :(NSString *)arg2 {
    self.lastMethodCalled = @"methodWithTwoStrings::";
    self.lastStringArg = arg1;
    self.lastStringArg2 = arg2;
}

- (NSString *)methodReturningString {
    self.lastMethodCalled = @"methodReturningString";
    return @"TestResult";
}

- (NSString *)methodReturningStringWithArg:(NSString *)arg {
    self.lastMethodCalled = @"methodReturningStringWithArg:";
    self.lastStringArg = arg;
    return @"ReturnedValue";
}

@end

@interface PWEasyJSListenerTest : XCTestCase
@property (nonatomic, strong) PWEasyJSListener *listener;
@property (nonatomic, strong) PWEasyJSListenerTestInterface *testInterface;
@property (nonatomic, strong) id mockWebView;
@property (nonatomic, strong) id mockFrame;
@end

@implementation PWEasyJSListenerTest

- (void)setUp {
    [super setUp];

    self.listener = [[PWEasyJSListener alloc] init];
    self.testInterface = [[PWEasyJSListenerTestInterface alloc] init];

    self.listener.javascriptInterfaces = @{@"TestInterface": self.testInterface};

    self.mockWebView = OCMClassMock([WKWebView class]);
    self.mockFrame = OCMClassMock([WKFrameInfo class]);
}

- (void)tearDown {
    self.listener = nil;
    self.testInterface = nil;
    self.mockWebView = nil;
    self.mockFrame = nil;
    [super tearDown];
}

- (void)testMethodWithoutReturnValue {
    NSString *prompt = @"TestInterface:methodWithoutReturn";

    __block BOOL completionCalled = NO;
    [self.listener webView:self.mockWebView
runJavaScriptTextInputPanelWithPrompt:prompt
               defaultText:nil
            initiatedByFrame:self.mockFrame
         completionHandler:^(NSString *result) {
        completionCalled = YES;
        XCTAssertNil(result);
    }];

    XCTAssertTrue(completionCalled);
    XCTAssertTrue(self.testInterface.methodWithoutReturnCalled);
    XCTAssertEqualObjects(self.testInterface.lastMethodCalled, @"methodWithoutReturn");
}

- (void)testMethodWithStringArgument {
    NSMutableCharacterSet *allowedChars = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    [allowedChars removeCharactersInString:@":"];
    NSString *encodedMethod = [@"methodWithString:" stringByAddingPercentEncodingWithAllowedCharacters:allowedChars];
    NSString *encodedArgs = [@"s:TestValue" stringByAddingPercentEncodingWithAllowedCharacters:allowedChars];
    NSString *prompt = [NSString stringWithFormat:@"TestInterface:%@:%@", encodedMethod, encodedArgs];

    __block BOOL completionCalled = NO;
    [self.listener webView:self.mockWebView
runJavaScriptTextInputPanelWithPrompt:prompt
               defaultText:nil
            initiatedByFrame:self.mockFrame
         completionHandler:^(NSString *result) {
        completionCalled = YES;
        XCTAssertNil(result);
    }];

    XCTAssertTrue(completionCalled);
    XCTAssertEqualObjects(self.testInterface.lastMethodCalled, @"methodWithString:");
    XCTAssertEqualObjects(self.testInterface.lastStringArg, @"TestValue");
}

- (void)testMethodWithPercentEncodedArgument {
    NSMutableCharacterSet *allowedChars = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    [allowedChars removeCharactersInString:@":"];
    NSString *encodedMethod = [@"methodWithString:" stringByAddingPercentEncodingWithAllowedCharacters:allowedChars];
    NSString *encodedArgs = [@"s:Test Value" stringByAddingPercentEncodingWithAllowedCharacters:allowedChars];
    NSString *prompt = [NSString stringWithFormat:@"TestInterface:%@:%@", encodedMethod, encodedArgs];

    __block BOOL completionCalled = NO;
    [self.listener webView:self.mockWebView
runJavaScriptTextInputPanelWithPrompt:prompt
               defaultText:nil
            initiatedByFrame:self.mockFrame
         completionHandler:^(NSString *result) {
        completionCalled = YES;
        XCTAssertNil(result);
    }];

    XCTAssertTrue(completionCalled);
    XCTAssertEqualObjects(self.testInterface.lastStringArg, @"Test Value");
}

- (void)testMethodWithTwoStringArguments {
    NSMutableCharacterSet *allowedChars = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    [allowedChars removeCharactersInString:@":"];
    NSString *encodedMethod = [@"methodWithTwoStrings::" stringByAddingPercentEncodingWithAllowedCharacters:allowedChars];
    NSString *encodedArgs = [@"s:FirstValue:s:SecondValue" stringByAddingPercentEncodingWithAllowedCharacters:allowedChars];
    NSString *prompt = [NSString stringWithFormat:@"TestInterface:%@:%@", encodedMethod, encodedArgs];

    __block BOOL completionCalled = NO;
    [self.listener webView:self.mockWebView
runJavaScriptTextInputPanelWithPrompt:prompt
               defaultText:nil
            initiatedByFrame:self.mockFrame
         completionHandler:^(NSString *result) {
        completionCalled = YES;
        XCTAssertNil(result);
    }];

    XCTAssertTrue(completionCalled);
    XCTAssertEqualObjects(self.testInterface.lastMethodCalled, @"methodWithTwoStrings::");
    XCTAssertEqualObjects(self.testInterface.lastStringArg, @"FirstValue");
    XCTAssertEqualObjects(self.testInterface.lastStringArg2, @"SecondValue");
}

- (void)testMethodReturningString {
    NSString *prompt = @"TestInterface:methodReturningString";

    __block NSString *returnedValue = nil;
    [self.listener webView:self.mockWebView
runJavaScriptTextInputPanelWithPrompt:prompt
               defaultText:nil
            initiatedByFrame:self.mockFrame
         completionHandler:^(NSString *result) {
        returnedValue = result;
    }];

    XCTAssertNotNil(returnedValue);
    NSString *decodedResult = [returnedValue stringByRemovingPercentEncoding];
    XCTAssertEqualObjects(decodedResult, @"TestResult");
    XCTAssertEqualObjects(self.testInterface.lastMethodCalled, @"methodReturningString");
}

- (void)testMethodReturningStringWithArgument {
    NSMutableCharacterSet *allowedChars = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    [allowedChars removeCharactersInString:@":"];
    NSString *encodedMethod = [@"methodReturningStringWithArg:" stringByAddingPercentEncodingWithAllowedCharacters:allowedChars];
    NSString *encodedArgs = [@"s:InputValue" stringByAddingPercentEncodingWithAllowedCharacters:allowedChars];
    NSString *prompt = [NSString stringWithFormat:@"TestInterface:%@:%@", encodedMethod, encodedArgs];

    __block NSString *returnedValue = nil;
    [self.listener webView:self.mockWebView
runJavaScriptTextInputPanelWithPrompt:prompt
               defaultText:nil
            initiatedByFrame:self.mockFrame
         completionHandler:^(NSString *result) {
        returnedValue = result;
    }];

    XCTAssertNotNil(returnedValue);
    NSString *decodedResult = [returnedValue stringByRemovingPercentEncoding];
    XCTAssertEqualObjects(decodedResult, @"ReturnedValue");
    XCTAssertEqualObjects(self.testInterface.lastStringArg, @"InputValue");
}

- (void)testJavascriptInterfacesProperty {
    NSDictionary *interfaces = @{@"Interface1": @"value1", @"Interface2": @"value2"};
    self.listener.javascriptInterfaces = interfaces;

    XCTAssertEqualObjects(self.listener.javascriptInterfaces, interfaces);
}

- (void)testUpdatedJavascriptInterfacesProperty {
    NSMutableDictionary *updatedInterfaces = [NSMutableDictionary dictionaryWithObject:@"value" forKey:@"key"];
    self.listener.updatedJavascriptInterfaces = updatedInterfaces;

    XCTAssertEqualObjects(self.listener.updatedJavascriptInterfaces, updatedInterfaces);
}

@end
