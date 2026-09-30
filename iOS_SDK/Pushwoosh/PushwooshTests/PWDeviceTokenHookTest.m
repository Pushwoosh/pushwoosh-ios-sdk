//  PWDeviceTokenHookTest.m
//  Created by André Kis

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#import "PWPreferences.h"
#import "PWManagerBridge.h"
#import "PWPushRuntime.ios.h"

typedef void (*PWHookTokenIMP)(id, SEL, id, NSData *);

static NSData *pw_hook_token;
static NSCountedSet<NSString *> *pw_hook_calls;
static NSUInteger pw_hook_sdkDeliveries;
static BOOL pw_hook_autoRegistration;
static id pw_hook_forwardingTarget;

static SEL pw_hook_tokenSelector(void) {
    return @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:);
}

static SEL pw_hook_uniqueSelector(NSString *prefix) {
    return NSSelectorFromString([NSString stringWithFormat:@"application:%@%u_didRegisterForRemoteNotificationsWithDeviceToken:", prefix, arc4random()]);
}

static void pw_hook_record(NSString *label, NSData *token) {
    if (pw_hook_token != nil && [token isEqualToData:pw_hook_token]) {
        [pw_hook_calls addObject:label];
    }
}

static void pw_hook_appCallback(id self, SEL _cmd, id application, NSData *token) {
    pw_hook_record(@"app", token);
}

static void pw_hook_appCallbackDelivering(id self, SEL _cmd, id application, NSData *token) {
    pw_hook_record(@"app", token);
    [[PWManagerBridge shared] handlePushRegistration:token];
}

static void pw_hook_appCallbackDeliveringLater(id self, SEL _cmd, id application, NSData *token) {
    pw_hook_record(@"app", token);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[PWManagerBridge shared] handlePushRegistration:token];
    });
}

static void pw_hook_overrideWithoutSuper(id self, SEL _cmd, id application, NSData *token) {
    pw_hook_record(@"override", token);
}

static id pw_hook_forwardingTargetForSelector(id self, SEL _cmd, SEL selector) {
    return [pw_hook_forwardingTarget respondsToSelector:selector] ? pw_hook_forwardingTarget : nil;
}

/// A fresh name per call: a hooked class stays hooked for the rest of the process.
static Class pw_hook_makeClass(Class superclass, NSString *prefix, IMP tokenImplementation) {
    NSString *name = [NSString stringWithFormat:@"%@_%u", prefix, arc4random()];
    Class cls = objc_allocateClassPair(superclass, name.UTF8String, 0);
    if (tokenImplementation) {
        class_addMethod(cls, pw_hook_tokenSelector(), tokenImplementation, "v@:@@");
    }
    objc_registerClassPair(cls);
    return cls;
}

static Class pw_hook_makeForwardingWrapperClass(void) {
    Class cls = pw_hook_makeClass([NSObject class], @"PWHookSwiftUIAdaptor", NULL);
    class_addMethod(cls, @selector(forwardingTargetForSelector:), (IMP)pw_hook_forwardingTargetForSelector, "@@::");
    return cls;
}

/// What `-[UIApplication setDelegate:]` does with the delegate it is handed.
static void pw_hook_setDelegate(id delegate) {
    [PWPushRuntime swizzleDeviceTokenHandlerForDelegateClass:[delegate class]];
}

static void pw_hook_drainMainQueue(void) {
    XCTestExpectation *drained = [[XCTestExpectation alloc] initWithDescription:@"main queue drained"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [drained fulfill];
    });
    [XCTWaiter waitForExpectations:@[drained] timeout:10];
}

static void pw_hook_deliverToken(id delegate) {
    ((PWHookTokenIMP)objc_msgSend)(delegate, pw_hook_tokenSelector(), nil, pw_hook_token);
    pw_hook_drainMainQueue();
}

