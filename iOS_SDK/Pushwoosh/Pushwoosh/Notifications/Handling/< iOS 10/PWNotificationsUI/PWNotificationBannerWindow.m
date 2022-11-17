//
//  PWNotificationBannerWindow.m
//  PWNotificationsUI
//
//  Created by Leo Natan on 9/5/14.
//  Copyright (c) 2014 Leo Natan. All rights reserved.
//

#import "PWNotificationBannerWindow.h"
#import "PWNotification.h"
#import "PWNotificationBannerView.h"
#import "PWNotificationCenter.h"

static const NSTimeInterval PWNotificationAnimationDuration = 0.5;
static const NSTimeInterval PWNotificationFullDuration = 5.0;
static const NSTimeInterval PWNotificationCutOffDuration = 2.5;

static const CGFloat PWNotificationViewHeight = 68.0;

@interface PWNotification ()

@property (nonatomic, copy) NSDictionary* userInfo;

@end

@interface PWNotificationBannerWindow ()

@property (nonatomic) BOOL ignoresAddedConstraints;

@end

@interface _PWWindowSizedView : UIView @end
@implementation _PWWindowSizedView

- (void)didMoveToWindow
{
	if(self.window == nil)
	{
		return;
	}
	
	self.translatesAutoresizingMaskIntoConstraints = NO;
	
	BOOL oldVal = [(PWNotificationBannerWindow*)self.window ignoresAddedConstraints];
	[(PWNotificationBannerWindow*)self.window setIgnoresAddedConstraints:NO];
	
	[self.window addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|" options:0 metrics:nil views:@{@"view": self}]];
	[self.window addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|" options:0 metrics:nil views:@{@"view": self}]];
	
	[(PWNotificationBannerWindow*)self.window setIgnoresAddedConstraints:oldVal];
}

@end

@interface _PWStatusBarStylePreservingViewController : UIViewController @end
@implementation _PWStatusBarStylePreservingViewController

- (void)loadView
{
	self.view = [_PWWindowSizedView new];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
	return [[UIApplication sharedApplication] statusBarStyle];
}

@end

@implementation PWNotificationBannerWindow
{
	PWNotificationBannerView* _notificationView;
	UIView* _swipeView;
	BOOL _notificationViewShown;
	NSDate* _lastShowDate;
	UISwipeGestureRecognizer* _sgr;
	UITapGestureRecognizer* _tgr;
	
	NSLayoutConstraint* _topConstraint;
	
	void (^_pendingCompletionHandler)();
}

- (instancetype)initWithFrame:(CGRect)frame
{
	return [self initWithFrame:frame style:PWNotificationBannerStyleDark];
}

- (instancetype)initWithFrame:(CGRect)frame style:(PWNotificationBannerStyle)bannerStyle
{
	self = [super initWithFrame:frame];
	
	if(self)
	{
		_notificationView = [[PWNotificationBannerView alloc] initWithFrame:self.bounds style:bannerStyle];
		_notificationView.translatesAutoresizingMaskIntoConstraints = NO;
		
		self.backgroundColor = [[UIColor greenColor] colorWithAlphaComponent:0.0];

		UIViewController* vc = [_PWStatusBarStylePreservingViewController new];
		[vc.view addSubview:_notificationView];
		
		[vc.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_notificationView]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_notificationView)]];

		_topConstraint = [NSLayoutConstraint constraintWithItem:_notificationView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:vc.view attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0];
		
		[vc.view addConstraint:_topConstraint];
		[vc.view addConstraint:[NSLayoutConstraint constraintWithItem:_notificationView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeHeight multiplier:1.0 constant:PWNotificationViewHeight]];
		
		_topConstraint.constant = -PWNotificationViewHeight;
		
		_swipeView = [UIView new];
		_swipeView.translatesAutoresizingMaskIntoConstraints = NO;
		
		[vc.view addSubview:_swipeView];
		[vc.view sendSubviewToBack:_swipeView];
		
		_sgr = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(_dismissFromSwipe)];
		_sgr.direction = UISwipeGestureRecognizerDirectionUp;
		[_swipeView addGestureRecognizer:_sgr];
		
		_tgr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_userTappedNotification)];
		[_swipeView addGestureRecognizer:_tgr];
		
		[vc.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_swipeView]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_swipeView)]];
		[vc.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_swipeView(68)]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_swipeView)]];
		
		[self setRootViewController:vc];
		
		self.windowLevel = UIWindowLevelAlert + 2000;
	}
	
	return self;
}

- (BOOL)isNotificationViewShown
{
	return _notificationViewShown;
}

