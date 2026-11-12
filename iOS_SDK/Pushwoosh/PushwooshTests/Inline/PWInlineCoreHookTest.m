//
//  PWInlineCoreHookTest.m
//  PushwooshTests
//
//  Created by André Kis on 30.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWInAppMessagesManager.h"
#import "PWInAppHandler.h"
#import "PWPostEventRequest.h"
#import "PWRegisterUserRequest.h"
#import "PWRequestManager.h"
#import "PWPreferences.h"
#import "PushwooshModuleRegistry.h"
#import "PushwooshModuleIdentifier.h"
#import "PWPurchaseManager.h"
#import <StoreKit/StoreKit.h>

extern NSString * const PW_DEVICE_RESTORED_KEY;

@interface PWPurchaseManager (PWInlineCoreHookTest)
@property (nonatomic, strong) PWRequestManager *requestManager;
@property (nonatomic, strong) NSMutableDictionary *productArray;
- (void)sendSKPayments:(NSArray *)transactions;
@end

@interface PWInAppMessagesManager (PWInlineCoreHookTest)

@property (nonatomic, strong) PWRequestManager *requestManager;
- (void)setUserId:(NSString *)userId completion:(void(^)(NSError * error))completion;

@end

@interface PWInlineHookRecorder : NSObject <PWInAppHandler>

@property (nonatomic, strong) NSMutableArray *slotBlocks;
@property (nonatomic, strong) NSMutableArray<NSString *> *slotUserIds;
@property (nonatomic, strong) NSMutableArray<NSString *> *slotAppCodes;
@property (nonatomic) NSInteger userChanges;
@property (nonatomic) NSInteger userChangeFailures;
@property (nonatomic, strong) NSMutableArray<NSString *> *userIdsReported;

@end

@implementation PWInlineHookRecorder

- (instancetype)init {
    self = [super init];
    if (self) {
        _slotBlocks = [NSMutableArray new];
        _slotUserIds = [NSMutableArray new];
        _slotAppCodes = [NSMutableArray new];
        _userIdsReported = [NSMutableArray new];
    }
    return self;
}

- (void)handleInAppConfig:(NSDictionary *)config {
}

- (void)handleInAppConfig:(NSDictionary *)config onShown:(void (^)(void))onShown {
}

- (void)handleInAppConfig:(NSDictionary *)config onShown:(void (^)(void))onShown onClicked:(void (^)(void))onClicked onClosed:(void (^)(void))onClosed {
}

- (void)handleInlineSlots:(NSDictionary *)content userId:(NSString *)userId appCode:(NSString *)appCode {
    [_slotBlocks addObject:content];
    [_slotUserIds addObject:userId];
    [_slotAppCodes addObject:appCode];
}

- (void)handleInlineUserChanged {
    _userChanges += 1;
    [_userIdsReported addObject:[PWPreferences preferences].userId ?: @""];
}

- (void)handleInlineUserChangeFailed {
    _userChangeFailures += 1;
    [_userIdsReported addObject:[PWPreferences preferences].userId ?: @""];
}

@end

@interface PWInlineCoreHookTest : XCTestCase

@property (nonatomic, strong) PWInlineHookRecorder *handler;
@property (nonatomic, strong) PWInAppMessagesManager *manager;
@property (nonatomic, copy) NSDictionary *postEventResponse;
@property (nonatomic, copy) NSString *userIdOnAnswer;
@property (nonatomic, copy) NSString *userIdBeforeSend;
@property (nonatomic, strong) NSError *registerUserError;
@property (nonatomic) BOOL holdsRegisterUser;
@property (nonatomic, copy) void (^heldRegisterUser)(NSError *);
@property (nonatomic, strong) id preferencesMock;
@property (nonatomic, copy) NSString *savedUserId;
@property (nonatomic) BOOL savedUsesDefaultUserId;
@property (nonatomic, copy) NSDate *savedLastRegisterUserDate;
@property (nonatomic, copy) NSString *savedRestoredHwid;

@end

@implementation PWInlineCoreHookTest

- (void)setUp {
    [super setUp];
    _handler = [PWInlineHookRecorder new];
    [PushwooshModuleRegistry registerHandler:_handler forIdentifier:PWModuleIdentifierInApp];
    PWPreferences *preferences = [PWPreferences preferences];
    _savedUserId = preferences.userId;
    _savedUsesDefaultUserId = preferences.usesDefaultUserId;
    _savedLastRegisterUserDate = preferences.lastRegisterUserDate;
    _savedRestoredHwid = [[NSUserDefaults standardUserDefaults] valueForKey:PW_DEVICE_RESTORED_KEY];
    [[NSUserDefaults standardUserDefaults] setValue:preferences.hwid forKey:PW_DEVICE_RESTORED_KEY];
    _manager = [self managerWithStubbedNetwork];
    _preferencesMock = OCMPartialMock(preferences);
    OCMStub([_preferencesMock appCode]).andReturn(@"INLNE-00001");
}

