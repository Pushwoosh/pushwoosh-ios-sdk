#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWRichMediaColorSchemeResolver.h"
#import "PWConfig.h"
#import "PWInteractionDisabledWindow.h"

@interface PWRichMediaColorSchemeResolver (Test)
+ (UIUserInterfaceStyle)interfaceStyleForScheme:(PWRichMediaColorScheme)scheme
                                       hostStyle:(UIUserInterfaceStyle)hostStyle
                                     systemStyle:(UIUserInterfaceStyle)systemStyle;
+ (UIViewController *)hostViewController;
@end

@interface PWRichMediaColorSchemeResolverTest : XCTestCase

@property (nonatomic, strong) id mockConfig;

@end

@implementation PWRichMediaColorSchemeResolverTest

- (void)setUp {
    [super setUp];
    self.mockConfig = OCMClassMock([PWConfig class]);
    OCMStub([self.mockConfig config]).andReturn(self.mockConfig);
}

- (void)tearDown {
    [self.mockConfig stopMocking];
    self.mockConfig = nil;
    [super tearDown];
}

/// Verifies that the Light scheme is light regardless of host and system styles.
- (void)testLightSchemeIgnoresHostAndSystemStyles {
    UIUserInterfaceStyle result = [PWRichMediaColorSchemeResolver interfaceStyleForScheme:PWRichMediaColorSchemeLight
                                                                                 hostStyle:UIUserInterfaceStyleDark
                                                                               systemStyle:UIUserInterfaceStyleDark];
    XCTAssertEqual(UIUserInterfaceStyleLight, result);
}

/// Verifies that the Dark scheme is dark regardless of host and system styles.
- (void)testDarkSchemeIgnoresHostAndSystemStyles {
    UIUserInterfaceStyle result = [PWRichMediaColorSchemeResolver interfaceStyleForScheme:PWRichMediaColorSchemeDark
                                                                                 hostStyle:UIUserInterfaceStyleLight
                                                                               systemStyle:UIUserInterfaceStyleLight];
    XCTAssertEqual(UIUserInterfaceStyleDark, result);
}

/// Verifies that the System scheme follows the system style and ignores the host style.
- (void)testSystemSchemeFollowsSystemStyle {
    XCTAssertEqual(UIUserInterfaceStyleDark, [PWRichMediaColorSchemeResolver interfaceStyleForScheme:PWRichMediaColorSchemeSystem
                                                                                            hostStyle:UIUserInterfaceStyleLight
                                                                                          systemStyle:UIUserInterfaceStyleDark]);
    XCTAssertEqual(UIUserInterfaceStyleLight, [PWRichMediaColorSchemeResolver interfaceStyleForScheme:PWRichMediaColorSchemeSystem
                                                                                             hostStyle:UIUserInterfaceStyleDark
                                                                                           systemStyle:UIUserInterfaceStyleLight]);
}

/// Verifies that the App scheme follows the host style and ignores the system style.
- (void)testAppSchemeFollowsHostStyle {
    XCTAssertEqual(UIUserInterfaceStyleDark, [PWRichMediaColorSchemeResolver interfaceStyleForScheme:PWRichMediaColorSchemeApp
                                                                                            hostStyle:UIUserInterfaceStyleDark
                                                                                          systemStyle:UIUserInterfaceStyleLight]);
    XCTAssertEqual(UIUserInterfaceStyleLight, [PWRichMediaColorSchemeResolver interfaceStyleForScheme:PWRichMediaColorSchemeApp
                                                                                             hostStyle:UIUserInterfaceStyleLight
                                                                                           systemStyle:UIUserInterfaceStyleDark]);
}

/// Verifies that the App scheme falls back to the system style when the host style is unspecified.
- (void)testAppSchemeFallsBackToSystemWhenHostUnspecified {
    UIUserInterfaceStyle result = [PWRichMediaColorSchemeResolver interfaceStyleForScheme:PWRichMediaColorSchemeApp
                                                                                 hostStyle:UIUserInterfaceStyleUnspecified
                                                                               systemStyle:UIUserInterfaceStyleDark];
    XCTAssertEqual(UIUserInterfaceStyleDark, result);
}

/// Verifies that the host lookup skips the SDK's own window even when it is key and returns the app's top presented controller.
- (void)testHostViewControllerSkipsSDKWindowAndReturnsTopPresentedController {
    UIViewController *presented = [UIViewController new];
    id root = OCMClassMock([UIViewController class]);
    OCMStub([root presentedViewController]).andReturn(presented);

    id appWindow = OCMClassMock([UIWindow class]);
    OCMStub([appWindow rootViewController]).andReturn(root);

    id sdkWindow = OCMClassMock([PWInteractionDisabledWindow class]);
    OCMStub([sdkWindow isKeyWindow]).andReturn(YES);
    OCMStub([sdkWindow rootViewController]).andReturn([UIViewController new]);

    NSArray<UIWindow *> *windows = @[sdkWindow, appWindow];
    id application = OCMClassMock([UIApplication class]);
    OCMStub([application sharedApplication]).andReturn(application);
    OCMStub([application windows]).andReturn(windows);

    XCTAssertEqual(presented, [PWRichMediaColorSchemeResolver hostViewController]);

    [application stopMocking];
}