/// Braze, Airship, MoEngage: a block holding the IMP the class answered with, own or inherited.
static void pw_hook_foreignSetImplementation(Class cls, NSString *label) {
    SEL selector = pw_hook_tokenSelector();
    Method method = class_getInstanceMethod(cls, selector);
    IMP original = method ? method_getImplementation(method) : NULL;
    IMP foreign = imp_implementationWithBlock(^(id receiver, id application, NSData *token) {
        pw_hook_record(label, token);
        if (original) {
            ((PWHookTokenIMP)original)(receiver, selector, application, token);
        }
    });
    class_replaceMethod(cls, selector, foreign, "v@:@@");
}

/// Exchange with an own method, the original called through the IMP it was exchanged to.
static void pw_hook_foreignExchange(Class cls, NSString *label) {
    SEL selector = pw_hook_tokenSelector();
    SEL foreignSelector = pw_hook_uniqueSelector(label);
    IMP foreign = imp_implementationWithBlock(^(id receiver, id application, NSData *token) {
        pw_hook_record(label, token);
        IMP original = method_getImplementation(class_getInstanceMethod(cls, foreignSelector));
        ((PWHookTokenIMP)original)(receiver, selector, application, token);
    });
    class_addMethod(cls, foreignSelector, foreign, "v@:@@");
    method_exchangeImplementations(class_getInstanceMethod(cls, selector), class_getInstanceMethod(cls, foreignSelector));
}

/// OneSignal, CleverTap, Insider and the Pushwoosh RN/Cordova plugins: exchange, then the original is sent to self under the foreign selector.
static void pw_hook_foreignSelectorOnSelf(Class cls, NSString *label, BOOL deliversToSdk) {
    SEL selector = pw_hook_tokenSelector();
    SEL foreignSelector = pw_hook_uniqueSelector(label);
    IMP foreign = imp_implementationWithBlock(^(id receiver, id application, NSData *token) {
        pw_hook_record(label, token);
        if ([receiver respondsToSelector:foreignSelector]) {
            ((PWHookTokenIMP)objc_msgSend)(receiver, foreignSelector, application, token);
        }
        if (deliversToSdk) {
            [[PWManagerBridge shared] handlePushRegistration:token];
        }
    });
    if (class_getInstanceMethod(cls, selector)) {
        class_addMethod(cls, foreignSelector, foreign, "v@:@@");
        method_exchangeImplementations(class_getInstanceMethod(cls, selector), class_getInstanceMethod(cls, foreignSelector));
    } else {
        class_addMethod(cls, selector, foreign, "v@:@@");
    }
}

/// GoogleUtilities: an isa-swizzled subclass of the delegate's class, then the delegate is reassigned.
static Class pw_hook_firebaseProxyDelegate(id delegate) {
    Class subclass = pw_hook_makeClass([delegate class], @"GUL_PWHookAppDelegate", NULL);
    object_setClass(delegate, subclass);
    pw_hook_setDelegate(delegate);
    return subclass;
}

/// GoogleUtilities with Messaging: the token donor goes into the subclass with class_addMethod, calling
/// the real class's IMP; a NO here is I-SWZ001009 and Messaging never sees the APNs token.
static BOOL pw_hook_firebaseAddTokenDonor(Class subclass, Class realClass) {
    SEL selector = pw_hook_tokenSelector();
    Method realMethod = class_getInstanceMethod(realClass, selector);
    IMP realImplementation = realMethod ? method_getImplementation(realMethod) : NULL;
    IMP donor = imp_implementationWithBlock(^(id receiver, id application, NSData *token) {
        pw_hook_record(@"donor", token);
        if (realImplementation) {
            ((PWHookTokenIMP)realImplementation)(receiver, selector, application, token);
        }
    });
    return class_addMethod(subclass, selector, donor, "v@:@@");
}

@interface PWHookTestProxy : NSProxy
@property (nonatomic, strong) id target;
@end

@implementation PWHookTestProxy

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [self.target methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:self.target];
}

@end

