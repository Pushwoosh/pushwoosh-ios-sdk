#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <UIKit/UIKit.h>
#import "PWUtils.ios.h"
#import "PWUtils+Internal.h"
#import "PWUniversalLinkResolver.h"
#import "PWConfig.h"

@interface PWUniversalLinkResolver (RoutingTest)
+ (void)clearCache;
@end

@interface PWTestSceneDelegate : NSObject <UISceneDelegate>
@property (nonatomic, strong) NSUserActivity *receivedActivity;
@end

@implementation PWTestSceneDelegate
- (void)scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)userActivity {
    self.receivedActivity = userActivity;
}
@end

@interface PWTestAppDelegate : NSObject <UIApplicationDelegate>
@property (nonatomic, assign) BOOL returnValue;
@property (nonatomic, strong) NSUserActivity *receivedActivity;
@end

@implementation PWTestAppDelegate
- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> *))restorationHandler {
    self.receivedActivity = userActivity;
    return self.returnValue;
}
@end

@interface PWTestSilentAppDelegate : NSObject <UIApplicationDelegate>
@end

@implementation PWTestSilentAppDelegate
@end

@interface PWUniversalLinkRoutingTest : XCTestCase
@property (nonatomic, strong) id applicationMock;
@property (nonatomic, strong) id resolverMock;
@property (nonatomic, strong) id configMock;
@end

@implementation PWUniversalLinkRoutingTest

- (void)setUp {
    [super setUp];
    self.applicationMock = OCMClassMock([UIApplication class]);
    OCMStub([self.applicationMock sharedApplication]).andReturn(self.applicationMock);
    OCMStub([self.applicationMock connectedScenes]).andReturn([NSSet set]);
    self.resolverMock = OCMClassMock([PWUniversalLinkResolver class]);
    self.configMock = nil;
}

- (void)tearDown {
    [self.applicationMock stopMocking];
    [self.resolverMock stopMocking];
    [self.configMock stopMocking];
    [PWUniversalLinkResolver clearCache];
    [super tearDown];
}

- (void)stubVerdict:(PWUniversalLinkVerdict)verdict {
    OCMStub(ClassMethod([self.resolverMock resolveURL:[OCMArg any] completion:[OCMArg any]])).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained void (^completion)(PWUniversalLinkVerdict) = nil;
        [invocation getArgument:&completion atIndex:3];
        completion(verdict);
    });
}

- (void)stubDisableUrlFallback:(BOOL)value {
    self.configMock = OCMClassMock([PWConfig class]);
    OCMStub([self.configMock config]).andReturn(self.configMock);
    OCMStub([(PWConfig *)self.configMock disableUrlFallback]).andReturn(value);
}

- (void)replaceApplicationMockWithScenes:(NSSet *)scenes {
    [self.applicationMock stopMocking];
    self.applicationMock = OCMClassMock([UIApplication class]);
    OCMStub([self.applicationMock sharedApplication]).andReturn(self.applicationMock);
    OCMStub([self.applicationMock connectedScenes]).andReturn(scenes);
}

- (id)foregroundActiveSceneWithDelegate:(id)delegate {
    id scene = OCMClassMock([UIWindowScene class]);
    OCMStub([(UIScene *)scene activationState]).andReturn(UISceneActivationStateForegroundActive);
    OCMStub([(UIScene *)scene delegate]).andReturn(delegate);
    return scene;
}

- (id)backgroundSceneWithDelegate:(id)delegate {
    id scene = OCMClassMock([UIWindowScene class]);
    OCMStub([(UIScene *)scene activationState]).andReturn(UISceneActivationStateBackground);
    OCMStub([(UIScene *)scene delegate]).andReturn(delegate);
    return scene;
}

