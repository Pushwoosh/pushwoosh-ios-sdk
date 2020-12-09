
# <a name="heading"></a>class PWMessage : NSObject  
Message from Pushwoosh. 
## Members  

<table>
	<tr>
		<td><a href="#1ab5c82fb11a261cc567417627d38c5975">@property NSString *title</a></td>
	</tr>
	<tr>
		<td><a href="#1a5dcb2cd749bcbe79c941ddb327465517">@property NSString *subTitle</a></td>
	</tr>
	<tr>
		<td><a href="#1ab1fd3f3f97365a25eb2926d49da198ee">@property NSString *message</a></td>
	</tr>
	<tr>
		<td><a href="#1ab365d5ab62ebc13c91f231f3c2c9a570">@property NSUInteger badge</a></td>
	</tr>
	<tr>
		<td><a href="#1ae0e889873dcc1961787928f64da95a69">@property NSString *link</a></td>
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
		<td><a href="#1a34fc0dffbfd64bc53e1eed03327ca052">@property NSDictionary *customData</a></td>
	</tr>
	<tr>
		<td><a href="#1a8fc910e8a8d8869955f620ac6a8521b3">@property NSDictionary *payload</a></td>
	</tr>
	<tr>
		<td><a href="#1af0d03793d4a4db71b60408c2ded7020d">+ (BOOL)isPushwooshMessage:(NSDictionary *)userInfo</a></td>
	</tr>
</table>


----------  
  

#### <a name="1ab5c82fb11a261cc567417627d38c5975"></a>@property NSString \*title  
Title of the push message. 

----------  
  

#### <a name="1a5dcb2cd749bcbe79c941ddb327465517"></a>@property NSString \*subTitle  
Subtitle of the push message. 

----------  
  

#### <a name="1ab1fd3f3f97365a25eb2926d49da198ee"></a>@property NSString \*message  
Body of the push message. 

----------  
  

#### <a name="1ab365d5ab62ebc13c91f231f3c2c9a570"></a>@property NSUInteger badge  
Badge number of the push message. 

----------  
  

#### <a name="1ae0e889873dcc1961787928f64da95a69"></a>@property NSString \*link  
Remote URL or deeplink from the push message. 

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
  

#### <a name="1a34fc0dffbfd64bc53e1eed03327ca052"></a>@property NSDictionary \*customData  
Gets custom JSON data from push notifications dictionary as specified in Pushwoosh Control Panel. 

----------  
  

#### <a name="1a8fc910e8a8d8869955f620ac6a8521b3"></a>@property NSDictionary \*payload  
Original payload of the message. 

----------  
  

#### <a name="1af0d03793d4a4db71b60408c2ded7020d"></a>+ (BOOL)isPushwooshMessage:(NSDictionary \*)userInfo  
Returns YES if this message is recieved from Pushwoosh. 