//
//  PWActionButtonsRegistrarTest.m
//  PushwooshTests
//
//  Created by André Kis on 08.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <UserNotifications/UserNotifications.h>

#import "PWActionButton.h"
#import "PWActionButtonsParser.h"
#import "PWActionButtonsRegistrar.h"

#if TARGET_OS_IOS

static NSString * const kDefaultsSuite = @"com.pushwoosh.tests.actionbuttons";

@interface PWActionButtonsRegistrarTest : XCTestCase

@property (nonatomic, strong) id centerMock;
@property (nonatomic, strong) NSUserDefaults *defaults;
@property (nonatomic, strong) PWActionButtonsRegistrar *registrar;
/// What iOS currently has registered; the mock reads it and setNotificationCategories: replaces it.
/// Atomic throughout: the registrar runs its sections on its own gate queue, so the stubs below are
/// driven from a background thread while the test body reads them.
@property (atomic, strong) NSSet<UNNotificationCategory *> *registered;
/// When YES, the read-back that follows setNotificationCategories: is parked instead of answered,
/// which is how a daemon that has not applied the set yet behaves.
@property (atomic) BOOL parksTheReadBack;
@property (atomic, copy) void (^parkedReadBack)(NSSet<UNNotificationCategory *> *);
@property (atomic) BOOL categoriesWereSet;
/// When YES, the very next read is parked instead of answered, which is how a registrar that is
/// holding a snapshot while another one runs behaves.
@property (atomic) BOOL parksTheNextRead;
@property (atomic, copy) void (^parkedRead)(NSSet<UNNotificationCategory *> *);
/// Registrations started and not yet answered, so tearDown can tell a finished test from one that still
/// has a section waiting on the gate.
@property (nonatomic) NSInteger outstanding;

@end

@implementation PWActionButtonsRegistrarTest

- (void)setUp {
    [super setUp];

    _registered = [NSSet set];
    _centerMock = OCMClassMock([UNUserNotificationCenter class]);

    __weak typeof(self) weakSelf = self;
    OCMStub([_centerMock getNotificationCategoriesWithCompletionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void (^handler)(NSSet<UNNotificationCategory *> *) = nil;
        [invocation getArgument:&handler atIndex:2];
        PWActionButtonsRegistrarTest *test = weakSelf;
        if (test.parksTheNextRead) {
            test.parksTheNextRead = NO;
            test.parkedRead = handler;
            return;
        }
        if (test.parksTheReadBack && test.categoriesWereSet) {
            test.parkedReadBack = handler;
            return;
        }
        handler(test.registered);
    });
    OCMStub([_centerMock setNotificationCategories:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSSet<UNNotificationCategory *> *categories = nil;
        [invocation getArgument:&categories atIndex:2];
        weakSelf.registered = [categories copy];
        weakSelf.categoriesWereSet = YES;
    });

    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:kDefaultsSuite];
    _defaults = [[NSUserDefaults alloc] initWithSuiteName:kDefaultsSuite];
    _registrar = [[PWActionButtonsRegistrar alloc] initWithNotificationCenter:_centerMock defaults:_defaults];
}

/// Finishes anything this test left parked and waits for the sections it woke, so the gate is never
/// carried into the next test and no section is still running when the mock below is stopped. The gate's
/// timeout bounds each waiter but never the gate itself - a count that is never given back stays at zero
/// for the life of the process - so a test that fails mid-sequence has to be cleaned up here.
- (void)tearDown {
    self.parksTheNextRead = NO;
    self.parksTheReadBack = NO;

    void (^parkedRead)(NSSet<UNNotificationCategory *> *) = self.parkedRead;
    self.parkedRead = nil;
    if (parkedRead) {
        parkedRead(self.registered);
    }

    void (^parkedReadBack)(NSSet<UNNotificationCategory *> *) = self.parkedReadBack;
    self.parkedReadBack = nil;
    if (parkedReadBack) {
        parkedReadBack(self.registered);
    }

    [self waitUntil:^BOOL { return [self outstandingRegistrations] == 0; } timeout:2];

    [_centerMock stopMocking];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:kDefaultsSuite];
    [super tearDown];
}

- (NSInteger)outstandingRegistrations {
    @synchronized (self) {
        return _outstanding;
    }
}

/// Every registration in this class goes through here, so tearDown can see the ones still in flight.
- (void)startRegistering:(NSArray<PWActionButton *> *)buttons
                      on:(PWActionButtonsRegistrar *)registrar
              completion:(dispatch_block_t)completion {
    @synchronized (self) {
        _outstanding++;
    }

    __weak typeof(self) weakSelf = self;
    [registrar registerCategoryForButtons:buttons completion:^{
        typeof(self) test = weakSelf;
        if (test) {
            @synchronized (test) {
                test->_outstanding--;
            }
        }
        if (completion) {
            completion();
        }
    }];
}

