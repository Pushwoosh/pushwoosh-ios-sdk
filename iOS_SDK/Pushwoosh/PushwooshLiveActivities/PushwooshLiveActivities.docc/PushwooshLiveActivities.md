# ``PushwooshLiveActivities``

Real-time iOS Live Activities powered by push notifications.

## Overview

PushwooshLiveActivities integrates Apple's ActivityKit framework to deliver real-time updates to Live Activities on the Lock Screen and Dynamic Island. Live Activities provide persistent, glanceable information that users can track without opening your app.

The module handles token registration, activity lifecycle management, and push notification delivery automatically. It supports both custom activity attributes and a default configuration for cross-platform scenarios.

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:Examples>

### Setup Methods

- ``PushwooshLiveActivitiesImplementationSetup/setup(_:)``

  Configures Live Activities with custom attributes.

- ``PushwooshLiveActivitiesImplementationSetup/defaultSetup()``

  Configures Live Activities with default attributes managed by Pushwoosh.

### Token Management

- ``PushwooshLiveActivitiesImplementationSetup/sendPushToStartLiveActivity(token:)``

  Sends push-to-start token to enable remote activity initiation.

- ``PushwooshLiveActivitiesImplementationSetup/startLiveActivity(token:activityId:)``

  Registers an active Live Activity with the server.

- ``PushwooshLiveActivitiesImplementationSetup/stopLiveActivity()``

  Notifies the server that a Live Activity has ended.

- ``PushwooshLiveActivitiesImplementationSetup/stopLiveActivity(activityId:)``

  Notifies the server that a specific Live Activity has ended.

### Default Mode

- ``PushwooshLiveActivitiesImplementationSetup/defaultStart(_:attributes:content:)``

  Starts a Live Activity using default attributes.

- ``DefaultLiveActivityAttributes``

  A flexible structure for defining Live Activity content dynamically.

### Custom Attributes

- ``PushwooshLiveActivityAttributes``

  Protocol for defining custom Live Activity attributes.

- ``PushwooshLiveActivityAttributeData``

  Pushwoosh-specific metadata required for activity tracking.

- ``PushwooshLiveActivityContentState``

  Protocol for defining Live Activity content state.

- ``PushwooshLiveActivityContentStateData``

  Pushwoosh-specific metadata for content updates.
