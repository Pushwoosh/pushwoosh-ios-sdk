
# <a name="heading"></a>class PWMessage : NSObject  
Message from Pushwoosh. 
## Members  

<table>
	<tr>
		<td><a href="#1aecf83b72f600bc65ae4dbe7706a90cc6">@property NSString *_Nullable</a></td>
	</tr>
	<tr>
		<td><a href="#1ab365d5ab62ebc13c91f231f3c2c9a570">@property NSUInteger badge</a></td>
	</tr>
	<tr>
		<td><a href="#1a5ab472e4bef8f1ced38a12e8651c50d2">@property uint64_t messageId</a></td>
	</tr>
	<tr>
		<td><a href="#1aec059e69dbd3e7c012c6b4de4da4c568">@property uint64_t campaignId</a></td>
	</tr>
	<tr>
		<td><a href="#1ac7d0b924c194696c787a77fb51cc6a81">@property NSUInteger badgeExtension</a></td>
	</tr>
	<tr>
		<td><a href="#1aad03d7da48cd4f84c28d2b3f1524351c">@property BOOL foregroundMessage</a></td>
	</tr>
	<tr>
		<td><a href="#1ae676998a2448d3e00e13f3ce3e3ff7bb">@property BOOL contentAvailable</a></td>
	</tr>
	<tr>
		<td><a href="#1afb8a25a51b17fdb4d6d0406ea93cb3a1">@property BOOL inboxMessage</a></td>
	</tr>
	<tr>
		<td><a href="#1a018d9ef3c615dedad1d73b2d5239b16a">@property NSDictionary *_Nullable</a></td>
	</tr>
	<tr>
		<td><a href="#1abfddd755ecd6390f7f6f79b36f39ff0b">+ (BOOL)isPushwooshMessage:(NSDictionary *_Nonnull)userInfo</a></td>
	</tr>
</table>


----------  
  

#### <a name="1aecf83b72f600bc65ae4dbe7706a90cc6"></a>@property NSString \*_Nullable  
Title of the push message.<br/>Subtitle of the push message.<br/>Body of the push message.<br/>Message code of the push message.<br/>Remote URL or deeplink from the push message.<br/>Returns actionIdentifier of the button pressed<br/>Original payload of the message. 

----------  
  

#### <a name="1ab365d5ab62ebc13c91f231f3c2c9a570"></a>@property NSUInteger badge  
Badge number of the push message. 

----------  
  

#### <a name="1a5ab472e4bef8f1ced38a12e8651c50d2"></a>@property uint64\_t messageId  
Unique identifier of the message. 

----------  
  

#### <a name="1aec059e69dbd3e7c012c6b4de4da4c568"></a>@property uint64\_t campaignId  
Unique identifier of the campaign. 

----------  
  

#### <a name="1ac7d0b924c194696c787a77fb51cc6a81"></a>@property NSUInteger badgeExtension  
Extension badge number of the push message. 

----------  
  

#### <a name="1aad03d7da48cd4f84c28d2b3f1524351c"></a>@property BOOL foregroundMessage  
Returns YES if this message received/opened then the app is in foreground state. 

----------  
  

#### <a name="1ae676998a2448d3e00e13f3ce3e3ff7bb"></a>@property BOOL contentAvailable  
Returns YES if this message contains 'content-available' key (silent or newsstand push). 

----------  
  

#### <a name="1afb8a25a51b17fdb4d6d0406ea93cb3a1"></a>@property BOOL inboxMessage  
Returns YES if this is inbox message. 

----------  
  

#### <a name="1a018d9ef3c615dedad1d73b2d5239b16a"></a>@property NSDictionary \*_Nullable  
Gets custom JSON data from push notifications dictionary as specified in Pushwoosh Control Panel.<br/>Original payload of the message. 

----------  
  

#### <a name="1abfddd755ecd6390f7f6f79b36f39ff0b"></a>+ (BOOL)isPushwooshMessage:(NSDictionary \*\_Nonnull)userInfo  
Returns YES if this message is recieved from Pushwoosh. 