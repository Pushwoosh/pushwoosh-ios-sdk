# ``Pushwoosh/handlePushRegistrationFailure(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Handles push notification registration failures.

## Discussion

Call this method from your AppDelegate's `application:didFailToRegisterForRemoteNotificationsWithError:` to notify Pushwoosh of registration failures. This helps with debugging and analytics.

The error information is logged to help diagnose registration issues such as network problems, provisioning profile configuration, or APNs availability.

## Parameters

- error: The error received from APNs during registration
