
# <a name="heading"></a>class Pushwoosh : NSObject  
Pushwoosh class offers access to the singleton-instance of the push manager responsible for registering the device with the APS servers, receiving and processing push notifications. 
## Members  

<table>
	<tr>
		<td><a href="#1ad3eed702180c17050080e0df9ec1d3f6">@property NSString *applicationCode</a></td>
	</tr>
	<tr>
		<td><a href="#1a0f7cae72bb8d489c74d25a91147407ca">@property NSObject&lt;PWMessagingDelegate&gt; *delegate</a></td>
	</tr>
	<tr>
		<td><a href="#1a221ce364a31cffe798c0172c5a155b1d">@property NSDictionary *launchNotification</a></td>
	</tr>
	<tr>
		<td><a href="#1a42e773c001914bf76ed49a4e2828100a">@property PWNotificationCenterDelegateProxy *notificationCenterDelegateProxy</a></td>
	</tr>
	<tr>
		<td><a href="#1ad29805f70c2d90156603ca8d952f4060">@property NSString *language</a></td>
	</tr>
	<tr>
		<td><a href="#1aa517c7b582ca90591b1362eed7cac960">+ (void)initializeWithAppCode:(NSString *)appCode</a></td>
	</tr>
	<tr>
		<td><a href="#1a56604d5ec5713778ee74a249fab624f7">+ (instancetype)sharedInstance</a></td>
	</tr>
	<tr>
		<td><a href="#1a75a5f815795676a3bf003c8613b5f296">+ (NSString *)version</a></td>
	</tr>
	<tr>
		<td><a href="#1af5330c15b4af7f1ecbbf0f178a0c845d">+ (NSMutableDictionary *)getRemoteNotificationStatus</a></td>
	</tr>
	<tr>
		<td><a href="#1a8a34fd51f7987a3ed6725edf5c0d7ea7">+ (void)clearNotificationCenter</a></td>
	</tr>
	<tr>
		<td><a href="#1a5a5885f51ca841cb3a69fe7bbc19a081">- (void)registerForPushNotifications</a></td>
	</tr>
	<tr>
		<td><a href="#1a87649621d23de0c8a0de7f188d3587e9">- (void)registerForPushNotificationsWithCompletion:(PushwooshRegistrationHandler)completion</a></td>
	</tr>
	<tr>
		<td><a href="#1ac30104920e79607ee1b645911b7b0ef6">- (void)unregisterForPushNotifications</a></td>
	</tr>
	<tr>
		<td><a href="#1a748303ef70f2acb42f064e819566f68e">- (void)unregisterForPushNotificationsWithCompletion:(void(^)(NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a19bb8534c1ec1e22ada527c2fcfc1f93">- (void)handlePushRegistration:(NSData *)devToken</a></td>
	</tr>
	<tr>
		<td><a href="#1a2180719fd1f05032eecadaaae9eb0e31">- (void)handlePushRegistrationFailure:(NSError *)error</a></td>
	</tr>
	<tr>
		<td><a href="#1a9f488cd813fbc38716ff94b9b1818329">- (BOOL)handlePushReceived:(NSDictionary *)userInfo</a></td>
	</tr>
	<tr>
		<td><a href="#1aa6ffe7d71c784b048461ddb1c9f1e436">- (void)setReverseProxy:(NSString *)url</a></td>
	</tr>
	<tr>
		<td><a href="#1acc5ce9be719d84d3fcdd4939b10856bf">- (void)disableReverseProxy</a></td>
	</tr>
	<tr>
		<td><a href="#1a876d8250c9a9641e7daf77c277c31be7">- (void)setTags:(NSDictionary *)tags</a></td>
	</tr>
	<tr>
		<td><a href="#1a51e9882787068540d016c56b5ec5c50c">- (void)setTags:(NSDictionary *)tags completion:(void(^)(NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1af14c2945a66c1c7219bbc6ba9c84cb86">- (void)setEmailTags:(NSDictionary *)tags forEmail:(NSString *)email</a></td>
	</tr>
	<tr>
		<td><a href="#1a0ddd6f1d9e85253451fe1d5c5490294a">- (void)setEmailTags:(NSDictionary *)tags forEmail:(NSString *)email completion:(void(^)(NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a7451ea555a6f451c99f8508940c02edb">- (void)getTags:(PushwooshGetTagsHandler)successHandler onFailure:(PushwooshErrorHandler)errorHandler</a></td>
	</tr>
	<tr>
		<td><a href="#1a79fe3e5ad3167a9301d5e8a0ea2c1de9">- (void)sendBadges:(NSInteger)badge</a></td>
	</tr>
	<tr>
		<td><a href="#1a20bca4bec6bef003cd148876eee4bff4">- (NSString *)getPushToken</a></td>
	</tr>
	<tr>
		<td><a href="#1ae5916071d5d72271a239ab7c3970f060">- (NSString *)getHWID</a></td>
	</tr>
	<tr>
		<td><a href="#1a1de9c6bbc5c650d04f9a2c97e641be16">- (void)setUserId:(NSString *)userId completion:(void(^)(NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1ab1c821af2cbcded89c6cb16b104bafa9">- (void)setUserId:(NSString *)userId</a></td>
	</tr>
	<tr>
		<td><a href="#1aad3cbbeae4e45eab0085065c0bb83eaf">- (void)setUser:(NSString *)userId emails:(NSArray *)emails completion:(void(^)(NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a76880b034b01ecb8100f7bb476cc42f9">- (void)setUser:(NSString *)userId emails:(NSArray *)emails</a></td>
	</tr>
	<tr>
		<td><a href="#1ad413d699dc59ac2b19ac88a23c4f2993">- (void)setUser:(NSString *)userId email:(NSString *)email completion:(void(^)(NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a8dbe726012aa780a7318073e3ea0b722">- (void)setEmails:(NSArray *)emails completion:(void(^)(NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a7075ab1e16e686623608763af29443ea">- (void)setEmails:(NSArray *)emails</a></td>
	</tr>
	<tr>
		<td><a href="#1a73040b96e6452b8a3f3e9a7476163423">- (void)setEmail:(NSString *)email completion:(void(^)(NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a290ea9a84c7670143927537ea7a8e3ca">- (void)setEmail:(NSString *)email</a></td>
	</tr>
	<tr>
		<td><a href="#1a91c67cf46fb878df0db97260de08819e">- (void)mergeUserId:(NSString *)oldUserId to:(NSString *)newUserId doMerge:(BOOL)doMerge completion:(void(^)(NSError *error))completion</a></td>
	</tr>
</table>


----------  
  

#### <a name="1ad3eed702180c17050080e0df9ec1d3f6"></a>@property NSString \*applicationCode  
Pushwoosh Application ID. Usually retrieved automatically from Info.plist parameter Pushwoosh\_APPID

----------  
  

#### <a name="1a0f7cae72bb8d489c74d25a91147407ca"></a>@property NSObject&lt;<a href="PWMessagingDelegate-p.md">PWMessagingDelegate</a>&gt; \*delegate  
PushNotificationDelegate protocol delegate that would receive the information about events for push notification manager such as registering with APS services, receiving push notifications or working with the received notification. Pushwoosh Runtime sets it to ApplicationDelegate by default 

----------  
  

#### <a name="1a221ce364a31cffe798c0172c5a155b1d"></a>@property NSDictionary \*launchNotification  
Returns push notification payload if the app was started in response to push notification or null otherwise 

----------  
  

#### <a name="1a42e773c001914bf76ed49a4e2828100a"></a>@property PWNotificationCenterDelegateProxy \*notificationCenterDelegateProxy  
Proxy contains UNUserNotificationCenterDelegate objects. 

----------  
  

#### <a name="1ad29805f70c2d90156603ca8d952f4060"></a>@property NSString \*language  
Set custom application language. Must be a lowercase two-letter code according to ISO-639-1 standard ("en", "de", "fr", etc.). Device language used by default. Set to nil if you want to use device language again. 

----------  
  

#### <a name="1aa517c7b582ca90591b1362eed7cac960"></a>+ (void)initializeWithAppCode:(NSString \*)appCode  
Initializes Pushwoosh. <br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>appCode</strong></td>
		<td>Pushwoosh App ID. </td>
	</tr>
</table>


----------  
  

#### <a name="1a56604d5ec5713778ee74a249fab624f7"></a>+ (instancetype)sharedInstance  
Returns an object representing the current push manager.<br/><br/><br/><strong>Returns</strong> A singleton object that represents the push manager. 

----------  
  

#### <a name="1a75a5f815795676a3bf003c8613b5f296"></a>+ (NSString \*)version  
Pushwoosh SDK version. 

----------  
  

#### <a name="1af5330c15b4af7f1ecbbf0f178a0c845d"></a>+ (NSMutableDictionary \*)getRemoteNotificationStatus  
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
  

#### <a name="1a8a34fd51f7987a3ed6725edf5c0d7ea7"></a>+ (void)clearNotificationCenter  
Clears the notifications from the notification center. 

----------  
  

#### <a name="1a5a5885f51ca841cb3a69fe7bbc19a081"></a>- (void)registerForPushNotifications  
Registers for push notifications. By default registeres for "UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert" flags. Automatically detects if you have "newsstand-content" in "UIBackgroundModes" and adds "UIRemoteNotificationTypeNewsstandContentAvailability" flag. 

----------  
  

#### <a name="1a87649621d23de0c8a0de7f188d3587e9"></a>- (void)registerForPushNotificationsWithCompletion:(PushwooshRegistrationHandler)completion  


----------  
  

#### <a name="1ac30104920e79607ee1b645911b7b0ef6"></a>- (void)unregisterForPushNotifications  
Unregisters from push notifications. 

----------  
  

#### <a name="1a748303ef70f2acb42f064e819566f68e"></a>- (void)unregisterForPushNotificationsWithCompletion:(void(^)(NSError \*error))completion  


----------  
  

#### <a name="1a19bb8534c1ec1e22ada527c2fcfc1f93"></a>- (void)handlePushRegistration:(NSData \*)devToken  
Handle registration to remote notifications. 

----------  
  

#### <a name="1a2180719fd1f05032eecadaaae9eb0e31"></a>- (void)handlePushRegistrationFailure:(NSError \*)error  


----------  
  

#### <a name="1a9f488cd813fbc38716ff94b9b1818329"></a>- (BOOL)handlePushReceived:(NSDictionary \*)userInfo  
Handle received push notification. 

----------  
  

#### <a name="1aa6ffe7d71c784b048461ddb1c9f1e436"></a>- (void)setReverseProxy:(NSString \*)url  
Change default base url to reverse proxy url <br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>url</strong></td>
		<td>- reverse proxy url </td>
	</tr>
</table>


----------  
  

#### <a name="1acc5ce9be719d84d3fcdd4939b10856bf"></a>- (void)disableReverseProxy  
Disables reverse proxy 

----------  
  

#### <a name="1a876d8250c9a9641e7daf77c277c31be7"></a>- (void)setTags:(NSDictionary \*)tags  
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
  

#### <a name="1a51e9882787068540d016c56b5ec5c50c"></a>- (void)setTags:(NSDictionary \*)tags completion:(void(^)(NSError \*error))completion  
Send tags to server with completion block. If setTags succeeds competion is called with nil argument. If setTags fails completion is called with error. 

----------  
  

#### <a name="1af14c2945a66c1c7219bbc6ba9c84cb86"></a>- (void)setEmailTags:(NSDictionary \*)tags forEmail:(NSString \*)email  


----------  
  

#### <a name="1a0ddd6f1d9e85253451fe1d5c5490294a"></a>- (void)setEmailTags:(NSDictionary \*)tags forEmail:(NSString \*)email completion:(void(^)(NSError \*error))completion  


----------  
  

#### <a name="1a7451ea555a6f451c99f8508940c02edb"></a>- (void)getTags:(PushwooshGetTagsHandler)successHandler onFailure:(PushwooshErrorHandler)errorHandler  
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
  

#### <a name="1a79fe3e5ad3167a9301d5e8a0ea2c1de9"></a>- (void)sendBadges:(NSInteger)badge  
Sends current badge value to server. Called internally by SDK Runtime when UIApplicationsetApplicationBadgeNumber: is set. This function is used for "auto-incremeting" badges to work. This way Pushwoosh server can know what current badge value is set for the application.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>badge</strong></td>
		<td>Current badge value. </td>
	</tr>
</table>


----------  
  

#### <a name="1a20bca4bec6bef003cd148876eee4bff4"></a>- (NSString \*)getPushToken  
Gets current push token.<br/><br/><br/><strong>Returns</strong> Current push token. May be nil if no push token is available yet. 

----------  
  

#### <a name="1ae5916071d5d72271a239ab7c3970f060"></a>- (NSString \*)getHWID  
Gets HWID. Unique device identifier that used in all API calls with Pushwoosh. This is identifierForVendor for iOS &gt;= 7.<br/><br/><br/><strong>Returns</strong> Unique device identifier. 

----------  
  

#### <a name="1a1de9c6bbc5c650d04f9a2c97e641be16"></a>- (void)setUserId:(NSString \*)userId completion:(void(^)(NSError \*error))completion  
Set User indentifier. This could be Facebook ID, username or email, or any other user ID. This allows data and events to be matched across multiple user devices. If setUserId succeeds competion is called with nil argument. If setUserId fails completion is called with error.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>userId</strong></td>
		<td>user identifier </td>
	</tr>
</table>


----------  
  

#### <a name="1ab1c821af2cbcded89c6cb16b104bafa9"></a>- (void)setUserId:(NSString \*)userId  
Set User indentifier. This could be Facebook ID, username or email, or any other user ID. This allows data and events to be matched across multiple user devices.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>userId</strong></td>
		<td>user identifier </td>
	</tr>
</table>


----------  
  

#### <a name="1aad3cbbeae4e45eab0085065c0bb83eaf"></a>- (void)setUser:(NSString \*)userId emails:(NSArray \*)emails completion:(void(^)(NSError \*error))completion  
Set User indentifier. This could be Facebook ID, username or email, or any other user ID. This allows data and events to be matched across multiple user devices. If setUser succeeds competion is called with nil argument. If setUser fails completion is called with error.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>userId</strong></td>
		<td>user identifier </td>
	</tr>
	<tr>
		<td><strong>emails</strong></td>
		<td>user's emails array </td>
	</tr>
</table>


----------  
  

#### <a name="1a76880b034b01ecb8100f7bb476cc42f9"></a>- (void)setUser:(NSString \*)userId emails:(NSArray \*)emails  
Set User indentifier. This could be Facebook ID, username or email, or any other user ID. This allows data and events to be matched across multiple user devices.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>userId</strong></td>
		<td>user identifier </td>
	</tr>
	<tr>
		<td><strong>emails</strong></td>
		<td>user's emails array </td>
	</tr>
</table>


----------  
  

#### <a name="1ad413d699dc59ac2b19ac88a23c4f2993"></a>- (void)setUser:(NSString \*)userId email:(NSString \*)email completion:(void(^)(NSError \*error))completion  
Set User indentifier. This could be Facebook ID, username or email, or any other user ID. This allows data and events to be matched across multiple user devices. If setUser succeeds competion is called with nil argument. If setUser fails completion is called with error.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>userId</strong></td>
		<td>user identifier </td>
	</tr>
	<tr>
		<td><strong>email</strong></td>
		<td>user's email string </td>
	</tr>
</table>


----------  
  

#### <a name="1a8dbe726012aa780a7318073e3ea0b722"></a>- (void)setEmails:(NSArray \*)emails completion:(void(^)(NSError \*error))completion  
Register emails list associated to the current user. If setEmails succeeds competion is called with nil argument. If setEmails fails completion is called with error.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>emails</strong></td>
		<td>user's emails array </td>
	</tr>
</table>


----------  
  

#### <a name="1a7075ab1e16e686623608763af29443ea"></a>- (void)setEmails:(NSArray \*)emails  
Register emails list associated to the current user.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>emails</strong></td>
		<td>user's emails array </td>
	</tr>
</table>


----------  
  

#### <a name="1a73040b96e6452b8a3f3e9a7476163423"></a>- (void)setEmail:(NSString \*)email completion:(void(^)(NSError \*error))completion  
Register email associated to the current user. Email should be a string and could not be null or empty. If setEmail succeeds competion is called with nil argument. If setEmail fails completion is called with error.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>email</strong></td>
		<td>user's email string </td>
	</tr>
</table>


----------  
  

#### <a name="1a290ea9a84c7670143927537ea7a8e3ca"></a>- (void)setEmail:(NSString \*)email  
Register email associated to the current user. Email should be a string and could not be null or empty.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>email</strong></td>
		<td>user's email string </td>
	</tr>
</table>


----------  
  

#### <a name="1a91c67cf46fb878df0db97260de08819e"></a>- (void)mergeUserId:(NSString \*)oldUserId to:(NSString \*)newUserId doMerge:(BOOL)doMerge completion:(void(^)(NSError \*error))completion  
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
		<td>callback </td>
	</tr>
</table>
