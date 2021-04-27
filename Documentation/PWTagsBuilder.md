
# <a name="heading"></a>class PWTagsBuilder : NSObject  
PWNotificationCenterDelegateProxy class handles notifications on iOS 10 and forwards methods of UNUserNotificationCenterDelegate to all added delegates. Returns UNUserNotificationCenterDelegate that handles foreground push notifications on iOS10 Adds extra UNUserNotificationCenterDelegate that handles foreground push notifications on iOS10. PWTagsBuilder class encapsulates the methods for creating tags parameters for sending them to the server. 
## Members  

<table>
	<tr>
		<td><a href="#1a0a2b16c5d61c9dc29a180a9e142e1ec1">+ (NSDictionary *)incrementalTagWithInteger:(NSInteger)delta</a></td>
	</tr>
	<tr>
		<td><a href="#1a5957dbb0aa9a819abc2c144452a55e5e">+ (NSDictionary *)appendValuesToListTag:(NSArray&lt;NSString *&gt; *)array</a></td>
	</tr>
</table>


----------  
  

#### <a name="1a0a2b16c5d61c9dc29a180a9e142e1ec1"></a>+ (NSDictionary \*)incrementalTagWithInteger:(NSInteger)delta  
Creates a dictionary for incrementing/decrementing a numeric tag on the server.<br/>Example: 
```Objective-C
NSDictionary *tags = @{
    @"Alias" : aliasField.text,
    @"FavNumber" : @([favNumField.text intValue]),
    @"price": [PWTags incrementalTagWithInteger:5],
};

[[PushNotificationManager pushManager] setTags:tags];
```
<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>delta</strong></td>
		<td>Difference that needs to be applied to the tag's counter.</td>
	</tr>
</table>
<strong>Returns</strong> Dictionary, that needs to be sent as the value for the tag 

----------  
  

#### <a name="1a5957dbb0aa9a819abc2c144452a55e5e"></a>+ (NSDictionary \*)appendValuesToListTag:(NSArray&lt;NSString \*&gt; \*)array  
Creates a dictionary for extending Tag’s values list with additional values<br/>Example:<br/>
```Objective-C
NSDictionary *tags = @{
    @"Alias" : aliasField.text,
    @"FavNumber" : @([favNumField.text intValue]),
    @"List" : [PWTags appendValuesToListTag:@[ @"Item1" ]]
};

[[PushNotificationManager pushManager] setTags:tags];
```
<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>array</strong></td>
		<td>Array of values to be added to the tag.</td>
	</tr>
</table>
<strong>Returns</strong> Dictionary to be sent as the value for the tag 