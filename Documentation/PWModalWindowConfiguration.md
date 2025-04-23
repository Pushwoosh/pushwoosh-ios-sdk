
# <a name="heading"></a>class PWModalWindowConfiguration : NSObject  

## Members  

<table>
	<tr>
		<td><a href="#1a5f8d00538f404342dfc5838615b30519">+ (instancetype)shared</a></td>
	</tr>
	<tr>
		<td><a href="#1a05a1642033098b6ce1cbd99264574bed">- (void)configureModalWindowWith:(ModalWindowPosition)position presentAnimation:(PresentModalWindowAnimation)presentAnimation dismissAnimation:(DismissModalWindowAnimation)dismissAnimation</a></td>
	</tr>
	<tr>
		<td><a href="#1ad451803070b3619fd0bd0f6addfa317e">- (void)setDismissSwipeDirections:(NSArray&lt;NSNumber *&gt; *)swipeDirection</a></td>
	</tr>
	<tr>
		<td><a href="#1a8ae9ca8575e4665772bf0e1eb6217e01">- (void)setPresentHapticFeedbackType:(HapticFeedbackType)type</a></td>
	</tr>
	<tr>
		<td><a href="#1ae5629b7edb0326eac6c22080479cc7e5">- (void)setCornerType:(CornerType)type withRadius:(CGFloat)radius</a></td>
	</tr>
	<tr>
		<td><a href="#1ab14b651f66b2c2c69ef9d24cfe4f126c">- (void)closeModalWindowAfter:(NSTimeInterval)interval</a></td>
	</tr>
	<tr>
		<td><a href="#1a89ad2815d81700a2ec4356631f50c17f">- (void)presentModalWindow:(PWRichMedia *)richMedia</a></td>
	</tr>
</table>


----------  
  

#### <a name="1a5f8d00538f404342dfc5838615b30519"></a>+ (instancetype)shared  
Provides access to the shared instance of the modal window manager.<br/><br/><br/><strong>Returns</strong> A singleton instance of the modal window manager. 

----------  
  

#### <a name="1a05a1642033098b6ce1cbd99264574bed"></a>- (void)configureModalWindowWith:(ModalWindowPosition)position presentAnimation:(PresentModalWindowAnimation)presentAnimation dismissAnimation:(DismissModalWindowAnimation)dismissAnimation  
Configures the modal window to be displayed at a specified position on the screen and defines the animation styles for presenting and dismissing the window.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>position</strong></td>
		<td>The screen position where the modal window will be displayed (e.g., top, bottom). </td>
	</tr>
	<tr>
		<td><strong>presentAnimation</strong></td>
		<td>The animation style used when the modal window is presented (e.g., fade, slide). </td>
	</tr>
	<tr>
		<td><strong>dismissAnimation</strong></td>
		<td>The animation style used when the modal window is dismissed (e.g., fade, slide). </td>
	</tr>
</table>


----------  
  

#### <a name="1ad451803070b3619fd0bd0f6addfa317e"></a>- (void)setDismissSwipeDirections:(NSArray&lt;NSNumber \*&gt; \*)swipeDirection  
Configures swipe gestures for interacting with the modal window. These gestures allow the user to dismiss the window by swiping in specified directions.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>swipeDirection</strong></td>
		<td>An array of swipe directions allowed for dismissing the modal window (e.g., up, down, left, right). </td>
	</tr>
</table>


----------  
  

#### <a name="1a8ae9ca8575e4665772bf0e1eb6217e01"></a>- (void)setPresentHapticFeedbackType:(HapticFeedbackType)type  
Sets the type of haptic feedback that will be triggered when the modal window is presented.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>type</strong></td>
		<td>The type of haptic feedback to be used (e.g., light, medium, heavy). </td>
	</tr>
</table>


----------  
  

#### <a name="1ae5629b7edb0326eac6c22080479cc7e5"></a>- (void)setCornerType:(CornerType)type withRadius:(CGFloat)radius  
Sets the corner type and radius for rounding specific corners of the view.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>type</strong></td>
		<td>The type of corners to be rounded (e.g., top-left, bottom-right, or a combination). </td>
	</tr>
	<tr>
		<td><strong>radius</strong></td>
		<td>The radius of the corner rounding. </td>
	</tr>
</table>


----------  
  

#### <a name="1ab14b651f66b2c2c69ef9d24cfe4f126c"></a>- (void)closeModalWindowAfter:(NSTimeInterval)interval  
Schedules the automatic closing of the modal window after a specified time interval.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>interval</strong></td>
		<td>The time interval, in seconds, after which the modal window will be automatically closed. </td>
	</tr>
</table>


----------  
  

#### <a name="1a89ad2815d81700a2ec4356631f50c17f"></a>- (void)presentModalWindow:(PWRichMedia \*)richMedia  
Presents the modal window with the specified rich media content.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>richMedia</strong></td>
		<td>The rich media content that will be displayed inside the modal window. </td>
	</tr>
</table>