/// Verifies that custom-scheme URLs open directly without consulting the resolver.
- (void)testCustomSchemeOpensDirectly {
    OCMReject(ClassMethod([self.resolverMock resolveURL:[OCMArg any] completion:[OCMArg any]]));
    NSURL *url = [NSURL URLWithString:@"myapp://section/1"];
    [PWUtils applicationOpenURL:url];
    OCMVerify([self.applicationMock openURL:url options:[OCMArg any] completionHandler:[OCMArg any]]);
}

/// Verifies that a NoMatch verdict opens Safari and never delivers the activity.
- (void)testNoMatchOpensSafari {
    [self stubVerdict:PWUniversalLinkVerdictNoMatch];
    PWTestSceneDelegate *sceneDelegate = [PWTestSceneDelegate new];
    id scene = [self foregroundActiveSceneWithDelegate:sceneDelegate];
    [self replaceApplicationMockWithScenes:[NSSet setWithObject:scene]];

    NSURL *url = [NSURL URLWithString:@"https://foreign.com/page"];
    [PWUtils applicationOpenURL:url];

    XCTAssertNil(sceneDelegate.receivedActivity);
    OCMVerify([self.applicationMock openURL:url options:[OCMArg any] completionHandler:[OCMArg any]]);
}

/// Verifies that disableUrlFallback does not suppress Safari for a NoMatch verdict (routing, not fallback).
- (void)testNoMatchIgnoresDisableUrlFallback {
    [self stubVerdict:PWUniversalLinkVerdictNoMatch];
    [self stubDisableUrlFallback:YES];
    NSURL *url = [NSURL URLWithString:@"https://foreign.com/page"];
    [PWUtils applicationOpenURL:url];
    OCMVerify([self.applicationMock openURL:url options:[OCMArg any] completionHandler:[OCMArg any]]);
}

/// Verifies that a Match verdict delivers the activity to a foregroundActive scene delegate without opening Safari.
- (void)testMatchDeliversToForegroundActiveScene {
    [self stubVerdict:PWUniversalLinkVerdictMatch];
    PWTestSceneDelegate *sceneDelegate = [PWTestSceneDelegate new];
    id scene = [self foregroundActiveSceneWithDelegate:sceneDelegate];
    [self replaceApplicationMockWithScenes:[NSSet setWithObject:scene]];
    OCMReject([self.applicationMock openURL:[OCMArg any] options:[OCMArg any] completionHandler:[OCMArg any]]);

    NSURL *url = [NSURL URLWithString:@"https://claimed.com/products/1"];
    [PWUtils applicationOpenURL:url];

    XCTAssertEqualObjects(sceneDelegate.receivedActivity.webpageURL, url);
    XCTAssertEqualObjects(sceneDelegate.receivedActivity.activityType, NSUserActivityTypeBrowsingWeb);
}

/// Verifies that a foregroundActive scene is preferred over a background scene for a Match verdict.
- (void)testMatchPrefersForegroundActiveSceneOverBackground {
    [self stubVerdict:PWUniversalLinkVerdictMatch];
    PWTestSceneDelegate *backgroundDelegate = [PWTestSceneDelegate new];
    PWTestSceneDelegate *activeDelegate = [PWTestSceneDelegate new];
    id backgroundScene = [self backgroundSceneWithDelegate:backgroundDelegate];
    id activeScene = [self foregroundActiveSceneWithDelegate:activeDelegate];
    [self replaceApplicationMockWithScenes:[NSSet setWithObjects:backgroundScene, activeScene, nil]];
    OCMReject([self.applicationMock openURL:[OCMArg any] options:[OCMArg any] completionHandler:[OCMArg any]]);

    NSURL *url = [NSURL URLWithString:@"https://claimed.com/x"];
    [PWUtils applicationOpenURL:url];

    XCTAssertEqualObjects(activeDelegate.receivedActivity.webpageURL, url);
    XCTAssertNil(backgroundDelegate.receivedActivity);
}

/// Verifies that with no foreground scene a Match verdict is still delivered to a background scene, not Safari or the app delegate.
- (void)testMatchFallsBackToBackgroundSceneWhenNoForeground {
    [self stubVerdict:PWUniversalLinkVerdictMatch];
    PWTestSceneDelegate *sceneDelegate = [PWTestSceneDelegate new];
    id scene = [self backgroundSceneWithDelegate:sceneDelegate];
    PWTestAppDelegate *appDelegate = [PWTestAppDelegate new];
    [self replaceApplicationMockWithScenes:[NSSet setWithObject:scene]];
    OCMStub([self.applicationMock delegate]).andReturn(appDelegate);
    OCMReject([self.applicationMock openURL:[OCMArg any] options:[OCMArg any] completionHandler:[OCMArg any]]);

    NSURL *url = [NSURL URLWithString:@"https://claimed.com/x"];
    [PWUtils applicationOpenURL:url];

    XCTAssertEqualObjects(sceneDelegate.receivedActivity.webpageURL, url);
    XCTAssertNil(appDelegate.receivedActivity);
}

/// Verifies that a Match verdict with app delegate returning NO and no flag opens Safari.
- (void)testMatchAppDelegateReturnsNoOpensSafari {
    [self stubVerdict:PWUniversalLinkVerdictMatch];
    PWTestAppDelegate *appDelegate = [PWTestAppDelegate new];
    appDelegate.returnValue = NO;
    OCMStub([self.applicationMock delegate]).andReturn(appDelegate);

    NSURL *url = [NSURL URLWithString:@"https://claimed.com/x"];
    [PWUtils applicationOpenURL:url];

    OCMVerify([self.applicationMock openURL:url options:[OCMArg any] completionHandler:[OCMArg any]]);
}

/// Verifies that a Match verdict with app delegate returning NO and disableUrlFallback set does nothing.
- (void)testMatchAppDelegateReturnsNoWithFlagDoesNothing {
    [self stubVerdict:PWUniversalLinkVerdictMatch];
    [self stubDisableUrlFallback:YES];
    PWTestAppDelegate *appDelegate = [PWTestAppDelegate new];
    appDelegate.returnValue = NO;
    OCMStub([self.applicationMock delegate]).andReturn(appDelegate);
    OCMReject([self.applicationMock openURL:[OCMArg any] options:[OCMArg any] completionHandler:[OCMArg any]]);

    [PWUtils applicationOpenURL:[NSURL URLWithString:@"https://claimed.com/x"]];

    XCTAssertNotNil(appDelegate.receivedActivity);
}

/// Verifies that a Match verdict with nobody implementing continueUserActivity opens Safari.
- (void)testMatchNobodyImplementsOpensSafari {
    [self stubVerdict:PWUniversalLinkVerdictMatch];
    PWTestSilentAppDelegate *appDelegate = [PWTestSilentAppDelegate new];
    OCMStub([self.applicationMock delegate]).andReturn(appDelegate);

    NSURL *url = [NSURL URLWithString:@"https://claimed.com/x"];
    [PWUtils applicationOpenURL:url];

    OCMVerify([self.applicationMock openURL:url options:[OCMArg any] completionHandler:[OCMArg any]]);
}

/// Verifies that Unknown opens Safari instead of handing the activity to a scene delegate on a guess.
///
/// This is the regression the scene path used to hide: `scene:continueUserActivity:` returns void,
/// so a router that does not recognize the URL swallowed the link with no navigation, no browser
/// and no error. The verdict says the domain could not be reached, not that the app claims it.
- (void)testUnknownOpensSafariRatherThanGuessingAtTheScene {
    [self stubVerdict:PWUniversalLinkVerdictUnknown];
    PWTestSceneDelegate *sceneDelegate = [PWTestSceneDelegate new];
    id scene = [self foregroundActiveSceneWithDelegate:sceneDelegate];
    [self replaceApplicationMockWithScenes:[NSSet setWithObject:scene]];

    NSURL *url = [NSURL URLWithString:@"https://maybe.com/x"];
    [PWUtils applicationOpenURL:url];

    XCTAssertNil(sceneDelegate.receivedActivity);
    OCMVerify([self.applicationMock openURL:url options:[OCMArg any] completionHandler:[OCMArg any]]);
}

/// Verifies that Unknown opens Safari even where the app delegate would have claimed the activity.
///
/// An app delegate returning YES proves nothing either: RCTLinkingManager returns YES for every
/// browsing activity whether or not JS acts on it, which is how React Native apps lost the link.
- (void)testUnknownOpensSafariEvenWhenAppDelegateWouldClaimIt {
    [self stubVerdict:PWUniversalLinkVerdictUnknown];
    PWTestAppDelegate *appDelegate = [PWTestAppDelegate new];
    appDelegate.returnValue = YES;
    OCMStub([self.applicationMock delegate]).andReturn(appDelegate);

    NSURL *url = [NSURL URLWithString:@"https://maybe.com/x"];
    [PWUtils applicationOpenURL:url];

    XCTAssertNil(appDelegate.receivedActivity);
    OCMVerify([self.applicationMock openURL:url options:[OCMArg any] completionHandler:[OCMArg any]]);
}

/// Verifies that disableUrlFallback keeps the old Unknown behaviour for a scene: deliver, no Safari.
///
/// Unlike NoMatch — where the flag is ignored because the verdict is routing, not fallback — an
/// Unknown verdict is exactly the "I handle my own links, never open the browser" case the flag
/// was documented for, so an integrator who set it keeps what they configured.
- (void)testUnknownWithDisableUrlFallbackDeliversToScene {
    [self stubVerdict:PWUniversalLinkVerdictUnknown];
    [self stubDisableUrlFallback:YES];
    PWTestSceneDelegate *sceneDelegate = [PWTestSceneDelegate new];
    id scene = [self foregroundActiveSceneWithDelegate:sceneDelegate];
    [self replaceApplicationMockWithScenes:[NSSet setWithObject:scene]];
    OCMReject([self.applicationMock openURL:[OCMArg any] options:[OCMArg any] completionHandler:[OCMArg any]]);

    NSURL *url = [NSURL URLWithString:@"https://maybe.com/x"];
    [PWUtils applicationOpenURL:url];

    XCTAssertEqualObjects(sceneDelegate.receivedActivity.webpageURL, url);
}

/// Verifies that disableUrlFallback keeps the old Unknown behaviour for the app delegate too.
- (void)testUnknownWithDisableUrlFallbackDeliversToAppDelegate {
    [self stubVerdict:PWUniversalLinkVerdictUnknown];
    [self stubDisableUrlFallback:YES];
    PWTestAppDelegate *appDelegate = [PWTestAppDelegate new];
    appDelegate.returnValue = NO;
    OCMStub([self.applicationMock delegate]).andReturn(appDelegate);
    OCMReject([self.applicationMock openURL:[OCMArg any] options:[OCMArg any] completionHandler:[OCMArg any]]);

    [PWUtils applicationOpenURL:[NSURL URLWithString:@"https://maybe.com/x"]];

    XCTAssertNotNil(appDelegate.receivedActivity);
}

/// Verifies that Unknown opens Safari when nothing implements continueUserActivity at all.
- (void)testUnknownNobodyImplementsOpensSafari {
    [self stubVerdict:PWUniversalLinkVerdictUnknown];
    PWTestSilentAppDelegate *appDelegate = [PWTestSilentAppDelegate new];
    OCMStub([self.applicationMock delegate]).andReturn(appDelegate);

    NSURL *url = [NSURL URLWithString:@"https://maybe.com/x"];
    [PWUtils applicationOpenURL:url];

    OCMVerify([self.applicationMock openURL:url options:[OCMArg any] completionHandler:[OCMArg any]]);
}

@end