/// Spins the run loop until the predicate holds or the wait runs out; the registrar answers from its
/// own queue, so nothing it does is observable on the line after the call.
- (BOOL)waitUntil:(BOOL (^)(void))predicate timeout:(NSTimeInterval)timeout {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while (!predicate() && [deadline timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];
    }
    return predicate();
}

#pragma mark - Fixtures

- (NSArray<PWActionButton *> *)buttonsFromJSON:(NSString *)json {
    return [PWActionButtonsParser buttonsFromUserInfo:@{ @"pw_msg" : @"1", @"pw_buttons" : json }];
}

- (NSArray<PWActionButton *> *)threeButtons {
    return [self buttonsFromJSON:@"[{\"id\":\"open_app\",\"label\":\"Open\",\"action\":\"open\"},"
                                  "{\"id\":\"site\",\"label\":\"Website\",\"action\":\"url\",\"url\":\"https://www.pushwoosh.com\"},"
                                  "{\"id\":\"cancel\",\"label\":\"Cancel\",\"action\":\"custom\",\"style\":\"destructive\"}]"];
}

- (UNNotificationCategory *)registeredCategoryWithIdentifier:(NSString *)identifier {
    for (UNNotificationCategory *category in self.registered) {
        if ([category.identifier isEqualToString:identifier]) {
            return category;
        }
    }
    return nil;
}

- (NSSet<NSString *> *)registeredIdentifiers {
    NSMutableSet *ids = [NSMutableSet set];
    for (UNNotificationCategory *category in self.registered) {
        [ids addObject:category.identifier];
    }
    return ids;
}

- (void)register:(NSArray<PWActionButton *> *)buttons {
    XCTestExpectation *done = [self expectationWithDescription:@"registered"];
    [self startRegistering:buttons on:_registrar completion:^{
        [done fulfill];
    }];
    [self waitForExpectations:@[ done ] timeout:2];
}

#pragma mark - What iOS gets

/// Verifies the category carries the buttons in payload order, with the labels exactly as they arrived.
- (void)testCategoryCarriesButtonsInOrderWithTheirOwnLabels {
    NSArray<PWActionButton *> *buttons = [self threeButtons];

    UNNotificationCategory *category = [PWActionButtonsRegistrar categoryForButtons:buttons];

    XCTAssertEqual(category.actions.count, 3);
    XCTAssertEqualObjects(category.actions[0].identifier, @"open_app");
    XCTAssertEqualObjects(category.actions[0].title, @"Open");
    XCTAssertEqualObjects(category.actions[1].identifier, @"site");
    XCTAssertEqualObjects(category.actions[1].title, @"Website");
    XCTAssertEqualObjects(category.actions[2].identifier, @"cancel");
    XCTAssertEqualObjects(category.actions[2].title, @"Cancel");
}

/// Verifies open, url and deeplink open the application while custom does not, and that destructive
/// is the only style that paints the button red.
- (void)testActionOptionsFollowTheAction {
    NSArray<PWActionButton *> *buttons = [self buttonsFromJSON:
        @"[{\"id\":\"a\",\"label\":\"A\",\"action\":\"open\"},"
         "{\"id\":\"b\",\"label\":\"B\",\"action\":\"url\",\"url\":\"https://x\"},"
         "{\"id\":\"c\",\"label\":\"C\",\"action\":\"custom\",\"style\":\"destructive\"}]"];

    UNNotificationCategory *category = [PWActionButtonsRegistrar categoryForButtons:buttons];

    XCTAssertTrue(category.actions[0].options & UNNotificationActionOptionForeground);
    XCTAssertFalse(category.actions[0].options & UNNotificationActionOptionDestructive);
    XCTAssertTrue(category.actions[1].options & UNNotificationActionOptionForeground);
    XCTAssertFalse(category.actions[2].options & UNNotificationActionOptionForeground);
    XCTAssertTrue(category.actions[2].options & UNNotificationActionOptionDestructive);
}

/// Verifies no button ever asks the user for Face ID.
- (void)testNoActionRequiresAuthentication {
    UNNotificationCategory *category = [PWActionButtonsRegistrar categoryForButtons:[self threeButtons]];

    for (UNNotificationAction *action in category.actions) {
        XCTAssertFalse(action.options & UNNotificationActionOptionAuthenticationRequired);
    }
}

