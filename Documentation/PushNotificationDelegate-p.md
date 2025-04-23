
# <a name="heading"></a>protocol PushNotificationDelegate  
PushNotificationDelegate protocol defines the methods that can be implemented in the delegate of the PushNotificationManager class' singleton object. These methods provide information about the key events for push notification manager such as registering with APS services, receiving push notifications or working with the received notification. These methods implementation allows to react on these events properly.<br/>Deprecated. Use PWMessagingDelegate instead. 
## Members  

<table>
	<tr>
		<td><a href="#1a012a61171ad487f99d13108c62575b6e">- (void)onDidRegisterForRemoteNotificationsWithDeviceToken:(NSString *)token</a></td>
	</tr>
	<tr>
		<td><a href="#1a58f4ecba5967fcfb2b5c38288bd69f31">- (void)onDidFailToRegisterForRemoteNotificationsWithError:(NSError *)error</a></td>
	</tr>
	<tr>
		<td><a href="#1a5da7054a1082115cdd88bd191bcccee8">- (void)onPushReceived:(PushNotificationManager *)pushManager withNotification:(NSDictionary *)pushNotification onStart:(BOOL)onStart</a></td>
	</tr>
	<tr>
		<td><a href="#1aee6ae0863f9f5020be09017042f83a83">- (void)onPushAccepted:(PushNotificationManager *)pushManager withNotification:(NSDictionary *)pushNotification</a></td>
	</tr>
	<tr>
		<td><a href="#1a592d9b804b15474dee8e490cd7058ab7">- (void)onActionIdentifierReceived:(NSString *)identifier withNotification:(NSDictionary *)notification</a></td>
	</tr>
	<tr>
		<td><a href="#1ad88d413d33964da81236c4e151eafcb0">- (void)onPushAccepted:(PushNotificationManager *)pushManager withNotification:(NSDictionary *)pushNotification onStart:(BOOL)onStart</a></td>
	</tr>
	<tr>
		<td><a href="#1a5798a1bf2bb6ae81f599361e34c6a738">- (void)onTagsReceived:(NSDictionary *)tags</a></td>
	</tr>
	<tr>
		<td><a href="#1a798bfd73045482b35c74c03b8efb547e">- (void)onTagsFailedToReceive:(NSError *)error</a></td>
	</tr>
	<tr>
		<td><a href="#1aa814f0142367a2ad980a3df9404ce577">- (void)onInAppClosed:(NSString *)code</a></td>
	</tr>
	<tr>
		<td><a href="#1aaf5194ee0c3930f008f5d87ccf3575ea">- (void)onInAppDisplayed:(NSString *)code</a></td>
	</tr>
</table>


----------  
  

#### <a name="1a012a61171ad487f99d13108c62575b6e"></a>- (void)onDidRegisterForRemoteNotificationsWithDeviceToken:(NSString \*)token  
Tells the delegate that the application has registered with Apple Push Service (APS) successfully.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>token</strong></td>
		<td>A token used for identifying the device with APS. </td>
	</tr>
</table>


----------  
  

#### <a name="1a58f4ecba5967fcfb2b5c38288bd69f31"></a>- (void)onDidFailToRegisterForRemoteNotificationsWithError:(NSError \*)error  
Sent to the delegate when Apple Push Service (APS) could not complete the registration process successfully.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>error</strong></td>
		<td>An NSError object encapsulating the information about the reason of the registration failure. Within this method you can define application's behaviour in case of registration failure. </td>
	</tr>
</table>


----------  
  

#### <a name="1a5da7054a1082115cdd88bd191bcccee8"></a>- (void)onPushReceived:(<a href="PushNotificationManager.md">PushNotificationManager</a> \*)pushManager withNotification:(NSDictionary \*)pushNotification onStart:(BOOL)onStart  
Tells the delegate that the push manager has received a remote notification.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>pushManager</strong></td>
		<td>The push manager that received the remote notification. </td>
	</tr>
	<tr>
		<td><strong>pushNotification</strong></td>
		<td>A dictionary that contains information referring to the remote notification, potentially including a badge number for the application icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data. The provider originates it as a JSON-defined dictionary that iOS converts to an NSDictionary object; the dictionary may contain only property-list objects plus NSNull. </td>
	</tr>
	<tr>
		<td><strong>onStart</strong></td>
		<td>If the application was not foreground when the push notification was received, the application will be opened with this parameter equal to YES, otherwise the parameter will be NO. </td>
	</tr>
