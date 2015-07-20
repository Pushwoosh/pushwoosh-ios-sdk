# PushNotificationManager #

PushNotificationManager class offers access to the singletone-instance of the push manager responsible for registering the device with the APS servers, receiving and processing push notifications.

## Tasks
[appCode](#appcode) *property*  
[appName](#appname) *property*  
[delegate](#delegate) *property*  
[showPushnotificationAlert](#showpushnotificationalert) *property*  
[launchNotification](#launchnotification) *property*  

[+ initializeWithAppCode:appName:](#initializewithappcodeappname)  
[+ pushManager](#pushmanager)  
[– registerForPushNotifications](#registerforpushnotifications)  
[– unregisterForPushNotifications](#unregisterforpushnotifications)  
[– startLocationTracking](#startlocationtracking)  
[– stopLocationTracking](#startbeacontracking)  
[– startBeaconTracking](#startbeacontracking)  
[– stopBeaconTracking](#stopbeacontracking)  
[– setTags:](#settags)  
[- setTags:withCompletion:](#settagswithcompletion)
[– loadTags](#loadtags)  
[– loadTags:error:](#loadtagserror)  
[– sendAppOpen](#sendappopen)  
[– sendBadges:](#sendbadges)  
[– sendSKPaymentTransactions:](#sendskpaymenttransactions)  
[– sendPurchase:withPrice:currencyCode:andDate:](#sendpurchasewithpricecurrencycodeanddate)  
[– getPushToken](#getpushtoken)  
[– getHWID](#gethwid)  
[– getApnPayload:](#getapnpayload)  
[– getCustomPushData:](#getcustompushdata)  
[– getCustomPushDataAsNSDict:](#getcustompushdataasnsdict)  
[+ getRemoteNotificationStatus](#getremotenotificationstatus)  
[+ clearNotificationCenter](#clearnotificationcenter)  


## Properties


### appCode

Pushwoosh Application ID. Usually retrieved automatically from `Info.plist` parameter `Pushwoosh_APPID`


```objc
@property (nonatomic, copy) NSString *appCode
```


### appName

Application name. Usually retrieved automatically from `Info.plist` bundle name (CFBundleDisplayName). Could be used to override bundle name. In addition could be set in `Info.plist` as `Pushwoosh_APPNAME` parameter.


```objc
@property (nonatomic, copy) NSString *appName
```

Example logic from Pushwoosh SDK Runtime:

```objc
NSString * appname = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"Pushwoosh_APPNAME"];
if(!appname)
	appname = [[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_APPNAME"];

if(!appname)
	appname = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];

if(!appname)
	appname = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];

if(!appname) {
	appname = @"";
}

instance = [[PushNotificationManager alloc] initWithApplicationCode:appid appName:appname ];
```


### delegate

PushNotificationDelegate protocol delegate that would receive the information about events for push notification manager such as registering with APS services, receiving push notifications or working with the received notification. Pushwoosh Runtime sets it to ApplicationDelegate by default


```objc
@property (nonatomic, assign) NSObject<PushNotificationDelegate> *delegate
```


### launchNotification

Returns push notification payload if the app was started in response to push notification or null otherwise

```objc
@property (nonatomic, copy, readonly) NSDictionary *launchNotification
```


### showPushnotificationAlert

Show push notifications alert when push notification is received while the app is running, default is YES

```objc
@property (nonatomic, assign) BOOL showPushnotificationAlert
```

## Class Methods


### clearNotificationCenter

Clears the notifications from the notification center.

```objc
+ (void)clearNotificationCenter
```


### getRemoteNotificationStatus

Returns dictionary with enabled remove notificaton types.  
Enabled push example:  
```
{
	enabled = 1;
	pushAlert = 1;
	pushBadge = 1;
	pushSound = 1;
	type = 7;
}
```
where “type” field is UIUserNotificationType  

Disabled push example:
```
{
	enabled = 1;
	pushAlert = 0;
	pushBadge = 0;
	pushSound = 0;
	type = 0;
}
```
Note: In the latter example “enabled” field means that device can receive push notification but could not display alerts (ex: silent push)

```objc
+ (NSMutableDictionary *)getRemoteNotificationStatus
```


### initializeWithAppCode:appName:

Initializes PushNotificationManager. Usually called by Pushwoosh Runtime internally.

* **appName** - Application name.
* **appcCode** - Pushwoosh App ID.

```objc
+ (void)initializeWithAppCode:(NSString *)appCode appName:(NSString *)appName
```

### pushManager

Returns an object representing the current push manager.

* **Return Value** - A singleton object that represents the push manager.

```objc
+ (PushNotificationManager *)pushManager
```

## Instance Methods

### getApnPayload:

Gets APN payload from push notifications dictionary.

```objc
- (NSDictionary *)getApnPayload:(NSDictionary *)pushNotification
```

* **pushNotification** - Push notifications dictionary as received in `onPushAccepted: withNotification: onStart:`

Example:
```objc
- (void) onPushAccepted:(PushNotificationManager *)pushManager withNotification:(NSDictionary *)pushNotification onStart:(BOOL)onStart {
    NSDictionary * apnPayload = [[PushNotificationsManager pushManager] getApnPayload:pushNotification];
    NSLog(@"%@", apnPayload);
}
```

For Push dictionary sample:
```
{
    aps =     {
        alert = "Some text.";
        sound = default;
    };
    p = 1pb;
}
```

Result is:
```
{
    alert = "Some text.";
    sound = default;
}
```

### getCustomPushData:

Gets custom JSON string data from push notifications dictionary as specified in Pushwoosh Control Panel.

```objc
- (NSString *)getCustomPushData:(NSDictionary *)pushNotification
```

* **pushNotification** - Push notifications dictionary as received in `onPushAccepted: withNotification: onStart:`

Example:
```objc
- (void) onPushAccepted:(PushNotificationManager *)pushManager withNotification:(NSDictionary *)pushNotification onStart:(BOOL)onStart {
    NSString * customData = [[PushNotificationsManager pushManager] getCustomPushData:pushNotification];
    NSLog(@"%@", customData);
}
```

### getCustomPushDataAsNSDict:

The same as `getCustomPushData:` but returns NSDictionary rather than JSON string (converts JSON string into NSDictionary).

```objc
- (NSDictionary *)getCustomPushDataAsNSDict:(NSDictionary *)pushNotification
```

### getHWID

Gets HWID. Unique device identifier that used in all API calls with Pushwoosh. This is identifierForVendor for iOS >= 7.

```objc
- (NSString *)getHWID
```

* **Return Value** - Unique device identifier.

### getPushToken

Gets current push token.

```objc
- (NSString *)getPushToken
```

* **Return Value** - Current push token. May be nil if no push token is available yet.

### loadTags

Get tags from the server. Calls `delegate` method `onTagsReceived:` or `onTagsFailedToReceive:` depending on the results.

```objc
- (void)loadTags
```

### loadTags:error:

Get tags from server. Calls `delegate` method if exists and handler (block).

```objc
- (void)loadTags:(pushwooshGetTagsHandler)successHandler error:(pushwooshErrorHandler)errorHandler
```

* **successHandler** - The block is executed on the successful completion of the request. This block has no return value and takes one argument: the dictionary representation of the recieved tags. Example of the dictionary representation of the received tags:
```
{
    Country = us;
    Language = en;
}
```
* **errorHandler** - The block is executed on the unsuccessful completion of the request. This block has no return value and takes one argument: the error that occurred during the request.

### registerForPushNotifications

Registers for push notifications. By default registeres for `UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert` flags. Automatically detects if you have `newsstand-content` in `UIBackgroundModes` and adds `UIRemoteNotificationTypeNewsstandContentAvailability` flag.

```objc
- (void)registerForPushNotifications
```

### sendAppOpen

Informs the Pushwoosh about the app being launched. Usually called internally by SDK Runtime.

```objc
- (void)sendAppOpen
```

### sendBadges:

Sends current badge value to server. Called internally by SDK Runtime when `UIApplication setApplicationBadgeNumber:` is set. This function is used for “auto-incremeting” badges to work. This way Pushwoosh server can know what current badge value is set for the application.

```objc
- (void)sendBadges:(NSInteger)badge
```

### sendPurchase:withPrice:currencyCode:andDate:

Tracks individual in-app purchase. See recommended `sendSKPaymentTransactions:` method.

```objc
- (void)sendPurchase:(NSString *)productIdentifier withPrice:(NSDecimalNumber *)price currencyCode:(NSString *)currencyCode andDate:(NSDate *)date
```

### sendSKPaymentTransactions:

Sends in-app purchases to Pushwoosh. Use in `paymentQueue:updatedTransactions:` payment queue method (see example).

```objc
- (void)sendSKPaymentTransactions:(NSArray *)transactions
```

* **transactions** - Array of SKPaymentTransaction items as received in the payment queue.

Example:
```objc
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
   [[PushNotificationManager pushManager] sendSKPaymentTransactions:transactions];
}
```

### setTags:

Send tags to server. Tag names have to be created in the Pushwoosh Control Panel. Possible tag types: Integer, String, Incremental (integer only), List tags (array of values).

```objc
- (void)setTags:(NSDictionary *)tags
```

* **tags** - Dictionary representation of tags to send.

Example:
```objc
NSDictionary *tags = [NSDictionary dictionaryWithObjectsAndKeys:
                         aliasField.text, @"Alias",
                         [NSNumber numberWithInt:[favNumField.text intValue]], @"FavNumber",
                         [PWTags incrementalTagWithInteger:5], @"price",
                         [NSArray arrayWithObjects:@"Item1", @"Item2", @"Item3", nil], @"List",
                         nil];

[[PushNotificationManager pushManager] setTags:tags];
```

### setTags:withCompletion:

Send tags to server. Calls handler (block) when operation is finished.

```objc
- (void)setTags:(NSDictionary *)tags withCompletion:(void(^)(NSError* error))completion
```

### startLocationTracking:

Start location tracking.

```objc
- (void)startLocationTracking
```

### stopLocationTracking:

Stop location tracking.

```objc
- (void)stopLocationTracking
```

### startBeaconTracking:

Start iBeacon tracking.

```objc
- (void)startBeaconTracking
```

### stopBeaconTracking:

Stop iBeacon tracking.

```objc
- (void)stopBeaconTracking
```

### unregisterForPushNotifications:

Unregisters from push notifications. You should call this method in rare circumstances only, such as when a new version of the app drops support for remote notifications. Users can temporarily prevent apps from receiving remote notifications through the Notifications section of the Settings app. Apps unregistered through this method can always re-register.

```objc
- (void)unregisterForPushNotifications
```
