
# <a name="heading"></a>protocol PWRichMediaStyleAnimationDelegate&lt;NSObject&gt;  
Interface for Rich Media Custom Animation. 
## Members  

<table>
	<tr>
		<td><a href="#1a5a05fe4332a8fc4d3d27fa0dcefafcaf">- (void)runPresentingAnimationWithContentView:(UIView *)contentView parentView:(UIView *)parentView completion:(dispatch_block_t)completion</a></td>
	</tr>
	<tr>
		<td><a href="#1abedb0a2a61bff863820dd4d170b7ec74">- (void)runDismissingAnimationWithContentView:(UIView *)contentView parentView:(UIView *)parentView completion:(dispatch_block_t)completion</a></td>
	</tr>
</table>


----------  
  

#### <a name="1a5a05fe4332a8fc4d3d27fa0dcefafcaf"></a>- (void)runPresentingAnimationWithContentView:(UIView \*)contentView parentView:(UIView \*)parentView completion:(dispatch\_block\_t)completion  
This method can be used to animate Rich Media presenting view. 

----------  
  

#### <a name="1abedb0a2a61bff863820dd4d170b7ec74"></a>- (void)runDismissingAnimationWithContentView:(UIView \*)contentView parentView:(UIView \*)parentView completion:(dispatch\_block\_t)completion  
This method can be used to animate Rich Media dismissing view. 