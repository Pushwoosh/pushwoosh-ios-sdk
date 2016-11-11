//
//  AppDelegate.swift
//  PushNotificationsApp
//
//  Created by User on 30/10/15.
//
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, PushNotificationDelegate {

	var window: UIWindow?


	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
		PushNotificationManager.push().delegate = self
		PushNotificationManager.push().handlePushReceived(launchOptions)
		PushNotificationManager.push().sendAppOpen()
		PushNotificationManager.push().registerForPushNotifications()
		return true
	}
	
	func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
		PushNotificationManager.push().handlePushRegistration(deviceToken as Data!)
	}
	
	func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
		PushNotificationManager.push().handlePushRegistrationFailure(error)
	}
	
	func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
		PushNotificationManager.push().handlePushReceived(userInfo)
	}
	
	func onPushAccepted(_ pushManager: PushNotificationManager!, withNotification pushNotification: [AnyHashable : Any]!, onStart: Bool) {
		print("Push notification accepted: \(pushNotification)")
	}
}

