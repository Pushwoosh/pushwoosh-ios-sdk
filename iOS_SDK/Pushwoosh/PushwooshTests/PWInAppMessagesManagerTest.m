#import "PWInAppMessagesManager.h"
#import "PWPreferences.h"
#import "PWTriggerInAppActionRequest.h"
#import "PWRegisterUserRequest.h"
#import "PWRequestManager.h"
#import "PWSdkStateProvider.h"

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

extern NSString * const PW_DEVICE_RESTORED_KEY;

@interface PWInAppMessagesManager (TEST)

@property (nonatomic, strong) PWRequestManager *requestManager;
- (void)setUserId:(NSString *)userId completion:(void(^)(NSError * error))completion;
- (void)registerEmailUser:(NSString *)email userId:(NSString *)userId;
- (void)sendInitRequests;
+ (NSDictionary *)richMediaDescriptorFrom:(id)rawRichMedia;

@end

@interface PWSdkStateProvider (TEST)

- (void)resetForTesting;

@end

@interface PWInAppMessagesManagerTest : XCTestCase

@property (nonatomic, copy) NSString *savedUserId;
@property (nonatomic) BOOL savedUsesDefaultUserId;
@property (nonatomic, copy) NSDate *savedLastRegisterUserDate;
@property (nonatomic, copy) NSString *savedRestoredHwid;
@property (nonatomic) NSMutableArray<NSString *> *sentRegisterUserIds;
@property (nonatomic) NSMutableArray<NSArray *> *unansweredRegisterUsers;
@property (nonatomic) NSMutableArray *heldManagers;
@property (nonatomic) NSError *failure;

@end

@implementation PWInAppMessagesManagerTest

- (void)setUp {
    [super setUp];
    PWPreferences *prefs = [PWPreferences preferences];
    _savedUserId = prefs.userId;
    _savedUsesDefaultUserId = prefs.usesDefaultUserId;
    _savedLastRegisterUserDate = prefs.lastRegisterUserDate;
    _savedRestoredHwid = [[NSUserDefaults standardUserDefaults] valueForKey:PW_DEVICE_RESTORED_KEY];
    [[NSUserDefaults standardUserDefaults] setValue:prefs.hwid forKey:PW_DEVICE_RESTORED_KEY];
    _sentRegisterUserIds = [NSMutableArray array];
    _unansweredRegisterUsers = [NSMutableArray array];
    _heldManagers = [NSMutableArray array];
    _failure = [NSError errorWithDomain:@"PWInAppMessagesManagerTest" code:500 userInfo:nil];
}

- (void)tearDown {
    while (_unansweredRegisterUsers.count > 0) {
        [self answerInFlightRegisterUserWithError:_failure];
    }
    PWPreferences *prefs = [PWPreferences preferences];
    if (_savedUsesDefaultUserId) {
        [prefs resetUserIdToHwid];
    } else {
        prefs.userId = _savedUserId;
    }
    if (_savedLastRegisterUserDate) {
        prefs.lastRegisterUserDate = _savedLastRegisterUserDate;
    }
    [[NSUserDefaults standardUserDefaults] setValue:_savedRestoredHwid forKey:PW_DEVICE_RESTORED_KEY];
    [super tearDown];
}

- (PWInAppMessagesManager *)managerAnsweringRegisterUserWithError:(NSError *)error sentUserIds:(NSMutableArray *)sentUserIds {
    id requestManager = OCMClassMock([PWRequestManager class]);
    OCMStub([requestManager sendRequest:[OCMArg isKindOfClass:[PWRegisterUserRequest class]] completion:[OCMArg any]]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained PWRequest *request;
        __unsafe_unretained void (^completion)(NSError *);
        [invocation getArgument:&request atIndex:2];
        [invocation getArgument:&completion atIndex:3];
        [sentUserIds addObject:request.requestDictionary[@"userId"]];
        completion(error);
    });
    PWInAppMessagesManager *manager = [[PWInAppMessagesManager alloc] init];
    manager.requestManager = requestManager;
    return manager;
}

- (PWInAppMessagesManager *)managerHoldingRegisterUserRequests {
    id requestManager = OCMClassMock([PWRequestManager class]);
    __weak typeof(self) wself = self;
    OCMStub([requestManager sendRequest:[OCMArg isKindOfClass:[PWRegisterUserRequest class]] completion:[OCMArg any]]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained PWRequest *request;
        __unsafe_unretained void (^completion)(NSError *);
        [invocation getArgument:&request atIndex:2];
        [invocation getArgument:&completion atIndex:3];
        NSString *userId = request.requestDictionary[@"userId"];
        [wself.sentRegisterUserIds addObject:userId];
        [wself.unansweredRegisterUsers addObject:(@[userId, [completion copy]])];
    });
    PWInAppMessagesManager *manager = OCMPartialMock([PWInAppMessagesManager new]);
    OCMStub([manager sendInitRequests]);
    manager.requestManager = requestManager;
    [_heldManagers addObject:manager];
    return manager;
}

- (void)answerInFlightRegisterUserWithError:(NSError *)error {
    NSArray *request = _unansweredRegisterUsers.firstObject;
    [_unansweredRegisterUsers removeObjectAtIndex:0];
    void (^completion)(NSError *) = request[1];
    completion(error);
}

- (void)answerRegisterUserFor:(NSString *)userId error:(NSError *)error {
    NSUInteger index = [_unansweredRegisterUsers indexOfObjectPassingTest:^BOOL(NSArray *request, NSUInteger idx, BOOL *stop) {
        return [request[0] isEqualToString:userId];
    }];
    if (index == NSNotFound) {
        return;
    }
    NSArray *request = _unansweredRegisterUsers[index];
    [_unansweredRegisterUsers removeObjectAtIndex:index];
    void (^completion)(NSError *) = request[1];
    completion(error);
}

