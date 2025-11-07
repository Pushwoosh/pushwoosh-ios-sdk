# ``PushwooshTVOS``

Push notifications and Rich Media for tvOS apps.

## Overview

PushwooshTVOS is an optional module that extends the Pushwoosh SDK with tvOS-specific functionality. It provides seamless integration of push notifications and interactive Rich Media content optimized for Apple TV.

### Key Features

- **Push Notifications**: Full support for tvOS push notifications with automatic device registration
- **Rich Media**: Display interactive HTML content with Focus Engine support for Apple TV remote navigation
- **Customizable Animations**: Configure presentation and dismissal animations for Rich Media
- **Flexible Positioning**: Position Rich Media content anywhere on screen (center, left, right, top, bottom)
- **Button Actions**: Support for event tracking, tag management, and custom actions
- **Focus Management**: Automatic focus handling for tvOS remote navigation

### tvOS Requirements

- tvOS 11.0 or later
- Pushwoosh App Code configured for tvOS
- Push Notification capability enabled in Xcode

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:Examples>
- <doc:HTMLGuide>

### Configuration

- ``PushwooshTVOSImplementation/setAppCode(_:)``
- ``PushwooshTVOSImplementation/registerForTvPushNotifications()``
- ``PushwooshTVOSImplementation/unregisterForTvPushNotifications(completion:)``

### Push Notification Handling

- ``PushwooshTVOSImplementation/handleTvPushToken(_:)``
- ``PushwooshTVOSImplementation/handleTvPushRegistrationFailure(_:)``
- ``PushwooshTVOSImplementation/handleTvPushReceived(userInfo:completionHandler:)``
- ``PushwooshTVOSImplementation/handleTVOSPush(userInfo:)``

### Rich Media Configuration

- ``PushwooshTVOSImplementation/configureRichMediaWith(position:presentAnimation:dismissAnimation:)``
- ``PushwooshTVOSImplementation/configureCloseButton(_:)``
- ``PWTVOSRichMediaPosition``
- ``PWTVOSRichMediaPresentAnimation``
- ``PWTVOSRichMediaDismissAnimation``

### Rich Media Manager

- ``PWTVOSRichMediaManager``
