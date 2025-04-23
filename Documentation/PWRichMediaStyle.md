
# <a name="heading"></a>class PWRichMediaStyle : NSObject  
Custom Rich Media loading view. It is shown while Rich Media is loading. 'PWRichMediaStyle' class allows customizing the appearance of Rich Media pages. 
## Members  

<table>
	<tr>
		<td><a href="#1a0ac5cd12a0eeee733ac5d4c8bdee0e31">@property id&lt;PWRichMediaStyleAnimationDelegate&gt; animationDelegate</a></td>
	</tr>
	<tr>
		<td><a href="#1a460c0c46605926ec378acb7c3bb4b932">@property NSTimeInterval closeButtonPresentingDelay</a></td>
	</tr>
	<tr>
		<td><a href="#1aea1aa6a8116dcad747f75cefcf912557">@property BOOL shouldHideStatusBar</a></td>
	</tr>
	<tr>
		<td><a href="#1a89331ec6e1e51285b55013f0b9a36ba0">@property NSNumber *allowsInlineMediaPlayback</a></td>
	</tr>
	<tr>
		<td><a href="#1ab0a07a2be0ee8a7cb3dc671921388e55">@property NSNumber *mediaPlaybackRequiresUserAction</a></td>
	</tr>
</table>


----------  
  

#### <a name="1a0ac5cd12a0eeee733ac5d4c8bdee0e31"></a>@property id&lt;<a href="PWRichMediaStyleAnimationDelegate-p.md">PWRichMediaStyleAnimationDelegate</a>&gt; animationDelegate  
Background color of Rich Media pages. Delegate to manage Rich Media presenting animation. 

----------  
  

#### <a name="1a460c0c46605926ec378acb7c3bb4b932"></a>@property NSTimeInterval closeButtonPresentingDelay  
Block to customize Rich Media loading view.<br/>Example: 
```Objective-C
style.loadingViewBlock = ^PWLoadingView *{
   return [[[NSBundle mainBundle] loadNibNamed:@"LoadingView" owner:self options:nil] lastObject];
};
```
 Delay of the close button presenting in seconds. 

----------  
  

#### <a name="1aea1aa6a8116dcad747f75cefcf912557"></a>@property BOOL shouldHideStatusBar  
Should status bar to be hidden or not while Rich Media page is presented. Default is 'YES'. 

----------  
  

#### <a name="1a89331ec6e1e51285b55013f0b9a36ba0"></a>@property NSNumber \*allowsInlineMediaPlayback  
A Boolean value that determines whether HTML5 videos play inline or use the native full-screen controller. 

----------  
  

#### <a name="1ab0a07a2be0ee8a7cb3dc671921388e55"></a>@property NSNumber \*mediaPlaybackRequiresUserAction  
A Boolean value that determines whether HTML5 videos can play automatically or require the user to start playing them. 