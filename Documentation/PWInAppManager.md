
# <a name="heading"></a>class PWInAppManager : NSObject  

## Members  

<table>
	<tr>
		<td><a href="#1a49c87bae4b7c156655b687d7fef44842">+ (instancetype)sharedManager</a></td>
	</tr>
	<tr>
		<td><a href="#1aa12c8d575a4969c9d50a50ce0935e5ab">+ (void)updateInAppManagerInstance</a></td>
	</tr>
	<tr>
		<td><a href="#1a7b1bb8202b67bfb20ae4fbd8750b1c4a">- (void)setUserId:(NSString *)userId</a></td>
	</tr>
	<tr>
		<td><a href="#1a7a2fa8fb95d6e6a9ec18ef73a000927f">- (void)setUserId:(NSString *)userId completion:(void(^)(NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a02638dac9aeb7cf8ceb0b555a3a40b65">- (void)setUser:(NSString *)userId emails:(NSArray *)emails completion:(void(^)(NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1ac12417ff8361927e3a9c565ce3ec4795">- (void)setEmails:(NSArray *)emails completion:(void(^)(NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a716053392e1af46ed4d8c0a581f41e33">- (void)mergeUserId:(NSString *)oldUserId to:(NSString *)newUserId doMerge:(BOOL)doMerge completion:(void(^)(NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a03ea81f92233aa5350abb80aa3265cff">- (void)postEvent:(NSString *)event withAttributes:(NSDictionary *)attributes completion:(void(^)(NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a6bbae004bf3b27d6eef87043b5a183a9">- (void)postEvent:(NSString *)event withAttributes:(NSDictionary *)attributes</a></td>
	</tr>
</table>


----------  
  

#### <a name="1a49c87bae4b7c156655b687d7fef44842"></a>+ (instancetype)sharedManager  


----------  
  

#### <a name="1aa12c8d575a4969c9d50a50ce0935e5ab"></a>+ (void)updateInAppManagerInstance  


----------  
  

#### <a name="1a7b1bb8202b67bfb20ae4fbd8750b1c4a"></a>- (void)setUserId:(NSString \*)userId  
Set User indentifier. This could be Facebook ID, username or email, or any other user ID. This allows data and events to be matched across multiple user devices. 

----------  
  

#### <a name="1a7a2fa8fb95d6e6a9ec18ef73a000927f"></a>- (void)setUserId:(NSString \*)userId completion:(void(^)(NSError \*error))completion  
Set User indentifier. This could be Facebook ID, username or email, or any other user ID. This allows data and events to be matched across multiple user devices. If setUser succeeds competion is called with nil argument. If setUser fails completion is called with error. 

----------  
  

#### <a name="1a02638dac9aeb7cf8ceb0b555a3a40b65"></a>- (void)setUser:(NSString \*)userId emails:(NSArray \*)emails completion:(void(^)(NSError \*error))completion  
Set User indentifier. This could be Facebook ID, username or email, or any other user ID. This allows data and events to be matched across multiple user devices.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>userId</strong></td>
		<td>user identifier </td>
	</tr>
	<tr>
		<td><strong>emails</strong></td>
		<td>user's emails array </td>
	</tr>
</table>


----------  
  

#### <a name="1ac12417ff8361927e3a9c565ce3ec4795"></a>- (void)setEmails:(NSArray \*)emails completion:(void(^)(NSError \*error))completion  
Register emails list associated to the current user.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>emails</strong></td>
		<td>user's emails array </td>
	</tr>
</table>


----------  
  

#### <a name="1a716053392e1af46ed4d8c0a581f41e33"></a>- (void)mergeUserId:(NSString \*)oldUserId to:(NSString \*)newUserId doMerge:(BOOL)doMerge completion:(void(^)(NSError \*error))completion  
Move all events from oldUserId to newUserId if doMerge is true. If doMerge is false all events for oldUserId are removed.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>oldUserId</strong></td>
		<td>source user </td>
	</tr>
	<tr>
		<td><strong>newUserId</strong></td>
		<td>destination user </td>
	</tr>
	<tr>
		<td><strong>doMerge</strong></td>
		<td>if false all events for oldUserId are removed, if true all events for oldUserId are moved to newUserId </td>
	</tr>
	<tr>
		<td><strong>completion</strong></td>
		<td>callback </td>
	</tr>
</table>


----------  
  

#### <a name="1a03ea81f92233aa5350abb80aa3265cff"></a>- (void)postEvent:(NSString \*)event withAttributes:(NSDictionary \*)attributes completion:(void(^)(NSError \*error))completion  
Post events for In-App Messages. This can trigger In-App message display as specified in Pushwoosh Control Panel.<br/>Example: 
```Objective-C
[[PWInAppManager sharedManager] setUserId:@"96da2f590cd7246bbde0051047b0d6f7"];
[[PWInAppManager sharedManager] postEvent:@"buttonPressed" withAttributes:@{ @"buttonNumber" : @"4", @"buttonLabel" : @"Banner" } completion:nil];
```
<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>event</strong></td>
		<td>name of the event </td>
	</tr>
	<tr>
		<td><strong>attributes</strong></td>
		<td>NSDictionary of event attributes </td>
	</tr>
	<tr>
		<td><strong>completion</strong></td>
		<td>function to call after posting event </td>
	</tr>
</table>


----------  
  

#### <a name="1a6bbae004bf3b27d6eef87043b5a183a9"></a>- (void)postEvent:(NSString \*)event withAttributes:(NSDictionary \*)attributes  
See postEvent:withAttributes:completion: