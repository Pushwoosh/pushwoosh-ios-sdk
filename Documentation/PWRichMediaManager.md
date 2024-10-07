
# <a name="heading"></a>class PWRichMediaManager : NSObject  

## Members  

<table>
	<tr>
		<td><a href="#1ad9f33c59136b94047ad25de198e32448">@property PWRichMediaStyle *richMediaStyle</a></td>
	</tr>
	<tr>
		<td><a href="#1a65042870d8e1dfe3379e0388f4445de5">@property id&lt;PWRichMediaPresentingDelegate&gt; delegate</a></td>
	</tr>
	<tr>
		<td><a href="#1acfeecba381e57e6e1fc3fef93d98c523">+ (instancetype)sharedManager</a></td>
	</tr>
	<tr>
		<td><a href="#1a93601cf8b2fa3b6387da0b245a7794a7">- (void)presentRichMedia:(PWRichMedia *)richMedia</a></td>
	</tr>
</table>


----------  
  

#### <a name="1ad9f33c59136b94047ad25de198e32448"></a>@property <a href="PWRichMediaStyle.md">PWRichMediaStyle</a> \*richMediaStyle  
Style for Rich Media presenting. 

----------  
  

#### <a name="1a65042870d8e1dfe3379e0388f4445de5"></a>@property id&lt;<a href="PWRichMediaPresentingDelegate-p.md">PWRichMediaPresentingDelegate</a>&gt; delegate  
Delegate for Rich Media presentation managing. 

----------  
  

#### <a name="1acfeecba381e57e6e1fc3fef93d98c523"></a>+ (instancetype)sharedManager  
A singleton object that represents the rich media manager. 

----------  
  

#### <a name="1a93601cf8b2fa3b6387da0b245a7794a7"></a>- (void)presentRichMedia:(PWRichMedia \*)richMedia  
Presents the rich media object. 