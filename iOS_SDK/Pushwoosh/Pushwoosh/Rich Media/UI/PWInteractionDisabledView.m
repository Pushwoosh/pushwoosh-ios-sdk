//
//  PushNotificationManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//
#if TARGET_OS_IOS || TARGET_OS_WATCH
#import "PWInteractionDisabledView.h"

@implementation PWInteractionDisabledView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
	UIView *view = [super hitTest:point withEvent:event];
	if (view == self) {
		return nil;
	}
	return view;
}

@end
#endif