- (void)selectApplicationRestoredAfterTest {
    PWPreferences *prefs = [PWPreferences preferences];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *savedAppCode = prefs.appCode;
    NSString *savedBaseUrl = [defaults objectForKey:@"Pushwoosh_BASEURL"];
    id savedRecord = [defaults objectForKey:@"Pushwoosh_ACTIVE_APPLICATION"];
    [defaults removeObjectForKey:@"Pushwoosh_ACTIVE_APPLICATION"];
    [self addTeardownBlock:^{
        [defaults removeObjectForKey:@"Pushwoosh_ACTIVE_APPLICATION"];
        prefs.appCode = savedAppCode;
        NSString *restoredBaseUrl = savedBaseUrl.length > 0 ? savedBaseUrl : [prefs defaultBaseUrl];
        if (restoredBaseUrl.length > 0) {
            [prefs updateBaseUrl:restoredBaseUrl];
        }
        if (savedBaseUrl) {
            [defaults setObject:savedBaseUrl forKey:@"Pushwoosh_BASEURL"];
        } else {
            [defaults removeObjectForKey:@"Pushwoosh_BASEURL"];
        }
        if (savedRecord) {
            [defaults setObject:savedRecord forKey:@"Pushwoosh_ACTIVE_APPLICATION"];
        }
    }];
    prefs.appCode = @"REGUS-00001";
    [prefs updateBaseUrl:@"https://register-user-a.example.com/json/1.3/"];
}

- (BOOL)relaunchSkipsRegisteringUser:(NSString *)userId {
    PWPreferences *relaunched = [[PWPreferences alloc] init];
    NSDate *lastRegistration = relaunched.lastRegisterUserDate;
    return [relaunched.userId isEqualToString:userId] && lastRegistration && [[NSDate date] timeIntervalSinceDate:lastRegistration] < 24 * 60 * 60;
}

- (NSString *)userIdOfCall:(NSString *)call {
    return [call isEqualToString:@"reset"] ? [PWPreferences preferences].hwid : call;
}

- (void)makeCall:(NSString *)call on:(PWInAppMessagesManager *)manager completion:(void(^)(NSError *error))completion {
    if ([call isEqualToString:@"reset"]) {
        [manager resetUserIdWithCompletion:completion];
    } else {
        [manager setUserId:call completion:completion];
    }
}

- (void)verifyCalls:(NSArray<NSString *> *)calls failures:(NSUInteger)failures afterConfirmed:(NSString *)confirmed manager:(PWInAppMessagesManager *)manager {
    PWPreferences *prefs = [PWPreferences preferences];
    if ([confirmed isEqualToString:@"reset"]) {
        [prefs resetUserIdToHwid];
    } else {
        prefs.userId = confirmed;
    }
    NSDate *confirmedRegistration = [NSDate dateWithTimeIntervalSinceNow:-2 * 24 * 60 * 60];
    prefs.lastRegisterUserDate = confirmedRegistration;
    [_sentRegisterUserIds removeAllObjects];
    NSString *name = [NSString stringWithFormat:@"%@ confirmed, calls %@, failure bits %lu", confirmed, [calls componentsJoinedByString:@","], (unsigned long)failures];
    NSMutableArray *outcomes = [NSMutableArray array];
    for (NSUInteger i = 0; i < calls.count; i++) {
        [outcomes addObject:[NSNull null]];
        [self makeCall:calls[i] on:manager completion:^(NSError *error) {
            outcomes[i] = error ?: @"ok";
        }];
    }

    NSInteger lastConfirmedCall = -1;
    for (NSUInteger i = 0; i < calls.count; i++) {
        XCTAssertEqual(_unansweredRegisterUsers.count, 1, @"%@", name);
        XCTAssertEqualObjects(_sentRegisterUserIds.lastObject, [self userIdOfCall:calls[i]], @"%@", name);
        XCTAssertEqualObjects(prefs.userId, [self userIdOfCall:calls.lastObject], @"%@", name);
        XCTAssertNil(prefs.lastRegisterUserDate, @"%@", name);
        BOOL fails = (failures >> i) & 1;
        if (!fails) {
            lastConfirmedCall = i;
        }
        [self answerInFlightRegisterUserWithError:fails ? _failure : nil];
        XCTAssertEqualObjects(outcomes[i], fails ? _failure : @"ok", @"%@", name);
    }

    XCTAssertEqual(_unansweredRegisterUsers.count, 0, @"%@", name);
    XCTAssertEqual(_sentRegisterUserIds.count, calls.count, @"%@", name);
    NSString *expected = lastConfirmedCall >= 0 ? calls[lastConfirmedCall] : confirmed;
    XCTAssertEqualObjects(prefs.userId, [self userIdOfCall:expected], @"%@", name);
    XCTAssertEqual(prefs.usesDefaultUserId, [expected isEqualToString:@"reset"], @"%@", name);
    if (lastConfirmedCall >= 0) {
        XCTAssertLessThan([[NSDate date] timeIntervalSinceDate:prefs.lastRegisterUserDate], 60, @"%@", name);
    } else {
        XCTAssertEqualObjects(prefs.lastRegisterUserDate, confirmedRegistration, @"%@", name);
    }

    BOOL repeatIsSkipped = lastConfirmedCall >= 0 && [[self userIdOfCall:expected] isEqualToString:[self userIdOfCall:calls.lastObject]];
    [self makeCall:calls.lastObject on:manager completion:nil];
    XCTAssertEqual(_sentRegisterUserIds.count, calls.count + (repeatIsSkipped ? 0 : 1), @"%@", name);
    while (_unansweredRegisterUsers.count > 0) {
        [self answerInFlightRegisterUserWithError:_failure];
    }
}

