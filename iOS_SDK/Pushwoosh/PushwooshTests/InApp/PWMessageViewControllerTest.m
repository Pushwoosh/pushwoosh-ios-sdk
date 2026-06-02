#import <XCTest/XCTest.h>
#import "PWRichMediaManager.h"
#import "PWMessageViewController.ios.h"
#import <objc/runtime.h>
#import "PWRichMediaStyle.h"

@interface PWMessageViewControllerTest : XCTestCase

@property (nonatomic) PWMessageViewController *messageViewController;
@property (nonatomic) XCTestExpectation *expectation;

@end

@interface PWRichMediaAnimatorMock : PWRichMediaAnimator

@property (nonatomic) NSInteger countRunPresentingAnimation;
@property (nonatomic) NSInteger countRunDismissingAnimation;

@end

@implementation PWRichMediaAnimatorMock

- (void)runPresentingAnimationWithCompletion:(dispatch_block_t)completion {
    _countRunPresentingAnimation++;
    completion();
}

- (void)runDismissingAnimationWithCompletion:(dispatch_block_t)completion {
    _countRunDismissingAnimation++;
    completion();
}

@end

@implementation PWMessageViewControllerTest

- (void)setUp {
    [super setUp];
    PWRichMediaManager *richMediaManager = [PWRichMediaManager new];
    richMediaManager.richMediaStyle.backgroundColor = UIColor.redColor;

    PWRichMediaAnimatorMock *animator = [PWRichMediaAnimatorMock new];
    _messageViewController = [[PWMessageViewController alloc] initWithRichMedia:nil window:nil richMediaStyle:richMediaManager.richMediaStyle animator:animator completion:nil];
}

/// Verifies that the view's backgroundColor is applied from the rich-media style after the presenting animation completes.
- (void)testRunAnimationShouldSetBackgroundColorAfterAnimation {
    [_messageViewController.view addObserver:self forKeyPath:@"backgroundColor" options:NSKeyValueObservingOptionNew context:nil];

    _expectation = [self expectationWithDescription:@"backgroundColor applied"];

    SEL selector = NSSelectorFromString(@"runAnimation");
    [_messageViewController performSelector:selector];

    [self waitForExpectationsWithTimeout:2 handler:^(NSError *error) {
        XCTAssertEqualObjects(UIColor.redColor, _messageViewController.view.backgroundColor);
    }];

    [_messageViewController.view removeObserver:self forKeyPath:@"backgroundColor"];
}

/// Verifies that runAnimation invokes the animator's presenting routine exactly once.
- (void)testRunAnimationShouldPresentAnimation {
    SEL selector = NSSelectorFromString(@"runAnimation");
    [_messageViewController performSelector:selector];

    PWRichMediaAnimatorMock *mock = (id)_messageViewController.animator;

    XCTAssertEqual(mock.countRunPresentingAnimation, 1);
}

/// Verifies that closeController invokes the animator's dismissing routine exactly once.
- (void)testRunDismissingAnimation {
    SEL selector = NSSelectorFromString(@"closeController");
    [_messageViewController performSelector:selector];

    PWRichMediaAnimatorMock *mock = (id)_messageViewController.animator;

    XCTAssertEqual(mock.countRunDismissingAnimation, 1);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"backgroundColor"]) {
        [_expectation fulfill];
    }
}

@end
