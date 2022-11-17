//
//  PWMessageViewControllerTest.m
//  PushwooshTests
//
//  Created by Fectum on 10/10/2018.
//  Copyright © 2018 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "PWRichMediaManager.h"
#import "PWMessageViewController.ios.h"
#import <objc/runtime.h>
#import "PWRichMediaStyle.h"

@interface PWMessageViewControllerTest : XCTestCase

@property(nonatomic)  PWMessageViewController *messageViewConroller;

@property(nonatomic) XCTestExpectation *expectation;


@end

@interface PWRichMediaAnimatorMock : PWRichMediaAnimator

@property(nonatomic) NSInteger countRunPresentingAnimation;

@property(nonatomic) NSInteger countRunDismissingAnimation;

@end


@implementation PWRichMediaAnimatorMock

- (void)runPresentingAnimationWithCompletion:(dispatch_block_t)completion{
    _countRunPresentingAnimation++;
    completion();
}

- (void)runDismissingAnimationWithCompletion:(dispatch_block_t)completion{
    _countRunDismissingAnimation++;
    completion();
}

@end



@implementation PWMessageViewControllerTest


- (void)setUp {
    PWRichMediaManager *richMediaManager = [PWRichMediaManager new];
    richMediaManager.richMediaStyle.backgroundColor = UIColor.redColor;
    
    PWRichMediaAnimatorMock *animator = [PWRichMediaAnimatorMock new];
    _messageViewConroller = [[PWMessageViewController alloc] initWithRichMedia:nil window:nil richMediaStyle:richMediaManager.richMediaStyle animator:animator completion:nil];
}

- (void)testRunAnimationShouldSetBackgroundColorAfterAnimation {
    [_messageViewConroller.view addObserver:self forKeyPath:@"backgroundColor" options:NSKeyValueObservingOptionNew context:nil];
    
    _expectation = [self expectationWithDescription:@"..."];
    
    SEL selector = NSSelectorFromString(@"runAnimation");
    [_messageViewConroller performSelector:selector];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
        XCTAssertEqual(UIColor.redColor, _messageViewConroller.view.backgroundColor);
    }];
}

- (void)testRunAnimationShouldPresentAnimation{
    SEL selector = NSSelectorFromString(@"runAnimation");
    [_messageViewConroller performSelector:selector];
    
    PWRichMediaAnimatorMock *mock = (id)_messageViewConroller.animator;
    
    XCTAssertEqual(mock.countRunPresentingAnimation, 1);
}

- (void)testRunDismissingAnimation {
    SEL selector = NSSelectorFromString(@"closeController");
    [_messageViewConroller performSelector:selector];
    
    PWRichMediaAnimatorMock *mock = (id)_messageViewConroller.animator;
    
    XCTAssertEqual(mock.countRunDismissingAnimation, 1);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if([keyPath isEqualToString:@"backgroundColor"]){
        [_expectation fulfill];
    }
}

@end
