
# <a name="heading"></a>class PWInbox : NSObject  

## Members  

<table>
	<tr>
		<td><a href="#1a8b76d820c4effcaa3440c4a29ce6fdec">+ (void)messagesWithNoActionPerformedCountWithCompletion:(void(^)(NSInteger count, NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1ab73de8dcd7da0865e760d89a2d719fcd">+ (void)unreadMessagesCountWithCompletion:(void(^)(NSInteger count, NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a7e1195936ebd49d5a63c47ec260c4ca8">+ (void)messagesCountWithCompletion:(void(^)(NSInteger count, NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1ad53335832b0ed698057fc89eca4837ed">+ (void)loadMessagesWithCompletion:(void(^)(NSArray&lt;NSObject&lt;PWInboxMessageProtocol&gt; *&gt; *messages, NSError *error))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a90ef7fc82a22f7d5a119365ae3bd949c">+ (void)readMessagesWithCodes:(NSArray&lt;NSString *&gt; *)codes</a></td>
	</tr>
	<tr>
		<td><a href="#1ab9ee5b2d0b0aa052e493222ae0458399">+ (void)performActionForMessageWithCode:(NSString *)code</a></td>
	</tr>
	<tr>
		<td><a href="#1a9a2fdeec674758b710289247308da16a">+ (void)deleteMessagesWithCodes:(NSArray&lt;NSString *&gt; *)codes</a></td>
	</tr>
	<tr>
		<td><a href="#1adf914d8ad61b9a37eedba055e123a87a">+ (id&lt;NSObject&gt;)addObserverForDidReceiveInPushNotificationCompletion:(void(^)(NSArray&lt;NSObject&lt;PWInboxMessageProtocol&gt; *&gt; *messagesAdded))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a8dd9025d3506e9e457fe68a7fc659d9f">+ (id&lt;NSObject&gt;)addObserverForUpdateInboxMessagesCompletion:(void(^)(NSArray&lt;NSObject&lt;PWInboxMessageProtocol&gt; *&gt; *messagesDeleted, NSArray&lt;NSObject&lt;PWInboxMessageProtocol&gt; *&gt; *messagesAdded, NSArray&lt;NSObject&lt;PWInboxMessageProtocol&gt; *&gt; *messagesUpdated))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a48977a9207f07bd13f6498987fc9ffa1">+ (id&lt;NSObject&gt;)addObserverForUnreadMessagesCountUsingBlock:(void(^)(NSUInteger count))block</a></td>
	</tr>
	<tr>
		<td><a href="#1ae93eafaaf71e319a0bee022d547a5816">+ (id&lt;NSObject&gt;)addObserverForNoActionPerformedMessagesCountUsingBlock:(void(^)(NSUInteger count))block</a></td>
	</tr>
	<tr>
		<td><a href="#1a3615207158c38bbbe75e81143767c043">+ (void)removeObserver:(id&lt;NSObject&gt;)observer</a></td>
	</tr>
	<tr>
		<td><a href="#1ad36308527a6a65a6f11b73eedc739707">+ (void)updateInboxForNewUserId:(void(^)(NSUInteger messagesCount))completion</a></td>
	</tr>
	<tr>
		<td><a href="#1a4880d842d17260527577455f39107652">- (instancetype)init</a></td>
	</tr>
</table>


----------  
  

#### <a name="1a8b76d820c4effcaa3440c4a29ce6fdec"></a>+ (void)messagesWithNoActionPerformedCountWithCompletion:(void(^)(NSInteger count, NSError \*error))completion  
Get the number of the PWInboxMessageProtocol with no action performed<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>completion</strong></td>
		<td>- if successful, return the number of the InboxMessages with no action performed. Otherwise, return error </td>
	</tr>
</table>


----------  
  

#### <a name="1ab73de8dcd7da0865e760d89a2d719fcd"></a>+ (void)unreadMessagesCountWithCompletion:(void(^)(NSInteger count, NSError \*error))completion  
Get the number of the unread PWInboxMessageProtocol<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>completion</strong></td>
		<td>- if successful, return the number of the unread InboxMessages. Otherwise, return error </td>
	</tr>
</table>


----------  
  

#### <a name="1a7e1195936ebd49d5a63c47ec260c4ca8"></a>+ (void)messagesCountWithCompletion:(void(^)(NSInteger count, NSError \*error))completion  
Get the total number of the PWInboxMessageProtocol<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>completion</strong></td>
		<td>- if successful, return the total number of the InboxMessages. Otherwise, return error </td>
	</tr>
</table>


----------  
  

#### <a name="1ad53335832b0ed698057fc89eca4837ed"></a>+ (void)loadMessagesWithCompletion:(void(^)(NSArray&lt;NSObject&lt;<a href="PWInboxMessageProtocol-p.md">PWInboxMessageProtocol</a>&gt; \*&gt; \*messages, NSError \*error))completion  
Get the collection of the PWInboxMessageProtocol that the user received<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>completion</strong></td>
		<td>- if successful, return the collection of the InboxMessages. Otherwise, return error </td>
	</tr>
</table>


----------  
  

#### <a name="1a90ef7fc82a22f7d5a119365ae3bd949c"></a>+ (void)readMessagesWithCodes:(NSArray&lt;NSString \*&gt; \*)codes  
Call this method to mark the list of InboxMessageProtocol as read<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>codes</strong></td>
		<td>of the inboxMessages </td>
	</tr>
</table>


----------  
  

#### <a name="1ab9ee5b2d0b0aa052e493222ae0458399"></a>+ (void)performActionForMessageWithCode:(NSString \*)code  
Call this method, when the user clicks on the InboxMessageProtocol and the message’s action is performed<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>code</strong></td>
		<td>of the inboxMessage that the user tapped </td>
	</tr>
</table>


----------  
  

#### <a name="1a9a2fdeec674758b710289247308da16a"></a>+ (void)deleteMessagesWithCodes:(NSArray&lt;NSString \*&gt; \*)codes  
Call this method, when the user deletes the list of InboxMessageProtocol manually<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>codes</strong></td>
		<td>of the list of InboxMessageProtocol.code that the user deleted </td>
	</tr>
</table>


----------  
  

#### <a name="1adf914d8ad61b9a37eedba055e123a87a"></a>+ (id&lt;NSObject&gt;)addObserverForDidReceiveInPushNotificationCompletion:(void(^)(NSArray&lt;NSObject&lt;<a href="PWInboxMessageProtocol-p.md">PWInboxMessageProtocol</a>&gt; \*&gt; \*messagesAdded))completion  
Subscribe for messages arriving with push notifications. warning You need to unsubscribe by calling the removeObserver method, if you don't want to receive notifications<br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>completion</strong></td>
		<td>- return the collection of the InboxMessages. </td>
	</tr>
</table>


----------  
  

#### <a name="1a8dd9025d3506e9e457fe68a7fc659d9f"></a>+ (id&lt;NSObject&gt;)addObserverForUpdateInboxMessagesCompletion:(void(^)(NSArray&lt;NSObject&lt;<a href="PWInboxMessageProtocol-p.md">PWInboxMessageProtocol</a>&gt; \*&gt; \*messagesDeleted, NSArray&lt;NSObject&lt;<a href="PWInboxMessageProtocol-p.md">PWInboxMessageProtocol</a>&gt; \*&gt; \*messagesAdded, NSArray&lt;NSObject&lt;<a href="PWInboxMessageProtocol-p.md">PWInboxMessageProtocol</a>&gt; \*&gt; \*messagesUpdated))completion  
Subscribe for messages arriving when a message is deleted, added, or updated. warning You need to unsubscribe by calling the removeObserver method, if you don't want to receive notifications<br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>completion</strong></td>
		<td>- return the collection of the InboxMessages. </td>
	</tr>
</table>


----------  
  

#### <a name="1a48977a9207f07bd13f6498987fc9ffa1"></a>+ (id&lt;NSObject&gt;)addObserverForUnreadMessagesCountUsingBlock:(void(^)(NSUInteger count))block  
Subscribe for unread messages count changes. warning You need to unsubscribe by calling the removeObserver method, if you don't want to receive notifications<br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>block</strong></td>
		<td>- return the count of unread messages. </td>
	</tr>
</table>


----------  
  

#### <a name="1ae93eafaaf71e319a0bee022d547a5816"></a>+ (id&lt;NSObject&gt;)addObserverForNoActionPerformedMessagesCountUsingBlock:(void(^)(NSUInteger count))block  
Subscribe for messages with no action performed count changes. warning You need to unsubscribe by calling the removeObserver method, if you don't want to receive notifications<br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>block</strong></td>
		<td>- return the count of unread messages. </td>
	</tr>
</table>


----------  
  

#### <a name="1a3615207158c38bbbe75e81143767c043"></a>+ (void)removeObserver:(id&lt;NSObject&gt;)observer  
Unsubscribes from notifications<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>observer</strong></td>
		<td>- Unsubscribes observer </td>
	</tr>
</table>


----------  
  

#### <a name="1ad36308527a6a65a6f11b73eedc739707"></a>+ (void)updateInboxForNewUserId:(void(^)(NSUInteger messagesCount))completion  
updates observers 

----------  
  

#### <a name="1a4880d842d17260527577455f39107652"></a>- (instancetype)init  