/// Verifies that the key window of any foreground scene wins over a non-key window of another equally active scene.
- (void)testHostViewControllerPrefersKeyWindowAcrossForegroundScenes {
    UIViewController *rootA = [UIViewController new];
    UIViewController *rootB = [UIViewController new];

    id windowA = OCMClassMock([UIWindow class]);
    OCMStub([windowA rootViewController]).andReturn(rootA);
    id windowB = OCMClassMock([UIWindow class]);
    OCMStub([windowB isKeyWindow]).andReturn(YES);
    OCMStub([windowB rootViewController]).andReturn(rootB);

    NSArray<UIWindow *> *windowsA = @[windowA];
    NSArray<UIWindow *> *windowsB = @[windowB];
    id sceneA = OCMClassMock([UIWindowScene class]);
    OCMStub([sceneA activationState]).andReturn(UISceneActivationStateForegroundActive);
    OCMStub([sceneA windows]).andReturn(windowsA);
    id sceneB = OCMClassMock([UIWindowScene class]);
    OCMStub([sceneB activationState]).andReturn(UISceneActivationStateForegroundActive);
    OCMStub([sceneB windows]).andReturn(windowsB);

    NSSet<UIScene *> *scenes = [NSSet setWithArray:@[sceneA, sceneB]];
    id application = OCMClassMock([UIApplication class]);
    OCMStub([application sharedApplication]).andReturn(application);
    OCMStub([application connectedScenes]).andReturn(scenes);

    XCTAssertEqual(rootB, [PWRichMediaColorSchemeResolver hostViewController]);

    [application stopMocking];
}

/// Verifies that without a key window the fallback skips windows above UIWindowLevelNormal.
- (void)testHostViewControllerFallbackSkipsElevatedWindows {
    UIViewController *alertRoot = [UIViewController new];
    UIViewController *normalRoot = [UIViewController new];

    id alertWindow = OCMClassMock([UIWindow class]);
    OCMStub([alertWindow windowLevel]).andReturn(UIWindowLevelAlert);
    OCMStub([alertWindow rootViewController]).andReturn(alertRoot);
    id normalWindow = OCMClassMock([UIWindow class]);
    OCMStub([normalWindow rootViewController]).andReturn(normalRoot);

    NSArray<UIWindow *> *windows = @[alertWindow, normalWindow];
    id scene = OCMClassMock([UIWindowScene class]);
    OCMStub([scene activationState]).andReturn(UISceneActivationStateForegroundActive);
    OCMStub([scene windows]).andReturn(windows);

    NSSet<UIScene *> *scenes = [NSSet setWithObject:scene];
    id application = OCMClassMock([UIApplication class]);
    OCMStub([application sharedApplication]).andReturn(application);
    OCMStub([application connectedScenes]).andReturn(scenes);

    XCTAssertEqual(normalRoot, [PWRichMediaColorSchemeResolver hostViewController]);

    [application stopMocking];
}

/// Verifies that resolvedInterfaceStyle applies the scheme configured in PWConfig.
- (void)testResolvedInterfaceStyleUsesConfiguredScheme {
    OCMStub([(PWConfig *)self.mockConfig richMediaColorScheme]).andReturn(PWRichMediaColorSchemeDark);
    XCTAssertEqual(UIUserInterfaceStyleDark, [PWRichMediaColorSchemeResolver resolvedInterfaceStyle]);

    [self.mockConfig stopMocking];
    self.mockConfig = OCMClassMock([PWConfig class]);
    OCMStub([self.mockConfig config]).andReturn(self.mockConfig);
    OCMStub([(PWConfig *)self.mockConfig richMediaColorScheme]).andReturn(PWRichMediaColorSchemeLight);
    XCTAssertEqual(UIUserInterfaceStyleLight, [PWRichMediaColorSchemeResolver resolvedInterfaceStyle]);
}

/// Verifies that isCurrentSchemeDark mirrors the resolved style for the configured scheme.
- (void)testIsCurrentSchemeDarkFollowsConfiguredScheme {
    OCMStub([(PWConfig *)self.mockConfig richMediaColorScheme]).andReturn(PWRichMediaColorSchemeDark);
    XCTAssertTrue([PWRichMediaColorSchemeResolver isCurrentSchemeDark]);

    [self.mockConfig stopMocking];
    self.mockConfig = OCMClassMock([PWConfig class]);
    OCMStub([self.mockConfig config]).andReturn(self.mockConfig);
    OCMStub([(PWConfig *)self.mockConfig richMediaColorScheme]).andReturn(PWRichMediaColorSchemeLight);
    XCTAssertFalse([PWRichMediaColorSchemeResolver isCurrentSchemeDark]);
}

@end
