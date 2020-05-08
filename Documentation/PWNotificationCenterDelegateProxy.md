
# <a name="heading"></a>class PWNotificationCenterDelegateProxy : NSObject&lt;UNUserNotificationCenterDelegate&gt;  
PWNotificationCenterDelegateProxy class handles notifications on iOS 10 and forwards methods of UNUserNotificationCenterDelegate to all added delegates. 
## Members  

<table>
	<tr>
		<td><a href="#1ade300d15fc92827d39a373e4cf49c551">- (void)addNotificationCenterDelegate:(id&lt;UNUserNotificationCenterDelegate&gt;)delegate</a></td>
	</tr>
</table>


----------  
  

#### <a name="1ade300d15fc92827d39a373e4cf49c551"></a>- (void)addNotificationCenterDelegate:(id&lt;UNUserNotificationCenterDelegate&gt;)delegate  
Returns UNUserNotificationCenterDelegate that handles foreground push notifications on iOS10 Adds extra UNUserNotificationCenterDelegate that handles foreground push notifications on iOS10. 