/// Verifies that every sequence of up to three setUserId/resetUserId calls is sent one request at a time in call order and settles on the last user the server confirmed.
- (void)testRegisterUserCallSequencesSettleOnLastConfirmedUser {
    PWInAppMessagesManager *manager = [self managerHoldingRegisterUserRequests];
    NSArray<NSString *> *calls = @[@"alice", @"bob", @"reset"];
    NSMutableArray<NSArray<NSString *> *> *sequences = [NSMutableArray array];
    NSArray<NSArray<NSString *> *> *shorter = @[@[]];
    for (NSUInteger length = 1; length <= 3; length++) {
        NSMutableArray<NSArray<NSString *> *> *longer = [NSMutableArray array];
        for (NSArray<NSString *> *prefix in shorter) {
            for (NSString *call in calls) {
                [longer addObject:[prefix arrayByAddingObject:call]];
            }
        }
        [sequences addObjectsFromArray:longer];
        shorter = longer;
    }

    for (NSString *confirmed in @[@"zed", @"reset"]) {
        for (NSArray<NSString *> *sequence in sequences) {
            for (NSUInteger failures = 0; failures < (1u << sequence.count); failures++) {
                [self verifyCalls:sequence failures:failures afterConfirmed:confirmed manager:manager];
            }
        }
    }
}

/// Verifies that resetUserId makes the HWID the default user again and registers it on the server.
- (void)testResetUserIdRegistersHwidAsDefaultUser {
    PWPreferences *prefs = [PWPreferences preferences];
    prefs.userId = @"bob";
    prefs.lastRegisterUserDate = [NSDate date];
    NSMutableArray *sentUserIds = [NSMutableArray array];
    PWInAppMessagesManager *manager = [self managerAnsweringRegisterUserWithError:nil sentUserIds:sentUserIds];
    __block BOOL completed = NO;
    __block NSError *receivedError = nil;

    [manager resetUserIdWithCompletion:^(NSError *error) {
        completed = YES;
        receivedError = error;
    }];

    XCTAssertEqualObjects(sentUserIds, @[prefs.hwid]);
    XCTAssertEqualObjects(prefs.userId, prefs.hwid);
    XCTAssertTrue(prefs.usesDefaultUserId);
    XCTAssertTrue(completed);
    XCTAssertNil(receivedError);
}

/// Verifies that resetUserId sends nothing when the HWID was registered as the user less than a day ago.
- (void)testResetUserIdSkipsRequestWhenHwidRegisteredRecently {
    PWPreferences *prefs = [PWPreferences preferences];
    prefs.userId = prefs.hwid;
    prefs.lastRegisterUserDate = [NSDate date];
    id requestManager = OCMClassMock([PWRequestManager class]);
    OCMReject([requestManager sendRequest:[OCMArg any] completion:[OCMArg any]]);
    PWInAppMessagesManager *manager = [[PWInAppMessagesManager alloc] init];
    manager.requestManager = requestManager;
    __block BOOL completed = NO;
    __block NSError *receivedError = nil;

    [manager resetUserIdWithCompletion:^(NSError *error) {
        completed = YES;
        receivedError = error;
    }];

    XCTAssertTrue(completed);
    XCTAssertNil(receivedError);
    XCTAssertEqualObjects(prefs.userId, prefs.hwid);
    XCTAssertTrue(prefs.usesDefaultUserId);
    OCMVerifyAll(requestManager);
}

/// Verifies that a failed resetUserId restores the previous custom user and its last registration date.
- (void)testResetUserIdRestoresPreviousUserOnError {
    PWPreferences *prefs = [PWPreferences preferences];
    prefs.userId = @"bob";
    NSDate *lastRegistration = [NSDate dateWithTimeIntervalSinceNow:-2 * 24 * 60 * 60];
    prefs.lastRegisterUserDate = lastRegistration;
    PWInAppMessagesManager *manager = [self managerAnsweringRegisterUserWithError:_failure sentUserIds:[NSMutableArray array]];
    __block NSError *receivedError = nil;

    [manager resetUserIdWithCompletion:^(NSError *error) {
        receivedError = error;
    }];

    XCTAssertEqualObjects(prefs.userId, @"bob");
    XCTAssertFalse(prefs.usesDefaultUserId);
    XCTAssertEqualObjects(prefs.lastRegisterUserDate, lastRegistration);
    XCTAssertEqual(receivedError, _failure);
}

/// Verifies that a failed setUserId leaves a user without a custom id on the HWID default.
- (void)testSetUserIdKeepsHwidDefaultOnError {
    PWPreferences *prefs = [PWPreferences preferences];
    [prefs resetUserIdToHwid];
    prefs.lastRegisterUserDate = [NSDate dateWithTimeIntervalSinceNow:-2 * 24 * 60 * 60];
    PWInAppMessagesManager *manager = [self managerAnsweringRegisterUserWithError:_failure sentUserIds:[NSMutableArray array]];

    [manager setUserId:@"bob" completion:^(NSError *error) {}];

    XCTAssertEqualObjects(prefs.userId, prefs.hwid);
    XCTAssertTrue(prefs.usesDefaultUserId);
}

/// Verifies that a slow setUserId confirmed after the user logged out again does not bring that user back.
- (void)testSlowSetUserIdConfirmedAfterLogoutKeepsHwidUser {
    PWPreferences *prefs = [PWPreferences preferences];
    [prefs resetUserIdToHwid];
    prefs.lastRegisterUserDate = [NSDate dateWithTimeIntervalSinceNow:-60 * 60];
    PWInAppMessagesManager *manager = [self managerHoldingRegisterUserRequests];

    [manager setUserId:@"bob" completion:^(NSError *error) {}];
    [manager setUserId:@"carol" completion:^(NSError *error) {}];
    [self answerRegisterUserFor:@"carol" error:_failure];
    [manager resetUserIdWithCompletion:^(NSError *error) {}];
    [self answerRegisterUserFor:@"bob" error:nil];
    [self answerRegisterUserFor:@"carol" error:_failure];
    [self answerRegisterUserFor:prefs.hwid error:nil];

    XCTAssertEqualObjects(prefs.userId, prefs.hwid);
    XCTAssertTrue(prefs.usesDefaultUserId);
    XCTAssertTrue([self relaunchSkipsRegisteringUser:prefs.hwid]);
    XCTAssertEqualObjects(_sentRegisterUserIds, (@[@"bob", @"carol", prefs.hwid]));
}

