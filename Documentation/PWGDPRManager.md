
# <a name="heading"></a>class PWGDPRManager : NSObject  

## Members  

<table>
	<tr>
		<td><a href="#1aafb4c03bd1b8ce53a6957444f664d586">@property BOOL available</a></td>
	</tr>
	<tr>
		<td><a href="#1a218139fc7170faaec0b9cda904963c41">@property BOOL communicationEnabled</a></td>
	</tr>
	<tr>
		<td><a href="#1ae8a86ec152c1e0e5ce73efab81724ea7">@property BOOL deviceDataRemoved</a></td>
	</tr>
	<tr>
		<td><a href="#1a6e89b32cccd55d8ae36fceb63aaf97b6">+ (instancetype)sharedManager</a></td>
	</tr>
	<tr>
		<td><a href="#1a4d07351b5a24dc21ce30b0c7dfbbf9f6">- (void)setCommunicationEnabled:(BOOL)enabled completion:(void(^)(NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a5f9c4520f769c841c5da392f4e17003c">- (void)removeAllDeviceDataWithCompletion:(void(^)(NSError *error))completion</a></td>
	</tr>
</table>


----------  
  

#### <a name="1aafb4c03bd1b8ce53a6957444f664d586"></a>@property BOOL available  
Indicates availability of the GDPR compliance solution. 

----------  
  

#### <a name="1a218139fc7170faaec0b9cda904963c41"></a>@property BOOL communicationEnabled  


----------  
  

#### <a name="1ae8a86ec152c1e0e5ce73efab81724ea7"></a>@property BOOL deviceDataRemoved  


----------  
  

#### <a name="1a6e89b32cccd55d8ae36fceb63aaf97b6"></a>+ (instancetype)sharedManager  


----------  
  

#### <a name="1a4d07351b5a24dc21ce30b0c7dfbbf9f6"></a>- (void)setCommunicationEnabled:(BOOL)enabled completion:(void(^)(NSError \*error))completion  
Enable/disable all communication with Pushwoosh. Enabled by default. 

----------  
  

#### <a name="1a5f9c4520f769c841c5da392f4e17003c"></a>- (void)removeAllDeviceDataWithCompletion:(void(^)(NSError \*error))completion  
Removes all device data from Pushwoosh and stops all interactions and communication permanently. 