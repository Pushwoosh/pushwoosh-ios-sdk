//
//  PushwooshConfigTrimTest.m
//  PushwooshTests
//
//  Created by André Kis
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PushwooshConfig.h"
#import "PWSdkStateProvider.h"
#import "PWPreferences.h"
#import "PWManagerBridge.h"
#import "PWInAppManager.h"

@interface PWSdkStateProvider (TrimTest)
- (void)resetForTesting;
@end

@interface PushwooshConfigTrimTest : XCTestCase
@property (nonatomic) id mockBridge;
@property (nonatomic) id mockPreferences;
@property (nonatomic, copy) NSString *originalAppCode;
@property (nonatomic, copy) NSString *originalApiToken;
@end

@implementation PushwooshConfigTrimTest

- (void)setUp {
    [super setUp];
    [[PWSdkStateProvider sharedInstance] resetForTesting];
    [[PWSdkStateProvider sharedInstance] setReady];
    _mockBridge = OCMPartialMock([PWManagerBridge shared]);
    _mockPreferences = OCMPartialMock([PWPreferences preferences]);
    _originalAppCode = [[[PWPreferences preferences] appCode] copy];
    _originalApiToken = [[[PWPreferences preferences] apiToken] copy];
}

- (void)tearDown {
    [[PWPreferences preferences] setAppCode:_originalAppCode];
    [[PWPreferences preferences] setApiToken:_originalApiToken];
    [_mockPreferences stopMocking];
    [_mockBridge stopMocking];
    _mockPreferences = nil;
    _mockBridge = nil;
    [[PWSdkStateProvider sharedInstance] resetForTesting];
    [super tearDown];
}

#pragma mark - setAppCode

/// Verifies that trailing newline is stripped before storing app code.
- (void)testSetAppCodeTrimsTrailingNewline {
    [PushwooshConfig setAppCode:@"12345-ABCDE\n"];
    XCTAssertEqualObjects(@"12345-ABCDE", [PushwooshConfig getAppCode]);
}

/// Verifies that whitespace-only app code is rejected and previous value is preserved.
- (void)testSetAppCodeWhitespaceOnlyIsIgnored {
    [PushwooshConfig setAppCode:@"FIRST-APPID"];
    [PushwooshConfig setAppCode:@"   \n"];
    XCTAssertEqualObjects(@"FIRST-APPID", [PushwooshConfig getAppCode]);
}

/// SDK-814: Verifies that dotted app code is rejected and previous canonical value is preserved.
- (void)testSetAppCodeDottedIsRejected {
    [PushwooshConfig setAppCode:@"FIRST-APPID"];
    [PushwooshConfig setAppCode:@"XXXXX-XXXXX.legacy"];
    XCTAssertEqualObjects(@"FIRST-APPID", [PushwooshConfig getAppCode]);
}

/// SDK-814: Verifies that dotted app code with surrounding whitespace is trimmed then rejected.
- (void)testSetAppCodeDottedTrimmedIsRejected {
    [PushwooshConfig setAppCode:@"FIRST-APPID"];
    [PushwooshConfig setAppCode:@"  XXXXX-XXXXX.legacy  \n"];
    XCTAssertEqualObjects(@"FIRST-APPID", [PushwooshConfig getAppCode]);
}

/// SDK-814: Sanity check — canonical app code is still accepted (no false positives on dot rejection).
- (void)testSetAppCodeCanonicalAcceptedSanityCheck {
    [PushwooshConfig setAppCode:@"XXXXX-XXXXX"];
    XCTAssertEqualObjects(@"XXXXX-XXXXX", [PushwooshConfig getAppCode]);
}

/// Verifies that nil app code is forwarded to PWPreferences (existing semantics).
- (void)testSetAppCodeNilIsAccepted {
    OCMExpect([_mockPreferences setAppCode:nil]);
    [PushwooshConfig setAppCode:nil];
    OCMVerifyAll(_mockPreferences);
}

#pragma mark - setApiToken

/// Verifies that api token with surrounding whitespace is trimmed before storing.
- (void)testSetApiTokenTrimsAndStores {
    [PushwooshConfig setApiToken:@"  api-token-xyz  "];
    XCTAssertEqualObjects(@"api-token-xyz", [PushwooshConfig getApiToken]);
}