/// Verifies that a resetUserId failing after an earlier resetUserId was confirmed keeps the HWID user and lets the old user log in again.
- (void)testFailedResetUserIdAfterConfirmedResetKeepsHwidUser {
    PWPreferences *prefs = [PWPreferences preferences];
    prefs.userId = @"alice";
    prefs.lastRegisterUserDate = [NSDate dateWithTimeIntervalSinceNow:-60 * 60];
    PWInAppMessagesManager *manager = [self managerHoldingRegisterUserRequests];

    [manager resetUserIdWithCompletion:^(NSError *error) {}];
    [manager setUserId:@"bob" completion:^(NSError *error) {}];
    [self answerRegisterUserFor:@"bob" error:_failure];
    XCTAssertEqualObjects(_sentRegisterUserIds, @[prefs.hwid]);
    [manager resetUserIdWithCompletion:^(NSError *error) {}];
    [self answerRegisterUserFor:prefs.hwid error:nil];
    [self answerRegisterUserFor:@"bob" error:_failure];
    [self answerRegisterUserFor:prefs.hwid error:_failure];

    XCTAssertEqualObjects(prefs.userId, prefs.hwid);
    XCTAssertTrue(prefs.usesDefaultUserId);
    NSUInteger sentBeforeLogin = _sentRegisterUserIds.count;
    [manager setUserId:@"alice" completion:^(NSError *error) {}];
    XCTAssertEqual(_sentRegisterUserIds.count, sentBeforeLogin + 1);
}

/// Verifies that setUserId of the confirmed user made while another setUserId is in flight is sent after it instead of being skipped.
- (void)testSetUserIdOfConfirmedUserWhileAnotherIsInFlightIsSentAfterIt {
    PWPreferences *prefs = [PWPreferences preferences];
    prefs.userId = @"alice";
    prefs.lastRegisterUserDate = [NSDate dateWithTimeIntervalSinceNow:-60 * 60];
    PWInAppMessagesManager *manager = [self managerHoldingRegisterUserRequests];
    __block BOOL aliceAgainCompleted = NO;

    [manager setUserId:@"bob" completion:^(NSError *error) {}];
    [manager setUserId:@"alice" completion:^(NSError *error) {
        aliceAgainCompleted = YES;
    }];

    XCTAssertFalse(aliceAgainCompleted);
    XCTAssertEqualObjects(_sentRegisterUserIds, @[@"bob"]);
    [self answerInFlightRegisterUserWithError:nil];
    XCTAssertEqualObjects(_sentRegisterUserIds, (@[@"bob", @"alice"]));
    [self answerInFlightRegisterUserWithError:nil];
    XCTAssertTrue(aliceAgainCompleted);
    XCTAssertEqualObjects(prefs.userId, @"alice");
}

/// Verifies that setUserId of a recreated manager waits for the request the replaced manager still has in flight.
- (void)testSetUserIdOfRecreatedManagerWaitsForReplacedManagerRequest {
    PWPreferences *prefs = [PWPreferences preferences];
    prefs.userId = @"bob";
    prefs.lastRegisterUserDate = [NSDate dateWithTimeIntervalSinceNow:-2 * 24 * 60 * 60];
    PWInAppMessagesManager *replaced = [self managerHoldingRegisterUserRequests];
    PWInAppMessagesManager *recreated = [self managerHoldingRegisterUserRequests];

    [replaced setUserId:@"alice" completion:^(NSError *error) {}];
    [recreated setUserId:@"carol" completion:^(NSError *error) {}];

    XCTAssertEqualObjects(_sentRegisterUserIds, @[@"alice"]);
    [self answerInFlightRegisterUserWithError:nil];
    XCTAssertEqualObjects(_sentRegisterUserIds, (@[@"alice", @"carol"]));
    [self answerInFlightRegisterUserWithError:nil];
    XCTAssertEqualObjects(prefs.userId, @"carol");
}

/// Verifies that a setUserId dropped while the SDK is in the error state fails at once and does not hold the calls made after the SDK recovers.
- (void)testSetUserIdDroppedInSdkErrorStateDoesNotHoldLaterCalls {
    PWPreferences *prefs = [PWPreferences preferences];
    prefs.userId = @"bob";
    NSDate *bobRegistration = [NSDate dateWithTimeIntervalSinceNow:-2 * 24 * 60 * 60];
    prefs.lastRegisterUserDate = bobRegistration;
    PWInAppMessagesManager *manager = [self managerHoldingRegisterUserRequests];
    PWSdkStateProvider *sdkState = [PWSdkStateProvider sharedInstance];
    BOOL sdkWasReady = [sdkState isReady];
    __block NSError *droppedError = nil;

    [sdkState setError];
    [manager setUserId:@"alice" completion:^(NSError *error) {
        droppedError = error;
    }];
    [sdkState resetForTesting];
    if (sdkWasReady) {
        [sdkState setReady];
    }
    NSString *userAfterDrop = prefs.userId;
    NSDate *registrationAfterDrop = prefs.lastRegisterUserDate;
    [manager setUserId:@"carol" completion:^(NSError *error) {}];

    XCTAssertNotNil(droppedError);
    XCTAssertEqualObjects(userAfterDrop, @"bob");
    XCTAssertEqualObjects(registrationAfterDrop, bobRegistration);
    XCTAssertEqualObjects(_sentRegisterUserIds, @[@"carol"]);
}

