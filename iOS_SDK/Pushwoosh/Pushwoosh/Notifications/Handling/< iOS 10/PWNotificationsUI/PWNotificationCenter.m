//
//  PWNotificationCenter.m
//  PWNotificationsUI
//
//  Created by Leo Natan on 9/4/14.
//  Copyright (c) 2014 Leo Natan. All rights reserved.
//

#import "PWNotificationCenter.h"
#import "PWNotification.h"
#import "PWNotificationAppSettings_Private.h"
#import "PWNotificationBannerWindow.h"
#import "PWUtils.h"

#import <AVFoundation/AVFoundation.h>
#import <PushwooshCore/PushwooshLog.h>

@interface PWNotificationAlertView : UIAlertView <UIAlertViewDelegate>

@property (nonatomic, retain) PWNotification* alertBackingNotification;

@end

@implementation PWNotificationAlertView

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if(buttonIndex == alertView.cancelButtonIndex)
	{
		return;
	}
	
	if(buttonIndex == alertView.cancelButtonIndex + 1 && self.alertBackingNotification.defaultAction.handler)
	{
		self.alertBackingNotification.defaultAction.handler(self.alertBackingNotification.defaultAction);
	}
	
	if(buttonIndex > alertView.cancelButtonIndex + 1 && [self.alertBackingNotification.otherActions[buttonIndex - 2] handler] != nil)
	{
		PWNotificationAction* action = self.alertBackingNotification.otherActions[buttonIndex - 2];
		action.handler(action);
	}
}

- (void)show
{
	self.delegate = self;
	
	[super show];
}

@end

@interface PWNotification ()

@property (nonatomic, copy) NSString* appIdentifier;
@property (nonatomic, copy) NSDictionary* userInfo;

@end

static PWNotificationCenter* __ln_defaultNotificationCenter;

static NSString *const _PWSettingsKey = @"PWNotificationSettingsKey";

@interface PWNotificationCenter () <UIAlertViewDelegate, AVAudioPlayerDelegate> @end

@implementation PWNotificationCenter
{
	NSMutableDictionary* _applicationMapping;
	NSMutableDictionary* _notificationSettings;
	PWNotificationBannerWindow* _notificationWindow;
	NSMutableArray* _pendingNotifications;
	
	PWNotificationBannerStyle _bannerStyle;
	BOOL _wantsBannerStyleChange;
	
	BOOL _currentlyAnimating;
	
	AVAudioPlayer* _currentAudioPlayer;
	
	id _orientationHandler;
}

+ (instancetype)defaultCenter
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		__ln_defaultNotificationCenter = [PWNotificationCenter new];
	});
	
	return __ln_defaultNotificationCenter;
}

- (instancetype)init
{
	self = [super init];
	
	if(self)
	{
		_applicationMapping = [NSMutableDictionary new];
		_pendingNotifications = [NSMutableArray new];
		
		_notificationSettings = [[[NSUserDefaults standardUserDefaults] valueForKey:_PWSettingsKey] mutableCopy];
		if(_notificationSettings == nil)
		{
			_notificationSettings = [NSMutableDictionary new];
		}
		
		_orientationHandler = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillChangeStatusBarOrientationNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
			
			UIInterfaceOrientation newOrientation = [note.userInfo[UIApplicationStatusBarOrientationUserInfoKey] unsignedIntegerValue];
			
			if([UIDevice currentDevice].orientation == (UIDeviceOrientation)newOrientation)
			{
				return;
			}
		
			//Fix Apple bug of rotations.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            if (TARGET_OS_IOS && ![PWUtils isSystemVersionGreaterOrEqualTo:@"16.0"]) {
                [[UIDevice currentDevice] performSelector:@selector(setOrientation:) withObject:(__bridge id)((void*)[note.userInfo[UIApplicationStatusBarOrientationUserInfoKey] unsignedIntegerValue])];
            }
#pragma clang diagnostic pop
		}];
	}
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:_orientationHandler];
	_orientationHandler = nil;
}

- (PWNotificationBannerStyle)notificationsBannerStyle
{
	return _bannerStyle;
}