/// Verifies that whitespace-only api token is rejected.
- (void)testSetApiTokenWhitespaceOnlyIsIgnored {
    [PushwooshConfig setApiToken:@"first-token"];
    [PushwooshConfig setApiToken:@"\n  \t"];
    XCTAssertEqualObjects(@"first-token", [PushwooshConfig getApiToken]);
}

#pragma mark - setLanguage

/// Verifies that "en\n" is trimmed to "en" and forwarded to PWPreferences.
- (void)testSetLanguageWithTrailingNewlineIsTrimmedToTwoChars {
    OCMExpect([_mockPreferences setLanguage:@"en"]);
    [PushwooshConfig setLanguage:@"en\n"];
    OCMVerifyAll(_mockPreferences);
}

/// Verifies that whitespace-only language forwards nil to PWPreferences (system locale fallback).
- (void)testSetLanguageWhitespaceOnlyFallsBackToSystemLocale {
    OCMExpect([_mockPreferences setLanguage:nil]);
    [PushwooshConfig setLanguage:@"   "];
    OCMVerifyAll(_mockPreferences);
}

#pragma mark - setEmails

/// Verifies that each email entry is individually trimmed before reaching the bridge.
- (void)testSetEmailsTrimsEntries {
    NSArray *expected = @[@"a@b.com", @"c@d.com"];
    OCMExpect([_mockBridge setEmails:expected]);
    [PushwooshConfig setEmails:@[@"a@b.com", @"   c@d.com\n  "]];
    OCMVerifyAll(_mockBridge);
}

/// Verifies that empty entries inside the array are dropped silently.
- (void)testSetEmailsDropsWhitespaceOnlyEntries {
    NSArray *expected = @[@"a@b.com"];
    OCMExpect([_mockBridge setEmails:expected]);
    [PushwooshConfig setEmails:@[@"a@b.com", @"   ", @"\n"]];
    OCMVerifyAll(_mockBridge);
}

/// Manual #8: mixed whitespace, empty strings, and trailing newlines — only valid emails remain trimmed.
- (void)testSetEmailsManualScenarioMixed {
    NSArray *expected = @[@"a@b.com", @"c@d.com"];
    OCMExpect([_mockBridge setEmails:expected]);
    [PushwooshConfig setEmails:@[@"  a@b.com  ", @"", @"   ", @"c@d.com\n"]];
    OCMVerifyAll(_mockBridge);
}

/// Verifies that an array consisting only of whitespace strings is rejected without calling the bridge.
- (void)testSetEmailsAllEmptyAfterTrimIsRejected {
    OCMReject([_mockBridge setEmails:[OCMArg any]]);
    [PushwooshConfig setEmails:@[@"  ", @"\n"]];
}

#pragma mark - setUserId

/// Manual #6: setUserId with surrounding whitespace must reach the in-app manager trimmed.
- (void)testSetUserIdTrimsAndForwardsToInAppManager {
    id mockInApp = OCMClassMock([PWInAppManager class]);
    OCMStub([_mockBridge inAppManager]).andReturn(mockInApp);
    OCMExpect([mockInApp setUserId:@"user-12345"]);
    [PushwooshConfig setUserId:@"  user-12345  "];
    OCMVerifyAll(mockInApp);
    [mockInApp stopMocking];
}

/// Manual #7: whitespace-only setUserId must be rejected — no call to in-app manager.
- (void)testSetUserIdWhitespaceOnlyIsRejected {
    id mockInApp = OCMClassMock([PWInAppManager class]);
    OCMStub([_mockBridge inAppManager]).andReturn(mockInApp);
    OCMReject([mockInApp setUserId:[OCMArg any]]);
    [PushwooshConfig setUserId:@"   "];
    [mockInApp stopMocking];
}

#pragma mark - registerSmsNumber / registerWhatsappNumber

/// Verifies that trailing newline is stripped from sms number before bridge call.
- (void)testRegisterSmsNumberTrimsValue {
    OCMExpect([_mockBridge registerSmsNumber:@"+1 234 567 8900"]);
    [PushwooshConfig registerSmsNumber:@"+1 234 567 8900\n"];
    OCMVerifyAll(_mockBridge);
}

