//
//  PushRuntime.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2024
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
#import "PWAppLifecycleTrackingManager.h"

#if !__has_feature(objc_arc)
#error "ARC is required to compile Pushwoosh SDK"
#endif

static IMP pw_original_setApplicationIconBadgeNumber_Imp;
static IMP pw_original_registerForRemoteNotifications_Imp;
static IMP pw_original_didReceiveRemoteNotification_Imp;
static IMP pw_original_didRegisterForRemoteNotificationWithDeviceToken_Imp;
static IMP pw_original_didFailToRegisterForRemoteNotificationsWithError_Imp;
static IMP pw_original_didReceiveRemoteNotificationWithUserInfo_Imp;
static IMP pw_original_didFinishLaunchingWithOptionsExtension;
static IMP pw_original_didFinishLaunchingWithOptions;

@interface UIApplication (PushwooshRuntime)

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

BOOL _replacement_didFinishLaunchingWithOptionsExtensionRequest(id self, SEL _cmd, UIApplication *application, NSDictionary *launchOptions) {
    ((BOOL(*)(id, SEL, UIApplication *, NSDictionary *))pw_original_didFinishLaunchingWithOptionsExtension)(self, _cmd, application, launchOptions);
    
    BOOL result = YES;

    [[PWAppLifecycleTrackingManager sharedManager] startTracking];
    
    return result;
}

void _replacement_didReceiveRemoteNotificationWithUserInfo(id self, SEL _cmd, UIApplication *application, NSDictionary *userInfo) {
    if ([self respondsToSelector:@selector(application:didReceiveRemoteNotification:)]) {
        ((void(*)(id, SEL, UIApplication *, NSDictionary *))pw_original_didReceiveRemoteNotificationWithUserInfo_Imp)(self, _cmd, application, userInfo);
    }
    
    if ([[PWPreferences preferences] hasAppCode]) {
        [[PushNotificationManager pushManager] handlePushReceived:userInfo];
    }
}

void _replacement_didReceiveRemoteNotification(id self, SEL _cmd, UIApplication * application, NSDictionary * userInfo, void (^completionHandler)(UIBackgroundFetchResult)) {
    ((void(*)(id, SEL, UIApplication *, NSDictionary *, void(^)(UIBackgroundFetchResult)))pw_original_didReceiveRemoteNotification_Imp)(self, _cmd, application, userInfo, completionHandler);
    
    if ([[PWPreferences preferences] hasAppCode]) {
        [[PushNotificationManager pushManager] handlePushReceived:userInfo];
    }
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
            PWLogError(@"");
            PWLogError(@"!!!!!!-----Exception caused by AppDelegate proxy: %@-----!!!!!!", exception);
            PWLogError(@"");
        }
    }
    
    [self swizzle_didFinishLaunchingWithOptionsForExtensionRequest:[delegate class]];
        
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
    
    [self swizzle_didFinishLaunchingWithOptions:delegateClass];
    [self swizzle_didRegisterForRemoteNotificationsWithDeviceToken:delegateClass];
    [self swizzle_didFailToRegisterForRemoteNotificationsWithError:delegateClass];
    [self swizzle_didReceiveRemoteNotification:delegateClass];
    [self swizzle_didReceiveRemoteNotificationWithFetchBlock:delegateClass];
    
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

- (void)swizzle_didFinishLaunchingWithOptions:(Class)delegateClass {
    Method originalMethod = class_getInstanceMethod(delegateClass, @selector(application:didFinishLaunchingWithOptions:));
    pw_original_didFinishLaunchingWithOptions = method_setImplementation(originalMethod, (IMP)_replacement_didFinishLaunchingWithOptions);
}

- (void)swizzle_didFinishLaunchingWithOptionsForExtensionRequest:(Class)delegateClass {
    static BOOL swizzleDone = NO;
    if (swizzleDone)
        return;
    swizzleDone = YES;
    
    Method originalMethod = class_getInstanceMethod(delegateClass, @selector(application:didFinishLaunchingWithOptions:));
    pw_original_didFinishLaunchingWithOptionsExtension = method_setImplementation(originalMethod, (IMP)_replacement_didFinishLaunchingWithOptionsExtensionRequest);
}

- (void)swizzle_didReceiveRemoteNotificationWithFetchBlock:(Class)delegateClass {
    Method originalMethod = class_getInstanceMethod(delegateClass, @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:));
    pw_original_didReceiveRemoteNotification_Imp = method_setImplementation(originalMethod, (IMP)_replacement_didReceiveRemoteNotification);
}

- (void)swizzle_didReceiveRemoteNotification:(Class)delegeteClass {
    Method originalMethod = class_getInstanceMethod(delegeteClass, @selector(application:didReceiveRemoteNotification:));
    pw_original_didReceiveRemoteNotificationWithUserInfo_Imp = method_setImplementation(originalMethod, (IMP)_replacement_didReceiveRemoteNotificationWithUserInfo);
}

- (void)pw_setDelegate:(id<UIApplicationDelegate>)delegate {
    [self performSwizzlingForDelegate:delegate proxy:nil];
}

void _replacement_didRegisterForRemoteNotificationWithToken(id self, SEL _cmd, UIApplication *application, NSData *deviceToken) {
    if ([self respondsToSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)]) {
        ((void(*)(id, SEL, UIApplication*, NSData*))pw_original_didRegisterForRemoteNotificationWithDeviceToken_Imp)(self, _cmd, application, deviceToken);
    }
    
    if ([[PWPreferences preferences] hasAppCode]) {
        [[PushNotificationManager pushManager] handlePushRegistration:deviceToken];
    }
}


BOOL _replacement_didFinishLaunchingWithOptions(id self, SEL _cmd, UIApplication *application, NSDictionary *launchOptions) {
    BOOL result = YES;
    
    if ([self respondsToSelector:@selector(application:didFinishLaunchingWithOptions:)]) {
        result = ((BOOL(*)(id, SEL, UIApplication *, NSDictionary *))pw_original_didFinishLaunchingWithOptions)(self, _cmd, application, launchOptions);
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


void _replacement_didFailToRegisterForRemoteNotificationsWithError(id self, SEL _cmd, UIApplication *application, NSError *error) {
    if ([self respondsToSelector:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)]) {
        ((void(*)(id, SEL, UIApplication*, NSError*))pw_original_didFailToRegisterForRemoteNotificationsWithError_Imp)(self, _cmd, application, error);
    }

    PWLogError(@"Error registering for push notifications. Error: %@", error);

    if ([[PWPreferences preferences] hasAppCode]) {
        [[PushNotificationManager pushManager] handlePushRegistrationFailure:error];
    }
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

- (void)swizzle_didRegisterForRemoteNotificationsWithDeviceToken:(Class)delegateClass {
    Method originalMethod = class_getInstanceMethod(delegateClass, @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:));
    pw_original_didRegisterForRemoteNotificationWithDeviceToken_Imp = method_setImplementation(originalMethod, (IMP)_replacement_didRegisterForRemoteNotificationWithToken);
}

- (void)swizzle_didFailToRegisterForRemoteNotificationsWithError:(Class)delegateClass {
    Method originalMethod = class_getInstanceMethod(delegateClass, @selector(application:didFailToRegisterForRemoteNotificationsWithError:));
    pw_original_didFailToRegisterForRemoteNotificationsWithError_Imp = method_setImplementation(originalMethod, (IMP)_replacement_didFailToRegisterForRemoteNotificationsWithError);
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
