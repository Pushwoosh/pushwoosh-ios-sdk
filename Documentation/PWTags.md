
# <a name="heading"></a>class PWTags : NSObject  
PWTags class encapsulates the methods for creating tags parameters for sending them to the server. 
## Members  

<table>
	<tr>
		<td><a href="#1a759617d9ac0a81e21ae208bcae140e01">+ (NSDictionary *)incrementalTagWithInteger:(NSInteger)delta</a></td>
	</tr>
	<tr>
		<td><a href="#1a310ac7649ca5d2be1ef1d752a024f798">+ (NSDictionary *)appendValuesToListTag:(NSArray&lt;NSString *&gt; *)array</a></td>
	</tr>
	<tr>
		<td><a href="#1afff82dab823902bd63ae6dd5442a0bac">+ (NSDictionary *)removeValuesFromListTag:(NSArray&lt;NSString *&gt; *)array</a></td>
	</tr>
</table>


----------  
  

#### <a name="1a759617d9ac0a81e21ae208bcae140e01"></a>+ (NSDictionary \*)incrementalTagWithInteger:(NSInteger)delta  
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
  

#### <a name="1a310ac7649ca5d2be1ef1d752a024f798"></a>+ (NSDictionary \*)appendValuesToListTag:(NSArray&lt;NSString \*&gt; \*)array  
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

----------  
  

#### <a name="1afff82dab823902bd63ae6dd5442a0bac"></a>+ (NSDictionary \*)removeValuesFromListTag:(NSArray&lt;NSString \*&gt; \*)array  
Creates a dictionary for removing Tag’s values from existing values list<br/>Example:<br/>
```Objective-C
NSDictionary *tags = @{
    @"Alias" : aliasField.text,
    @"FavNumber" : @([favNumField.text intValue]),
    @"List" : [PWTags removeValuesFromListTag:@[ @"Item1" ]]
};

[[PushNotificationManager pushManager] setTags:tags];
```
<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>array</strong></td>
		<td>Array of values to be removed from the tag.</td>
	</tr>
</table>
<strong>Returns</strong> Dictionary to be sent as the value for the tag 