- (void)setNotificationsBannerStyle:(PWNotificationBannerStyle)bannerStyle
{
	_bannerStyle = bannerStyle;
	
	//Signal future handling of banner style change.
	_wantsBannerStyleChange = YES;
	
	if(_currentlyAnimating == NO)
	{
		//Handle banner change.
		[self _handleBannerCanChange];
	}
}

- (void)_handleBannerCanChange
{
	if(_wantsBannerStyleChange)
	{
		_notificationWindow.hidden = YES;
		_notificationWindow = nil;
		
		_wantsBannerStyleChange = NO;
	}
}

+ (UIImage *)imageWithColor:(UIColor *)color {
	CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
	UIGraphicsBeginImageContext(rect.size);
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	CGContextSetFillColorWithColor(context, [color CGColor]);
	CGContextFillRect(context, rect);
	
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	
	return image;
}

- (void)registerApplicationWithIdentifier:(NSString*)appIdentifier name:(NSString*)name icon:(UIImage*)icon defaultSettings:(PWNotificationAppSettings *)defaultSettings
{
	NSParameterAssert(appIdentifier != nil);
	NSParameterAssert(name != nil);
	NSParameterAssert(defaultSettings != nil);
	
	if(icon == nil)
	{
		icon = [UIImage imageNamed:@"PWNotificationsUIDefaultAppIcon"];
	}
	
	if(icon == nil)
	{
		icon = [PWNotificationCenter imageWithColor:[UIColor whiteColor]];
	}
	
	_applicationMapping[appIdentifier] = @{PWAppNameKey: name, PWAppIconNameKey: icon};
	if(_notificationSettings[appIdentifier] == nil)
	{
		[self setSettings:defaultSettings enabled:YES forAppIdentifier:appIdentifier];
	}
}

- (void)clearPendingNotificationForApplictionIdentifier:(NSString*)appIdentifier;
{
	[_pendingNotifications filterUsingPredicate:[NSPredicate predicateWithFormat:@"appIdentifier != %@", appIdentifier]];
}

- (void)clearAllPendingNotifications;
{
	[_pendingNotifications removeAllObjects];
}

- (void)presentNotification:(PWNotification*)notification forApplicationIdentifier:(NSString*)appIdentifier
{
	[self presentNotification:notification forApplicationIdentifier:appIdentifier userInfo:nil];
}

- (void)presentNotification:(PWNotification*)notification forApplicationIdentifier:(NSString*)appIdentifier userInfo:(NSDictionary*)userInfo
{
	NSAssert(_applicationMapping[appIdentifier] != nil, @"Unrecognized app identifier: %@. The app must be registered with the notification center before attempting presentation of notifications for it.", appIdentifier);
	NSParameterAssert(notification.message != nil);
	
	if([_notificationSettings[appIdentifier][PWNotificationsDisabledKey] boolValue])
	{
		return;
	}
	
	if([_notificationSettings[appIdentifier][PWAppAlertStyleKey] unsignedIntegerValue] == PWNotificationAlertStyleNone)
	{
		[self _handleSoundForAppId:appIdentifier fileName:notification.soundName];
	}
	else
	{
		PWNotification* pendingNotification = [notification copy];
		
		pendingNotification.title = notification.title ? notification.title : _applicationMapping[appIdentifier][PWAppNameKey];
		pendingNotification.icon = notification.icon ? notification.icon : _applicationMapping[appIdentifier][PWAppIconNameKey];
		pendingNotification.appIdentifier = appIdentifier;
		pendingNotification.userInfo = userInfo;
		
		if([_notificationSettings[appIdentifier][PWAppAlertStyleKey] unsignedIntegerValue] == PWNotificationAlertStyleAlert)
		{
			PWNotificationAlertView* alert = [[PWNotificationAlertView alloc] initWithTitle:pendingNotification.title message:pendingNotification.message delegate:self cancelButtonTitle:NSLocalizedString(@"Close", @"") otherButtonTitles:nil];
			
			if(pendingNotification.defaultAction)
			{
				[alert addButtonWithTitle:pendingNotification.defaultAction.title];
			}
			
			[pendingNotification.otherActions enumerateObjectsUsingBlock:^(PWNotificationAction* alertAction, NSUInteger idx, BOOL *stop) {
				[alert addButtonWithTitle:alertAction.title];
			}];
			
			alert.alertBackingNotification = pendingNotification;
			[alert show];
			[self _handleSoundForAppId:appIdentifier fileName:notification.soundName];
		}
		else
		{
			[_pendingNotifications addObject:pendingNotification];
			
			[self _handlePendingNotifications];
		}
	}
}