- (void)presentNotification:(PWNotification *)notification completionBlock:(void (^)())completionBlock
{
	NSDate* targetDate;
 
	if(_lastShowDate == nil)
	{
		targetDate = [NSDate date];
	}
	else
	{
		targetDate = [_lastShowDate dateByAddingTimeInterval:PWNotificationCutOffDuration];
	}
	
	NSTimeInterval delay = [targetDate timeIntervalSinceDate:[NSDate date]];
	if(delay < 0)
	{
		delay = 0;
	}
	
	if(!_notificationViewShown)
	{
		[_notificationView configureForNotification:notification];
		
		_topConstraint.constant = -PWNotificationViewHeight;
		[self layoutIfNeeded];
		
		[UIView animateWithDuration:PWNotificationAnimationDuration delay:delay usingSpringWithDamping:500 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
			_topConstraint.constant = 0;
			[self layoutIfNeeded];
		} completion:^(BOOL finished) {
			_lastShowDate = [NSDate date];
			_notificationViewShown = YES;
			
			_pendingCompletionHandler = completionBlock;
			
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(PWNotificationCutOffDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				if(_pendingCompletionHandler)
				{
					void (^prevPendingCompletionHandler)() = _pendingCompletionHandler;
					_pendingCompletionHandler = nil;
					prevPendingCompletionHandler();
				}
			});
		}];
	}
	else
	{
		UIView* snapshot = [_notificationView.notificationContentView snapshotViewAfterScreenUpdates:NO];
		
		__block CGRect frame = _notificationView.notificationContentView.frame;
		frame.origin.y = -frame.size.height;
		_notificationView.notificationContentView.frame = frame;
		[_notificationView configureForNotification:notification];
		
		[_notificationView.notificationContentView.superview insertSubview:snapshot belowSubview:_notificationView.notificationContentView];
		
		
		
		[UIView animateWithDuration:0.75 * PWNotificationAnimationDuration delay:delay usingSpringWithDamping:500 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
			frame.origin.y = 0;
			_notificationView.notificationContentView.frame = frame;
			snapshot.alpha = 0;
		} completion:^(BOOL finished) {
			[snapshot removeFromSuperview];
			_lastShowDate = [NSDate date];
			
			_pendingCompletionHandler = completionBlock;
			
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(PWNotificationCutOffDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				if(_pendingCompletionHandler)
				{
					void (^prevPendingCompletionHandler)() = _pendingCompletionHandler;
					_pendingCompletionHandler = nil;
					prevPendingCompletionHandler();
				}
			});
		}];
	}
}

- (void)dismissNotificationViewWithCompletionBlock:(void (^)())completionBlock
{
	[self _dismissNotificationViewWithCompletionBlock:completionBlock force:NO];
}

- (void)_dismissNotificationViewWithCompletionBlock:(void (^)())completionBlock force:(BOOL)forced
{
	if(_notificationViewShown == NO)
	{
		return;
	}
	
	NSDate* targetDate = [_lastShowDate dateByAddingTimeInterval:PWNotificationFullDuration];
	
	NSTimeInterval delay = [targetDate timeIntervalSinceDate:[NSDate date]];
	
	if(forced == YES)
	{
		delay = 0;
	}
	
	[_notificationView.layer removeAllAnimations];
	
	_pendingCompletionHandler = completionBlock;
	
	_topConstraint.constant = 0;
	[self layoutIfNeeded];
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		_notificationViewShown = NO;
	});
	
	[UIView animateWithDuration:PWNotificationAnimationDuration delay:delay usingSpringWithDamping:500 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
		_topConstraint.constant = -PWNotificationViewHeight;
		[self layoutIfNeeded];
	} completion:^(BOOL finished) {
		_lastShowDate = nil;
		_notificationViewShown = NO;
		[_notificationView configureForNotification:nil];
		
		if(_pendingCompletionHandler)
		{
			void (^prevPendingCompletionHandler)() = _pendingCompletionHandler;
			_pendingCompletionHandler = nil;
			prevPendingCompletionHandler();
		}
	}];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
	UIView* rv = [super hitTest:point withEvent:event];
	
	if(rv == self || rv == self.rootViewController.view)
	{
		return nil;
	}
	
	if(rv == _swipeView && _notificationViewShown == NO)
	{
		return nil;
	}
	
	return rv;
}

- (void)_dismissFromSwipe
{
	[self _dismissNotificationViewWithCompletionBlock:_pendingCompletionHandler force:YES];
}

- (void)_userTappedNotification
{
	[self _dismissNotificationViewWithCompletionBlock:_pendingCompletionHandler force:YES];
	
	if(_notificationView.currentNotification != nil && _notificationView.currentNotification.defaultAction.handler != nil)
	{
		_notificationView.currentNotification.defaultAction.handler(_notificationView.currentNotification.defaultAction);
	}
}

- (void)setHidden:(BOOL)hidden
{
	self.ignoresAddedConstraints = YES;
	
	[super setHidden:hidden];
	
	self.ignoresAddedConstraints = NO;
}

- (void)addConstraint:(NSLayoutConstraint *)constraint
{
	if(self.ignoresAddedConstraints)
	{
		return;
	}
	
	[super addConstraint:constraint];
}

@end
