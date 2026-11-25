# ``PushwooshForegroundPush``

Customizable foreground push notifications for iOS applications.

## Overview

Starting from version 6.10.0, PushwooshForegroundPush enables customization of foreground push notifications when native iOS system alerts are disabled. This module creates animated push banners that appear at the top of your app with rich visual effects, haptic feedback, and interactive capabilities.

The module offers extensive customization options including gradient backgrounds, custom colors and fonts, multiple animation styles, and modern iOS 26+ Liquid Glass effects.

## Configuration

The module is reached through `Pushwoosh.ForegroundPush`:

- `foregroundNotificationWith(style:duration:vibration:disappearedPushAnimation:)` configures the banner: the visual style, the display time in seconds, the haptic feedback and the exit animation.
- `showForegroundPush(userInfo:)` shows a banner for a push payload.
- `didTapForegroundPush` is a closure called when the user taps the banner; `delegate` takes a ``PWForegroundPushDelegate`` instead.

The option types are declared in PushwooshBridge:

- `PWForegroundPushStyle`: `.style1`, the standard banner with icon, title and message.
- `PWForegroundPushHapticFeedback`: `.none`, `.light`, `.medium`, `.heavy`, `.soft`, `.rigid`, `.notification`.
- `PWForegroundPushDisappearedAnimation`: `.balls` (the banner explodes into particles) or `.regularPush` (it slides up and fades out).

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:Examples>

### Core Classes

- ``PushwooshForegroundPushImplementation``

  Main implementation class that manages foreground push notifications display and configuration.

- ``ForegroundPushConfiguration``

  Configuration object containing all visual and behavioral settings for foreground pushes.

- ``PWForegroundPushDelegate``

  Delegate that receives taps on the foreground push banner.

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

### Interaction

- ``PushwooshForegroundPushImplementation/delegate``

  Delegate that receives taps on the foreground push banner.