/// Verifies that a resetUserId failing before the next user logged in keeps the new user once the server confirms it.
- (void)testResetUserIdFailureKeepsUserSetAfterIt {
    PWPreferences *prefs = [PWPreferences preferences];
    prefs.userId = @"alice";
    prefs.lastRegisterUserDate = [NSDate dateWithTimeIntervalSinceNow:-2 * 24 * 60 * 60];
    PWInAppMessagesManager *manager = [self managerHoldingRegisterUserRequests];

    [manager resetUserIdWithCompletion:^(NSError *error) {}];
    [manager setUserId:@"bob" completion:^(NSError *error) {}];
    XCTAssertEqualObjects(_sentRegisterUserIds, @[prefs.hwid]);
    [self answerInFlightRegisterUserWithError:_failure];
    XCTAssertEqualObjects(prefs.userId, @"bob");
    [self answerInFlightRegisterUserWithError:nil];

    XCTAssertEqualObjects(prefs.userId, @"bob");
    XCTAssertFalse(prefs.usesDefaultUserId);
    XCTAssertTrue([self relaunchSkipsRegisteringUser:@"bob"]);
}

/// Verifies that a setUserId failing before a newer setUserId keeps the newer user.
- (void)testSetUserIdFailureKeepsNewerUser {
    PWPreferences *prefs = [PWPreferences preferences];
    [prefs resetUserIdToHwid];
    prefs.lastRegisterUserDate = [NSDate dateWithTimeIntervalSinceNow:-2 * 24 * 60 * 60];
    PWInAppMessagesManager *manager = [self managerHoldingRegisterUserRequests];

    [manager setUserId:@"alice" completion:^(NSError *error) {}];
    [manager setUserId:@"bob" completion:^(NSError *error) {}];
    [self answerInFlightRegisterUserWithError:_failure];
    [self answerInFlightRegisterUserWithError:nil];

    XCTAssertEqualObjects(_sentRegisterUserIds, (@[@"alice", @"bob"]));
    XCTAssertEqualObjects(prefs.userId, @"bob");
    XCTAssertFalse(prefs.usesDefaultUserId);
}

/// Verifies that a setUserId with the HWID failing before resetUserId keeps the HWID as the default user.
- (void)testSetUserIdWithHwidFailureKeepsResetDoneAfterIt {
    PWPreferences *prefs = [PWPreferences preferences];
    prefs.userId = @"alice";
    prefs.lastRegisterUserDate = [NSDate dateWithTimeIntervalSinceNow:-2 * 24 * 60 * 60];
    PWInAppMessagesManager *manager = [self managerHoldingRegisterUserRequests];

    [manager setUserId:prefs.hwid completion:^(NSError *error) {}];
    [manager resetUserIdWithCompletion:^(NSError *error) {}];
    [self answerInFlightRegisterUserWithError:_failure];
    [self answerInFlightRegisterUserWithError:nil];

    XCTAssertEqualObjects(prefs.userId, prefs.hwid);
    XCTAssertTrue(prefs.usesDefaultUserId);
}

/// Verifies that a failing resetUserId followed by another user and a second resetUserId ends on the second reset.
- (void)testResetUserIdFailureKeepsLaterResetAfterAnotherUser {
    PWPreferences *prefs = [PWPreferences preferences];
    prefs.userId = @"alice";
    prefs.lastRegisterUserDate = [NSDate dateWithTimeIntervalSinceNow:-2 * 24 * 60 * 60];
    PWInAppMessagesManager *manager = [self managerHoldingRegisterUserRequests];

    [manager resetUserIdWithCompletion:^(NSError *error) {}];
    [manager setUserId:@"carol" completion:^(NSError *error) {}];
    [manager resetUserIdWithCompletion:^(NSError *error) {}];
    [self answerInFlightRegisterUserWithError:_failure];
    [self answerInFlightRegisterUserWithError:nil];
    [self answerInFlightRegisterUserWithError:nil];

    XCTAssertEqualObjects(_sentRegisterUserIds, (@[prefs.hwid, @"carol", prefs.hwid]));
    XCTAssertEqualObjects(prefs.userId, prefs.hwid);
    XCTAssertTrue(prefs.usesDefaultUserId);
    XCTAssertTrue([self relaunchSkipsRegisteringUser:prefs.hwid]);
}

/// Verifies that a failing setUserId followed by another user and the same user again ends on that user.
- (void)testSetUserIdFailureKeepsSameUserSetAgainLater {
    PWPreferences *prefs = [PWPreferences preferences];
    [prefs resetUserIdToHwid];
    prefs.lastRegisterUserDate = [NSDate dateWithTimeIntervalSinceNow:-2 * 24 * 60 * 60];
    PWInAppMessagesManager *manager = [self managerHoldingRegisterUserRequests];

    [manager setUserId:@"alice" completion:^(NSError *error) {}];
    [manager setUserId:@"bob" completion:^(NSError *error) {}];
    [manager setUserId:@"alice" completion:^(NSError *error) {}];
    [self answerInFlightRegisterUserWithError:_failure];
    [self answerInFlightRegisterUserWithError:nil];
    [self answerInFlightRegisterUserWithError:nil];

    XCTAssertEqualObjects(_sentRegisterUserIds, (@[@"alice", @"bob", @"alice"]));
    XCTAssertEqualObjects(prefs.userId, @"alice");
    XCTAssertFalse(prefs.usesDefaultUserId);
    XCTAssertTrue([self relaunchSkipsRegisteringUser:@"alice"]);
}

