# ``PushwooshInApp``

Native in-app messages rendered on-device, without a web view.

## Overview

PushwooshInApp renders in-app messages from their layout description with native UIKit views instead of loading HTML into a web view. Supported templates are modal, sheet, carousel, stories, banner, fullscreen, video, picture-in-picture, scratch card and spin wheel.

A native in-app is delivered the same way as a regular in-app: the SDK downloads its content and, when the content carries a native layout, hands it to this module, which renders the matching template. Show, click and close statistics are sent automatically. If the module is not linked, the SDK logs a warning and skips the message.

Messages are shown one at a time in their own window above the app. A message that arrives while another one is on screen waits in a queue; a picture-in-picture video floats in a separate window and can stay on screen together with other messages.

## Usage

The module is reached through `Pushwoosh.inApp`:

- `delegate` takes a ``PWInAppMessageDelegate`` that receives the lifecycle, click and reward callbacks and can veto a message before it is shown.
- `isPaused` holds new messages in the queue while `true` and shows them once it is set back to `false`.
- `isPresenting` tells whether an in-app is on screen.
- `dismiss()` closes the in-app that is on screen.
- `setFrequencyCapEnabled(_:)` turns on the `maxDisplays` and `cooldown` limits of an in-app config. Off by default.
- `present(_:)` shows an in-app from a config dictionary built in code, for example to check a layout during development.

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:Examples>

### Core Classes

- ``PushwooshInAppImplementation``
- ``PWInAppMessageDelegate``

### Display Control

- ``PushwooshInAppImplementation/delegate``
- ``PushwooshInAppImplementation/isPaused``
- ``PushwooshInAppImplementation/isPresenting``
- ``PushwooshInAppImplementation/dismiss()``
- ``PushwooshInAppImplementation/setFrequencyCapEnabled(_:)``
- ``PushwooshInAppImplementation/present(_:)``

### Lifecycle Callbacks

- ``PWInAppMessageDelegate/pushwooshInAppShouldDisplay(messageId:)``
- ``PWInAppMessageDelegate/pushwooshInAppWillPresent(messageId:)``
- ``PWInAppMessageDelegate/pushwooshInAppDidPresent(messageId:)``
- ``PWInAppMessageDelegate/pushwooshInAppDidClose(messageId:)``
- ``PWInAppMessageDelegate/pushwooshInAppClickedAction(url:messageId:)``

### Reward Callbacks

- ``PWInAppMessageDelegate/pushwooshInAppRewardRevealed(promoCode:messageId:)``
- ``PWInAppMessageDelegate/pushwooshInAppRewardClaimed(promoCode:messageId:)``
