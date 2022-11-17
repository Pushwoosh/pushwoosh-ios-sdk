//
//  PushRuntime.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import <objc/runtime.h>
#import <objc/message.h>

#import "PWPushRuntime.ios.h"
#import "Pushwoosh+Internal.h"
#import "PWConfig.h"
#import "PWPreferences.h"
#import "PWInteractivePush.h"
#import "PWUtils.h"
#import "PWPlatformModule.h"
#import "PWNotificationManagerCompat.h"

#if !__has_feature(objc_arc)
#error "ARC is required to compile Pushwoosh SDK"
#endif

static IMP pw_original_setApplicationIconBadgeNumber_Imp;
static IMP pw_original_registerForRemoteNotifications_Imp;

@interface UIApplication (PushwooshRuntime)
- (void)application:(UIApplication *)application pw_didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)devToken;
- (void)application:(UIApplication *)application pw_didFailToRegisterForRemoteNotificationsWithError:(NSError *)err;
- (void)application:(UIApplication *)application pw_didReceiveRemoteNotification:(NSDictionary *)userInfo;
- (void)application:(UIApplication *)application pw_didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

- (BOOL)application:(UIApplication *)application pw_didFinishLaunchingWithOptions:(NSDictionary *)launchOptions;
- (BOOL)application:(UIApplication *)application pw_openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation;
- (BOOL)application:(UIApplication *)application pw_openURL:(NSURL *)url options:(NSDictionary<NSString *, id> *)options;
- (BOOL)application:(UIApplication *)application pw_handleOpenURL:(NSURL *)url;

- (NSObject<PushNotificationDelegate> *)getPushwooshDelegate;
- (BOOL)pushwooshUseRuntimeMagic;  //use runtime to handle default push notifications callbacks (used in plugins)
- (BOOL)application:(UIApplication *)application pw_didFinishLaunchingWithOptionsAutoTest:(NSDictionary *)launchOptions;
- (BOOL)application:(UIApplication *)application pw_didRegisterUserNotificationSettings:(UIUserNotificationSettings *)settings;

- (void)scene:(id)scene pw_openURLContexts:(NSSet<id> *)URLContexts;

@end

@implementation UIApplication (Pushwoosh)

//auto test that simulates push notification on start
BOOL dynamicDidFinishLaunchingAutoTest(id self, SEL _cmd, id application, id launchOptions) {
	//create test push payload if we are self testing
	if ([PWPushRuntime isSelfTestEnabled]) {
		NSMutableDictionary *launchOpts = [NSMutableDictionary new];
		NSMutableDictionary *apsDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"Alert!", @"alert", @"sound", @"default", nil];
		NSMutableDictionary *startPush = [NSMutableDictionary dictionaryWithObjectsAndKeys:apsDict, @"aps", @"0", @"p", nil];

		launchOpts[UIApplicationLaunchOptionsRemoteNotificationKey] = startPush;
		launchOptions = launchOpts;
	}

	return [self application:application pw_didFinishLaunchingWithOptionsAutoTest:launchOptions];
}

BOOL dynamicDidFinishLaunching(id self, SEL _cmd, id application, id launchOptions) {
	BOOL result = YES;

	if ([self respondsToSelector:@selector(application:pw_didFinishLaunchingWithOptions:)]) {
		result = (BOOL)[self application:application pw_didFinishLaunchingWithOptions:launchOptions];
	} else {
		[self applicationDidFinishLaunching:application];
		result = YES;
	}

	if (![[PWPreferences preferences] hasAppCode]) {
		// pushwoosh has not been initialized yet
		return result;
	}

	if (![PushNotificationManager pushManager].delegate) {
		if ([[UIApplication sharedApplication] respondsToSelector:@selector(getPushwooshDelegate)]) {
			[PushNotificationManager pushManager].delegate = [[UIApplication sharedApplication] getPushwooshDelegate];
		} else {
			[PushNotificationManager pushManager].delegate = (NSObject<PushNotificationDelegate> *)self;
		}
	}

    if (![UNUserNotificationCenter currentNotificationCenter].delegate) {
        //this function will also handle UIApplicationLaunchOptionsLocationKey
        [[PushNotificationManager pushManager] handlePushReceived:launchOptions];
    }
	
	return result;
}

void dynamicDidRegisterForRemoteNotificationsWithDeviceToken(id self, SEL _cmd, id application, id devToken) {
	if ([self respondsToSelector:@selector(application:pw_didRegisterForRemoteNotificationsWithDeviceToken:)]) {
		[self application:application pw_didRegisterForRemoteNotificationsWithDeviceToken:devToken];
	}
    
	if ([[PWPreferences preferences] hasAppCode]) {
		[[PushNotificationManager pushManager] handlePushRegistration:devToken];
	}
}

