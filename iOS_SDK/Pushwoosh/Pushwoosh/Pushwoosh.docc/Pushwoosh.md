# ``Pushwoosh``

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

## Topics

### Getting Started

- <doc:QuickStart>
- <doc:GettingStarted>
- <doc:AdvancedIntegration>

### Core Classes

- ``Pushwoosh``

  Main SDK interface for push notification management.

- ``PWMessage``

  Encapsulates push notification payload data.

- ``PWInbox``

  Manages inbox messages and notifications.

### Delegates

- ``PWMessagingDelegate``

  Delegate protocol for receiving push notification events.

- ``PWPurchaseDelegate``

  Delegate protocol for in-app purchase events from rich media.

### Configuration

- ``PushwooshConfig``

  Configuration object for SDK initialization.

- ``PWPreferences``

  User preferences and settings storage.

### Initialization

- ``Pushwoosh/sharedInstance``

  Returns the shared Pushwoosh instance.

### Registration

- ``Pushwoosh/registerForPushNotifications``

  Registers for push notifications and requests user permission.

- ``Pushwoosh/setToken:``

  Sets the device push token manually.

- ``Pushwoosh/unregisterForPushNotifications``

  Unregisters from push notifications.

### User Management

- ``Pushwoosh/setUserId:``

  Associates a user ID with the device.

- ``Pushwoosh/setEmail:``

  Associates an email with the device.

- ``Pushwoosh/setTags:``

  Sets custom tags for user segmentation.

- ``Pushwoosh/getTags:``

  Retrieves current device tags.

### Messaging

- ``PWMessagingDelegate/pushwoosh:onMessageReceived:``

  Called when a push notification is received.

- ``PWMessagingDelegate/pushwoosh:onMessageOpened:``

  Called when user taps on a push notification.

### Badge Management

- ``Pushwoosh/setBadgeNumber:``

  Sets the application badge number.

- ``Pushwoosh/addBadgeNumber:``

  Increments the badge number.

### Rich Media

- ``PWNotificationExtensionManager``

  Manages rich media notification content.

### Logging

- ``PushwooshLog``

  Logging utility for SDK diagnostics.

- ``Pushwoosh/setLogLevel:``

  Sets the SDK logging level.
