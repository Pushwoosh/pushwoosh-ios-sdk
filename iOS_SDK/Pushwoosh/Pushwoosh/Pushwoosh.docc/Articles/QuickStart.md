# Quick Start

Get your first push notification running in minutes.

## Overview

This quick start guide helps you set up Pushwoosh SDK and send your first push notification as quickly as possible. For comprehensive integration steps, see <doc:GettingStarted>.

> Important: Integrate through ``Pushwoosh/configure-type.property`` and the module accessors, not through `Pushwoosh.sharedInstance()`, which is deprecated since 7.3.0. Registration, user data, tags and settings go through `Pushwoosh.configure` (Objective-C: `[Pushwoosh configure]`); each feature has its own accessor: `Pushwoosh.media`, `Pushwoosh.inbox`, `Pushwoosh.inApp`, `Pushwoosh.inline`, `Pushwoosh.debug`, `Pushwoosh.LiveActivities`, `Pushwoosh.VoIP`, `Pushwoosh.ForegroundPush`, `Pushwoosh.Keychain` and `Pushwoosh.InboxKit`.

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

        3. Add the following frameworks to the app target:
           - PushwooshFramework
           - PushwooshCore
           - PushwooshBridge

        The Notification Service Extension target gets the same three frameworks (see step 4).
    }

    @Tab("CocoaPods") {
        Add to your `Podfile`, with a block for the Notification Service Extension target (see step 4):

        ```ruby
        target 'YourApp' do
          pod 'PushwooshXCFramework'
        end

        target 'NotificationService' do
          pod 'PushwooshXCFramework'
        end
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

                Pushwoosh.configure.registerForPushNotifications()

                return true
            }

            func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
                Pushwoosh.configure.handlePushRegistration(deviceToken)
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

            [Pushwoosh.configure registerForPushNotifications];

            return YES;
        }

        - (void)application:(UIApplication *)application
                didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
            [Pushwoosh.configure handlePushRegistration:deviceToken];
        }

        @end
        ```
    }
}

### 4. Add a Notification Service Extension and an App Group

This step is required. The message delivery event is sent only by the Notification Service Extension: without it pushes are shown, but they are never counted as delivered. The extension also applies the badge and downloads media attachments. The app and the extension share data through an App Group.

1. In Xcode, choose File → New → Target → Notification Service Extension.
2. Link PushwooshFramework, PushwooshCore and PushwooshBridge to the extension target.
3. Replace the generated class with a subclass of ``PushwooshNotificationServiceExtension``:

@TabNavigator {
    @Tab("Swift") {
        ```swift
        import PushwooshFramework

        class NotificationService: PushwooshNotificationServiceExtension {}
        ```
    }

    @Tab("Objective-C") {
        ```objc
        #import <PushwooshFramework/PushwooshFramework.h>

        @interface NotificationService : PushwooshNotificationServiceExtension
        @end

        @implementation NotificationService
        @end
        ```
    }
}

   Without a class of your own, set the extension's `NSExtensionPrincipalClass` to `PushwooshNotificationServiceExtension`.

4. In Signing & Capabilities, add the App Groups capability to the app target and to the extension target, with the same group selected in both.
5. Set that group as `PW_APP_GROUPS_NAME` in the `Info.plist` of the app and of the extension:

```xml
<key>PW_APP_GROUPS_NAME</key>
<string>group.com.example.app</string>
```

6. Keep `Pushwoosh_APPID` in the app's `Info.plist` only: the extension inherits it, like the other `Pushwoosh_*` keys, from the app.
7. iOS starts the extension only for pushes whose `aps` dictionary carries `mutable-content: 1`.

For how the delivery event is sent and what the App Group is used for, see <doc:AdvancedIntegration#Delivery-Event>.

### 5. Register for Push Notifications

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

### Delivery Not Counted

- Confirm the Notification Service Extension target is embedded in the app and its class subclasses ``PushwooshNotificationServiceExtension``
- Confirm the push carries `mutable-content: 1`
- Confirm both targets have the same App Group and the same `PW_APP_GROUPS_NAME`
- Look for a `messageDeliveryEvent skipped:` line in the extension's console log: it names the missing setting

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
- <doc:AdvancedIntegration#Delivery-Event> - How the delivery event is sent
- Implement PWMessagingDelegate for custom handling
- Configure user tags for segmentation
