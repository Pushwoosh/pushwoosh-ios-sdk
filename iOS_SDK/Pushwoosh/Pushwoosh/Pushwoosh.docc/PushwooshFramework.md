# ``PushwooshFramework``

Push notification SDK for iOS applications.

## Overview

PushwooshiOS provides a comprehensive solution for integrating push notifications into iOS applications. The SDK handles device registration, token management, notification delivery, and rich media content display automatically.

Key features include:
- Remote and local push notification support
- Rich media notifications with HTML content
- In-app messaging
- User tags and attributes
- Geolocation tracking
- Inbox functionality

The SDK API is reached through `Pushwoosh.configure`: registration (`registerForPushNotifications()`), user data (`setUserId(_:)`, `setEmail(_:)`), tags (`setTags(_:)`) and the rest of the settings. Feature modules have their own accessors, such as `Pushwoosh.media`, `Pushwoosh.inbox` and `Pushwoosh.LiveActivities`. `Pushwoosh.configure` returns `PushwooshConfig`, and `PWMessage`, `PushwooshConfig` and `PWPreferences` are documented in the PushwooshCore module. The instance methods of ``Pushwoosh`` are deprecated since 7.3.0.

## Topics

### Getting Started

- <doc:QuickStart>
- <doc:GettingStarted>
- <doc:AdvancedIntegration>

### Core Classes

- ``Pushwoosh``

  Main SDK interface for push notification management.

- ``PWInboxCenter``

  Inbox messages and notifications, reached through `Pushwoosh.inbox`.

### Delegates

- ``PWMessagingDelegate``

  Delegate protocol for receiving push notification events.

- ``PWPurchaseDelegate``

  Delegate protocol for in-app purchase events from rich media.

### Initialization

- ``Pushwoosh/configure-type.property``

  Entry point to the SDK API: registration, user data, tags and settings.

### Messaging

- ``PWMessagingDelegate/pushwoosh(_:onMessageReceived:)``

  Called when a push notification is received.

- ``PWMessagingDelegate/pushwoosh(_:onMessageOpened:)``

  Called when user taps on a push notification.

### Notification Service Extension

- ``PushwooshNotificationServiceExtension``

  Base class for the required Notification Service Extension: sends the delivery event, applies the badge and downloads media attachments.
