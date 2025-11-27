# ``Pushwoosh/registerForPushNotifications(with:completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Registers the device for push notifications with initial tags and a completion handler.

## Overview

This method combines device registration and tag assignment, providing a callback when the operation completes. Use this when you need to know whether registration succeeded and want to set initial tags.

The tags are only set if registration succeeds. If registration fails, the tags will not be applied.

## Example

Register with user profile data and handle result:

```swift
func completeUserSignup(user: User) {
    let userTags: [String: Any] = [
        "user_id": user.id,
        "subscription_plan": user.subscriptionPlan,
        "account_type": user.accountType,
        "signup_date": Date()
    ]

    Pushwoosh.configure.registerForPushNotifications(with: userTags) { token, error in
        if let error = error {
            self.logger.error("Registration failed: \(error.localizedDescription)")
            self.analytics.track("push_registration_failed")
            return
        }

        self.logger.info("Push registration successful")
        self.analytics.track("push_registration_success", properties: [
            "has_token": token != nil
        ])

        self.updateOnboardingProgress(.notificationsEnabled)
    }
}
```

## See Also

- ``Pushwoosh/registerForPushNotifications(with:)``
- ``Pushwoosh/registerForPushNotifications(withCompletion:)``