</table>


----------  
  

#### <a name="1aee6ae0863f9f5020be09017042f83a83"></a>- (void)onPushAccepted:(<a href="PushNotificationManager.md">PushNotificationManager</a> \*)pushManager withNotification:(NSDictionary \*)pushNotification  
Tells the delegate that the user has pressed OK on the push notification. IMPORTANT: This method is used for backwards compatibility and is deprecated. Please use the onPushAccepted:withNotification:onStart: method instead<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>pushManager</strong></td>
		<td>The push manager that received the remote notification. </td>
	</tr>
	<tr>
		<td><strong>pushNotification</strong></td>
		<td>A dictionary that contains information referring to the remote notification, potentially including a badge number for the application icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data. The provider originates it as a JSON-defined dictionary that iOS converts to an NSDictionary object; the dictionary may contain only property-list objects plus NSNull. Push dictionary sample: 
```Objective-C
{
   aps =     {
       alert = "Some text.";
       sound = default;
   };
   p = 1pb;
}
```
</td>
	</tr>
</table>


----------  
  

#### <a name="1a592d9b804b15474dee8e490cd7058ab7"></a>- (void)onActionIdentifierReceived:(NSString \*)identifier withNotification:(NSDictionary \*)notification  
Tells the delegate that a custom action was triggered when opening a notification.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>identifier</strong></td>
		<td>NSString containing an ID of a clicked button. This ID is set by a user when creating a category in the Pushwoosh Control Panel </td>
	</tr>
	<tr>
		<td><strong>notification</strong></td>
		<td>NSDictionary with push payload. </td>
	</tr>
</table>


----------  
  

#### <a name="1ad88d413d33964da81236c4e151eafcb0"></a>- (void)onPushAccepted:(<a href="PushNotificationManager.md">PushNotificationManager</a> \*)pushManager withNotification:(NSDictionary \*)pushNotification onStart:(BOOL)onStart  
Tells the delegate that the user has pressed on the push notification banner.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>pushManager</strong></td>
		<td>The push manager that received the remote notification. </td>
	</tr>
	<tr>
		<td><strong>pushNotification</strong></td>
		<td>A dictionary that contains information about the remote notification, potentially including a badge number for the application icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data. The provider originates it as a JSON-defined dictionary that iOS converts to an NSDictionary object; the dictionary may contain only property-list objects plus NSNull. Push dictionary sample: 
```Objective-C
{
    aps =     {
        alert = "Some text.";
        sound = default;
    };
    p = 1pb;
}
```
</td>
	</tr>
	<tr>
		<td><strong>onStart</strong></td>
		<td>If the application was not foreground when the push notification was received, the application will be opened with this parameter equal to YES, otherwise the parameter will be NO. </td>
	</tr>
</table>


----------  
  

#### <a name="1a5798a1bf2bb6ae81f599361e34c6a738"></a>- (void)onTagsReceived:(NSDictionary \*)tags  
Tells the delegate that the push manager has received tags from the server.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>tags</strong></td>
		<td>Dictionary representation of received tags. Dictionary example: 
```Objective-C
{
    Country = ru;
    Language = ru;
}
```
</td>
	</tr>
</table>


----------  
  

#### <a name="1a798bfd73045482b35c74c03b8efb547e"></a>- (void)onTagsFailedToReceive:(NSError \*)error  
Sent to the delegate when push manager could not complete the tags receiving process successfully.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>error</strong></td>
		<td>An NSError object that encapsulates information why receiving tags did not succeed. </td>
	</tr>
</table>


----------  
  

#### <a name="1aa814f0142367a2ad980a3df9404ce577"></a>- (void)onInAppClosed:(NSString \*)code  
Tells the delegate that In-App with specified code has been closed<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>code</strong></td>
		<td>In-App code </td>
	</tr>
</table>


----------  
  

#### <a name="1aaf5194ee0c3930f008f5d87ccf3575ea"></a>- (void)onInAppDisplayed:(NSString \*)code  
Tells the delegate that In-App with specified code has been displayed<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>code</strong></td>
		<td>In-App code </td>
	</tr>
</table>