void dynamicDidFailToRegisterForRemoteNotificationsWithError(id self, SEL _cmd, id application, id error) {
	if ([self respondsToSelector:@selector(application:pw_didFailToRegisterForRemoteNotificationsWithError:)]) {
		[self application:application pw_didFailToRegisterForRemoteNotificationsWithError:error];
	}

	PWLogError(@"Error registering for push notifications. Error: %@", error);

	if ([[PWPreferences preferences] hasAppCode]) {
		[[PushNotificationManager pushManager] handlePushRegistrationFailure:error];
	}
}

void dynamicDidReceiveRemoteNotification(id self, SEL _cmd, id application, id userInfo) {
	if ([self respondsToSelector:@selector(application:pw_didReceiveRemoteNotification:)]) {
		[self application:application pw_didReceiveRemoteNotification:userInfo];
	}

	if ([[PWPreferences preferences] hasAppCode]) {
		[[PushNotificationManager pushManager] handlePushReceived:userInfo];
	}
}

void dynamicDidReceiveRemoteNotificationWithFetch(id self, SEL _cmd, id application, id userInfo, void (^completionHandler)(UIBackgroundFetchResult)) {
	if ([self respondsToSelector:@selector(application:pw_didReceiveRemoteNotification:fetchCompletionHandler:)]) {
		[self application:application pw_didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
	}

	if ([[PWPreferences preferences] hasAppCode]) {
		[[PushNotificationManager pushManager] handlePushReceived:userInfo];
	}
	
	completionHandler(UIBackgroundFetchResultNewData);
}

BOOL dynamicOpenURLSourceApplicationAnnotation(id self, SEL _cmd, id application, id openURL, id sourceApplication, id annotation) {
	if ([application pw_checkURL:openURL])
		return YES;

	if ([self respondsToSelector:@selector(application:pw_openURL:sourceApplication:annotation:)]) {
		return [self application:application pw_openURL:openURL sourceApplication:sourceApplication annotation:annotation];
	}
	return NO;
}

BOOL dynamicOpenURLOptions(id self, SEL _cmd, id application, id openURL, id options) {
	if ([application pw_checkURL:openURL])
		return YES;

	if ([self respondsToSelector:@selector(application:pw_openURL:options:)]) {
		return [self application:application pw_openURL:openURL options:options];
	}
	return NO;
}

BOOL dynamicHandleOpenURL(id self, SEL _cmd, id application, id openURL) {
	if ([application pw_checkURL:openURL])
		return YES;

	if ([self respondsToSelector:@selector(application:pw_handleOpenURL:)]) {
		return [self application:application pw_handleOpenURL:openURL];
	}
	return NO;
}

void dynamicSceneOpenURLContexts(id self, SEL _cmd, id scene, id contexts) {
    if ([contexts isKindOfClass:[NSSet class]]) {
        id context = [contexts anyObject];
        
        if ([context respondsToSelector:@selector(URL)]) {
            NSURL *url = [context URL];
            
            if (url) {
                [[UIApplication sharedApplication] pw_checkURL:url];
            }
        }
    }

    if ([self respondsToSelector:@selector(scene:pw_openURLContexts:)]) {
        [self scene:scene pw_openURLContexts:contexts];
    }
}

- (BOOL)pw_checkURL:(NSURL *)url {
	return [PWUtils handleURL:url];
}

static BOOL openURLSwizzled = NO;


- (void)pw_swizzleOpenURLMethods:(Class)delegateClass {
    if (delegateClass == NULL)
        return;
    if (openURLSwizzled)
        return;
    openURLSwizzled = YES;
	if ([delegateClass instancesRespondToSelector:@selector(application:openURL:options:)]) {
		[PWUtils swizzle:delegateClass
			  fromSelector:@selector(application:openURL:options:)
				toSelector:@selector(application:pw_openURL:options:)
			implementation:(IMP)dynamicOpenURLOptions
			  typeEncoding:"v@:::::"];
	}
	if ([delegateClass instancesRespondToSelector:@selector(application:openURL:sourceApplication:annotation:)]) {
		[PWUtils swizzle:delegateClass
			  fromSelector:@selector(application:openURL:sourceApplication:annotation:)
				toSelector:@selector(application:pw_openURL:sourceApplication:annotation:)
			implementation:(IMP)dynamicOpenURLSourceApplicationAnnotation
			  typeEncoding:"v@:::::"];
	}
	[PWUtils swizzle:delegateClass
		  fromSelector:@selector(application:handleOpenURL:)
			toSelector:@selector(application:pw_handleOpenURL:)
		implementation:(IMP)dynamicHandleOpenURL
		  typeEncoding:"v@:::::"];
    
    //Scene environment support
    NSDictionary *sceneManifest = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIApplicationSceneManifest"];
    
    if ([sceneManifest isKindOfClass:[NSDictionary class]]) {
        NSDictionary *configs = sceneManifest[@"UISceneConfigurations"];
        
        if ([configs isKindOfClass:[NSDictionary class]]) {
            NSArray *sessionRole = configs[@"UIWindowSceneSessionRoleApplication"];
            
            if ([sessionRole isKindOfClass:[NSArray class]]) {
                NSDictionary *config = sessionRole.firstObject;
                
                if ([config isKindOfClass:[NSDictionary class]]) {
                    NSString *sceneDelegateClassName = config[@"UISceneDelegateClassName"];
                    
                    if (sceneDelegateClassName) {
                        Class sceneDelegateClass = NSClassFromString(sceneDelegateClassName);
                        
                        [PWUtils swizzle:sceneDelegateClass
                            fromSelector:@selector(scene:openURLContexts:)
                              toSelector:@selector(scene:pw_openURLContexts:)
                          implementation:(IMP)dynamicSceneOpenURLContexts
                            typeEncoding:"v@:::"];
                    }
                }
            }
        }
    }
}

- (void)performSwizzlingForDelegate:(id<UIApplicationDelegate>)delegate proxy:(id<UIApplicationDelegate>)proxy {
    BOOL useRuntime = [PWConfig config].useRuntime;

    if (delegate.superclass == NSProxy.class) {
        @try {
            NSString *propertyName = @"delegates";
            objc_property_t property = class_getProperty(delegate.class, [propertyName cStringUsingEncoding:NSASCIIStringEncoding]);
            
            if (property) {
                SEL getter = NSSelectorFromString(propertyName);
                NSArray *delegates = ((NSArray *(*)(id, SEL))objc_msgSend)(delegate, getter);
                
                if ([delegates isKindOfClass:[NSArray class]]) {
                    id <UIApplicationDelegate> realDelegate = delegates.firstObject;
                    
                    for (id <UIApplicationDelegate>candidateDelegate in delegates) {
                        if ([candidateDelegate conformsToProtocol:@protocol(UIApplicationDelegate)]) {
                            if ([candidateDelegate respondsToSelector:@selector(application:openURL:options:)] ||
                                [candidateDelegate respondsToSelector:@selector(application:handleOpenURL:)] ||
                                [candidateDelegate respondsToSelector:@selector(application:openURL:sourceApplication:annotation:)] ) {
                                realDelegate = candidateDelegate;
                                break;
                            }
                        }
                    }
                    
                    if (realDelegate) {
                        [self performSwizzlingForDelegate:realDelegate proxy:delegate];
                        return;
                    }
                }
            }
        } @catch (NSException *exception) {
            NSLog(@"");
            NSLog(@"!!!!!!-----Exception caused by AppDelegate proxy: %@-----!!!!!!", exception);
            NSLog(@"");
        }
    }
    
    //override runtime functions only if requested (used in plugins or by user decision)
    if (![[UIApplication sharedApplication] respondsToSelector:@selector(pushwooshUseRuntimeMagic)] && !useRuntime) {
        //auto test check
        if ([PWPushRuntime isSelfTestEnabled]) {
            [PWUtils swizzle:[delegate class]
                  fromSelector:@selector(application:didFinishLaunchingWithOptions:)
                    toSelector:@selector(application:pw_didFinishLaunchingWithOptionsAutoTest:)
                implementation:(IMP)dynamicDidFinishLaunchingAutoTest
                  typeEncoding:"v@:::"];
        }

        [self pw_swizzleOpenURLMethods:[delegate class]];

        [self pw_setDelegate:proxy ? : delegate];
        return;
    }
    
    static BOOL swizzleDone = NO;
    
    //do not swizzle twice
    if (swizzleDone || delegate == nil) {
        [self pw_setDelegate:proxy ? : delegate];
        return;
    }
    
    swizzleDone = YES;
    
    Class delegateClass = [delegate class];
    
    [PWUtils swizzle:delegateClass
        fromSelector:@selector(application:didFinishLaunchingWithOptions:)
          toSelector:@selector(application:pw_didFinishLaunchingWithOptions:)
      implementation:(IMP)dynamicDidFinishLaunching
        typeEncoding:"v@:::"];
    
    [PWUtils swizzle:delegateClass
        fromSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)
          toSelector:@selector(application:pw_didRegisterForRemoteNotificationsWithDeviceToken:)
      implementation:(IMP)dynamicDidRegisterForRemoteNotificationsWithDeviceToken
        typeEncoding:"v@:::"];
    
    [PWUtils swizzle:delegateClass
        fromSelector:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)
          toSelector:@selector(application:pw_didFailToRegisterForRemoteNotificationsWithError:)
      implementation:(IMP)dynamicDidFailToRegisterForRemoteNotificationsWithError
        typeEncoding:"v@:::"];
    
    [PWUtils swizzle:delegateClass
        fromSelector:@selector(application:didReceiveRemoteNotification:)
          toSelector:@selector(application:pw_didReceiveRemoteNotification:)
      implementation:(IMP)dynamicDidReceiveRemoteNotification
        typeEncoding:"v@:::"];
    
    [PWUtils swizzle:delegateClass
        fromSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)
          toSelector:@selector(application:pw_didReceiveRemoteNotification:fetchCompletionHandler:)
      implementation:(IMP)dynamicDidReceiveRemoteNotificationWithFetch
        typeEncoding:"v@::::"];
    
    [self pw_swizzleOpenURLMethods:delegateClass];
    
    //auto test check
    if ([PWPushRuntime isSelfTestEnabled]) {
        [PWUtils swizzle:delegateClass
            fromSelector:@selector(application:didFinishLaunchingWithOptions:)
              toSelector:@selector(application:pw_didFinishLaunchingWithOptionsAutoTest:)
          implementation:(IMP)dynamicDidFinishLaunchingAutoTest
            typeEncoding:"v@:::"];
    }
    
    [self pw_setDelegate:proxy ? : delegate];
}

