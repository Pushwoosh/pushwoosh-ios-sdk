
# <a name="heading"></a>class PWRichMedia : NSObject  

## Members  

<table>
	<tr>
		<td><a href="#1aa0e807bff47630b06e34e6da970205ba">@property PWRichMediaSource source</a></td>
	</tr>
	<tr>
		<td><a href="#1a375fb5e717c16d5f602377e7c80de5ac">@property NSString *content</a></td>
	</tr>
	<tr>
		<td><a href="#1a58f1b947f392021e2c3309f0f4e92f63">@property NSDictionary *pushPayload</a></td>
	</tr>
	<tr>
		<td><a href="#1a4afbbb0ecd2806e4676158576c154866">@property BOOL required</a></td>
	</tr>
</table>


----------  
  

#### <a name="1aa0e807bff47630b06e34e6da970205ba"></a>@property PWRichMediaSource source  
Rich Media presenter type. 

----------  
  

#### <a name="1a375fb5e717c16d5f602377e7c80de5ac"></a>@property NSString \*content  
Content of the Rich Media. For PWRichMediaSourceInApp it's equal to In-App code, for PWRichMediaSourcePush it's equal to Rich Media code. 

----------  
  

#### <a name="1a58f1b947f392021e2c3309f0f4e92f63"></a>@property NSDictionary \*pushPayload  
Payload of the associated push notification if source is equal to PWRichMediaSourcePush. 

----------  
  

#### <a name="1a4afbbb0ecd2806e4676158576c154866"></a>@property BOOL required  
Checks if PWRichMediaSourceInApp is a required In-App. Always returns YES for PWRichMediaSourcePush. 