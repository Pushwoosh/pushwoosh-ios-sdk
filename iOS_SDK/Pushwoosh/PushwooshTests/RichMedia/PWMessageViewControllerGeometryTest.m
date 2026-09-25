#import <XCTest/XCTest.h>
#import "PWMessageViewController.h"
#import "PWResource.h"

@interface PWMessageViewController (GeometryTest)
+ (CGFloat)originYForPresentationStyle:(IAResourcePresentationStyle)style
                         contentHeight:(CGFloat)contentHeight
                       containerHeight:(CGFloat)containerHeight;
@end

@interface PWMessageViewControllerGeometryTest : XCTestCase
@end

@implementation PWMessageViewControllerGeometryTest

/// Verifies that Center style positions content vertically centered in the container.
- (void)testOriginYForCenterStyleCentersContent {
    CGFloat originY = [PWMessageViewController originYForPresentationStyle:IAResourcePresentationCenter
                                                             contentHeight:200.0
                                                           containerHeight:800.0];

    XCTAssertEqualWithAccuracy(originY, 300.0, 0.001);
}

/// Verifies that BottomBanner style pins content to the bottom edge of the container.
- (void)testOriginYForBottomBannerStylePinsContentToBottom {
    CGFloat originY = [PWMessageViewController originYForPresentationStyle:IAResourcePresentationBottomBanner
                                                             contentHeight:200.0
                                                           containerHeight:800.0];

    XCTAssertEqualWithAccuracy(originY, 600.0, 0.001);
}

/// Verifies that styles other than Center and BottomBanner keep the content at the top of the container.
- (void)testOriginYForFullScreenStyleReturnsZero {
    CGFloat originY = [PWMessageViewController originYForPresentationStyle:IAResourcePresentationFullScreen
                                                             contentHeight:200.0
                                                           containerHeight:800.0];

    XCTAssertEqualWithAccuracy(originY, 0.0, 0.001);
}

@end