- (void)pw_setDelegate:(id<UIApplicationDelegate>)delegate {
    [self performSwizzlingForDelegate:delegate proxy:nil];
}

void _replacement_setApplicationIconBadgeNumber(UIApplication * self, SEL _cmd, NSInteger badgeNumber) {
    ((void(*)(id,SEL,NSInteger))pw_original_setApplicationIconBadgeNumber_Imp)(self, _cmd, badgeNumber);
    
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:[[PWConfig config] appGroupsName]];
    [defaults setInteger:badgeNumber forKey:@"badge_count"];
}

+ (void)load {
    static BOOL swizzleDone = NO;
    if (swizzleDone)
        return;
    swizzleDone = YES;
	//make sure app badges work
    [self.class swizzle_setApplicationIconBadgeNumber];

	method_exchangeImplementations(class_getInstanceMethod(self, @selector(setDelegate:)), class_getInstanceMethod(self, @selector(pw_setDelegate:)));

	NSLog(@"Pushwoosh: Initializing application runtime");

	if ([PWPushRuntime isSelfTestEnabled]) {
		//register for push notifications does not work on simulator, swizzle it
        [self.class swizzle_registerForRemoteNotifications];
	}
}

+ (void)swizzle_setApplicationIconBadgeNumber {
    Method originalMethod = class_getInstanceMethod([UIApplication class], @selector(setApplicationIconBadgeNumber:));
    pw_original_setApplicationIconBadgeNumber_Imp = method_setImplementation(originalMethod, (IMP)_replacement_setApplicationIconBadgeNumber);
}

