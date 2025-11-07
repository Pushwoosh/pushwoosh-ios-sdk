//
//  PushwooshLiveActivityAttributes.swift
//  Pushwoosh
//
//  Created by André Kis on 08.08.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#if !targetEnvironment(macCatalyst) && os(iOS)

import Foundation
import ActivityKit

/// Protocol for defining custom Live Activity attributes.
///
/// Conform to this protocol when creating custom Live Activity attributes for use with Pushwoosh.
/// Your custom attributes structure must include the `pushwoosh` property for activity tracking.
///
/// ## Example
///
/// ```swift
/// struct FoodDeliveryAttributes: PushwooshLiveActivityAttributes {
///     var pushwoosh: PushwooshLiveActivityAttributeData
///     var orderNumber: String
///     var restaurantName: String
///
///     struct ContentState: PushwooshLiveActivityContentState {
///         var pushwoosh: PushwooshLiveActivityContentStateData?
///         var status: String
///         var estimatedTime: String
///     }
/// }
/// ```
@available(iOS 16.1, *)
public protocol PushwooshLiveActivityAttributes: ActivityAttributes where ContentState: PushwooshLiveActivityContentState {
    /// Pushwoosh-specific metadata required for activity tracking.
    ///
    /// This property stores the unique activity ID that Pushwoosh uses to target push notification
    /// updates to specific Live Activity instances. Set this value when creating a new activity.
    var pushwoosh: PushwooshLiveActivityAttributeData { get set }
}

/// Pushwoosh-specific metadata required for Live Activity tracking.
public struct PushwooshLiveActivityAttributeData: Codable {
    /// The unique identifier for this Live Activity instance.
    public var activityId: String

    /// Creates Live Activity metadata with the specified activity ID.
    public init(activityId: String) {
        self.activityId = activityId
    }

    /// Creates Live Activity metadata with the specified activity ID.
    public static func create(activityId: String) -> PushwooshLiveActivityAttributeData {
        return PushwooshLiveActivityAttributeData(activityId: activityId)
    }
}

/// Protocol for defining Live Activity content state.
///
/// Conform to this protocol when defining the content state for your Live Activity.
/// The content state represents dynamic data that can be updated via push notifications.
///
/// ## Example
///
/// ```swift
/// struct FoodDeliveryAttributes: PushwooshLiveActivityAttributes {
///     // ...
///
///     struct ContentState: PushwooshLiveActivityContentState {
///         var pushwoosh: PushwooshLiveActivityContentStateData?
///         var status: String
///         var estimatedTime: String
///         var emoji: String
///     }
/// }
/// ```
@available(iOS 16.1, *)
public protocol PushwooshLiveActivityContentState: Codable, Hashable {
    /// Pushwoosh-specific metadata for content updates.
    ///
    /// This optional property is reserved for future Pushwoosh-specific content state metadata.
    /// Set to `nil` when creating initial content state, as it's managed automatically by the SDK.
    var pushwoosh: PushwooshLiveActivityContentStateData? { get set }
}

/// Pushwoosh-specific metadata for Live Activity content state updates.
public struct PushwooshLiveActivityContentStateData: Codable, Hashable {}
#endif