static id pw_hook_makeProxy(id target) {
    Class proxyClass = pw_hook_makeClass([PWHookTestProxy class], @"PWHookTestProxy", NULL);
    PWHookTestProxy *proxy = [proxyClass alloc];
    proxy.target = target;
    return proxy;
}

@interface PWHookTestObservable : NSObject
@property (nonatomic, copy) NSString *value;
@end

@implementation PWHookTestObservable
@end

@interface PWDeviceTokenHookTest : XCTestCase

@property (nonatomic, strong) NSMutableArray<dispatch_block_t> *restorations;

@end

@implementation PWDeviceTokenHookTest

- (void)setUp {
    [super setUp];
    pw_hook_token = [[NSUUID UUID].UUIDString dataUsingEncoding:NSUTF8StringEncoding];
    pw_hook_calls = [NSCountedSet new];
    pw_hook_sdkDeliveries = 0;
    pw_hook_autoRegistration = YES;
    pw_hook_forwardingTarget = nil;
    self.restorations = [NSMutableArray new];

    [self replaceMethod:@selector(hasAppCode) ofClass:[PWPreferences class] withBlock:^BOOL(id preferences) {
        return YES;
    }];
    [self replaceMethod:@selector(isAutoDeviceTokenRegistrationEnabled) ofClass:[PWPreferences class] withBlock:^BOOL(id preferences) {
        return pw_hook_autoRegistration;
    }];
    [self replaceMethod:@selector(handlePushRegistration:) ofClass:[PWManagerBridge class] withBlock:^(id bridge, NSData *token) {
        if (pw_hook_token != nil && [token isEqualToData:pw_hook_token]) {
            pw_hook_sdkDeliveries += 1;
        }
    }];
    [self replaceMethod:@selector(pushRegistrationCount) ofClass:[PWManagerBridge class] withBlock:^NSUInteger(id bridge) {
        return pw_hook_sdkDeliveries;
    }];
}

- (void)tearDown {
    pw_hook_drainMainQueue();
    for (dispatch_block_t restore in self.restorations.reverseObjectEnumerator) {
        restore();
    }
    self.restorations = nil;
    pw_hook_forwardingTarget = nil;
    pw_hook_calls = nil;
    pw_hook_token = nil;
    [super tearDown];
}

/// Swapped IMPs instead of partial mocks: a mock's isa swizzle on PWPreferences breaks the KVO other managers keep on it.
- (void)replaceMethod:(SEL)selector ofClass:(Class)cls withBlock:(id)block {
    Method method = class_getInstanceMethod(cls, selector);
    IMP original = method_setImplementation(method, imp_implementationWithBlock(block));
    [self.restorations addObject:^{
        method_setImplementation(method, original);
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
}

- (void)assertApp:(NSUInteger)app sdk:(NSUInteger)sdk {
    XCTAssertEqual([pw_hook_calls countForObject:@"app"], app, @"app callback");
    XCTAssertEqual(pw_hook_sdkDeliveries, sdk, @"token deliveries to the SDK");
}

#pragma mark - (a) isa-swizzled subclass, GoogleUtilities

/// Verifies that the Firebase-style subclass of a hooked delegate reaches the app callback and the SDK once each.
- (void)testFirebaseStyleSubclassOfHookedDelegateDeliversOnce {
    id delegate = [pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallback) new];
    pw_hook_setDelegate(delegate);

    pw_hook_firebaseProxyDelegate(delegate);
    pw_hook_deliverToken(delegate);

    [self assertApp:1 sdk:1];
}

/// Verifies that the Messaging token donor still fits into the Firebase subclass and every callback in the chain runs once.
- (void)testFirebaseStyleTokenDonorIsAddedAndCalledOnce {
    Class appDelegateClass = pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallback);
    id delegate = [appDelegateClass new];
    pw_hook_setDelegate(delegate);
    Class subclass = pw_hook_firebaseProxyDelegate(delegate);

    XCTAssertTrue(pw_hook_firebaseAddTokenDonor(subclass, appDelegateClass));
    pw_hook_setDelegate(delegate);
    pw_hook_deliverToken(delegate);

    XCTAssertEqual([pw_hook_calls countForObject:@"donor"], 1);
    [self assertApp:1 sdk:1];
}

