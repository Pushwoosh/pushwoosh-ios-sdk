//
//  AppDelegate.swift
//  PushNotificationsApp
//
//  Created by User on 30/10/15.
//
//

import UIKit
import Pushwoosh

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, PWMessagingDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        //initialization code
        //set custom delegate for push handling, in our case AppDelegate
        Pushwoosh.sharedInstance()?.delegate = self;
        
        //register for push notifications!
        Pushwoosh.sharedInstance()?.registerForPushNotifications()
        
        return true
    }
    
    //handle token received from APNS
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Pushwoosh.sharedInstance()?.handlePushRegistration(deviceToken)
    }
    
    //handle token receiving error
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Pushwoosh.sharedInstance()?.handlePushRegistrationFailure(error);
    }
    
    //this is for iOS < 10 and for silent push notifications
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Pushwoosh.sharedInstance()?.handlePushReceived(userInfo)
        completionHandler(.noData)
    }
    
    //this event is fired when the push gets received
    func pushwoosh(_ pushwoosh: Pushwoosh!, onMessageReceived message: PWMessage!) {
        print("onMessageReceived: ", message.payload.description)
    }
    
    //this event is fired when user taps the notification
    func pushwoosh(_ pushwoosh: Pushwoosh!, onMessageOpened message: PWMessage!) {
        print("onMessageOpened: ", message.payload.description)
    }
}

