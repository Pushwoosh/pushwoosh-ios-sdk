
# <a name="heading"></a>protocol PWMessagingDelegate&lt;NSObject&gt;  
PWMessagingDelegate protocol defines the methods that can be implemented in the delegate of the Pushwoosh class' singleton object. These methods provide information about the key events for push notification manager such as, receiving push notifications and opening the received notification. These methods implementation allows to react on these events properly. 
## Members  

<table>
	<tr>
		<td><a href="#1a33c3560dff32d557a15e3daab7fdc790">- (void)pushwoosh:(Pushwoosh *)pushwoosh onMessageReceived:(PWMessage *)message</a></td>
	</tr>
	<tr>
		<td><a href="#1a4f062e06264f937bac98bd0eb4f79227">- (void)pushwoosh:(Pushwoosh *)pushwoosh onMessageOpened:(PWMessage *)message</a></td>
	</tr>
</table>


----------  
  

#### <a name="1a33c3560dff32d557a15e3daab7fdc790"></a>- (void)pushwoosh:(<a href="Pushwoosh.md">Pushwoosh</a> \*)pushwoosh onMessageReceived:(<a href="PWMessage.md">PWMessage</a> \*)message  
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
  

#### <a name="1a4f062e06264f937bac98bd0eb4f79227"></a>- (void)pushwoosh:(<a href="Pushwoosh.md">Pushwoosh</a> \*)pushwoosh onMessageOpened:(<a href="PWMessage.md">PWMessage</a> \*)message  
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