/// Manual #12: surrounding whitespace + newline must be stripped from sms number.
- (void)testRegisterSmsNumberTrimsLeadingTrailingWhitespace {
    OCMExpect([_mockBridge registerSmsNumber:@"+1234567890"]);
    [PushwooshConfig registerSmsNumber:@"  +1234567890  "];
    OCMVerifyAll(_mockBridge);
}

/// Verifies that whitespace-only sms number is rejected.
- (void)testRegisterSmsNumberWhitespaceOnlyIsIgnored {
    OCMReject([_mockBridge registerSmsNumber:[OCMArg any]]);
    [PushwooshConfig registerSmsNumber:@"   \n"];
}

/// Manual #12: leading and trailing newlines must be stripped from whatsapp number.
- (void)testRegisterWhatsappNumberTrimsValue {
    OCMExpect([_mockBridge registerWhatsappNumber:@"+9876543210"]);
    [PushwooshConfig registerWhatsappNumber:@"\n+9876543210\n"];
    OCMVerifyAll(_mockBridge);
}

/// Manual #12 negative: whitespace-only whatsapp number must be rejected.
- (void)testRegisterWhatsappNumberWhitespaceOnlyIsRejected {
    OCMReject([_mockBridge registerWhatsappNumber:[OCMArg any]]);
    [PushwooshConfig registerWhatsappNumber:@"   \n"];
}

#pragma mark - Manual #21: programmatic setAppCode / setApiToken with whitespace

/// Manual #21: programmatic setAppCode with surrounding whitespace + newline.
- (void)testSetAppCodeTrimsLeadingTrailingWhitespace {
    [PushwooshConfig setAppCode:@"  12345-ABCDE\n  "];
    XCTAssertEqualObjects(@"12345-ABCDE", [PushwooshConfig getAppCode]);
}

/// Manual #21: programmatic setApiToken with surrounding whitespace.
- (void)testSetApiTokenTrimsLeadingTrailingWhitespace {
    [PushwooshConfig setApiToken:@"  abc-token-xyz  "];
    XCTAssertEqualObjects(@"abc-token-xyz", [PushwooshConfig getApiToken]);
}

#pragma mark - Manual #22-#23: setEmail (single, not array)

/// Manual #22: single setEmail with surrounding whitespace must reach the bridge trimmed (forwarded as @[trimmed] inside).
- (void)testSetEmailSingleTrimsValue {
    OCMExpect([_mockBridge setEmail:@"user@example.com"]);
    [PushwooshConfig setEmail:@"  user@example.com  "];
    OCMVerifyAll(_mockBridge);
}

/// Manual #23: single setEmail with whitespace-only is rejected.
- (void)testSetEmailSingleWhitespaceOnlyIsRejected {
    OCMReject([_mockBridge setEmail:[OCMArg any]]);
    [PushwooshConfig setEmail:@"   \n"];
}

/// Variant of #22 for the completion-bearing overload.
- (void)testSetEmailWithCompletionTrimsValue {
    NSArray *expected = @[@"user@example.com"];
    OCMExpect([_mockBridge setEmails:expected completion:[OCMArg any]]);
    [PushwooshConfig setEmail:@"  user@example.com  " completion:nil];
    OCMVerifyAll(_mockBridge);
}

/// Variant of #23 for the completion-bearing overload.
- (void)testSetEmailWithCompletionWhitespaceOnlyIsRejected {
    OCMReject([_mockBridge setEmails:[OCMArg any] completion:[OCMArg any]]);
    [PushwooshConfig setEmail:@"   " completion:nil];
}

#pragma mark - Manual #24: setUser:emails: combined

/// Manual #24: setUser:emails: trims userId and each email entry, drops empties.
- (void)testSetUserEmailsCombinedTrimsBoth {
    NSArray *expectedEmails = @[@"a@b.com", @"c@d.com"];
    OCMExpect([_mockBridge setUser:@"user-42" emails:expectedEmails]);
    [PushwooshConfig setUser:@"  user-42\n" emails:@[@" a@b.com ", @"  ", @"\nc@d.com"]];
    OCMVerifyAll(_mockBridge);
}

/// Verifies that whitespace-only userId in setUser:emails: blocks the whole call.
- (void)testSetUserEmailsCombinedRejectedOnEmptyUserId {
    OCMReject([_mockBridge setUser:[OCMArg any] emails:[OCMArg any]]);
    [PushwooshConfig setUser:@"   " emails:@[@"a@b.com"]];
}

