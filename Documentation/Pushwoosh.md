
# <a name="heading"></a>class Pushwoosh : NSObject  
Pushwoosh class offers access to the singleton-instance of the push manager responsible for registering the device with the APS servers, receiving and processing push notifications. 
## Members  

<table>
	<tr>
		<td><a href="#1aa7caab3e4111d4f4756a1e8d56d01c26">@property NSString *_Nonnull</a></td>
	</tr>
	<tr>
		<td><a href="#1ae9429c76f749caa36e1f798ef3e06c6c">@property NSObject&lt;PWMessagingDelegate&gt; *_Nullable</a></td>
	</tr>
	<tr>
		<td><a href="#1ad4f33662a2c344c8a590d03b859cf935">@property NSObject&lt;PWPurchaseDelegate&gt; *_Nullable</a></td>
	</tr>
	<tr>
		<td><a href="#1abe8dbad57ad73ac86a51cc0b4dfc64e5">@property NSDictionary *_Nullable</a></td>
	</tr>
	<tr>
		<td><a href="#1affd3a0d7e10d7fead43096d218db9f08">@property PWNotificationCenterDelegateProxy *_Nullable</a></td>
	</tr>
	<tr>
		<td><a href="#1a0949e0d478520ad209aa879486c44791">+ (void)initializeWithAppCode:(NSString *_Nonnull)appCode</a></td>
	</tr>
	<tr>
		<td><a href="#1a7dd1cfddec0982458354e912e1085610">+ (instancetype _Nonnull)sharedInstance</a></td>
	</tr>
	<tr>
		<td><a href="#1a34d474b47c01ccb0522228e8ba86cb46">+ (NSString *_Nonnull)version</a></td>
	</tr>
	<tr>
		<td><a href="#1a4f7cc70d103234a7a523129f6d7bf368">+ (NSMutableDictionary *_Nullable)getRemoteNotificationStatus</a></td>
	</tr>
	<tr>
		<td><a href="#1a8a34fd51f7987a3ed6725edf5c0d7ea7">+ (void)clearNotificationCenter</a></td>
	</tr>
	<tr>
		<td><a href="#1a5a5885f51ca841cb3a69fe7bbc19a081">- (void)registerForPushNotifications</a></td>
	</tr>
	<tr>
		<td><a href="#1a8fa8f03c76e3b4dec6899f86518ef00c">- (void)registerForPushNotificationsWithCompletion:(PushwooshRegistrationHandler _Nullable)completion</a></td>
	</tr>
	<tr>
		<td><a href="#1adc3d83ed9f6302149e961da11be8ff57">- (void)registerForPushNotificationsWith:(NSDictionary *_Nonnull)tags</a></td>
	</tr>
	<tr>
		<td><a href="#1ade933d38cfbac899053fe3d2e86d0c78">- (void)registerForPushNotificationsWith:(NSDictionary *_Nonnull)tags completion:(PushwooshRegistrationHandler _Nullable)completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a75ae1c085d180b3fe36e0f719983e5ab">- (void)registerSmsNumber:(NSString *_Nonnull)number</a></td>
	</tr>
	<tr>
		<td><a href="#1acd181e94d5156f6c3ed48be289866182">- (void)registerWhatsappNumber:(NSString *_Nonnull)number</a></td>
	</tr>
	<tr>
		<td><a href="#1ac30104920e79607ee1b645911b7b0ef6">- (void)unregisterForPushNotifications</a></td>
	</tr>
	<tr>
		<td><a href="#1a27882aeee06f0ba2097f0df1b2440d71">- (void)unregisterForPushNotificationsWithCompletion:(void(^)(NSError *_Nullable error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1af4788ced03fba3a8f36e7a1dfab1cd43">- (void)handlePushRegistration:(NSData *_Nonnull)devToken</a></td>
	</tr>
	<tr>
		<td><a href="#1a5329c8bdf96e042c7992d27eceaccbab">- (void)handlePushRegistrationFailure:(NSError *_Nonnull)error</a></td>
	</tr>
	<tr>
		<td><a href="#1a1ed225c61deb95af1d893b47cba4b426">- (BOOL)handlePushReceived:(NSDictionary *_Nonnull)userInfo</a></td>
	</tr>
	<tr>
		<td><a href="#1ad1aa7a27a94d074e45f9bbf6a6cf2eb0">- (void)setReverseProxy:(NSString *_Nonnull)url</a></td>
	</tr>
	<tr>
		<td><a href="#1acc5ce9be719d84d3fcdd4939b10856bf">- (void)disableReverseProxy</a></td>
	</tr>
	<tr>
		<td><a href="#1a14c7a0d776f2fa6bc63478dc7ed8b9e9">- (void)setTags:(NSDictionary *_Nonnull)tags</a></td>
	</tr>
	<tr>
		<td><a href="#1a3eda2a7574c32899fd745c88ae1f4666">- (void)setTags:(NSDictionary *_Nonnull)tags completion:(void(^)(NSError *_Nullable error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a00e4bc044d466de43b1a49d7cab720f1">- (void)setEmailTags:(NSDictionary *_Nonnull)tags forEmail:(NSString *_Nonnull)email</a></td>
	</tr>
	<tr>
		<td><a href="#1a5e155d50e627eca38305ba00184d374c">- (void)setEmailTags:(NSDictionary *_Nonnull)tags forEmail:(NSString *_Nonnull)email completion:(void(^)(NSError *_Nullable error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a50e1ef5fc5d015ba6ab4acc83352b7cf">- (void)getTags:(PushwooshGetTagsHandler _Nullable)successHandler onFailure:(PushwooshErrorHandler _Nullable)errorHandler</a></td>
	</tr>
	<tr>
		<td><a href="#1a79fe3e5ad3167a9301d5e8a0ea2c1de9">- (void)sendBadges:(NSInteger)badge</a></td>
	</tr>
	<tr>
		<td><a href="#1ac4d7fd2499c969a4fc6461e8fe6fe983">- (NSString *_Nullable)getPushToken</a></td>
	</tr>
	<tr>
		<td><a href="#1a0e0d155a862e9ca4c3839e2c3f8d4115">- (NSString *_Nonnull)getHWID</a></td>
	</tr>
	<tr>
		<td><a href="#1ad7d1b0957e50d70e5ae445a295744350">- (NSString *_Nonnull)getUserId</a></td>
	</tr>
	<tr>
		<td><a href="#1ab614f1fcd98bce58db800a09baf22f6d">- (void)setUserId:(NSString *_Nonnull)userId completion:(void(^)(NSError *_Nullable error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1ae8c7909cbea0b9171b9c22ccf1dadbed">- (void)setUserId:(NSString *_Nonnull)userId</a></td>
	</tr>
	<tr>
		<td><a href="#1a2257e88edf2c6f44cad770a6f3e10a17">- (void)setUser:(NSString *_Nonnull)userId emails:(NSArray *_Nonnull)emails completion:(void(^)(NSError *_Nullable error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a7a4b216e591b449e5afdd4f6b70c1933">- (void)setUser:(NSString *_Nonnull)userId emails:(NSArray *_Nonnull)emails</a></td>
	</tr>
	<tr>
		<td><a href="#1a15251b2a767457a1c79de01bda831b45">- (void)setUser:(NSString *_Nonnull)userId email:(NSString *_Nonnull)email completion:(void(^)(NSError *_Nullable error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a4a0147fe93493d6d9ee2254af6f0096b">- (void)setEmails:(NSArray *_Nonnull)emails completion:(void(^)(NSError *_Nullable error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a9c09efeafad961d34260a81545ae1dcc">- (void)setEmails:(NSArray *_Nonnull)emails</a></td>
	</tr>
	<tr>
		<td><a href="#1a511fb62dcc9802dea7057ca0f7107dad">- (void)setEmail:(NSString *_Nonnull)email completion:(void(^)(NSError *_Nullable error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1abe5a49398ecd6c86951d9d5b15bb4e9e">- (void)setEmail:(NSString *_Nonnull)email</a></td>
	</tr>
	<tr>
		<td><a href="#1a53627e1cbbb3507fec2b916a4dc958d0">- (void)mergeUserId:(NSString *_Nonnull)oldUserId to:(NSString *_Nonnull)newUserId doMerge:(BOOL)doMerge completion:(void(^)(NSError *_Nullable error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1aebffdb7820a9248fda21c760e46dc196">- (void)startServerCommunication</a></td>
	</tr>
	<tr>
		<td><a href="#1a86385c57c5f5a911092f40db090b6de4">- (void)stopServerCommunication</a></td>
	</tr>
	<tr>
		<td><a href="#1a52505171bf9f13f972680d795e796661">- (void)sendPushToStartLiveActivityToken:(NSString *_Nullable)token</a></td>
	</tr>
	<tr>
		<td><a href="#1a67fc0820b2e3d2e4164fe77946b46366">- (void)sendPushToStartLiveActivityToken:(NSString *_Nullable)token completion:(void(^)(NSError *_Nullable))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a5f19b5be349429bad1ef85e8eaaf5786">- (void)startLiveActivityWithToken:(NSString *_Nonnull)token activityId:(NSString *_Nullable)activityId</a></td>
	</tr>
	<tr>
		<td><a href="#1a33a157a696f3084f23fb5b2df9193705">- (void)startLiveActivityWithToken:(NSString *_Nonnull)token activityId:(NSString *_Nullable)activityId completion:(void(^)(NSError *_Nullable error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a0df2937a1b6953ab7d2d495787607cff">- (void)stopLiveActivity</a></td>
	</tr>
	<tr>
		<td><a href="#1adfbf6fe4e6ea6d777df916c0e7fba45c">- (void)stopLiveActivityWithCompletion:(void(^)(NSError *_Nullable error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a41d9f1c160ba507c2e99164d3031d06f">- (void)stopLiveActivityWith:(NSString *_Nullable)activityId</a></td>
	</tr>
	<tr>
		<td><a href="#1a98ac20ec9cd2e9cc1f4e6a9bd5561e45">- (void)stopLiveActivityWith:(NSString *_Nullable)activityId completion:(void(^)(NSError *_Nullable error))completion</a></td>
	</tr>
</table>


----------  
  

#### <a name="1aa7caab3e4111d4f4756a1e8d56d01c26"></a>@property NSString \*_Nonnull  
Pushwoosh Application ID. Usually retrieved automatically from Info.plist parameter Pushwoosh\_APPID<br/>Set custom application language. Must be a lowercase two-letter code according to ISO-639-1 standard ("en", "de", "fr", etc.). Device language used by default. Set to nil if you want to use device language again. 

----------  
  

#### <a name="1ae9429c76f749caa36e1f798ef3e06c6c"></a>@property NSObject&lt;<a href="PWMessagingDelegate-p.md">PWMessagingDelegate</a>&gt; \*_Nullable  
PushNotificationDelegate protocol delegate that would receive the information about events for push notification manager such as registering with APS services, receiving push notifications or working with the received notification. Pushwoosh Runtime sets it to ApplicationDelegate by default 

----------  
  

#### <a name="1ad4f33662a2c344c8a590d03b859cf935"></a>@property NSObject&lt;<a href="PWPurchaseDelegate-p.md">PWPurchaseDelegate</a>&gt; \*_Nullable  
PushPurchaseDelegate protocol delegate that would receive the information about events related to purchasing InApp products from rich medias 

----------  
  

#### <a name="1abe8dbad57ad73ac86a51cc0b4dfc64e5"></a>@property NSDictionary \*_Nullable  
Returns push notification payload if the app was started in response to push notification or null otherwise 

----------  
  

#### <a name="1affd3a0d7e10d7fead43096d218db9f08"></a>@property PWNotificationCenterDelegateProxy \*_Nullable  
Proxy contains UNUserNotificationCenterDelegate objects. 

----------  
  

#### <a name="1a0949e0d478520ad209aa879486c44791"></a>+ (void)initializeWithAppCode:(NSString \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)appCode  
Initializes Pushwoosh. <br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>appCode</strong></td>
		<td>Pushwoosh App ID. </td>
	</tr>
</table>


----------  
  

#### <a name="1a7dd1cfddec0982458354e912e1085610"></a>+ (instancetype <a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)sharedInstance  
Returns an object representing the current push manager.<br/><br/><br/><strong>Returns</strong> A singleton object that represents the push manager. 

----------  
  

#### <a name="1a34d474b47c01ccb0522228e8ba86cb46"></a>+ (NSString \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)version  
Pushwoosh SDK version. 

----------  
  

#### <a name="1a4f7cc70d103234a7a523129f6d7bf368"></a>+ (NSMutableDictionary \*<a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a>)getRemoteNotificationStatus  
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
  

#### <a name="1a8fa8f03c76e3b4dec6899f86518ef00c"></a>- (void)registerForPushNotificationsWithCompletion:(PushwooshRegistrationHandler <a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a>)completion  


----------  
  

#### <a name="1adc3d83ed9f6302149e961da11be8ff57"></a>- (void)registerForPushNotificationsWith:(NSDictionary \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)tags  
Registers for push notifications with custom tags. By default registeres for "UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert" flags. Automatically detects if you have "newsstand-content" in "UIBackgroundModes" and adds "UIRemoteNotificationTypeNewsstandContentAvailability" flag. 

----------  
  

#### <a name="1ade933d38cfbac899053fe3d2e86d0c78"></a>- (void)registerForPushNotificationsWith:(NSDictionary \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)tags completion:(PushwooshRegistrationHandler <a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a>)completion  


----------  
  

#### <a name="1a75ae1c085d180b3fe36e0f719983e5ab"></a>- (void)registerSmsNumber:(NSString \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)number  
Registration methods for Whatsapp and SMS 

----------  
  

#### <a name="1acd181e94d5156f6c3ed48be289866182"></a>- (void)registerWhatsappNumber:(NSString \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)number  


----------  
  

#### <a name="1ac30104920e79607ee1b645911b7b0ef6"></a>- (void)unregisterForPushNotifications  
Unregisters from push notifications. 

----------  
  

#### <a name="1a27882aeee06f0ba2097f0df1b2440d71"></a>- (void)unregisterForPushNotificationsWithCompletion:(void(^)(NSError \*<a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a> error))completion  


----------  
  

#### <a name="1af4788ced03fba3a8f36e7a1dfab1cd43"></a>- (void)handlePushRegistration:(NSData \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)devToken  
Handle registration to remote notifications. 

----------  
  

#### <a name="1a5329c8bdf96e042c7992d27eceaccbab"></a>- (void)handlePushRegistrationFailure:(NSError \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)error  


----------  
  

#### <a name="1a1ed225c61deb95af1d893b47cba4b426"></a>- (BOOL)handlePushReceived:(NSDictionary \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)userInfo  
Handle received push notification. 

----------  
  

#### <a name="1ad1aa7a27a94d074e45f9bbf6a6cf2eb0"></a>- (void)setReverseProxy:(NSString \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)url  
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
  

#### <a name="1a14c7a0d776f2fa6bc63478dc7ed8b9e9"></a>- (void)setTags:(NSDictionary \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)tags  
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
  

#### <a name="1a3eda2a7574c32899fd745c88ae1f4666"></a>- (void)setTags:(NSDictionary \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)tags completion:(void(^)(NSError \*<a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a> error))completion  
Send tags to server with completion block. If setTags succeeds competion is called with nil argument. If setTags fails completion is called with error. 

----------  
  

#### <a name="1a00e4bc044d466de43b1a49d7cab720f1"></a>- (void)setEmailTags:(NSDictionary \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)tags forEmail:(NSString \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)email  


----------  
  

#### <a name="1a5e155d50e627eca38305ba00184d374c"></a>- (void)setEmailTags:(NSDictionary \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)tags forEmail:(NSString \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)email completion:(void(^)(NSError \*<a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a> error))completion  


----------  
  

#### <a name="1a50e1ef5fc5d015ba6ab4acc83352b7cf"></a>- (void)getTags:(PushwooshGetTagsHandler <a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a>)successHandler onFailure:(PushwooshErrorHandler <a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a>)errorHandler  
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
  

#### <a name="1ac4d7fd2499c969a4fc6461e8fe6fe983"></a>- (NSString \*<a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a>)getPushToken  
Gets current push token.<br/><br/><br/><strong>Returns</strong> Current push token. May be nil if no push token is available yet. 

----------  
  

#### <a name="1a0e0d155a862e9ca4c3839e2c3f8d4115"></a>- (NSString \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)getHWID  
Gets HWID. Unique device identifier that used in all API calls with Pushwoosh. This is identifierForVendor for iOS &gt;= 7.<br/><br/><br/><strong>Returns</strong> Unique device identifier. 

----------  
  

#### <a name="1ad7d1b0957e50d70e5ae445a295744350"></a>- (NSString \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)getUserId  
Gets UserId.<br/><br/><br/><strong>Returns</strong> userId. If the userId hasn't been set previously, then the userId is assigned the HWID. 

----------  
  

#### <a name="1ab614f1fcd98bce58db800a09baf22f6d"></a>- (void)setUserId:(NSString \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)userId completion:(void(^)(NSError \*<a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a> error))completion  
Set User indentifier. This could be Facebook ID, username or email, or any other user ID. This allows data and events to be matched across multiple user devices. If setUserId succeeds competion is called with nil argument. If setUserId fails completion is called with error.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>userId</strong></td>
		<td>user identifier </td>
	</tr>
</table>


----------  
  

#### <a name="1ae8c7909cbea0b9171b9c22ccf1dadbed"></a>- (void)setUserId:(NSString \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)userId  
Set User indentifier. This could be Facebook ID, username or email, or any other user ID. This allows data and events to be matched across multiple user devices.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>userId</strong></td>
		<td>user identifier </td>
	</tr>
</table>


----------  
  

#### <a name="1a2257e88edf2c6f44cad770a6f3e10a17"></a>- (void)setUser:(NSString \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)userId emails:(NSArray \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)emails completion:(void(^)(NSError \*<a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a> error))completion  
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
  

#### <a name="1a7a4b216e591b449e5afdd4f6b70c1933"></a>- (void)setUser:(NSString \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)userId emails:(NSArray \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)emails  
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
  

#### <a name="1a15251b2a767457a1c79de01bda831b45"></a>- (void)setUser:(NSString \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)userId email:(NSString \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)email completion:(void(^)(NSError \*<a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a> error))completion  
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
  

#### <a name="1a4a0147fe93493d6d9ee2254af6f0096b"></a>- (void)setEmails:(NSArray \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)emails completion:(void(^)(NSError \*<a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a> error))completion  
Register emails list associated to the current user. If setEmails succeeds competion is called with nil argument. If setEmails fails completion is called with error.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>emails</strong></td>
		<td>user's emails array </td>
	</tr>
</table>


----------  
  

#### <a name="1a9c09efeafad961d34260a81545ae1dcc"></a>- (void)setEmails:(NSArray \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)emails  
Register emails list associated to the current user.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>emails</strong></td>
		<td>user's emails array </td>
	</tr>
</table>


----------  
  

#### <a name="1a511fb62dcc9802dea7057ca0f7107dad"></a>- (void)setEmail:(NSString \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)email completion:(void(^)(NSError \*<a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a> error))completion  
Register email associated to the current user. Email should be a string and could not be null or empty. If setEmail succeeds competion is called with nil argument. If setEmail fails completion is called with error.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>email</strong></td>
		<td>user's email string </td>
	</tr>
</table>


----------  
  

#### <a name="1abe5a49398ecd6c86951d9d5b15bb4e9e"></a>- (void)setEmail:(NSString \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)email  
Register email associated to the current user. Email should be a string and could not be null or empty.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>email</strong></td>
		<td>user's email string </td>
	</tr>
</table>


----------  
  

#### <a name="1a53627e1cbbb3507fec2b916a4dc958d0"></a>- (void)mergeUserId:(NSString \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)oldUserId to:(NSString \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)newUserId doMerge:(BOOL)doMerge completion:(void(^)(NSError \*<a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a> error))completion  
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


----------  
  

#### <a name="1aebffdb7820a9248fda21c760e46dc196"></a>- (void)startServerCommunication  
Starts communication with Pushwoosh server. 

----------  
  

#### <a name="1a86385c57c5f5a911092f40db090b6de4"></a>- (void)stopServerCommunication  
Stops communication with Pushwoosh server. 

----------  
  

#### <a name="1a52505171bf9f13f972680d795e796661"></a>- (void)sendPushToStartLiveActivityToken:(NSString \*<a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a>)token  
Process URL of some deep link. Primarly used for register test devices.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>url</strong></td>
		<td>Deep Link URL Sends push to start live activity token to the server. Call this method when you want to initiate live activity via push notification</td>
	</tr>
</table>

Example: 
```Objective-C
if #available(iOS 17.2, *) {
        Task {
            for await data in Activity<LiveActivityAttributes>.pushToStartTokenUpdates {
                let token = data.map { String(format: "%02x", $0) }.joined()
                do {
                    try await Pushwoosh.sharedInstance().sendPush(toStartLiveActivityToken: token)
                } catch {
                    print("Error sending push to start live activity: \(error)")
                }
           }
       }
 }
```


----------  
  

#### <a name="1a67fc0820b2e3d2e4164fe77946b46366"></a>- (void)sendPushToStartLiveActivityToken:(NSString \*<a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a>)token completion:(void(^)(NSError \*<a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a>))completion  


----------  
  

#### <a name="1a5f19b5be349429bad1ef85e8eaaf5786"></a>- (void)startLiveActivityWithToken:(NSString \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)token activityId:(NSString \*<a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a>)activityId  
Sends live activity token to the server. Call this method when you create a live activity.<br/>Example: 
```Objective-C
do {
    let activity = try Activity<PushwooshAppAttributes>.request(
        attributes: attributes,
        contentState: contentState,
        pushType: .token)
    
    for await data in activity.pushTokenUpdates {
        guard let token = data.map { String(format: "%02x", $0) }.joined(separator: "") else {
            continue
        }
        
        do {
            try await Pushwoosh.sharedInstance().startLiveActivity(withToken: token)
            return token
        } catch {
            print("Failed to start live activity with token \(token): \(error.localizedDescription)")
            return nil
        }
    }
    return nil
} catch {
    print("Error requesting activity: \(error.localizedDescription)")
    return nil
}
```
<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>token</strong></td>
		<td>Activity token </td>
	</tr>
	<tr>
		<td><strong>activityId</strong></td>
		<td>Activity ID for updating Live Activities by segments </td>
	</tr>
</table>


----------  
  

#### <a name="1a33a157a696f3084f23fb5b2df9193705"></a>- (void)startLiveActivityWithToken:(NSString \*<a href="Pushwoosh.md#1aa7caab3e4111d4f4756a1e8d56d01c26">_Nonnull</a>)token activityId:(NSString \*<a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a>)activityId completion:(void(^)(NSError \*<a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a> error))completion  


----------  
  

#### <a name="1a0df2937a1b6953ab7d2d495787607cff"></a>- (void)stopLiveActivity  
Call this method when you finish working with the live activity.<br/>Example: 
```Objective-C
func end(activity: Activity<PushwooshAppAttributes>) {
    Task {
        await activity.end(dismissalPolicy: .immediate)
        try await Pushwoosh.sharedInstance().stopLiveActivity()
    }
}
```


----------  
  

#### <a name="1adfbf6fe4e6ea6d777df916c0e7fba45c"></a>- (void)stopLiveActivityWithCompletion:(void(^)(NSError \*<a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a> error))completion  


----------  
  

#### <a name="1a41d9f1c160ba507c2e99164d3031d06f"></a>- (void)stopLiveActivityWith:(NSString \*<a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a>)activityId  


----------  
  

#### <a name="1a98ac20ec9cd2e9cc1f4e6a9bd5561e45"></a>- (void)stopLiveActivityWith:(NSString \*<a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a>)activityId completion:(void(^)(NSError \*<a href="Pushwoosh.md#1ae9429c76f749caa36e1f798ef3e06c6c">_Nullable</a> error))completion  
