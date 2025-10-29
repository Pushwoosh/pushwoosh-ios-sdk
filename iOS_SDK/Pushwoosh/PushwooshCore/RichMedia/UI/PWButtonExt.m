//
//  PWButtonExt.m
//  PushNotificationManager
//
//  Created by User on 24/08/15.
//
//
#if TARGET_OS_IOS || TARGET_OS_WATCH

#import "PWButtonExt.h"

@implementation PWButtonExt

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
	CGRect hitFrame = UIEdgeInsetsInsetRect(self.bounds, self.hitTestEdgeInsets);

	return CGRectContainsPoint(hitFrame, point);
}

@end

#endif