/// Verifies that all-empty emails array in setUser:emails: blocks the whole call.
- (void)testSetUserEmailsCombinedRejectedOnAllEmptyEmails {
    OCMReject([_mockBridge setUser:[OCMArg any] emails:[OCMArg any]]);
    [PushwooshConfig setUser:@"valid-user" emails:@[@"  ", @"\n"]];
}

#pragma mark - Manual #26: mergeUserId completion behaviour on rejection

/// Manual #26: mergeUserId rejection does not invoke the completion block (documented behaviour, ADR-3).
- (void)testMergeUserIdRejectionDoesNotInvokeCompletion {
    __block BOOL completionInvoked = NO;
    [PushwooshConfig mergeUserId:@"old"
                              to:@"   "
                         doMerge:NO
                      completion:^(NSError *error) { completionInvoked = YES; }];
    XCTAssertFalse(completionInvoked);
}

#pragma mark - Manual #28: multi-call setUserId

/// Manual #28: rapid sequence — last valid value wins, whitespace-only calls do not overwrite.
- (void)testSetUserIdMultiCallKeepsLastValid {
    id mockInApp = OCMClassMock([PWInAppManager class]);
    OCMStub([_mockBridge inAppManager]).andReturn(mockInApp);
    OCMExpect([mockInApp setUserId:@"first"]);
    OCMExpect([mockInApp setUserId:@"second"]);
    OCMReject([mockInApp setUserId:@""]);
    OCMReject([mockInApp setUserId:nil]);

    [PushwooshConfig setUserId:@"first"];
    [PushwooshConfig setUserId:@"  second  "];
    [PushwooshConfig setUserId:@"   "];
    [PushwooshConfig setUserId:@"\n\n"];

    OCMVerifyAll(mockInApp);
    [mockInApp stopMocking];
}

#pragma mark - Manual #29: setLanguage(nil)

/// Manual #29: setLanguage(nil) forwards nil to PWPreferences (system locale fallback) without warning.
- (void)testSetLanguageNilForwardsNilToPreferences {
    OCMExpect([_mockPreferences setLanguage:nil]);
    [PushwooshConfig setLanguage:nil];
    OCMVerifyAll(_mockPreferences);
}

#pragma mark - mergeUserId

/// Verifies that whitespace-only newUserId blocks the bridge call entirely.
- (void)testMergeUserIdEmptyNewUserIdAfterTrimIsRejected {
    OCMReject([_mockBridge mergeUserId:[OCMArg any] to:[OCMArg any] doMerge:NO completion:[OCMArg any]]);
    [PushwooshConfig mergeUserId:@"old" to:@"\n" doMerge:NO completion:nil];
}

/// Verifies that whitespace-only oldUserId blocks the bridge call entirely.
- (void)testMergeUserIdEmptyOldUserIdAfterTrimIsRejected {
    OCMReject([_mockBridge mergeUserId:[OCMArg any] to:[OCMArg any] doMerge:NO completion:[OCMArg any]]);
    [PushwooshConfig mergeUserId:@"   " to:@"new" doMerge:NO completion:nil];
}

/// Verifies that valid userIds with surrounding whitespace are trimmed before bridge call.
- (void)testMergeUserIdTrimsBothIds {
    OCMExpect([_mockBridge mergeUserId:@"old-id" to:@"new-id" doMerge:YES completion:[OCMArg any]]);
    [PushwooshConfig mergeUserId:@"  old-id\n" to:@"\nnew-id  " doMerge:YES completion:nil];
    OCMVerifyAll(_mockBridge);
}

#pragma mark - setReverseProxy

/// Verifies that reverse proxy URL is trimmed before forwarding to bridge.
- (void)testSetReverseProxyTrimsUrl {
    OCMExpect([_mockBridge setReverseProxy:@"https://proxy.example.com" headers:[OCMArg any]]);
    [PushwooshConfig setReverseProxy:@"  https://proxy.example.com\n" headers:nil];
    OCMVerifyAll(_mockBridge);
}

/// Verifies that whitespace-only proxy URL blocks the bridge call.
- (void)testSetReverseProxyWhitespaceOnlyIsRejected {
    OCMReject([_mockBridge setReverseProxy:[OCMArg any] headers:[OCMArg any]]);
    [PushwooshConfig setReverseProxy:@"   \n" headers:nil];
}

@end