- (void)tearDown {
    [_preferencesMock stopMocking];
    _manager = nil;
    PWPreferences *preferences = [PWPreferences preferences];
    if (_savedUsesDefaultUserId) {
        [preferences resetUserIdToHwid];
    } else {
        preferences.userId = _savedUserId;
    }
    if (_savedLastRegisterUserDate) {
        preferences.lastRegisterUserDate = _savedLastRegisterUserDate;
    }
    [[NSUserDefaults standardUserDefaults] setValue:_savedRestoredHwid forKey:PW_DEVICE_RESTORED_KEY];
    [PushwooshModuleRegistry registerHandler:nil forIdentifier:PWModuleIdentifierInApp];
    [super tearDown];
}

- (PWInAppMessagesManager *)managerWithStubbedNetwork {
    __weak PWInlineCoreHookTest *weakSelf = self;
    id requestManager = OCMClassMock([PWRequestManager class]);
    OCMStub([requestManager sendRequest:[OCMArg isKindOfClass:[PWPostEventRequest class]] completion:[OCMArg any]]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained PWRequest *request;
        __unsafe_unretained void (^completion)(NSError *);
        [invocation getArgument:&request atIndex:2];
        [invocation getArgument:&completion atIndex:3];
        if (weakSelf.userIdBeforeSend) {
            [PWPreferences preferences].userId = weakSelf.userIdBeforeSend;
        }
        [request requestDictionary];
        if (weakSelf.userIdOnAnswer) {
            [PWPreferences preferences].userId = weakSelf.userIdOnAnswer;
        }
        [request parseResponse:weakSelf.postEventResponse ?: @{}];
        completion(nil);
    });
    OCMStub([requestManager sendRequest:[OCMArg isKindOfClass:[PWRegisterUserRequest class]] completion:[OCMArg any]]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained void (^completion)(NSError *);
        [invocation getArgument:&completion atIndex:3];
        if (weakSelf.holdsRegisterUser) {
            weakSelf.holdsRegisterUser = NO;
            weakSelf.heldRegisterUser = completion;
            return;
        }
        completion(weakSelf.registerUserError);
    });
    PWInAppMessagesManager *manager = [PWInAppMessagesManager new];
    manager.requestManager = requestManager;
    return manager;
}

- (void)postEventAnsweredWith:(NSDictionary *)response {
    _postEventResponse = response;
    XCTestExpectation *posted = [self expectationWithDescription:@"postEvent"];
    [_manager postEvent:@"PurchaseCompleted" withAttributes:nil completion:^(NSError *error) {
        XCTAssertNil(error);
        [posted fulfill];
    }];
    [self waitForExpectations:@[posted] timeout:3.0];
}

/// Verifies that the inline block of a postEvent answer reaches the in-app module.
- (void)testPostEventInlineBlockReachesModule {
    NSDictionary *inlineBlock = @{ @"slots": @{ @"cart_bottom": [NSNull null] } };

    [self postEventAnsweredWith:@{ @"code": @"", @"inline": inlineBlock }];

    XCTAssertEqualObjects(_handler.slotBlocks, @[inlineBlock]);
}

/// Verifies that the inline block of a postEvent answer carries the user and application the event was sent for.
- (void)testPostEventInlineBlockCarriesUserOfTheEvent {
    [PWPreferences preferences].userId = @"inline-user-a";
    _userIdOnAnswer = @"inline-user-b";

    [self postEventAnsweredWith:@{ @"code": @"", @"inline": @{ @"slots": @{ @"cart_bottom": [NSNull null] } } }];

    XCTAssertEqualObjects(_handler.slotUserIds, @[@"inline-user-a"]);
    XCTAssertEqualObjects(_handler.slotAppCodes, @[@"INLNE-00001"]);
}

/// Verifies that a postEvent answer without an inline block leaves the in-app module alone.
- (void)testPostEventWithoutInlineBlockSkipsModule {
    [self postEventAnsweredWith:@{ @"code": @"" }];

    XCTAssertEqual(_handler.slotBlocks.count, 0);
}

- (PWPurchaseManager *)purchasesAnsweredWith:(NSDictionary *)response {
    _postEventResponse = response;
    PWPurchaseManager *purchases = [PWPurchaseManager new];
    purchases.requestManager = _manager.requestManager;
    return purchases;
}

/// Verifies that the inline block of the answer to sendPurchase reaches the in-app module with the user the purchase was sent for.
- (void)testPurchaseAnswerInlineBlockReachesModule {
    NSDictionary *inlineBlock = @{ @"slots": @{ @"cart_bottom": [NSNull null] } };
    PWPurchaseManager *purchases = [self purchasesAnsweredWith:@{ @"code": @"", @"inline": inlineBlock }];
    [PWPreferences preferences].userId = @"inline-buyer-a";
    _userIdOnAnswer = @"inline-buyer-b";

    [purchases sendPurchase:@"inline_sku" withPrice:[NSDecimalNumber one] currencyCode:@"USD" andDate:[NSDate date]];

    XCTAssertEqualObjects(_handler.slotBlocks, @[inlineBlock]);
    XCTAssertEqualObjects(_handler.slotUserIds, @[@"inline-buyer-a"]);
    XCTAssertEqualObjects(_handler.slotAppCodes, @[@"INLNE-00001"]);
}