/// Verifies the identifier is derived from the buttons: the same set gets the same identifier and a
/// different set gets a different one, so a push's buttons survive the next push.
- (void)testCategoryIdentifierIsStablePerButtonSet {
    NSString *first = [PWActionButtonsRegistrar categoryIdentifierForButtons:[self threeButtons]];
    NSString *again = [PWActionButtonsRegistrar categoryIdentifierForButtons:[self threeButtons]];
    NSString *other = [PWActionButtonsRegistrar categoryIdentifierForButtons:
                       [self buttonsFromJSON:@"[{\"id\":\"open_app\",\"label\":\"Open now\",\"action\":\"open\"}]"]];

    XCTAssertEqualObjects(first, again);
    XCTAssertNotEqualObjects(first, other);
    XCTAssertTrue([first hasPrefix:@"pw_"]);
}

#pragma mark - Merging with what is already there

/// Verifies the application's own categories and the Control Panel ones survive registration.
- (void)testForeignCategoriesSurvive {
    UNNotificationCategory *appCategory = [UNNotificationCategory categoryWithIdentifier:@"MY_APP_CATEGORY" actions:@[] intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
    UNNotificationCategory *controlPanel = [UNNotificationCategory categoryWithIdentifier:@"9301" actions:@[] intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
    self.registered = [NSSet setWithObjects:appCategory, controlPanel, nil];

    [self register:[self threeButtons]];

    XCTAssertTrue([[self registeredIdentifiers] containsObject:@"MY_APP_CATEGORY"]);
    XCTAssertTrue([[self registeredIdentifiers] containsObject:@"9301"]);
    XCTAssertEqual(self.registered.count, 3);
}

/// Verifies a category this SDK never registered survives even when its identifier happens to start
/// with the pw_ prefix, which the Control Panel and application categories are free to use.
- (void)testForeignCategoryWithThePushwooshPrefixSurvives {
    UNNotificationCategory *foreign = [UNNotificationCategory categoryWithIdentifier:@"pw_sale" actions:@[] intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
    self.registered = [NSSet setWithObject:foreign];

    for (NSUInteger i = 0; i < PWActionButtonsCategoryLimit + 2; i++) {
        NSString *json = [NSString stringWithFormat:@"[{\"id\":\"a%lu\",\"label\":\"A\",\"action\":\"open\"}]", (unsigned long)i];
        [self register:[self buttonsFromJSON:json]];
    }

    XCTAssertTrue([[self registeredIdentifiers] containsObject:@"pw_sale"]);
}

/// Verifies several pushes with buttons leave the application's own categories alone, which is what
/// an application that registered its categories in code depends on.
- (void)testForeignCategoriesSurviveManyPushes {
    UNNotificationCategory *appCategory = [UNNotificationCategory categoryWithIdentifier:@"MY_APP_CATEGORY" actions:@[] intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
    self.registered = [NSSet setWithObject:appCategory];

    for (NSUInteger i = 0; i < 5; i++) {
        NSString *json = [NSString stringWithFormat:@"[{\"id\":\"a%lu\",\"label\":\"A\",\"action\":\"open\"}]", (unsigned long)i];
        [self register:[self buttonsFromJSON:json]];
    }

    XCTAssertTrue([[self registeredIdentifiers] containsObject:@"MY_APP_CATEGORY"]);
}

/// Verifies registering the same button set twice leaves one category, not two.
- (void)testRegisteringTheSameButtonsTwiceKeepsOneCategory {
    [self register:[self threeButtons]];
    [self register:[self threeButtons]];

    XCTAssertEqual(self.registered.count, 1);
}

/// Verifies two pushes with different buttons both keep their category, so the first push's buttons
/// still work after the second push arrives.
- (void)testTwoButtonSetsKeepBothCategories {
    NSArray<PWActionButton *> *first = [self buttonsFromJSON:@"[{\"id\":\"a\",\"label\":\"A\",\"action\":\"open\"}]"];
    NSArray<PWActionButton *> *second = [self buttonsFromJSON:@"[{\"id\":\"b\",\"label\":\"B\",\"action\":\"open\"}]"];

    [self register:first];
    [self register:second];

    XCTAssertNotNil([self registeredCategoryWithIdentifier:[PWActionButtonsRegistrar categoryIdentifierForButtons:first]]);
    XCTAssertNotNil([self registeredCategoryWithIdentifier:[PWActionButtonsRegistrar categoryIdentifierForButtons:second]]);
}

/// Verifies the twenty-first button set drops the oldest pw_ category and keeps the other twenty.
- (void)testTwentyFirstCategoryEvictsTheOldestPushwooshOne {
    NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
    for (NSUInteger i = 0; i < PWActionButtonsCategoryLimit + 1; i++) {
        NSString *json = [NSString stringWithFormat:@"[{\"id\":\"a%lu\",\"label\":\"A\",\"action\":\"open\"}]", (unsigned long)i];
        NSArray<PWActionButton *> *buttons = [self buttonsFromJSON:json];
        [identifiers addObject:[PWActionButtonsRegistrar categoryIdentifierForButtons:buttons]];
        [self register:buttons];
    }

    XCTAssertEqual(self.registered.count, PWActionButtonsCategoryLimit);
    XCTAssertNil([self registeredCategoryWithIdentifier:identifiers.firstObject]);
    XCTAssertNotNil([self registeredCategoryWithIdentifier:identifiers.lastObject]);
    XCTAssertNotNil([self registeredCategoryWithIdentifier:identifiers[1]]);
}

/// Verifies re-registering an older set makes it recent again, so it is not the one evicted next.
- (void)testReRegisteringRefreshesRecency {
    NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
    NSMutableArray<NSArray<PWActionButton *> *> *sets = [NSMutableArray array];
    for (NSUInteger i = 0; i < PWActionButtonsCategoryLimit; i++) {
        NSString *json = [NSString stringWithFormat:@"[{\"id\":\"a%lu\",\"label\":\"A\",\"action\":\"open\"}]", (unsigned long)i];
        NSArray<PWActionButton *> *buttons = [self buttonsFromJSON:json];
        [sets addObject:buttons];
        [identifiers addObject:[PWActionButtonsRegistrar categoryIdentifierForButtons:buttons]];
        [self register:buttons];
    }

    [self register:sets.firstObject];
    [self register:[self buttonsFromJSON:@"[{\"id\":\"fresh\",\"label\":\"F\",\"action\":\"open\"}]"]];

    XCTAssertNotNil([self registeredCategoryWithIdentifier:identifiers.firstObject]);
    XCTAssertNil([self registeredCategoryWithIdentifier:identifiers[1]]);
}

#pragma mark - Answering the extension

/// Verifies the completion waits for iOS to confirm the new set, not merely for the setter to be
/// issued — a push presented before the daemon applied it would expand without its buttons.
- (void)testCompletionWaitsUntilTheCategoriesAreApplied {
    self.parksTheReadBack = YES;

    __block NSUInteger answered = 0;
    [self startRegistering:[self threeButtons] on:_registrar completion:^{
        answered++;
    }];

    XCTAssertTrue([self waitUntil:^BOOL { return self.parkedReadBack != nil; } timeout:2]);
    XCTAssertEqual(self.registered.count, 1);
    XCTAssertEqual(answered, 0);

    void (^readBack)(NSSet<UNNotificationCategory *> *) = self.parkedReadBack;
    self.parkedReadBack = nil;
    readBack(self.registered);

    XCTAssertEqual(answered, 1);
}

/// Verifies two registrars in one process cannot drop each other's category: the second one runs
/// while the first is still holding a snapshot taken before the second wrote, and both survive.
- (void)testTwoRegistrarsInterleavedKeepBothCategories {
    NSArray<PWActionButton *> *first = [self buttonsFromJSON:@"[{\"id\":\"a\",\"label\":\"A\",\"action\":\"open\"}]"];
    NSArray<PWActionButton *> *second = [self buttonsFromJSON:@"[{\"id\":\"b\",\"label\":\"B\",\"action\":\"open\"}]"];

    PWActionButtonsRegistrar *other = [[PWActionButtonsRegistrar alloc] initWithNotificationCenter:_centerMock defaults:_defaults];

    XCTestExpectation *firstDone = [self expectationWithDescription:@"first registered"];
    XCTestExpectation *secondDone = [self expectationWithDescription:@"second registered"];

    self.parksTheNextRead = YES;
    [self startRegistering:first on:_registrar completion:^{
        [firstDone fulfill];
    }];
    XCTAssertTrue([self waitUntil:^BOOL { return self.parkedRead != nil; } timeout:2]);

    [self startRegistering:second on:other completion:^{
        [secondDone fulfill];
    }];
    /// Gives the second registrar every chance to write before the first is resumed: serialized it
    /// cannot, unserialized it does, and that is the whole difference this test is looking for.
    [self waitUntil:^BOOL { return self.categoriesWereSet; } timeout:0.15];

    void (^resume)(NSSet<UNNotificationCategory *> *) = self.parkedRead;
    self.parkedRead = nil;
    resume([NSSet set]);

    [self waitForExpectations:@[ firstDone, secondDone ] timeout:2];

    XCTAssertNotNil([self registeredCategoryWithIdentifier:[PWActionButtonsRegistrar categoryIdentifierForButtons:first]]);
    XCTAssertNotNil([self registeredCategoryWithIdentifier:[PWActionButtonsRegistrar categoryIdentifierForButtons:second]]);
}

#pragma mark - Nothing to register

/// Verifies an empty button list touches nothing and still answers, so the NSE never waits on it.
- (void)testEmptyButtonsRegisterNothing {
    OCMReject([_centerMock setNotificationCategories:OCMOCK_ANY]);

    [self register:@[]];

    XCTAssertEqual(self.registered.count, 0);
}

@end

#endif
