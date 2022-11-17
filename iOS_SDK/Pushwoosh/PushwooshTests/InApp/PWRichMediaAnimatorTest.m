//
//  PWRichMediaAnimatorTest.m
//  PushwooshTests
//
//  Created by Fectum on 10/10/2018.
//  Copyright © 2018 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "PWRichMediaAnimator.h"

@interface PWRichMediaAnimatorTest : XCTestCase

@property (nonatomic) PWRichMediaAnimator *animator;

@property (nonatomic) UIView *view;
@property (nonatomic) UIView *parentView;

@end

@implementation PWRichMediaAnimatorTest

- (void)setUp {
    _view  = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    _parentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];

}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testAnimaytionBottom {
    [self prepareAnimatorForAnimationType:PWRichMediaStyleAnimationTypeSlideBottom];
    [_animator initialState];
    BOOL result = CGAffineTransformEqualToTransform(CGAffineTransformMakeTranslation(0, 100), _view.transform);
    XCTAssertTrue(result);
}

- (void)testAnimaytionTop {
    [self prepareAnimatorForAnimationType:PWRichMediaStyleAnimationTypeSlideTop];
    [_animator initialState];
    BOOL result = CGAffineTransformEqualToTransform(CGAffineTransformMakeTranslation(0, -100), _view.transform);
    XCTAssertTrue(result);
}

- (void)testAnimaytionLeft {
    [self prepareAnimatorForAnimationType:PWRichMediaStyleAnimationTypeSlideLeft];
    [_animator initialState];
    BOOL result = CGAffineTransformEqualToTransform(CGAffineTransformMakeTranslation(-100,0), _view.transform);
    XCTAssertTrue(result);
}

- (void)testAnimaytionRight {
    [self prepareAnimatorForAnimationType:PWRichMediaStyleAnimationTypeSlideRight];
    [_animator initialState];
    BOOL result = CGAffineTransformEqualToTransform(CGAffineTransformMakeTranslation(100,0), _view.transform);
    XCTAssertTrue(result);
}

- (void)prepareAnimatorForAnimationType: (PWRichMediaStyleAnimationType) type{
    _animator = [PWRichMediaAnimator new];
    _animator.view = _view;
    _animator.parentView = _parentView;
    PWRichMediaStyle *style = [PWRichMediaStyle new];
    style.animationType = type;
    _animator.style = style;
}

- (void) testFinalState{
    [self prepareAnimatorForAnimationType:PWRichMediaStyleAnimationTypeSlideLeft];

    [_animator initialState];
    [_animator finalState];

    BOOL result = CGAffineTransformEqualToTransform(CGAffineTransformIdentity, _view.transform);
    XCTAssertTrue(result);
}

- (void)testPresentingAnimation {
    [self prepareAnimatorForAnimationType:PWRichMediaStyleAnimationTypeSlideBottom];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"..."];
    
    [_animator runPresentingAnimationWithCompletion:^{
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
        BOOL result = CGAffineTransformEqualToTransform(CGAffineTransformIdentity, _view.transform);
        XCTAssertTrue(result);
    }];
}

- (void)testDissmissingAnimation {
    [self prepareAnimatorForAnimationType:PWRichMediaStyleAnimationTypeSlideBottom];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"..."];
    
    [_animator runDismissingAnimationWithCompletion:^{
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
        BOOL result = CGAffineTransformEqualToTransform(CGAffineTransformMakeTranslation(0, 100), _view.transform);
        XCTAssertTrue(result);
    }];
}

- (void)testPresentingCustomAnimation {
    __block NSInteger countCallAnimationBlock;
    __block NSInteger countCallCompletion;
     [self prepareAnimatorForAnimationType:PWRichMediaStyleAnimationTypeCustom];
    _animator.style.customPresentingAnimationBlock = ^(UIView * _Nonnull parentView, UIView * _Nonnull contentView, dispatch_block_t completion) {
        XCTAssertEqual(_view, contentView);
        XCTAssertEqual(_parentView, parentView);
        completion();
        countCallAnimationBlock++;
    };
    [_animator runPresentingAnimationWithCompletion:^{
        countCallCompletion++;
    }];
    XCTAssertEqual(1, countCallAnimationBlock);
    XCTAssertEqual(1, countCallCompletion);
}


- (void)testDissmissingCustomAnimation{
    __block NSInteger countCallAnimationBlock;
    __block NSInteger countCallCompletion;
    [self prepareAnimatorForAnimationType:PWRichMediaStyleAnimationTypeCustom];
    _animator.style.customDismissingAnimationBlock = ^(UIView * _Nonnull parentView, UIView * _Nonnull contentView, dispatch_block_t completion) {
        XCTAssertEqual(_view, contentView);
        XCTAssertEqual(_parentView, parentView);
        completion();
        countCallAnimationBlock++;
    };
    [_animator runDismissingAnimationWithCompletion:^{
        countCallCompletion++;
    }];
    XCTAssertEqual(1, countCallAnimationBlock);
    XCTAssertEqual(1, countCallCompletion);
}

@end
