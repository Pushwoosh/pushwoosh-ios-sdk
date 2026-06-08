#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import <objc/message.h>

#import "PWUtils.h"

static id pw_test_originalImp(id self, SEL _cmd) {
    return @"original";
}

static id pw_test_swizzledImp(id self, SEL _cmd) {
    return @"swizzled";
}

static id pw_test_invoke(id obj, SEL sel) {
    return ((id (*)(id, SEL))objc_msgSend)(obj, sel);
}

@interface PWUtilsSwizzleTest : XCTestCase
@end

@implementation PWUtilsSwizzleTest

/// Verifies that swizzle replaces the original implementation and keeps the original reachable under the toSelector.
- (void)testSwizzleReplacesImplementationAndExposesOriginal {
    SEL fooSel = NSSelectorFromString(@"foo");
    SEL pwFooSel = NSSelectorFromString(@"pw_foo");

    Class cls = objc_allocateClassPair([NSObject class], "PWSwizzleTarget_Replace", 0);
    class_addMethod(cls, fooSel, (IMP)pw_test_originalImp, "@@:");
    objc_registerClassPair(cls);

    [PWUtils swizzle:cls
        fromSelector:fooSel
          toSelector:pwFooSel
      implementation:(IMP)pw_test_swizzledImp
        typeEncoding:"@@:"];

    id obj = [cls new];
    XCTAssertEqualObjects(pw_test_invoke(obj, fooSel), @"swizzled");
    XCTAssertEqualObjects(pw_test_invoke(obj, pwFooSel), @"original");
}

/// Verifies that swizzling a method inherited from a superclass does not leak the change to the superclass or its other subclasses.
- (void)testSwizzleDoesNotLeakToSuperclass {
    SEL fooSel = NSSelectorFromString(@"foo");
    SEL pwFooSel = NSSelectorFromString(@"pw_foo");

    Class base = objc_allocateClassPair([NSObject class], "PWSwizzleBase_Leak", 0);
    class_addMethod(base, fooSel, (IMP)pw_test_originalImp, "@@:");
    objc_registerClassPair(base);

    Class child = objc_allocateClassPair(base, "PWSwizzleChild_Leak", 0);
    objc_registerClassPair(child);

    Class sibling = objc_allocateClassPair(base, "PWSwizzleSibling_Leak", 0);
    objc_registerClassPair(sibling);

    [PWUtils swizzle:child
        fromSelector:fooSel
          toSelector:pwFooSel
      implementation:(IMP)pw_test_swizzledImp
        typeEncoding:"@@:"];

    XCTAssertEqualObjects(pw_test_invoke([child new], fooSel), @"swizzled");
    XCTAssertEqualObjects(pw_test_invoke([sibling new], fooSel), @"original");
    XCTAssertEqualObjects(pw_test_invoke([base new], fooSel), @"original");
}

/// Verifies that when the class has no original method, swizzle simply installs the implementation under the fromSelector.
- (void)testSwizzleInstallsImplementationWhenOriginalAbsent {
    SEL fooSel = NSSelectorFromString(@"foo");
    SEL pwFooSel = NSSelectorFromString(@"pw_foo");

    Class cls = objc_allocateClassPair([NSObject class], "PWSwizzleTarget_Absent", 0);
    objc_registerClassPair(cls);

    [PWUtils swizzle:cls
        fromSelector:fooSel
          toSelector:pwFooSel
      implementation:(IMP)pw_test_swizzledImp
        typeEncoding:"@@:"];

    XCTAssertEqualObjects(pw_test_invoke([cls new], fooSel), @"swizzled");
}

@end
