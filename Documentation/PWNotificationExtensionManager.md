
# <a name="heading"></a>class PWNotificationExtensionManager : NSObject  

## Members  

<table>
	<tr>
		<td><a href="#1a3f88e929cd02d686ffda946ad238575f">+ (instancetype)sharedManager</a></td>
	</tr>
	<tr>
		<td><a href="#1a5c4c0640df52e8b6bf08ad83d9fff58b">- (void)handleNotificationRequest:(UNNotificationRequest *)request contentHandler:(void(^)(UNNotificationContent *))contentHandler</a></td>
	</tr>
	<tr>
		<td><a href="#1aae2803d91297c0f346bf89bc41736ae2">- (void)handleNotificationRequest:(UNNotificationRequest *)request withAppGroups:(NSString *_Nullable)appGroupsName</a></td>
	</tr>
</table>


----------  
  

#### <a name="1a3f88e929cd02d686ffda946ad238575f"></a>+ (instancetype)sharedManager  


----------  
  

#### <a name="1a5c4c0640df52e8b6bf08ad83d9fff58b"></a>- (void)handleNotificationRequest:(UNNotificationRequest \*)request contentHandler:(void(^)(UNNotificationContent \*))contentHandler  
Sends message delivery event to Pushwoosh and downloads media attachment. Call it from UNNotificationServiceExtension. Don't forget to set Pushwoosh\_APPID in extension Info.plist.<br/>Example: 
```Objective-C
- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
    self.contentHandler = contentHandler;
    self.bestAttemptContent = [request.content mutableCopy];
    
    [[PWNotificationExtensionManager sharedManager] handleNotificationRequest:request contentHandler:contentHandler];
}
```


----------  
  

#### <a name="1aae2803d91297c0f346bf89bc41736ae2"></a>- (void)handleNotificationRequest:(UNNotificationRequest \*)request withAppGroups:(NSString \*\_Nullable)appGroupsName  
Example: 
```Objective-C
- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
    self.contentHandler = contentHandler;
    self.bestAttemptContent = [request.content mutableCopy];
    
    [[PWNotificationExtensionManager sharedManager] handleNotificationRequest:request withAppGroups:@"group.com.example_domain.example_app_name."];
}
```