+ (void)swizzle_registerForRemoteNotifications {
    Method originalMethod = class_getInstanceMethod(self, @selector(registerForRemoteNotifications));
    pw_original_registerForRemoteNotifications_Imp = method_setImplementation(originalMethod, (IMP)_replacement_registerForRemoteNotifications);
}

void _replacement_registerForRemoteNotifications(UIApplication * self, SEL _cmd) {
    if (![PWUtils isSimulator]) {
        ((void(*)(id, SEL))pw_original_registerForRemoteNotifications_Imp)(self, _cmd);
        return;
    }
    
    //simulate fake token
    NSString *fakeToken = @"1234567890abcdef1234567890abcdef";
    NSData *data = [fakeToken dataUsingEncoding:NSUTF8StringEncoding];
    [[UIApplication sharedApplication].delegate application:[UIApplication sharedApplication] didRegisterForRemoteNotificationsWithDeviceToken:data];
}

@end

@implementation PWPushRuntime

BOOL dynamicDidRegisterUserNotificationSettings(id self, SEL _cmd, id application, id notificationSettings) {
	[[[PWPlatformModule module] notificationManagerCompat] didRegisterUserNotificationSettings:notificationSettings];

	if ([self respondsToSelector:@selector(application:pw_didRegisterUserNotificationSettings:)]) {
		[self application:application pw_didRegisterUserNotificationSettings:notificationSettings];
	}

	return YES;
}

+ (void)swizzleNotificationSettingsHandler {
	if ([UIApplication sharedApplication].delegate == nil) {
		return;
	}

	//do not swizzle the same class twice
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		Class appDelegateClass = [[UIApplication sharedApplication].delegate class];
		
		[PWUtils swizzle:appDelegateClass
			fromSelector:@selector(application:didRegisterUserNotificationSettings:)
			  toSelector:@selector(application:pw_didRegisterUserNotificationSettings:)
		  implementation:(IMP)dynamicDidRegisterUserNotificationSettings
			typeEncoding:"v@:::"];
	});
}

+ (BOOL)isSelfTestEnabled {
	return [PWConfig config].selfTestEnabled && [PWUtils isSimulator];
}

@end