/// Verifies that an app handing the token to the SDK itself behind the Messaging token donor leaves the SDK with one delivery.
- (void)testFirebaseStyleTokenDonorWithAppDeliveringTokenItselfDeliversOnce {
    Class appDelegateClass = pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallbackDelivering);
    id delegate = [appDelegateClass new];
    pw_hook_setDelegate(delegate);
    Class subclass = pw_hook_firebaseProxyDelegate(delegate);

    XCTAssertTrue(pw_hook_firebaseAddTokenDonor(subclass, appDelegateClass));
    pw_hook_setDelegate(delegate);
    pw_hook_deliverToken(delegate);

    XCTAssertEqual([pw_hook_calls countForObject:@"donor"], 1);
    [self assertApp:1 sdk:1];
}

/// Verifies that an app handing the token over on the next main-queue turn behind the Messaging token donor leaves the SDK with one delivery.
- (void)testFirebaseStyleTokenDonorWithAppDeliveringTokenLaterDeliversOnce {
    Class appDelegateClass = pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallbackDeliveringLater);
    id delegate = [appDelegateClass new];
    pw_hook_setDelegate(delegate);
    Class subclass = pw_hook_firebaseProxyDelegate(delegate);

    XCTAssertTrue(pw_hook_firebaseAddTokenDonor(subclass, appDelegateClass));
    pw_hook_setDelegate(delegate);
    pw_hook_deliverToken(delegate);

    XCTAssertEqual([pw_hook_calls countForObject:@"donor"], 1);
    [self assertApp:1 sdk:1];
}

/// Verifies that with auto registration off the Messaging token donor chain reaches the app and leaves the SDK alone.
- (void)testFirebaseStyleTokenDonorWithAutoRegistrationOffLeavesDeliveryToApp {
    pw_hook_autoRegistration = NO;
    Class appDelegateClass = pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallback);
    id delegate = [appDelegateClass new];
    pw_hook_setDelegate(delegate);
    Class subclass = pw_hook_firebaseProxyDelegate(delegate);

    XCTAssertTrue(pw_hook_firebaseAddTokenDonor(subclass, appDelegateClass));
    pw_hook_setDelegate(delegate);
    pw_hook_deliverToken(delegate);

    XCTAssertEqual([pw_hook_calls countForObject:@"donor"], 1);
    [self assertApp:1 sdk:0];
}

/// Verifies that the Firebase-style subclass of a delegate without a token callback still hands the token to the SDK once.
- (void)testFirebaseStyleSubclassOfDelegateWithoutCallbackDeliversOnce {
    Class appDelegateClass = pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", NULL);
    id delegate = [appDelegateClass new];
    pw_hook_setDelegate(delegate);
    Class subclass = pw_hook_firebaseProxyDelegate(delegate);

    XCTAssertTrue(pw_hook_firebaseAddTokenDonor(subclass, appDelegateClass));
    pw_hook_setDelegate(delegate);
    pw_hook_deliverToken(delegate);

    XCTAssertEqual([pw_hook_calls countForObject:@"donor"], 1);
    [self assertApp:0 sdk:1];
}

#pragma mark - (b) setImplementation and exchange on the same class

/// Verifies that a foreign setImplementation hook installed before ours keeps the whole chain once each.
- (void)testForeignSetImplementationBeforeHookKeepsChain {
    Class cls = pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallback);
    pw_hook_foreignSetImplementation(cls, @"foreign");
    id delegate = [cls new];

    pw_hook_setDelegate(delegate);
    pw_hook_deliverToken(delegate);

    XCTAssertEqual([pw_hook_calls countForObject:@"foreign"], 1);
    [self assertApp:1 sdk:1];
}

