//
//  PushwooshLiveActivityAttributes.swift
//  Pushwoosh
//
//  Created by André Kis on 08.08.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#if !targetEnvironment(macCatalyst)
import Foundation
import ActivityKit

@available(iOS 16.1, *)
public protocol PushwooshLiveActivityAttributes: ActivityAttributes where ContentState: PushwooshLiveActivityContentState {
    var pushwoosh: PushwooshLiveActivityAttributeData { get set }
}

public struct PushwooshLiveActivityAttributeData: Codable {
    public var activityId: String
    
    public init(activityId: String) {
        self.activityId = activityId
    }
    
    public static func create(activityId: String) -> PushwooshLiveActivityAttributeData {
        return PushwooshLiveActivityAttributeData(activityId: activityId)
    }
}

@available(iOS 16.1, *)
public protocol PushwooshLiveActivityContentState: Codable, Hashable {
    var pushwoosh: PushwooshLiveActivityContentStateData? { get set }
}

public struct PushwooshLiveActivityContentStateData: Codable, Hashable {}
#endif