/// Verifies that a setUserId still in flight when the app is relaunched is sent again after the relaunch.
- (void)testSetUserIdInFlightIsNotSkippedAfterRelaunch {
    PWPreferences *prefs = [PWPreferences preferences];
    prefs.userId = @"bob";
    prefs.lastRegisterUserDate = [NSDate date];
    PWInAppMessagesManager *manager = [self managerHoldingRegisterUserRequests];

    [manager setUserId:@"alice" completion:^(NSError *error) {}];

    XCTAssertFalse([self relaunchSkipsRegisteringUser:@"alice"]);
}

/// Verifies that a repeated resetUserId is sent after the first one fails, is not skipped after a relaunch, and both failing allow another reset.
- (void)testRepeatedResetUserIdIsSentAfterFirstFails {
    PWPreferences *prefs = [PWPreferences preferences];
    prefs.userId = @"alice";
    NSDate *aliceRegistration = [NSDate dateWithTimeIntervalSinceNow:-60 * 60];
    prefs.lastRegisterUserDate = aliceRegistration;
    PWInAppMessagesManager *manager = [self managerHoldingRegisterUserRequests];

    [manager resetUserIdWithCompletion:^(NSError *error) {}];
    [manager resetUserIdWithCompletion:^(NSError *error) {}];
    [self answerInFlightRegisterUserWithError:_failure];
    XCTAssertEqualObjects(_sentRegisterUserIds, (@[prefs.hwid, prefs.hwid]));
    XCTAssertFalse([self relaunchSkipsRegisteringUser:prefs.hwid]);
    [self answerInFlightRegisterUserWithError:_failure];

    XCTAssertEqualObjects(prefs.userId, @"alice");
    XCTAssertFalse(prefs.usesDefaultUserId);
    XCTAssertEqualObjects(prefs.lastRegisterUserDate, aliceRegistration);
    [manager resetUserIdWithCompletion:^(NSError *error) {}];
    XCTAssertEqual(_sentRegisterUserIds.count, 3);
}

/// Verifies that a repeated setUserId is sent after the first one fails, is not skipped after a relaunch, and both failing allow another setUserId.
- (void)testRepeatedSetUserIdIsSentAfterFirstFails {
    PWPreferences *prefs = [PWPreferences preferences];
    prefs.userId = @"bob";
    NSDate *bobRegistration = [NSDate dateWithTimeIntervalSinceNow:-60 * 60];
    prefs.lastRegisterUserDate = bobRegistration;
    PWInAppMessagesManager *manager = [self managerHoldingRegisterUserRequests];

    [manager setUserId:@"alice" completion:^(NSError *error) {}];
    [manager setUserId:@"alice" completion:^(NSError *error) {}];
    [self answerInFlightRegisterUserWithError:_failure];
    XCTAssertEqualObjects(_sentRegisterUserIds, (@[@"alice", @"alice"]));
    XCTAssertFalse([self relaunchSkipsRegisteringUser:@"alice"]);
    [self answerInFlightRegisterUserWithError:_failure];

    XCTAssertEqualObjects(prefs.userId, @"bob");
    XCTAssertEqualObjects(prefs.lastRegisterUserDate, bobRegistration);
    [manager setUserId:@"alice" completion:^(NSError *error) {}];
    XCTAssertEqual(_sentRegisterUserIds.count, 3);
}

/// Verifies that two different setUserId calls both failing return to the confirmed user and its registration date.
- (void)testSetUserIdFailuresRestoreConfirmedUser {
    PWPreferences *prefs = [PWPreferences preferences];
    prefs.userId = @"bob";
    NSDate *bobRegistration = [NSDate dateWithTimeIntervalSinceNow:-2 * 24 * 60 * 60];
    prefs.lastRegisterUserDate = bobRegistration;
    PWInAppMessagesManager *manager = [self managerHoldingRegisterUserRequests];

    [manager setUserId:@"alice" completion:^(NSError *error) {}];
    [manager setUserId:@"carol" completion:^(NSError *error) {}];
    [self answerInFlightRegisterUserWithError:_failure];
    [self answerInFlightRegisterUserWithError:_failure];

    XCTAssertEqualObjects(_sentRegisterUserIds, (@[@"alice", @"carol"]));
    XCTAssertEqualObjects(prefs.userId, @"bob");
    XCTAssertFalse(prefs.usesDefaultUserId);
    XCTAssertEqualObjects(prefs.lastRegisterUserDate, bobRegistration);
}

/// Verifies that a failing setUserId keeps the earlier user the server confirmed before it.
- (void)testSetUserIdFailureAfterEarlierUserConfirmedKeepsThatUser {
    PWPreferences *prefs = [PWPreferences preferences];
    prefs.userId = @"bob";
    prefs.lastRegisterUserDate = [NSDate dateWithTimeIntervalSinceNow:-2 * 24 * 60 * 60];
    PWInAppMessagesManager *manager = [self managerHoldingRegisterUserRequests];

    [manager setUserId:@"alice" completion:^(NSError *error) {}];
    [manager setUserId:@"carol" completion:^(NSError *error) {}];
    [self answerInFlightRegisterUserWithError:nil];
    [self answerInFlightRegisterUserWithError:_failure];
    NSUInteger sentBeforeRetry = _sentRegisterUserIds.count;
    [manager setUserId:@"alice" completion:^(NSError *error) {}];

    XCTAssertEqualObjects(prefs.userId, @"alice");
    XCTAssertFalse(prefs.usesDefaultUserId);
    XCTAssertEqual(_sentRegisterUserIds.count, sentBeforeRetry);
}

