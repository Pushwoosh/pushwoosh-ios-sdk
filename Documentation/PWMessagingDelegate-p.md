
# <a name="heading"></a>protocol PWMessagingDelegate&lt;NSObject&gt;  
PWMessagingDelegate protocol defines the methods that can be implemented in the delegate of the Pushwoosh class' singleton object. These methods provide information about the key events for push notification manager such as, receiving push notifications and opening the received notification. These methods implementation allows to react on these events properly. 
## Members  

<table>
	<tr>
		<td><a href="#1a457e510a5b5e7e8849351f6b641a74b8">- (void)pushwoosh:(Pushwoosh *_Nonnull)pushwoosh onMessageReceived:(PWMessage *_Nonnull)message</a></td>
	</tr>
	<tr>
		<td><a href="#1a072b85687fc5ff31b9ea64112f1c628b">- (void)pushwoosh:(Pushwoosh *_Nonnull)pushwoosh onMessageOpened:(PWMessage *_Nonnull)message</a></td>
	</tr>
</table>


----------  
  

#### <a name="1a457e510a5b5e7e8849351f6b641a74b8"></a>- (void)pushwoosh:(<a href="Pushwoosh.md">Pushwoosh</a> \*\_Nonnull)pushwoosh onMessageReceived:(<a href="PWMessage.md">PWMessage</a> \*\_Nonnull)message  
Tells the delegate that the application has received a remote notification.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>pushwoosh</strong></td>
		<td>The push manager that received the remote notification. </td>
	</tr>
	<tr>
		<td><strong>message</strong></td>
		<td>A PWMessage object that contains information referring to the remote notification, potentially including a badge number for the application icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data. </td>
	</tr>
</table>


----------  
  

#### <a name="1a072b85687fc5ff31b9ea64112f1c628b"></a>- (void)pushwoosh:(<a href="Pushwoosh.md">Pushwoosh</a> \*\_Nonnull)pushwoosh onMessageOpened:(<a href="PWMessage.md">PWMessage</a> \*\_Nonnull)message  
Tells the delegate that the user has pressed on the push notification banner.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>pushwoosh</strong></td>
		<td>The push manager that received the remote notification. </td>
	</tr>
	<tr>
		<td><strong>message</strong></td>
		<td>A PWMessage object that contains information about the remote notification, potentially including a badge number for the application icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data. </td>
	</tr>
</table>