/// Verifies that a foreign setImplementation hook installed after ours keeps the whole chain once each.
- (void)testForeignSetImplementationAfterHookKeepsChain {
    Class cls = pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallback);
    id delegate = [cls new];
    pw_hook_setDelegate(delegate);

    pw_hook_foreignSetImplementation(cls, @"foreign");
    pw_hook_deliverToken(delegate);

    XCTAssertEqual([pw_hook_calls countForObject:@"foreign"], 1);
    [self assertApp:1 sdk:1];
}

/// Verifies that a foreign method exchange done before our hook keeps the whole chain once each.
- (void)testForeignExchangeBeforeHookKeepsChain {
    Class cls = pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallback);
    pw_hook_foreignExchange(cls, @"foreign");
    id delegate = [cls new];

    pw_hook_setDelegate(delegate);
    pw_hook_deliverToken(delegate);

    XCTAssertEqual([pw_hook_calls countForObject:@"foreign"], 1);
    [self assertApp:1 sdk:1];
}

/// Verifies that a foreign method exchange done after our hook keeps the whole chain once each.
- (void)testForeignExchangeAfterHookKeepsChain {
    Class cls = pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallback);
    id delegate = [cls new];
    pw_hook_setDelegate(delegate);

    pw_hook_foreignExchange(cls, @"foreign");
    pw_hook_deliverToken(delegate);

    XCTAssertEqual([pw_hook_calls countForObject:@"foreign"], 1);
    [self assertApp:1 sdk:1];
}

#pragma mark - (c) original sent to self under a foreign selector

/// Verifies that a foreign hook sending our IMP to self under its own selector keeps the whole chain once each.
- (void)testForeignSelectorOnSelfAboveHookKeepsChain {
    Class cls = pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallback);
    id delegate = [cls new];
    pw_hook_setDelegate(delegate);

    pw_hook_foreignSelectorOnSelf(cls, @"foreign", NO);
    pw_hook_deliverToken(delegate);

    XCTAssertEqual([pw_hook_calls countForObject:@"foreign"], 1);
    [self assertApp:1 sdk:1];
}

/// Verifies that our hook wrapped around a foreign selector-on-self hook keeps the whole chain once each.
- (void)testForeignSelectorOnSelfBelowHookKeepsChain {
    Class cls = pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallback);
    pw_hook_foreignSelectorOnSelf(cls, @"foreign", NO);
    id delegate = [cls new];

    pw_hook_setDelegate(delegate);
    pw_hook_deliverToken(delegate);

    XCTAssertEqual([pw_hook_calls countForObject:@"foreign"], 1);
    [self assertApp:1 sdk:1];
}

/// Verifies that a plugin hook handing the token to the SDK itself leaves the SDK with a single delivery.
- (void)testPluginDeliveringTokenItselfLeavesSdkWithOneDelivery {
    Class cls = pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallback);
    id delegate = [cls new];
    pw_hook_setDelegate(delegate);

    pw_hook_foreignSelectorOnSelf(cls, @"plugin", YES);
    pw_hook_deliverToken(delegate);

    XCTAssertEqual([pw_hook_calls countForObject:@"plugin"], 1);
    [self assertApp:1 sdk:1];
}

#pragma mark - (d) our IMP copied elsewhere

/// Verifies that our IMP copied into an unrelated class and hooked there acts as a copy of the original instead of recursing.
- (void)testHookCopiedIntoUnrelatedClassActsAsOriginal {
    Class cls = pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallback);
    pw_hook_setDelegate([cls new]);
    IMP hook = method_getImplementation(class_getInstanceMethod(cls, pw_hook_tokenSelector()));
    id wrapper = [pw_hook_makeClass([NSObject class], @"PWHookUnrelatedWrapper", hook) new];

    pw_hook_setDelegate(wrapper);
    pw_hook_deliverToken(wrapper);

    [self assertApp:1 sdk:1];
}