/// Verifies that a setUserId the server confirmed is not sent again the same day.
- (void)testSetUserIdConfirmedByServerIsNotSentAgainTheSameDay {
    PWPreferences *prefs = [PWPreferences preferences];
    prefs.userId = @"bob";
    prefs.lastRegisterUserDate = [NSDate dateWithTimeIntervalSinceNow:-2 * 24 * 60 * 60];
    PWInAppMessagesManager *manager = [self managerHoldingRegisterUserRequests];
    __block BOOL repeatedSetSucceeded = NO;

    [manager setUserId:@"alice" completion:^(NSError *error) {}];
    [self answerInFlightRegisterUserWithError:nil];
    [manager setUserId:@"alice" completion:^(NSError *error) {
        repeatedSetSucceeded = error == nil;
    }];

    XCTAssertEqual(_sentRegisterUserIds.count, 1);
    XCTAssertTrue(repeatedSetSucceeded);
    XCTAssertTrue([self relaunchSkipsRegisteringUser:@"alice"]);
}

/// Verifies that setUserId with nil registers the current user, so a later setUserId failing after it rolls back to that user and is sent again.
- (void)testSetUserIdNilRegistersCurrentUserAndLaterFailureRollsBackToIt {
    PWPreferences *prefs = [PWPreferences preferences];
    prefs.userId = @"alice";
    prefs.lastRegisterUserDate = [NSDate dateWithTimeIntervalSinceNow:-2 * 24 * 60 * 60];
    PWInAppMessagesManager *manager = [self managerHoldingRegisterUserRequests];

    [manager setUserId:nil completion:^(NSError *error) {}];
    [manager setUserId:@"bob" completion:^(NSError *error) {}];
    XCTAssertEqualObjects(_sentRegisterUserIds, @[@"alice"]);
    [self answerInFlightRegisterUserWithError:nil];
    [self answerInFlightRegisterUserWithError:_failure];

    XCTAssertEqualObjects(prefs.userId, @"alice");
    [manager setUserId:@"bob" completion:^(NSError *error) {}];
    XCTAssertEqualObjects(_sentRegisterUserIds, (@[@"alice", @"bob", @"bob"]));
}

/// Verifies that setUserId with nil on the HWID default user registers the HWID and keeps it the default user.
- (void)testSetUserIdNilKeepsHwidDefaultUser {
    PWPreferences *prefs = [PWPreferences preferences];
    [prefs resetUserIdToHwid];
    prefs.lastRegisterUserDate = [NSDate dateWithTimeIntervalSinceNow:-2 * 24 * 60 * 60];
    PWInAppMessagesManager *manager = [self managerHoldingRegisterUserRequests];

    [manager setUserId:nil completion:^(NSError *error) {}];
    [self answerInFlightRegisterUserWithError:nil];

    XCTAssertEqualObjects(_sentRegisterUserIds, @[prefs.hwid]);
    XCTAssertTrue(prefs.usesDefaultUserId);
}

/// Verifies that a user confirmed by the previous application is registered with the application that replaced it while the request was in flight.
- (void)testSetUserIdConfirmedAfterApplicationChangeIsSentToNewApplication {
    [self selectApplicationRestoredAfterTest];
    PWPreferences *prefs = [PWPreferences preferences];
    prefs.userId = @"alice";
    prefs.lastRegisterUserDate = [NSDate dateWithTimeIntervalSinceNow:-2 * 24 * 60 * 60];
    PWInAppMessagesManager *manager = [self managerHoldingRegisterUserRequests];

    [manager setUserId:@"bob" completion:^(NSError *error) {}];
    XCTAssertTrue([prefs switchToApplicationWithAppCode:@"REGUS-00002" baseUrl:prefs.baseUrl]);
    [self answerInFlightRegisterUserWithError:nil];

    XCTAssertEqualObjects(prefs.userId, @"bob");
    [manager setUserId:@"bob" completion:^(NSError *error) {}];
    XCTAssertEqualObjects(_sentRegisterUserIds, (@[@"bob", @"bob"]));
}

/// Verifies that a user confirmed by the previous host is registered again after the host moved while the request was in flight.
- (void)testSetUserIdConfirmedAfterHostMoveIsSentAgain {
    [self selectApplicationRestoredAfterTest];
    PWPreferences *prefs = [PWPreferences preferences];
    prefs.userId = @"alice";
    prefs.lastRegisterUserDate = [NSDate dateWithTimeIntervalSinceNow:-2 * 24 * 60 * 60];
    PWInAppMessagesManager *manager = [self managerHoldingRegisterUserRequests];

    [manager setUserId:@"bob" completion:^(NSError *error) {}];
    XCTAssertTrue([prefs switchToApplicationWithAppCode:prefs.appCode baseUrl:@"https://register-user-b.example.com/json/1.3/"]);
    [self answerInFlightRegisterUserWithError:nil];

    [manager setUserId:@"bob" completion:^(NSError *error) {}];
    XCTAssertEqualObjects(_sentRegisterUserIds, (@[@"bob", @"bob"]));
}

/// Verifies that a setUserId failing after the application changed does not restore the previous application's registration date.
- (void)testSetUserIdFailedAfterApplicationChangeLeavesUserUnregistered {
    [self selectApplicationRestoredAfterTest];
    PWPreferences *prefs = [PWPreferences preferences];
    prefs.userId = @"alice";
    prefs.lastRegisterUserDate = [NSDate dateWithTimeIntervalSinceNow:-60 * 60];
    PWInAppMessagesManager *manager = [self managerHoldingRegisterUserRequests];

    [manager setUserId:@"bob" completion:^(NSError *error) {}];
    prefs.appCode = @"REGUS-00002";
    [self answerInFlightRegisterUserWithError:_failure];

    XCTAssertEqualObjects(prefs.userId, @"alice");
    [manager setUserId:@"alice" completion:^(NSError *error) {}];
    XCTAssertEqualObjects(_sentRegisterUserIds, (@[@"bob", @"alice"]));
}