- (void)_handlePendingNotifications
{
	if(_notificationWindow == nil)
	{
		_notificationWindow = [[PWNotificationBannerWindow alloc] initWithFrame:[UIScreen mainScreen].bounds style:_bannerStyle];
		
		[_notificationWindow setHidden:NO];
	}
	
	if(_currentlyAnimating)
	{
		return;
	}
	
	_currentlyAnimating = YES;
	
	void(^block)() = ^ {
		_currentlyAnimating = NO;
		
		[self _handleBannerCanChange];
		
		[self _handlePendingNotifications];
	};
	
	if(_pendingNotifications.count == 0)
	{
		if(![_notificationWindow isNotificationViewShown])
		{
			_currentlyAnimating = NO;
			
			//Clean up notification window.
			_notificationWindow.hidden = YES;
			_notificationWindow = nil;
			
			[self _handleBannerCanChange];
			
			return;
		}
		
		[_notificationWindow dismissNotificationViewWithCompletionBlock:block];
	}
	else
	{
		PWNotification* notification = _pendingNotifications.firstObject;
		[_pendingNotifications removeObjectAtIndex:0];
		
		[_notificationWindow presentNotification:notification completionBlock:block];
		
		[self _handleSoundForAppId:notification.appIdentifier fileName:notification.soundName];
	}
}

- (void)_handleSoundForAppId:(NSString*)appId fileName:(NSString*)fileName
{
    if (![_notificationSettings[appId][PWAppSoundsKey] boolValue]) {
        return;
    }
    
    if (![fileName isKindOfClass:[NSString class]] && fileName != nil) {
        [PushwooshLog pushwooshLog:PW_LL_WARN
                         className:self
                           message:[NSString stringWithFormat:@"Sound file name isn't a string class. Sound: %@", fileName]];
        return;
    }
    
    if (fileName == nil || [fileName isEqualToString:@""]) {
        return;
    } else if ([fileName isEqualToString:@"default"]) {
        AudioServicesPlaySystemSound(1007);
    } else {
        NSString *soundFilePath = [NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] resourcePath], fileName];
        NSURL *soundFileURL = [NSURL fileURLWithPath:soundFilePath];
        
        [_currentAudioPlayer stop];
        
        _currentAudioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:soundFileURL error:nil];
        _currentAudioPlayer.delegate = self;
        [_currentAudioPlayer play];
    }
}

- (NSDictionary*)_applicationsMapping
{
	return _applicationMapping;
}

- (NSDictionary*)_notificationSettings
{
	return _notificationSettings;
}

- (void)setSettings:(PWNotificationAppSettings*)settings enabled:(BOOL)enabled forAppIdentifier:(NSString*)appIdentifier
{
	_notificationSettings[appIdentifier] = @{PWAppAlertStyleKey: @(settings.alertStyle), PWNotificationsDisabledKey: @(!enabled), PWAppSoundsKey: @(settings.soundEnabled)};
	
	[[NSUserDefaults standardUserDefaults] setObject:_notificationSettings forKey:_PWSettingsKey];
}

- (void)_setSettingsDictionary:(NSDictionary*)settings forAppIdentifier:(NSString*)appIdentifier
{
	_notificationSettings[appIdentifier] = [settings copy];
	
	[[NSUserDefaults standardUserDefaults] setObject:_notificationSettings forKey:_PWSettingsKey];
}

#pragma mark AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
	[_currentAudioPlayer stop];
	_currentAudioPlayer = nil;
}

@end