/// Verifies that an NSProxy delegate forwarding to a hooked delegate reaches the app callback and the SDK once each.
- (void)testProxyDelegateForwardingToHookedDelegateDeliversOnce {
    id realDelegate = [pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallback) new];
    pw_hook_setDelegate(realDelegate);
    id proxy = pw_hook_makeProxy(realDelegate);

    pw_hook_setDelegate(proxy);
    pw_hook_deliverToken(proxy);

    [self assertApp:1 sdk:1];
}

#pragma mark - (e) delegate reassigned back and forth

/// Verifies that reassigning the delegate to another class and back adds no second hook and delivers once per token.
- (void)testReassigningDelegateBackAndForthAddsNoHooks {
    Class first = pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallback);
    Class second = pw_hook_makeClass([NSObject class], @"PWHookOtherDelegate", (IMP)pw_hook_appCallback);
    id delegate = [first new];
    pw_hook_setDelegate(delegate);
    IMP hooked = method_getImplementation(class_getInstanceMethod(first, pw_hook_tokenSelector()));

    pw_hook_setDelegate([second new]);
    pw_hook_setDelegate(delegate);
    pw_hook_deliverToken(delegate);

    XCTAssertEqual(method_getImplementation(class_getInstanceMethod(first, pw_hook_tokenSelector())), hooked);
    [self assertApp:1 sdk:1];
}

#pragma mark - (f) two levels of subclasses

/// Verifies that hooking a base class and then its grandchild delivers once each without recursing.
- (void)testHookOnBaseThenGrandchildDeliversOnce {
    Class base = pw_hook_makeClass([NSObject class], @"PWHookBaseDelegate", (IMP)pw_hook_appCallback);
    Class child = pw_hook_makeClass(base, @"PWHookChildDelegate", NULL);
    Class grandchild = pw_hook_makeClass(child, @"PWHookGrandchildDelegate", NULL);
    pw_hook_setDelegate([base new]);
    id delegate = [grandchild new];

    pw_hook_setDelegate(delegate);
    pw_hook_deliverToken(delegate);

    [self assertApp:1 sdk:1];
}

/// Verifies that hooking a grandchild and then its base class delivers once each without recursing.
- (void)testHookOnGrandchildThenBaseDeliversOnce {
    Class base = pw_hook_makeClass([NSObject class], @"PWHookBaseDelegate", (IMP)pw_hook_appCallback);
    Class child = pw_hook_makeClass(base, @"PWHookChildDelegate", NULL);
    Class grandchild = pw_hook_makeClass(child, @"PWHookGrandchildDelegate", NULL);
    id delegate = [grandchild new];
    pw_hook_setDelegate(delegate);

    pw_hook_setDelegate([base new]);
    pw_hook_deliverToken(delegate);

    [self assertApp:1 sdk:1];
}

/// Verifies that an app handing the token to the SDK itself through a grandchild and then base hook leaves the SDK with one delivery.
- (void)testHookOnGrandchildThenBaseWithAppDeliveringTokenItselfDeliversOnce {
    Class base = pw_hook_makeClass([NSObject class], @"PWHookBaseDelegate", (IMP)pw_hook_appCallbackDelivering);
    Class child = pw_hook_makeClass(base, @"PWHookChildDelegate", NULL);
    Class grandchild = pw_hook_makeClass(child, @"PWHookGrandchildDelegate", NULL);
    id delegate = [grandchild new];
    pw_hook_setDelegate(delegate);

    pw_hook_setDelegate([base new]);
    pw_hook_deliverToken(delegate);

    [self assertApp:1 sdk:1];
}

/// Verifies that an app handing the token over on the next main-queue turn through a grandchild and then base hook leaves the SDK with one delivery.
- (void)testHookOnGrandchildThenBaseWithAppDeliveringTokenLaterDeliversOnce {
    Class base = pw_hook_makeClass([NSObject class], @"PWHookBaseDelegate", (IMP)pw_hook_appCallbackDeliveringLater);
    Class child = pw_hook_makeClass(base, @"PWHookChildDelegate", NULL);
    Class grandchild = pw_hook_makeClass(child, @"PWHookGrandchildDelegate", NULL);
    id delegate = [grandchild new];
    pw_hook_setDelegate(delegate);

    pw_hook_setDelegate([base new]);
    pw_hook_deliverToken(delegate);

    [self assertApp:1 sdk:1];
}

