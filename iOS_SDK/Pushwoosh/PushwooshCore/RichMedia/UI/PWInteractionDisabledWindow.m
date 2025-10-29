//
//  PWInteractionDisabledWindow.m
//  PushNotificationManager
//
//  Created by Ilya Kuznecov on 17/08/15.
//
//
#if TARGET_OS_IOS || TARGET_OS_WATCH
#import "PWInteractionDisabledWindow.h"

@implementation PWInteractionDisabledWindow

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
	UIView *view = [super hitTest:point withEvent:event];
	if (view == self) {
		return nil;
	}
	return view;
}

@end
#endif
