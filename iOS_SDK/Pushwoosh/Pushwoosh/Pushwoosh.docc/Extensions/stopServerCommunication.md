# ``Pushwoosh/stopServerCommunication()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Stops communication with Pushwoosh server.

## Overview

Temporarily disables all network communication with Pushwoosh servers. Use this for:
- GDPR compliance (user opts out of data collection)
- Privacy-first onboarding (wait for user consent)
- Offline mode support
- Debugging network issues

## Behavior When Stopped

- No data is sent to Pushwoosh servers
- Tags and events are queued locally
- Push notifications can still be received (via APNs)
- Queued data is sent when communication resumes

## Example

Implement GDPR-compliant data collection opt-out:

```swift
func handleGDPROptOut() {
    Pushwoosh.configure.stopServerCommunication()

    userDefaults.set(false, forKey: "analyticsEnabled")

    showConfirmation("Data collection disabled")
}

func handleGDPROptIn() {
    Pushwoosh.configure.startServerCommunication()

    userDefaults.set(true, forKey: "analyticsEnabled")
}
```

Wait for privacy consent before enabling SDK:

```swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    if !userDefaults.bool(forKey: "privacyConsentGiven") {
        Pushwoosh.configure.stopServerCommunication()
    }

    return true
}

func privacyConsentViewController(_ controller: PrivacyConsentViewController,
                                   didFinishWithConsent consent: Bool) {
    userDefaults.set(consent, forKey: "privacyConsentGiven")

    if consent {
        Pushwoosh.configure.startServerCommunication()
        Pushwoosh.configure.registerForPushNotifications()
    }
}
```

## See Also

- ``Pushwoosh/startServerCommunication()``
