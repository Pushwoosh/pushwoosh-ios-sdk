# ``PushwooshForegroundPush``

Customizable foreground push notifications for iOS applications.

## Overview

Starting from version 6.10.0, PushwooshForegroundPush enables customization of foreground push notifications when native iOS system alerts are disabled. This module creates animated push banners that appear at the top of your app with rich visual effects, haptic feedback, and interactive capabilities.

The module offers extensive customization options including gradient backgrounds, custom colors and fonts, multiple animation styles, and modern iOS 26+ Liquid Glass effects.

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:Examples>

### Core Classes

- ``PushwooshForegroundPushImplementation``

  Main implementation class that manages foreground push notifications display and configuration.

- ``ForegroundPushConfiguration``

  Configuration object containing all visual and behavioral settings for foreground pushes.

### Configuration Methods

- ``PushwooshForegroundPushImplementation/foregroundNotificationWith(style:duration:vibration:disappearedPushAnimation:)``

  Configure the foreground push notification display settings.

- ``PushwooshForegroundPushImplementation/showForegroundPush(userInfo:)``

  Display a foreground push notification with the specified payload.

### Appearance Customization

- ``PushwooshForegroundPushImplementation/gradientColors``

  Custom gradient colors for the push notification background.

- ``PushwooshForegroundPushImplementation/backgroundColor``

  Solid background color for the push notification.

- ``PushwooshForegroundPushImplementation/titlePushColor``

  Text color for the notification title.

- ``PushwooshForegroundPushImplementation/messagePushColor``

  Text color for the notification message body.

- ``PushwooshForegroundPushImplementation/titlePushFont``

  Custom font for the notification title.

- ``PushwooshForegroundPushImplementation/messagePushFont``

  Custom font for the notification message body.

### Animation Settings

- ``PushwooshForegroundPushImplementation/usePushAnimation``

  Enable or disable the slide and wave animation when push appears.

- ``PushwooshForegroundPushImplementation/useLiquidView``

  Enable modern Liquid Glass effect on iOS 26+ devices.

- ``PWForegroundPushDisappearedAnimation``

  Animation style when push notification disappears.

- ``PWForegroundPushDisappearedAnimation/balls``

  Push explodes into small particles when disappearing.

- ``PWForegroundPushDisappearedAnimation/regularPush``

  Push slides upward and fades out like standard notifications.

### Interaction

- ``PushwooshForegroundPushImplementation/didTapForegroundPush``

  Callback triggered when user taps on the foreground push notification.

### Display Styles

- ``PWForegroundPushStyle``

  Visual style template for the foreground push notification.

- ``PWForegroundPushStyle/style1``

  Standard push notification style with icon, title, and message.

### Haptic Feedback

- ``PWForegroundPushHapticFeedback``

  Haptic feedback type to play when notification appears.

- ``PWForegroundPushHapticFeedback/none``

  No haptic feedback.

- ``PWForegroundPushHapticFeedback/light``

  Light impact haptic feedback.

- ``PWForegroundPushHapticFeedback/medium``

  Medium impact haptic feedback.

- ``PWForegroundPushHapticFeedback/heavy``

  Heavy impact haptic feedback.

- ``PWForegroundPushHapticFeedback/soft``

  Soft impact haptic feedback.

- ``PWForegroundPushHapticFeedback/rigid``

  Rigid impact haptic feedback.

- ``PWForegroundPushHapticFeedback/notification``

  System notification haptic feedback.
