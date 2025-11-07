# Quick Start

Get your first push notification running in minutes.

## Overview

This quick start guide helps you set up Pushwoosh SDK and send your first push notification as quickly as possible. For comprehensive integration steps, see <doc:GettingStarted>.

## Prerequisites

- Active Pushwoosh account with a configured project
- iOS platform set to Token-Based Authentication (recommended)
- Gateway set to `Sandbox` for simulator testing
- Your Application Code and Device API Token from Pushwoosh Control Panel

## Installation

@TabNavigator {
    @Tab("Swift Package Manager") {
        1. In Xcode, select File → Add Package Dependencies
        2. Enter the repository URL:

        ```
        https://github.com/Pushwoosh/Pushwoosh-XCFramework
        ```

        3. Select the following frameworks:
           - PushwooshFramework
           - PushwooshCore
           - PushwooshBridge
           - PushwooshLiveActivities
    }

    @Tab("CocoaPods") {
        Add to your `Podfile`:

        ```ruby
        pod 'PushwooshXCFramework'
        ```

        Then run:

        ```bash
        pod install
        ```
    }
}

## Configuration

### 1. Add Required Info.plist Keys

Add these two keys to your `Info.plist`:

- `Pushwoosh_APPID` → Your Application Code
- `Pushwoosh_API_TOKEN` → Your Device API Token

```xml
<key>Pushwoosh_APPID</key>
<string>YOUR-APPLICATION-CODE</string>
<key>Pushwoosh_API_TOKEN</key>
<string>YOUR-DEVICE-API-TOKEN</string>
```

### 2. Enable Push Notifications Capability

1. Select your app target in Xcode
2. Go to Signing & Capabilities
3. Click + Capability
4. Add "Push Notifications"
5. Add "Background Modes" and check "Remote notifications"

### 3. Initialize SDK

In your AppDelegate or App struct:

@TabNavigator {
    @Tab("Swift") {
        ```swift
        import PushwooshFramework

        class AppDelegate: NSObject, UIApplicationDelegate {
            func application(_ application: UIApplication,
                            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

                Pushwoosh.sharedInstance().registerForPushNotifications()

                return true
            }

            func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
                Pushwoosh.sharedInstance().handlePushRegistration(deviceToken)
            }
        }
        ```
    }

    @Tab("Objective-C") {
        ```objc
        #import <PushwooshFramework/PushwooshFramework.h>

        @interface AppDelegate : NSObject <UIApplicationDelegate>
        @end

        @implementation AppDelegate

        - (BOOL)application:(UIApplication *)application
                didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

            [[Pushwoosh sharedInstance] registerForPushNotifications];

            return YES;
        }

        - (void)application:(UIApplication *)application
                didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
            [[Pushwoosh sharedInstance] handlePushRegistration:deviceToken];
        }

        @end
        ```
    }
}

### 4. Register for Push Notifications

Run your app and grant push notification permissions when prompted. Check the console for a successful registration log containing your HWID and push token.

## Send Your First Push

1. Open Pushwoosh Control Panel
2. Navigate to your application
3. Click "Create Message"
4. Enter notification content
5. Click "Send"

Your device should receive the push notification!

## Troubleshooting

### Device Not Registered

- Verify push notification capability is enabled
- Check APNs certificate configuration in Pushwoosh
- Confirm app has notification permissions
- Look for registration logs in Xcode console

### Notifications Not Received

- Confirm device is registered in Pushwoosh Control Panel under Audience → Devices
- Verify Gateway is set to `Sandbox` for simulator testing
- Check notification is sent to correct audience
- Enable debug logging:

@TabNavigator {
    @Tab("Swift") {
        ```swift
        Pushwoosh.debug.setLogLevel(.PW_LL_VERBOSE)
        ```
    }

    @Tab("Objective-C") {
        ```objc
        [Pushwoosh.debug setLogLevel:PW_LL_VERBOSE];
        ```
    }
}

## Next Steps

- <doc:GettingStarted> - Complete integration guide
- <doc:AdvancedIntegration> - Advanced features and configuration
- Add Notification Service Extension for rich media
- Implement PWMessagingDelegate for custom handling
- Configure user tags for segmentation
