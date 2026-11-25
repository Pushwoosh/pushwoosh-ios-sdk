# Getting Started

Show native in-app messages and receive their callbacks.

## Prerequisites

Before you begin, ensure you have:

- A Pushwoosh account
- A Pushwoosh project set up in your account
- An iOS platform configured in your Pushwoosh project
- Your Pushwoosh Application Code from the Control Panel
- iOS 15.0+ deployment target
- Pushwoosh SDK version 7.2.0 or higher
- PushwooshFramework, PushwooshCore, and PushwooshBridge frameworks integrated in your project

> **Important**: Without PushwooshInApp linked, the SDK does not show native in-app messages: it logs `native in-app detected but PushwooshInApp module is not linked, skipping` and drops the message.

## Step 1: Install Module

@TabNavigator {
    @Tab("Swift Package Manager") {
        In Xcode, use the following URL to add the Pushwoosh dependency:

        ```
        https://github.com/Pushwoosh/Pushwoosh-XCFramework
        ```

        Select the required modules in your target: PushwooshFramework, PushwooshCore, PushwooshBridge and PushwooshInApp.
    }

    @Tab("CocoaPods") {
        Add to your Podfile:

        ```ruby
        pod 'PushwooshXCFramework'
        pod 'PushwooshXCFramework/PushwooshInApp'
        ```

        Then run:

        ```bash
        pod install
        ```
    }
}

Once the module is linked, in-app campaigns with native templates are shown automatically. No initialization call is required.

## Step 2: Set the Delegate

Set the delegate in `application(_:didFinishLaunchingWithOptions:)` to follow what happens to in-app messages:

```swift
import UIKit
import PushwooshFramework
import PushwooshInApp

@main
class AppDelegate: UIResponder, UIApplicationDelegate, PWInAppMessageDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        Pushwoosh.inApp.delegate = self

        return true
    }

    // MARK: - PWInAppMessageDelegate

    func pushwooshInAppDidPresent(messageId: String?) {
        print("In-app shown: \(messageId ?? "-")")
    }

    func pushwooshInAppClickedAction(url: String, messageId: String?) {
        print("In-app link tapped: \(url)")
    }

    func pushwooshInAppDidClose(messageId: String?) {
        print("In-app closed: \(messageId ?? "-")")
    }
}
```

The SDK keeps a weak reference to the delegate. Use an object that lives as long as the app, such as the app delegate, or keep a strong reference to it yourself.

### Delegate Methods

All methods of ``PWInAppMessageDelegate`` are optional and are called on the main thread:

| Method | Description |
|--------|-------------|
| `pushwooshInAppShouldDisplay(messageId:)` | Called right before a message is shown. Return `false` to drop this message. It is discarded, not postponed |
| `pushwooshInAppWillPresent(messageId:)` | Called right before the message appears |
| `pushwooshInAppDidPresent(messageId:)` | Called once the message is on screen |
| `pushwooshInAppDidClose(messageId:)` | Called after the message is closed |
| `pushwooshInAppClickedAction(url:messageId:)` | Called when the user taps an element with a URL action, before the SDK opens the URL |
| `pushwooshInAppRewardRevealed(promoCode:messageId:)` | Scratch card and spin wheel: the game is over and the prize is on screen. `promoCode` is the revealed code, if the prize has one |
| `pushwooshInAppRewardClaimed(promoCode:messageId:)` | Scratch card and spin wheel: the user copied the revealed promo code |

`messageId` is the code of the in-app resource for campaign messages and the `inAppId` of the config for messages shown with `present(_:)`. A button that only closes the message is not a click: it triggers `pushwooshInAppDidClose(messageId:)` only.

## Step 3: Trigger an In-App

In-app campaigns are shown on the triggers set up in the Control Panel. For an event trigger, post the event from the app:

```swift
Pushwoosh.configure.postEvent("PurchaseCompleted", withAttributes: ["amount": 25])
```

## Dark Appearance

When a campaign has a dark variant, the SDK uses it if the Rich Media color scheme resolves to dark. Native in-app messages and Rich Media share this setting:

```swift
Pushwoosh.media.setRichMediaColorScheme(.system)
```

A campaign without a dark variant always uses its light design.

## Testing

1. Build and run your app with PushwooshInApp linked
2. Trigger an in-app campaign that uses a native template, for example by posting its event
3. Verify the message appears and the delegate receives `pushwooshInAppWillPresent(messageId:)` and `pushwooshInAppDidPresent(messageId:)`
4. Tap a button with a link and verify `pushwooshInAppClickedAction(url:messageId:)` is called
5. Close the message and verify `pushwooshInAppDidClose(messageId:)` is called

If a message does not appear, check the SDK log. A config that does not match the template schema is dropped with `Invalid native in-app config, dropped at: <key>`.

## Next Steps

- <doc:Examples> - Pausing, suppressing and dismissing messages, reward callbacks, layouts built in code
- ``PWInAppMessageDelegate`` - Delegate protocol reference
- ``PushwooshInAppImplementation`` - Full API reference