/// Verifies that a subclass overriding the callback without calling super still gets the token to the SDK once.
- (void)testSubclassOverridingWithoutSuperGetsAutoDelivery {
    Class base = pw_hook_makeClass([NSObject class], @"PWHookBaseDelegate", (IMP)pw_hook_appCallback);
    Class child = pw_hook_makeClass(base, @"PWHookChildDelegate", (IMP)pw_hook_overrideWithoutSuper);
    pw_hook_setDelegate([base new]);
    id delegate = [child new];

    pw_hook_setDelegate(delegate);
    pw_hook_deliverToken(delegate);

    XCTAssertEqual([pw_hook_calls countForObject:@"override"], 1);
    [self assertApp:0 sdk:1];
}

#pragma mark - (g) no callback anywhere

/// Verifies that a delegate with no token callback in its hierarchy starts answering it and hands the token to the SDK once.
- (void)testClassWithoutCallbackStartsRespondingAndDeliversOnce {
    Class cls = pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", NULL);
    id delegate = [cls new];

    pw_hook_setDelegate(delegate);
    XCTAssertTrue([delegate respondsToSelector:pw_hook_tokenSelector()]);
    pw_hook_deliverToken(delegate);

    [self assertApp:0 sdk:1];
}

#pragma mark - (h) forwarding wrapper, SwiftUI @UIApplicationDelegateAdaptor

/// Verifies that the forwarding wrapper hands the token to the delegate behind it and to the SDK once each.
- (void)testForwardingWrapperReachesDelegateBehindIt {
    pw_hook_forwardingTarget = [pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallback) new];
    id wrapper = [pw_hook_makeForwardingWrapperClass() new];

    pw_hook_setDelegate(wrapper);
    pw_hook_deliverToken(wrapper);

    [self assertApp:1 sdk:1];
}

/// Verifies that the forwarding wrapper with no delegate behind it still hands the token to the SDK once.
- (void)testForwardingWrapperWithNothingBehindItStillDelivers {
    id wrapper = [pw_hook_makeForwardingWrapperClass() new];

    pw_hook_setDelegate(wrapper);
    pw_hook_deliverToken(wrapper);

    [self assertApp:0 sdk:1];
}

/// Verifies that a foreign selector-on-self hook above ours on the forwarding wrapper still reaches the delegate behind it.
- (void)testForwardingWrapperWithForeignSelectorOnSelfReachesDelegateBehindIt {
    pw_hook_forwardingTarget = [pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallback) new];
    Class wrapperClass = pw_hook_makeForwardingWrapperClass();
    id wrapper = [wrapperClass new];
    pw_hook_setDelegate(wrapper);

    pw_hook_foreignSelectorOnSelf(wrapperClass, @"foreign", NO);
    pw_hook_deliverToken(wrapper);

    XCTAssertEqual([pw_hook_calls countForObject:@"foreign"], 1);
    [self assertApp:1 sdk:1];
}

#pragma mark - (i) inherited callback

/// Verifies that a foreign hook put on the base class after ours on the subclass still runs once.
- (void)testInheritedCallbackReplacedOnBaseAfterHookStaysInChain {
    Class base = pw_hook_makeClass([NSObject class], @"PWHookBaseDelegate", (IMP)pw_hook_appCallback);
    Class child = pw_hook_makeClass(base, @"PWHookChildDelegate", NULL);
    id delegate = [child new];
    pw_hook_setDelegate(delegate);

    pw_hook_foreignSetImplementation(base, @"foreign");
    pw_hook_deliverToken(delegate);

    XCTAssertEqual([pw_hook_calls countForObject:@"foreign"], 1);
    [self assertApp:1 sdk:1];
}

#pragma mark - (j) foreign -[UIApplication setDelegate:] hook

