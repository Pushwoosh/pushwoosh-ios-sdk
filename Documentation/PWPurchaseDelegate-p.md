
# <a name="heading"></a>protocol PWPurchaseDelegate&lt;NSObject&gt;  
PWPurchaseDelegate protocol defines the methods that can be implemented in the delegate of the Pushwoosh class' singleton object. These methods provide callbacks for events related to purchasing In-App products from rich medias, such as successful purchase event, failed payment, etc. These methods implementation allows to react on such events properly. 
## Members  

<table>
	<tr>
		<td><a href="#1aa3aa2cd86030c676cb0263f7dfc0da38">- (void)onPWInAppPurchaseHelperProducts:(NSArray&lt;SKProduct *&gt; *_Nullable)products</a></td>
	</tr>
	<tr>
		<td><a href="#1a41112ade0f3fe66dd3927b05f0d83741">- (void)onPWInAppPurchaseHelperPaymentComplete:(NSString *_Nullable)identifier</a></td>
	</tr>
	<tr>
		<td><a href="#1afe6ba0166b6dece1f77613711f14623b">- (void)onPWInAppPurchaseHelperPaymentFailedProductIdentifier:(NSString *_Nullable)identifier error:(NSError *_Nullable)error</a></td>
	</tr>
	<tr>
		<td><a href="#1a6293e30dc66a113f8188a934500dd041">- (void)onPWInAppPurchaseHelperCallPromotedPurchase:(NSString *_Nullable)identifier</a></td>
	</tr>
	<tr>
		<td><a href="#1a8f3a21a6b045b0e32114881149600aff">- (void)onPWInAppPurchaseHelperRestoreCompletedTransactionsFailed:(NSError *_Nullable)error</a></td>
	</tr>
</table>


----------  
  

#### <a name="1aa3aa2cd86030c676cb0263f7dfc0da38"></a>- (void)onPWInAppPurchaseHelperProducts:(NSArray&lt;SKProduct \*&gt; \*\_Nullable)products  


----------  
  

#### <a name="1a41112ade0f3fe66dd3927b05f0d83741"></a>- (void)onPWInAppPurchaseHelperPaymentComplete:(NSString \*\_Nullable)identifier  


----------  
  

#### <a name="1afe6ba0166b6dece1f77613711f14623b"></a>- (void)onPWInAppPurchaseHelperPaymentFailedProductIdentifier:(NSString \*\_Nullable)identifier error:(NSError \*\_Nullable)error  


----------  
  

#### <a name="1a6293e30dc66a113f8188a934500dd041"></a>- (void)onPWInAppPurchaseHelperCallPromotedPurchase:(NSString \*\_Nullable)identifier  


----------  
  

#### <a name="1a8f3a21a6b045b0e32114881149600aff"></a>- (void)onPWInAppPurchaseHelperRestoreCompletedTransactionsFailed:(NSError \*\_Nullable)error  
