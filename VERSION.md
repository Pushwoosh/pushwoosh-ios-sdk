Current version: 4.1.8
=========================
Pushwoosh iOS SDK 4.1.8

Fixed
    [onDidRegisterForRemoteNotificationsWithDeviceToken](https://github.com/Pushwoosh/pushwoosh-ios-sdk/blob/master/Documentation/PushNotificationDelegate.md#ondidregisterforremotenotificationswithdevicetoken) callback not called after application relaunch
Current version: 4.1.7
=========================
Pushwoosh iOS SDK 4.1.7

Fixed
    Incorrect base url for html pages (https://github.com/Pushwoosh/pushwoosh-ios-sdk/issues/53)
Current version: 4.1.6
=========================
Fixed subsequent push registration after unregistering for push notifications
Current version: 4.1.5
=========================
Fixed missing push notification callback when hash ("p") is not presented in notification payload
Current version: 4.1.4
=========================
Fixed unsafe PushNotificationDelegate reference
Fixed incorrect HWID when 'Limit Ad Tracking' is enabled
Current version: 4.1.3
=========================
iOS7 compatibility fix
https://github.com/Pushwoosh/pushwoosh-ios-sdk/issues/45
Current version: 4.1.2
=========================
Removed unused categories.
SDK linked with «Perform Single-Object Prelink» flag.
https://github.com/Pushwoosh/pushwoosh-ios-sdk/issues/39
Current version: 4.1.1
=========================
Change Pushwoosh API url to https://APP_CODE.api.pushwoosh.com/json/1.3
Current version: 4.1.0
=========================
Disable inapps rotation for portrait orientation
RequestManager stability fixes 
Register test devices using QR code
minor fixes
Current version: 4.0.10
=========================
Clear push token on unregister
Current version: 4.0.9
=========================
Preserve hwid across multiple app launches
https://github.com/Pushwoosh/pushwoosh-ios-sdk/issues/34
Current version: 4.0.8
=========================
Do not cache Pushwoosh hwid
Current version: 4.0.7
=========================
Push token change handling
Current version: 4.0.6
=========================
Send registerDevice on every launch
Current version: 4.0.5
=========================
Pushwoosh response parsing bugfixes
Current version: 4.0.4
=========================
Stability fixes
Current version: 4.0.3
=========================
Fix missing module cache warnings
Current version: 4.0.2
=========================
Fix for overwriting local notification categories
Current version: 4.0.1
=========================
Fix for early initialization of PushNotificationManager in plugins
Current version: 4.0.0
=========================
Rich Media support
Current version: 3.1.2
=========================
loadTags stability fixes
Current version: 3.1.1
=========================
Fixed lots of dSYM warnings
Current version: 3.1.0
=========================
Send default tags with applicationOpen request
Current version: 3.0.14
=========================
XCode 7.2 build
Current version: 3.0.13
=========================
DWARF+dSYM debug info
Current version: 3.0.13
=========================
Add armv7s arch
Current version: 3.0.12
=========================
Fixed https://github.com/Pushwoosh/pushwoosh-ios-sdk/issues/25
Current version: 3.0.11
=========================
Request log fixes
Info.plist documentation
Current version: 3.0.10
=========================
Fixed double alerts on iOS9
Updated html pages UI
Use cached tags by default
Current version: 3.0.9
=========================
Fixed https://github.com/Pushwoosh/pushwoosh-ios-sdk/issues/23
Current version: 3.0.8
=========================
mergeUserId method for In-App Messages
Current version: 3.0.7
=========================
Local cache for tags
Fixed opening links with redirects
Current version: 3.0.6
=========================
Fix for opening non-secure urls on iOS9
Current version: 3.0.5
=========================
Log level management
Fixed XCode 7 warnings
Current version: 3.0.4
=========================
XCode 7 GM build
Current version: 3.0.3
=========================
In-App Messages UI fixes
Platform statistics
Current version: 3.0.2
=========================
Publishing for cocoapods
Current version: 3.0.1
=========================
Publishing for cocoapods
Current version: 3.0.0
=========================
Publishing for cocoapods
Current version: 3.0.0
=========================
In-Apps and Events
setTags stability fix
Current version: 2.13.7
=========================
setTags completion handler
Current version: 2.13.6
=========================
Rich page bug fixes and back button handler
Current version: 2.13.5
=========================
exposing sendPurchase method and sendSKPaymentTransactions method
Current version: 2.13.4
=========================
native rich pages and landscape orientation - fixed possible crash
localization support for actions
Current version: 2.13.3
=========================
adding tag
Current version: 2.13.2
=========================
iOS: fixed possible crash on dev apps without icon.
Current version: 2.13.1
=========================
pushing to podspec integrated with CI
Current version: 2.13.0
=========================
iOS in-app banner style alerts
Current version: 2.12.4
=========================
Updated method signature to prevent possible Apple Validator confusion
Current version: 2.12.3
=========================
display alert about invalid profile only when registration for pushes has been called
Current version: 2.12.2
=========================
iOS possible empty token on first registration fix (was broken on last commit)
Current version: 2.12.1
=========================
improving geozone precision
Current version: 2.12.0
=========================
Improved geofencing algorithm
Current version: 2.11.1
=========================
Rich page does not overlay Video
Current version: 2.11.0
=========================
Critical update, possible issue on multiple setTags detected and fixed
Current version: 2.10.1
=========================
Fix: possible endless registration cycle due to conflict with other ObjC categories
Current version: 2.10.0
=========================
Automatic IAP stats tracking for iOS
Current version: 2.9.4
=========================
stop location tracking only when enabled
Current version: 2.9.3
=========================
Correct handling of push categories on iOS7
Current version: 2.9.2
=========================
Removed iBeacons support from default. Available per request.
Current version: 2.9.1
=========================
adding missing by XCode6 arvm7s architecture
Current version: 2.9.0
=========================
+ iOS8.0 support!
+ categories for iOS8.0 support (will work with new cp update)
Current version: 2.8.3
=========================
iOS rich pages fix
Current version: 2.8.2
=========================
accept string values for show alert info.plist setting
Current version: 2.8.1
=========================
minor fix persisting unique device ID
Current version: 2.8.0
=========================
iOS: Use advertisement identifier if AdSupport.framework linked, otherwise Vendor identifier. 
Current version: 2.7.0
=========================
SDK with new default tags supported!
Current version: 2.6.0
=========================
iBeacon support
Better GeoZones algorithm with higher precision and less battery consumption in background
Current version: 2.5.0
=========================
Rebuilding iOS SDK version 2.5.0

