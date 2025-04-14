//
//  PWLiveActivitiesStub.swift
//  PushwooshOSCore
//
//  Created by André Kis on 04.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation

public class PWStubLiveActivities: NSObject, PWLiveActivities {
            
    @objc
    public static func liveActivities() -> AnyClass {
        return PWStubLiveActivities.self
    }
    
    public static func sendPushToStartLiveActivity(token: String) {
        print("PushwooshLiveActivities not found. To enable Live Activities features, make sure the PushwooshLiveActivities module is added to the project.")
    }
    
    public static func sendPushToStartLiveActivity(token: String, completion: @escaping (Error?) -> Void) {
        print("PushwooshLiveActivities not found. To enable Live Activities features, make sure the PushwooshLiveActivities module is added to the project.")
    }
    
    public static func startLiveActivity(token: String, activityId: String) {
        print("PushwooshLiveActivities not found. To enable Live Activities features, make sure the PushwooshLiveActivities module is added to the project.")
    }
    
    public static func startLiveActivity(token: String, activityId: String, completion: @escaping (Error?) -> Void) {
        print("PushwooshLiveActivities not found. To enable Live Activities features, make sure the PushwooshLiveActivities module is added to the project.")
    }
    
    public static func stopLiveActivity() {
        print("PushwooshLiveActivities not found. To enable Live Activities features, make sure the PushwooshLiveActivities module is added to the project.")
    }
    
    public static func stopLiveActivity(completion: @escaping (Error?) -> Void) {
        print("PushwooshLiveActivities not found. To enable Live Activities features, make sure the PushwooshLiveActivities module is added to the project.")
    }
    
    public static func stopLiveActivity(activityId: String) {
        print("PushwooshLiveActivities not found. To enable Live Activities features, make sure the PushwooshLiveActivities module is added to the project.")
    }
    
    public static func stopLiveActivity(activityId: String, completion: @escaping (Error?) -> Void) {
        print("PushwooshLiveActivities not found. To enable Live Activities features, make sure the PushwooshLiveActivities module is added to the project.")
    }
}
