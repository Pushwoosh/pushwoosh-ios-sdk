//
//  DefaultLiveActivityAttributes.swift
//  PushwooshiOS
//
//  Created by André Kis on 26.11.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#if !targetEnvironment(macCatalyst) && os(iOS)

/// A flexible structure for defining Live Activity content dynamically.
///
/// This structure is used when you want Pushwoosh SDK to manage the entire Live Activity lifecycle
/// without defining custom attribute structures. It's particularly useful for cross-platform applications
/// or when you have only one Live Activity widget.
///
/// All properties are dynamically defined as dictionaries in the `data` property, allowing flexible
/// content structures that can be defined entirely from push notification payloads.
///
/// ## Usage
///
/// 1. Call ``PushwooshLiveActivitiesImplementationSetup/defaultSetup()`` during app initialization
/// 2. Create a Widget Extension with `ActivityConfiguration` for `DefaultLiveActivityAttributes`
/// 3. Access content through `context.state.data` and `context.attributes.data` dictionaries
///
/// ## Example Widget
///
/// ```swift
/// ActivityConfiguration(for: DefaultLiveActivityAttributes.self) { context in
///     if let title = context.state.data["title"]?.value as? String {
///         Text(title)
///     }
/// }
/// ```
///
/// ## Push Notification Payloads
///
/// ### Start Activity
///
/// ```json
/// {
///   "live_activity": {
///     "event": "start",
///     "content-state": {
///       "data": {
///         "title": "Order #12345",
///         "status": "Preparing"
///       }
///     },
///     "attributes-type": "DefaultLiveActivityAttributes",
///     "attributes": {
///       "data": {
///         "orderNumber": "12345"
///       }
///     }
///   }
/// }
/// ```
///
/// ### Update Activity
///
/// ```json
/// {
///   "live_activity": {
///     "event": "update",
///     "content-state": {
///       "data": {
///         "status": "Ready for pickup"
///       }
///     },
///     "attributes-type": "DefaultLiveActivityAttributes"
///   }
/// }
/// ```
public struct DefaultLiveActivityAttributes: PushwooshLiveActivityAttributes {
    /// Dynamic attributes dictionary containing static activity data.
    public var data: [String: AnyCodable]

    /// Pushwoosh-specific metadata required for activity tracking.
    public var pushwoosh: PushwooshLiveActivityAttributeData

    /// Dynamic content state for the Live Activity.
    public struct ContentState: PushwooshLiveActivityContentState {
        /// Dynamic content dictionary containing updateable activity data.
        public var data: [String: AnyCodable]

        /// Pushwoosh-specific metadata for content updates.
        public var pushwoosh: PushwooshLiveActivityContentStateData?
    }
}
#endif