/// Verifies that a purchase that went out after a user change forwards its inline block with the user it was sent for.
- (void)testPurchaseSentAfterUserChangeCarriesTheUserItWasSentFor {
    PWPurchaseManager *purchases = [self purchasesAnsweredWith:@{ @"code": @"", @"inline": @{ @"slots": @{ @"cart_bottom": [NSNull null] } } }];
    [PWPreferences preferences].userId = @"inline-buyer-a";
    _userIdBeforeSend = @"inline-buyer-b";

    [purchases sendPurchase:@"inline_sku" withPrice:[NSDecimalNumber one] currencyCode:@"USD" andDate:[NSDate date]];

    XCTAssertEqualObjects(_handler.slotUserIds, @[@"inline-buyer-b"]);
}

/// Verifies that the inline block of the answer to a purchase tracked from StoreKit reaches the in-app module.
- (void)testStoreKitPurchaseAnswerInlineBlockReachesModule {
    NSDictionary *inlineBlock = @{ @"slots": @{ @"cart_bottom": [NSNull null] } };
    PWPurchaseManager *purchases = [self purchasesAnsweredWith:@{ @"code": @"", @"inline": inlineBlock }];
    id transaction = OCMClassMock([SKPaymentTransaction class]);
    id payment = OCMClassMock([SKPayment class]);
    id product = OCMClassMock([SKProduct class]);
    OCMStub([transaction payment]).andReturn(payment);
    OCMStub([transaction transactionState]).andReturn(SKPaymentTransactionStatePurchased);
    OCMStub([payment productIdentifier]).andReturn(@"inline_sku");
    OCMStub([(SKProduct *)product price]).andReturn([NSDecimalNumber one]);
    OCMStub([(SKProduct *)product priceLocale]).andReturn([NSLocale localeWithLocaleIdentifier:@"en_US"]);
    purchases.productArray = [@{ @"inline_sku": product } mutableCopy];

    [purchases sendSKPayments:@[transaction]];

    XCTAssertEqualObjects(_handler.slotBlocks, @[inlineBlock]);
}

/// Verifies that a user confirmed by registerUser is reported to the in-app module.
- (void)testConfirmedUserIsReportedToModule {
    NSString *userId = [NSString stringWithFormat:@"inline-%@", [NSUUID UUID].UUIDString];
    __block NSError *result = [NSError errorWithDomain:@"PWInlineCoreHookTest" code:1 userInfo:nil];

    [_manager setUserId:userId completion:^(NSError *error) {
        result = error;
    }];

    XCTAssertNil(result);
    XCTAssertEqual(_handler.userChanges, 1);
}

/// Verifies that a user refused by registerUser is reported to the in-app module, so its slots follow the user back.
- (void)testRefusedUserIsReportedToModule {
    _registerUserError = [NSError errorWithDomain:@"PWInlineCoreHookTest" code:500 userInfo:nil];
    __block NSError *result;

    [_manager setUserId:[NSString stringWithFormat:@"inline-%@", [NSUUID UUID].UUIDString] completion:^(NSError *error) {
        result = error;
    }];

    XCTAssertNotNil(result);
    XCTAssertEqual(_handler.userChangeFailures, 1);
    XCTAssertEqual(_handler.userChanges, 0);
}

/// Verifies that a refused user is reported once the user set after it is settled too, with the user the SDK went back to.
- (void)testRefusedUserWithAnotherWaitingIsReportedOnceSettled {
    NSString *confirmed = [PWPreferences preferences].userId;
    _holdsRegisterUser = YES;
    [_manager setUserId:[NSString stringWithFormat:@"inline-b-%@", [NSUUID UUID].UUIDString] completion:nil];
    [_manager setUserId:[NSString stringWithFormat:@"inline-c-%@", [NSUUID UUID].UUIDString] completion:nil];
    _registerUserError = [NSError errorWithDomain:@"PWInlineCoreHookTest" code:500 userInfo:nil];

    _heldRegisterUser(_registerUserError);

    XCTAssertEqual(_handler.userChangeFailures, 1);
    XCTAssertEqualObjects(_handler.userIdsReported, @[confirmed]);
}

/// Verifies that a confirmed user is reported once the user set after it is confirmed too, with that last user.
- (void)testConfirmedUserWithAnotherWaitingIsReportedOnceSettled {
    NSString *last = [NSString stringWithFormat:@"inline-c-%@", [NSUUID UUID].UUIDString];
    _holdsRegisterUser = YES;
    [_manager setUserId:[NSString stringWithFormat:@"inline-b-%@", [NSUUID UUID].UUIDString] completion:nil];
    [_manager setUserId:last completion:nil];

    _heldRegisterUser(nil);

    XCTAssertEqual(_handler.userChanges, 1);
    XCTAssertEqualObjects(_handler.userIdsReported, @[last]);
}

@end
