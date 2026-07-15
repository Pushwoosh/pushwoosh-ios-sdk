# ``PushwooshLiveActivities``

Real-time iOS Live Activities powered by push notifications.

## Overview

PushwooshLiveActivities integrates Apple's ActivityKit framework to deliver real-time updates to Live Activities on the Lock Screen and Dynamic Island. Live Activities provide persistent, glanceable information that users can track without opening your app.

The module handles token registration, activity lifecycle management, and push notification delivery automatically. It supports both custom activity attributes and a default configuration for cross-platform scenarios.

> Important: Call ``PushwooshLiveActivitiesImplementationSetup/setup(_:)`` for every attributes type your app uses **at launch** (in `application(_:didFinishLaunchingWithOptions:)` or the SwiftUI `App.init`), not lazily when a screen appears. Only a type registered in the current session is reconnected to its already-running activities so their push token can be re-uploaded after a cold start — for example an activity that started, or was scheduled to start, while the app was terminated. A type registered later (e.g. in a view's `onAppear`) can't receive remote updates until that screen is opened. ActivityKit exposes running activities only through the concrete `Activity<Attributes>` generic and does not persist the set of types across launches, so the SDK cannot reconnect a type it hasn't been told about this session. The call is idempotent — registering at launch and again per-screen is safe.

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