/// Verifies that setUserId:completion: persists the provided userId into PWPreferences.
- (void)testSetUserId {
    NSString *userId = @"1234567890";
    PWInAppMessagesManager *manager = [self managerAnsweringRegisterUserWithError:nil sentUserIds:nil];

    [manager setUserId:userId completion:^(NSError *error) {}];

    XCTAssertEqualObjects(userId, [PWPreferences preferences].userId);
}

/// Verifies that setUserId:completion: with nil leaves PWPreferences.userId at nil.
- (void)testSetUserIdEqualNil {
    PWInAppMessagesManager *manager = [self managerAnsweringRegisterUserWithError:nil sentUserIds:nil];
    id mockPWPreference = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPWPreference userId]).andReturn(nil);

    [manager setUserId:nil completion:^(NSError *error) {}];

    XCTAssertNil([PWPreferences preferences].userId);

    [mockPWPreference stopMocking];
}

/// Verifies that registerEmailUser:userId: persists the supplied userId into PWPreferences.
- (void)testRegisterEmailUserWithUserNotNil {
    NSString *userId = @"1234567890";
    NSString *email = @"test@test.com";
    PWInAppMessagesManager *manager = [[PWInAppMessagesManager alloc] init];

    [manager registerEmailUser:email userId:userId];

    XCTAssertEqualObjects(userId, [PWPreferences preferences].userId);
}

/// Verifies that trackInAppWithCode for a rich-media code (r- prefix) extracts the richMediaCode and leaves inAppCode empty.
- (void)testRichMedia {
    PWInAppMessagesManager *manager = [[PWInAppMessagesManager alloc] init];
    PWTriggerInAppActionRequest *request = [PWTriggerInAppActionRequest new];
    id mockPWTriggerInAppActionRequest = OCMClassMock([PWTriggerInAppActionRequest class]);
    OCMStub([mockPWTriggerInAppActionRequest new]).andReturn(request);

    [manager trackInAppWithCode:@"r-XXXXX-XXXX5" action:@"action" messageHash:@"__xczafasdadgsdf"];

    XCTAssertEqualObjects(request.inAppCode, @"");
    XCTAssertEqualObjects(request.messageHash, @"__xczafasdadgsdf");
    XCTAssertEqualObjects(request.richMediaCode, @"XXXXX-XXXX5");

    [mockPWTriggerInAppActionRequest stopMocking];
}

/// Verifies that trackInAppWithCode for a regular in-app code routes the code into inAppCode and leaves richMediaCode nil.
- (void)testOpenInApp {
    PWInAppMessagesManager *manager = [[PWInAppMessagesManager alloc] init];
    PWTriggerInAppActionRequest *request = [PWTriggerInAppActionRequest new];
    id mockPWTriggerInAppActionRequest = OCMClassMock([PWTriggerInAppActionRequest class]);
    OCMStub([mockPWTriggerInAppActionRequest new]).andReturn(request);

    [manager trackInAppWithCode:@"12345-67890" action:@"action" messageHash:@""];

    XCTAssertEqualObjects(request.inAppCode, @"12345-67890");
    XCTAssertEqualObjects(request.messageHash, @"");
    XCTAssertNil(request.richMediaCode);

    [mockPWTriggerInAppActionRequest stopMocking];
}

#pragma mark - richMediaDescriptorFrom

/// Verifies that a dictionary rm value is returned unchanged.
- (void)testRichMediaDescriptorFrom_dictionary_returnsSameDictionary {
    NSDictionary *rm = @{ @"url" : @"https://richmedia.pushwoosh.com/0/6/06883-1BC29.zip", @"ts" : @"1784034924" };

    NSDictionary *result = [PWInAppMessagesManager richMediaDescriptorFrom:rm];

    XCTAssertEqualObjects(result, rm);
}

/// Verifies that a zip URL string with a ts query item becomes a descriptor carrying that ts.
- (void)testRichMediaDescriptorFrom_urlStringWithTs_returnsDescriptorWithTs {
    NSString *url = @"https://richmedia.pushwoosh.com/0/6/06883-1BC29.zip?ts=1784034924";

    NSDictionary *result = [PWInAppMessagesManager richMediaDescriptorFrom:url];

    XCTAssertEqualObjects(result, (@{ @"url" : url, @"ts" : @"1784034924" }));
}

/// Verifies that a zip URL string without a ts query item gets ts "0".
- (void)testRichMediaDescriptorFrom_urlStringWithoutTs_returnsDescriptorWithZeroTs {
    NSString *url = @"https://richmedia.pushwoosh.com/0/6/06883-1BC29.zip";

    NSDictionary *result = [PWInAppMessagesManager richMediaDescriptorFrom:url];

    XCTAssertEqualObjects(result, (@{ @"url" : url, @"ts" : @"0" }));
}

/// Verifies that a JSON object string is parsed into a dictionary.
- (void)testRichMediaDescriptorFrom_jsonString_returnsParsedDictionary {
    NSString *json = @"{\"url\":\"https://richmedia.pushwoosh.com/0/6/06883-1BC29.zip\",\"ts\":\"1784034924\"}";

    NSDictionary *result = [PWInAppMessagesManager richMediaDescriptorFrom:json];

    XCTAssertEqualObjects(result, (@{ @"url" : @"https://richmedia.pushwoosh.com/0/6/06883-1BC29.zip", @"ts" : @"1784034924" }));
}

/// Verifies that a string without a host is returned as-is so the caller's type check rejects it.
- (void)testRichMediaDescriptorFrom_nonUrlString_returnsSameString {
    NSString *raw = @"not-a-url";

    id result = [PWInAppMessagesManager richMediaDescriptorFrom:raw];

    XCTAssertEqualObjects(result, raw);
}

/// Verifies that nil input yields nil.
- (void)testRichMediaDescriptorFrom_nil_returnsNil {
    XCTAssertNil([PWInAppMessagesManager richMediaDescriptorFrom:nil]);
}

@end