/// Verifies that a foreign setDelegate hook running after ours and isa-swizzling the delegate keeps the chain once each.
- (void)testForeignSetDelegateHookAfterOursKeepsChain {
    Class appDelegateClass = pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallback);
    id delegate = [appDelegateClass new];
    pw_hook_setDelegate(delegate);

    Class subclass = pw_hook_makeClass(appDelegateClass, @"PWHookForeignSubclass", NULL);
    XCTAssertTrue(pw_hook_firebaseAddTokenDonor(subclass, appDelegateClass));
    object_setClass(delegate, subclass);
    pw_hook_deliverToken(delegate);

    XCTAssertEqual([pw_hook_calls countForObject:@"donor"], 1);
    [self assertApp:1 sdk:1];
}

/// Verifies that a foreign setDelegate hook running before ours and isa-swizzling the delegate keeps the chain once each.
- (void)testForeignSetDelegateHookBeforeOursKeepsChain {
    Class appDelegateClass = pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallback);
    id delegate = [appDelegateClass new];

    Class subclass = pw_hook_makeClass(appDelegateClass, @"PWHookForeignSubclass", NULL);
    XCTAssertTrue(pw_hook_firebaseAddTokenDonor(subclass, appDelegateClass));
    object_setClass(delegate, subclass);

    pw_hook_setDelegate(delegate);
    pw_hook_deliverToken(delegate);

    XCTAssertEqual([pw_hook_calls countForObject:@"donor"], 1);
    [self assertApp:1 sdk:1];
}

/// Verifies that a foreign setDelegate hook handing us an NSProxy around an unhooked delegate keeps the chain once each.
- (void)testForeignSetDelegateHookWrappingDelegateInProxyKeepsChain {
    id realDelegate = [pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallback) new];
    id proxy = pw_hook_makeProxy(realDelegate);

    pw_hook_setDelegate(proxy);
    pw_hook_deliverToken(proxy);

    [self assertApp:1 sdk:1];
}

#pragma mark - (k) KVO isa subclass hiding behind -class

/// Verifies that a key-value observed delegate is hooked on the class it reports and delivers once each.
- (void)testKeyValueObservedDelegateDeliversOnce {
    Class cls = pw_hook_makeClass([PWHookTestObservable class], @"PWHookObservedDelegate", (IMP)pw_hook_appCallback);
    id delegate = [cls new];
    [delegate addObserver:self forKeyPath:@"value" options:0 context:NULL];
    XCTAssertNotEqual(object_getClass(delegate), cls);

    pw_hook_setDelegate(delegate);
    pw_hook_deliverToken(delegate);
    [delegate removeObserver:self forKeyPath:@"value"];

    [self assertApp:1 sdk:1];
}

#pragma mark - SDK-996 regression

/// Verifies that an app handing the token to the SDK from its callback leaves the SDK with a single delivery.
- (void)testAppDeliveringTokenItselfLeavesSdkWithOneDelivery {
    id delegate = [pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallbackDelivering) new];

    pw_hook_setDelegate(delegate);
    pw_hook_deliverToken(delegate);

    [self assertApp:1 sdk:1];
}

/// Verifies that an app handing the token over on the next main-queue turn leaves the SDK with a single delivery.
- (void)testAppDeliveringTokenOnNextMainQueueTurnLeavesSdkWithOneDelivery {
    id delegate = [pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallbackDeliveringLater) new];

    pw_hook_setDelegate(delegate);
    pw_hook_deliverToken(delegate);

    [self assertApp:1 sdk:1];
}

/// Verifies that with automatic token registration off the app callback still runs and the SDK gets nothing.
- (void)testAutoRegistrationOffLeavesDeliveryToApp {
    pw_hook_autoRegistration = NO;
    id delegate = [pw_hook_makeClass([NSObject class], @"PWHookAppDelegate", (IMP)pw_hook_appCallback) new];

    pw_hook_setDelegate(delegate);
    pw_hook_deliverToken(delegate);

    [self assertApp:1 sdk:0];
}

@end
