# Code Examples

Practical examples for common native in-app scenarios.

## Overview

This guide provides working code examples for controlling when in-app messages appear, reacting to their callbacks and building a message in code.

## Basic Setup

### Minimal Configuration

```swift
import UIKit
import PushwooshFramework
import PushwooshInApp

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        Pushwoosh.inApp.delegate = self

        return true
    }
}

extension AppDelegate: PWInAppMessageDelegate {

    func pushwooshInAppDidPresent(messageId: String?) {
        print("In-app shown: \(messageId ?? "-")")
    }

    func pushwooshInAppDidClose(messageId: String?) {
        print("In-app closed: \(messageId ?? "-")")
    }
}
```

## Controlling Display

### Hold Messages During Onboarding

Messages that arrive while `isPaused` is `true` wait in the queue and appear once it is set back to `false`:

```swift
import UIKit
import PushwooshFramework

final class OnboardingViewController: UIViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Pushwoosh.inApp.isPaused = true
    }

    func finishOnboarding() {
        Pushwoosh.inApp.isPaused = false
        dismiss(animated: true)
    }
}
```

### Skip Messages on Sensitive Screens

Return `false` from `pushwooshInAppShouldDisplay(messageId:)` to drop a message, for example while the user is paying or watching a video. A dropped message is not shown later:

```swift
import UIKit
import PushwooshFramework
import PushwooshInApp

final class InAppGate: NSObject, PWInAppMessageDelegate {

    static let shared = InAppGate()

    var isCheckoutOpen = false

    func pushwooshInAppShouldDisplay(messageId: String?) -> Bool {
        return !isCheckoutOpen
    }
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        Pushwoosh.inApp.delegate = InAppGate.shared

        return true
    }
}
```

Use `isPaused` instead when the message should be shown later rather than dropped.

### Close the Message on Logout

`dismiss()` closes the message on screen, including a picture-in-picture video:

```swift
import PushwooshFramework

func logout() {
    if Pushwoosh.inApp.isPresenting {
        Pushwoosh.inApp.dismiss()
    }
}
```

## Handling Callbacks

`Pushwoosh.inApp` holds one delegate at a time, so implement all the callbacks you need in the same object.

### Track Taps on In-App Links

`pushwooshInAppClickedAction(url:messageId:)` is called before the SDK opens the URL. The SDK opens the URL itself, so handle your deep links in the app's URL handling code:

```swift
import UIKit
import PushwooshFramework
import PushwooshInApp

final class InAppAnalytics: NSObject, PWInAppMessageDelegate {

    static let shared = InAppAnalytics()

    func pushwooshInAppClickedAction(url: String, messageId: String?) {
        print("In-app \(messageId ?? "-") opened \(url)")
    }

    func pushwooshInAppDidClose(messageId: String?) {
        print("In-app \(messageId ?? "-") closed")
    }
}
```

Assign it with `Pushwoosh.inApp.delegate = InAppAnalytics.shared`.

### Save a Promo Code from a Scratch Card or Spin Wheel

```swift
import UIKit
import PushwooshFramework
import PushwooshInApp

final class RewardHandler: NSObject, PWInAppMessageDelegate {

    static let shared = RewardHandler()

    func pushwooshInAppRewardRevealed(promoCode: String?, messageId: String?) {
        guard let promoCode = promoCode else {
            return
        }
        UserDefaults.standard.set(promoCode, forKey: "lastPromoCode")
    }

    func pushwooshInAppRewardClaimed(promoCode: String, messageId: String?) {
        print("Promo code copied: \(promoCode)")
    }
}
```

Assign it with `Pushwoosh.inApp.delegate = RewardHandler.shared`.

## Building a Message in Code

### Show a Modal

`present(_:)` shows an in-app from a config dictionary, which is handy for checking a layout during development. The config holds `displayType` and a block with the same name. Every required field must be present and of the right type; otherwise the SDK drops the whole config and logs `Invalid native in-app config, dropped at: <key>`:

```swift
import PushwooshFramework

func showWelcomeMessage() {
    Pushwoosh.inApp.present([
        "displayType": "modal",
        "modal": [
            "background": "#FFFFFF",
            "title": ["text": "Welcome", "color": "#000000"],
            "message": ["text": "Thanks for installing the app", "color": "#333333"],
            "showClose": true,
            "dimBackground": true,
            "buttons": [
                [
                    "text": ["text": "Got it", "color": "#FFFFFF"],
                    "background": "#007AFF",
                    "border": ["color": "#007AFF", "radius": 8],
                    "action": ["type": "close"]
                ]
            ]
        ]
    ])
}
```

Colors are hex strings with a leading `#`. A button action is either `["type": "close"]` or `["type": "url", "url": "..."]`.

### Show a Message Only Once

With frequency capping turned on, `maxDisplays` and `cooldown` (in seconds) limit how often a config with the same `inAppId` is shown. The display count survives app restarts:

```swift
import PushwooshFramework

func showTipOnce() {
    Pushwoosh.inApp.setFrequencyCapEnabled(true)

    Pushwoosh.inApp.present([
        "displayType": "banner",
        "inAppId": "swipe-tip",
        "maxDisplays": 1,
        "banner": [
            "position": "bottom",
            "background": "#1C1C1E",
            "message": ["text": "Swipe left to archive a message", "color": "#FFFFFF"],
            "action": ["type": "close"],
            "showClose": true,
            "autoDismiss": 5
        ]
    ])
}
```

## Next Steps

- <doc:GettingStarted> - Quick start guide
- ``PWInAppMessageDelegate`` - Full delegate reference
- ``PushwooshInAppImplementation`` - Full API reference
