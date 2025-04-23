
# <a name="heading"></a>protocol PWRichMediaPresentingDelegate&lt;NSObjectNSObject&gt;  
Interface for Rich Media presentation managing. 
## Members  

<table>
	<tr>
		<td><a href="#1a06d32e6522dbf41dd82071b51c54410d">- (BOOL)richMediaManager:(PWRichMediaManager *)richMediaManager shouldPresentRichMedia:(PWRichMedia *)richMedia</a></td>
	</tr>
	<tr>
		<td><a href="#1a7bd5b2f8156d61eed2594abd10018eaf">- (void)richMediaManager:(PWRichMediaManager *)richMediaManager didPresentRichMedia:(PWRichMedia *)richMedia</a></td>
	</tr>
	<tr>
		<td><a href="#1a4c9a7e6409e803087e682412d14f21f0">- (void)richMediaManager:(PWRichMediaManager *)richMediaManager didCloseRichMedia:(PWRichMedia *)richMedia</a></td>
	</tr>
	<tr>
		<td><a href="#1a094bfd1bf0f3269935a212e01539ac64">- (void)richMediaManager:(PWRichMediaManager *)richMediaManager presentingDidFailForRichMedia:(PWRichMedia *)richMedia withError:(NSError *)error</a></td>
	</tr>
</table>


----------  
  

#### <a name="1a06d32e6522dbf41dd82071b51c54410d"></a>- (BOOL)richMediaManager:(PWRichMediaManager \*)richMediaManager shouldPresentRichMedia:(PWRichMedia \*)richMedia  
Checks the delegate whether the Rich Media should be displayed. 

----------  
  

#### <a name="1a7bd5b2f8156d61eed2594abd10018eaf"></a>- (void)richMediaManager:(PWRichMediaManager \*)richMediaManager didPresentRichMedia:(PWRichMedia \*)richMedia  
Tells the delegate that Rich Media has been displayed. 

----------  
  

#### <a name="1a4c9a7e6409e803087e682412d14f21f0"></a>- (void)richMediaManager:(PWRichMediaManager \*)richMediaManager didCloseRichMedia:(PWRichMedia \*)richMedia  
Tells the delegate that Rich Media has been closed. 

----------  
  

#### <a name="1a094bfd1bf0f3269935a212e01539ac64"></a>- (void)richMediaManager:(PWRichMediaManager \*)richMediaManager presentingDidFailForRichMedia:(PWRichMedia \*)richMedia withError:(NSError \*)error  
Tells the delegate that error during Rich Media presenting has been occured. 