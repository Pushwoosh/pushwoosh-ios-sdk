
# <a name="heading"></a>class PushNotificationManager : NSObject  
PushNotificationManager class offers access to the singleton-instance of the push manager responsible for registering the device with the APS servers, receiving and processing push notifications.<br/>Deprecated. Use Pushwoosh class instead. 
## Members  

<table>
	<tr>
		<td><a href="#1a1fb29b36aacb5c9f9eabea5c8334f542">@property NSString *appCode</a></td>
	</tr>
	<tr>
		<td><a href="#1a8eba2b041b2b7ff0c369bc3e05e110ab">@property NSString *appName</a></td>
	</tr>
	<tr>
		<td><a href="#1a1dd1fab95d86d79a3a104f15b7296c4c">@property NSObject&lt;PushNotificationDelegate&gt; *delegate</a></td>
	</tr>
	<tr>
		<td><a href="#1a5caa8c890155ec74ec76549481b3b65e">@property NSDictionary *launchNotification</a></td>
	</tr>
	<tr>
		<td><a href="#1a28eef8ff3f8f16ebdcae90dabd2659c7">@property NSString *language</a></td>
	</tr>
	<tr>
		<td><a href="#1aef1303a6ee34073d2a5efcfdfd5e0c29">+ (void)initializeWithAppCode:(NSString *)appCode appName:(NSString *)appName</a></td>
	</tr>
	<tr>
		<td><a href="#1abd27a7028f103b88b0d9f4d8dea6631f">+ (PushNotificationManager *)pushManager</a></td>
	</tr>
	<tr>
		<td><a href="#1abaf502c205606d4fd359a20972e0580a">+ (NSMutableDictionary *)getRemoteNotificationStatus</a></td>
	</tr>
	<tr>
		<td><a href="#1a0b712026b2f4c08cbf8fff89b696f311">+ (void)clearNotificationCenter</a></td>
	</tr>
	<tr>
		<td><a href="#1a89cdae8030efe1edc0637bd9b37ffedb">+ (BOOL)isPushwooshMessage:(NSDictionary *)userInfo</a></td>
	</tr>
	<tr>
		<td><a href="#1abad961781957bdc51cbe48fc878a4ae3">- (void)registerForPushNotifications</a></td>
	</tr>
	<tr>
		<td><a href="#1a6f37674fd1036c135959565db23c6b9f">- (void)unregisterForPushNotificationsWithCompletion:(void(^)(NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a94a513b4f9d415374a23007330393fff">- (void)unregisterForPushNotifications</a></td>
	</tr>
	<tr>
		<td><a href="#1a6c9468cefeba80ee99fd8b03e8c11ca3">- (instancetype)initWithApplicationCode:(NSString *)appCode appName:(NSString *)appName</a></td>
	</tr>
	<tr>
		<td><a href="#1ab0742d0b90fec4cb6d99798a75d96947">- (void)setTags:(NSDictionary *)tags</a></td>
	</tr>
	<tr>
		<td><a href="#1a7e59d285b7a24808f632c892fc2f4cc7">- (void)setTags:(NSDictionary *)tags withCompletion:(void(^)(NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1af40e55285458a076cfc3fda863994ea8">- (void)loadTags</a></td>
	</tr>
	<tr>
		<td><a href="#1a14eb90b86883c1212a9afe59b5e83573">- (void)loadTags:(PushwooshGetTagsHandler)successHandler error:(PushwooshErrorHandler)errorHandler</a></td>
	</tr>
	<tr>
		<td><a href="#1a4cd6ec2302bebac9ffcb229eae5d6a59">- (void)sendAppOpen</a></td>
	</tr>
	<tr>
		<td><a href="#1abdb441794f0b85cfe15093684ec7dd11">- (NSString *)getPushToken</a></td>
	</tr>
	<tr>
		<td><a href="#1a20d2965e0e61fe71298606b9a0172d6b">- (NSString *)getHWID</a></td>
	</tr>
	<tr>
		<td><a href="#1a181bdb41cdd4419884d65c94a8ad912c">- (void)handlePushRegistration:(NSData *)devToken</a></td>
	</tr>
	<tr>
		<td><a href="#1afc15aecaa50e6127db3cc33a1d5155d1">- (void)handlePushRegistrationString:(NSString *)deviceID</a></td>
	</tr>
	<tr>
		<td><a href="#1a0251da98b4cb853e452d85988fb5b7d7">- (void)handlePushRegistrationFailure:(NSError *)error</a></td>
	</tr>
	<tr>
		<td><a href="#1a90302222210e3de8c1fb2e327688c6ed">- (BOOL)handlePushReceived:(NSDictionary *)userInfo</a></td>
	</tr>
	<tr>
		<td><a href="#1a039c586600ee9e576d71a11800853b49">- (void)handlePushAccepted:(NSDictionary *)userInfo onStart:(BOOL)onStart</a></td>
	</tr>
	<tr>
		<td><a href="#1ab29c158f17a957eb0e9b317903c9123a">- (NSDictionary *)getApnPayload:(NSDictionary *)pushNotification</a></td>
	</tr>
	<tr>
		<td><a href="#1ab5443fd59a891bb0be79aecbd604ba15">- (NSString *)getCustomPushData:(NSDictionary *)pushNotification</a></td>
	</tr>
	<tr>
		<td><a href="#1ab839038d0ab2dfbda8dc49ef4e6d6072">- (NSDictionary *)getCustomPushDataAsNSDict:(NSDictionary *)pushNotification</a></td>
	</tr>
	<tr>
		<td><a href="#1ad51b323a64cbedb408442f9b52cc39fd">- (void)setUserId:(NSString *)userId</a></td>
	</tr>
	<tr>
		<td><a href="#1a29202bbfdffb17469dfe29da72a506f8">- (void)mergeUserId:(NSString *)oldUserId to:(NSString *)newUserId doMerge:(BOOL)doMerge completion:(void(^)(NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a9c072f15aff83a03fb6dc4a0dd2f9ec7">- (void)postEvent:(NSString *)event withAttributes:(NSDictionary *)attributes completion:(void(^)(NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a8a9ad34df75ba18b7bfc13e2a775be34">- (void)postEvent:(NSString *)event withAttributes:(NSDictionary *)attributes</a></td>
	</tr>
</table>


----------  
  

#### <a name="1a1fb29b36aacb5c9f9eabea5c8334f542"></a>@property NSString \*appCode  
Pushwoosh Application ID. Usually retrieved automatically from Info.plist parameter Pushwoosh\_APPID

----------  
  

#### <a name="1a8eba2b041b2b7ff0c369bc3e05e110ab"></a>@property NSString \*appName  
Application name. Usually retrieved automatically from Info.plist bundle name (CFBundleDisplayName). Could be used to override bundle name. In addition could be set in Info.plist as Pushwoosh\_APPNAME parameter. 

----------  
  

#### <a name="1a1dd1fab95d86d79a3a104f15b7296c4c"></a>@property NSObject&lt;<a href="PushNotificationDelegate-p.md">PushNotificationDelegate</a>&gt; \*delegate  
PushNotificationDelegate protocol delegate that would receive the information about events for push notification manager such as registering with APS services, receiving push notifications or working with the received notification. Pushwoosh Runtime sets it to ApplicationDelegate by default 

----------  
  

#### <a name="1a5caa8c890155ec74ec76549481b3b65e"></a>@property NSDictionary \*launchNotification  
Returns push notification payload if the app was started in response to push notification or null otherwise 

----------  
  

#### <a name="1a28eef8ff3f8f16ebdcae90dabd2659c7"></a>@property NSString \*language  
Set custom application language. Must be a lowercase two-letter code according to ISO-639-1 standard ("en", "de", "fr", etc.). Device language used by default. Set to nil if you want to use device language again. 

----------  
  

#### <a name="1aef1303a6ee34073d2a5efcfdfd5e0c29"></a>+ (void)initializeWithAppCode:(NSString \*)appCode appName:(NSString \*)appName  
Initializes PushNotificationManager. Usually called by Pushwoosh Runtime internally. <br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>appCode</strong></td>
		<td>Pushwoosh App ID. </td>
	</tr>
	<tr>
		<td><strong>appName</strong></td>
		<td>Application name. </td>
	</tr>
</table>


----------  
  

#### <a name="1abd27a7028f103b88b0d9f4d8dea6631f"></a>+ (<a href="#heading">PushNotificationManager</a> \*)pushManager  
Returns an object representing the current push manager.<br/><br/><br/><strong>Returns</strong> A singleton object that represents the push manager. 

----------  
  

#### <a name="1abaf502c205606d4fd359a20972e0580a"></a>+ (NSMutableDictionary \*)getRemoteNotificationStatus  
Returns dictionary with enabled remove notificaton types.<br/>Example enabled push: 
```Objective-C
{
   enabled = 1;
   pushAlert = 1;
   pushBadge = 1;
   pushSound = 1;
   type = 7;
}
```
 where "type" field is UIUserNotificationType<br/>Disabled push: 
```Objective-C
{
   enabled = 1;
   pushAlert = 0;
   pushBadge = 0;
   pushSound = 0;
   type = 0;
}
```
<br/>Note: In the latter example "enabled" field means that device can receive push notification but could not display alerts (ex: silent push) 

----------  
  

#### <a name="1a0b712026b2f4c08cbf8fff89b696f311"></a>+ (void)clearNotificationCenter  
Clears the notifications from the notification center. 

----------  
  

#### <a name="1a89cdae8030efe1edc0637bd9b37ffedb"></a>+ (BOOL)isPushwooshMessage:(NSDictionary \*)userInfo  


----------  
  

#### <a name="1abad961781957bdc51cbe48fc878a4ae3"></a>- (void)registerForPushNotifications  
Registers for push notifications. By default registeres for "UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert" flags. Automatically detects if you have "newsstand-content" in "UIBackgroundModes" and adds "UIRemoteNotificationTypeNewsstandContentAvailability" flag. 

----------  
  

#### <a name="1a6f37674fd1036c135959565db23c6b9f"></a>- (void)unregisterForPushNotificationsWithCompletion:(void(^)(NSError \*error))completion  
Unregisters from push notifications. 

----------  
  

#### <a name="1a94a513b4f9d415374a23007330393fff"></a>- (void)unregisterForPushNotifications  
Deprecated. Use unregisterForPushNotificationsWithCompletion: method instead 

----------  
  

#### <a name="1a6c9468cefeba80ee99fd8b03e8c11ca3"></a>- (instancetype)initWithApplicationCode:(NSString \*)appCode appName:(NSString \*)appName  
Deprecated. Use initializeWithAppCode:appName: method instead 

----------  
  

#### <a name="1ab0742d0b90fec4cb6d99798a75d96947"></a>- (void)setTags:(NSDictionary \*)tags  
Send tags to server. Tag names have to be created in the Pushwoosh Control Panel. Possible tag types: Integer, String, Incremental (integer only), List tags (array of values).<br/>Example: 
```Objective-C
NSDictionary *tags =  @{ @"Alias" : aliasField.text,
                     @"FavNumber" : @([favNumField.text intValue]),
                         @"price" : [PWTags incrementalTagWithInteger:5],
                          @"List" : @[ @"Item1", @"Item2", @"Item3" ]
};
   
[[PushNotificationManager pushManager] setTags:tags];
```
<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>tags</strong></td>
		<td>Dictionary representation of tags to send. </td>
	</tr>
</table>


----------  
  

#### <a name="1a7e59d285b7a24808f632c892fc2f4cc7"></a>- (void)setTags:(NSDictionary \*)tags withCompletion:(void(^)(NSError \*error))completion  
Send tags to server with completion block. If setTags succeeds competion is called with nil argument. If setTags fails completion is called with error. 

----------  
  

#### <a name="1af40e55285458a076cfc3fda863994ea8"></a>- (void)loadTags  
Get tags from the server. Calls delegate method onTagsReceived: or onTagsFailedToReceive: depending on the results. 

----------  
  

#### <a name="1a14eb90b86883c1212a9afe59b5e83573"></a>- (void)loadTags:(PushwooshGetTagsHandler)successHandler error:(PushwooshErrorHandler)errorHandler  
Get tags from server. Calls delegate method if exists and handler (block).<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>successHandler</strong></td>
		<td>The block is executed on the successful completion of the request. This block has no return value and takes one argument: the dictionary representation of the recieved tags. Example of the dictionary representation of the received tags: { Country = ru; Language = ru; } </td>
	</tr>
	<tr>
		<td><strong>errorHandler</strong></td>
		<td>The block is executed on the unsuccessful completion of the request. This block has no return value and takes one argument: the error that occurred during the request. </td>
	</tr>
</table>


----------  
  

#### <a name="1a4cd6ec2302bebac9ffcb229eae5d6a59"></a>- (void)sendAppOpen  
Informs the Pushwoosh about the app being launched. Usually called internally by SDK Runtime. 

----------  
  

#### <a name="1abdb441794f0b85cfe15093684ec7dd11"></a>- (NSString \*)getPushToken  
Gets current push token.<br/><br/><br/><strong>Returns</strong> Current push token. May be nil if no push token is available yet. 

----------  
  

#### <a name="1a20d2965e0e61fe71298606b9a0172d6b"></a>- (NSString \*)getHWID  
Gets HWID. Unique device identifier that used in all API calls with Pushwoosh. This is identifierForVendor for iOS &gt;= 7.<br/><br/><br/><strong>Returns</strong> Unique device identifier. 

----------  
  

#### <a name="1a181bdb41cdd4419884d65c94a8ad912c"></a>- (void)handlePushRegistration:(NSData \*)devToken  


----------  
  

#### <a name="1afc15aecaa50e6127db3cc33a1d5155d1"></a>- (void)handlePushRegistrationString:(NSString \*)deviceID  


----------  
  

#### <a name="1a0251da98b4cb853e452d85988fb5b7d7"></a>- (void)handlePushRegistrationFailure:(NSError \*)error  


----------  
  

#### <a name="1a90302222210e3de8c1fb2e327688c6ed"></a>- (BOOL)handlePushReceived:(NSDictionary \*)userInfo  


----------  
  

#### <a name="1a039c586600ee9e576d71a11800853b49"></a>- (void)handlePushAccepted:(NSDictionary \*)userInfo onStart:(BOOL)onStart  


----------  
  

#### <a name="1ab29c158f17a957eb0e9b317903c9123a"></a>- (NSDictionary \*)getApnPayload:(NSDictionary \*)pushNotification  
Gets APN payload from push notifications dictionary.<br/>Example: 
```Objective-C
- (void)onPushAccepted:(PushNotificationManager *)pushManager withNotification:(NSDictionary *)pushNotification onStart:(BOOL)onStart {
    NSDictionary * apnPayload = [[PushNotificationsManager pushManager] getApnPayload:pushNotification];
    NSLog(@"%@", apnPayload);
}
```
<br/>For Push dictionary sample: 
```Objective-C
{
    aps =     {
        alert = "Some text.";
        sound = default;
    };
    p = 1pb;
}
```
<br/>Result is: 
```Objective-C
{
    alert = "Some text.";
    sound = default;
};
```
<br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>pushNotification</strong></td>
		<td>Push notifications dictionary as received in onPushAccepted: withNotification: onStart:</td>
	</tr>
</table>


----------  
  

#### <a name="1ab5443fd59a891bb0be79aecbd604ba15"></a>- (NSString \*)getCustomPushData:(NSDictionary \*)pushNotification  
Gets custom JSON string data from push notifications dictionary as specified in Pushwoosh Control Panel.<br/>Example: 
```Objective-C
- (void)onPushAccepted:(PushNotificationManager *)pushManager withNotification:(NSDictionary *)pushNotification onStart:(BOOL)onStart {
    NSString * customData = [[PushNotificationsManager pushManager] getCustomPushData:pushNotification];
    NSLog(@"%@", customData);
}
```
<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>pushNotification</strong></td>
		<td>Push notifications dictionary as received in onPushAccepted: withNotification: onStart:</td>
	</tr>
</table>


----------  
  

#### <a name="1ab839038d0ab2dfbda8dc49ef4e6d6072"></a>- (NSDictionary \*)getCustomPushDataAsNSDict:(NSDictionary \*)pushNotification  
The same as getCustomPushData but returns NSDictionary rather than JSON string (converts JSON string into NSDictionary). 

----------  
  

#### <a name="1ad51b323a64cbedb408442f9b52cc39fd"></a>- (void)setUserId:(NSString \*)userId  
Set User indentifier. This could be Facebook ID, username or email, or any other user ID. This allows data and events to be matched across multiple user devices.<br/>Deprecated. Use PWInAppManager setUserId method instead 

----------  
  

#### <a name="1a29202bbfdffb17469dfe29da72a506f8"></a>- (void)mergeUserId:(NSString \*)oldUserId to:(NSString \*)newUserId doMerge:(BOOL)doMerge completion:(void(^)(NSError \*error))completion  
Move all events from oldUserId to newUserId if doMerge is true. If doMerge is false all events for oldUserId are removed.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>oldUserId</strong></td>
		<td>source user </td>
	</tr>
	<tr>
		<td><strong>newUserId</strong></td>
		<td>destination user </td>
	</tr>
	<tr>
		<td><strong>doMerge</strong></td>
		<td>if false all events for oldUserId are removed, if true all events for oldUserId are moved to newUserId </td>
	</tr>
	<tr>
		<td><strong>completion</strong></td>
		<td>callback</td>
	</tr>
</table>

Deprecated. Use PWInAppManager mergeUserId method instead 

----------  
  

#### <a name="1a9c072f15aff83a03fb6dc4a0dd2f9ec7"></a>- (void)postEvent:(NSString \*)event withAttributes:(NSDictionary \*)attributes completion:(void(^)(NSError \*error))completion  
Post events for In-App Messages. This can trigger In-App message display as specified in Pushwoosh Control Panel.<br/>Example: 
```Objective-C
[[PushNotificationManager pushManager] setUserId:@"96da2f590cd7246bbde0051047b0d6f7"];
[[PushNotificationManager pushManager] postEvent:@"buttonPressed" withAttributes:@{ @"buttonNumber" : @"4", @"buttonLabel" : @"Banner" } completion:nil];
```
<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>event</strong></td>
		<td>name of the event </td>
	</tr>
	<tr>
		<td><strong>attributes</strong></td>
		<td>NSDictionary of event attributes </td>
	</tr>
	<tr>
		<td><strong>completion</strong></td>
		<td>function to call after posting event</td>
	</tr>
</table>

Deprecated. Use PWInAppManager postEvent method instead 

----------  
  

#### <a name="1a8a9ad34df75ba18b7bfc13e2a775be34"></a>- (void)postEvent:(NSString \*)event withAttributes:(NSDictionary \*)attributes  
See postEvent:withAttributes:completion:<br/>Deprecated. Use PWInAppManager postEvent method instead 