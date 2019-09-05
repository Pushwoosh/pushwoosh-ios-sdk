
# <a name="heading"></a>protocol PWJavaScriptInterface  
PWJavaScriptInterface protocol is a representation of Javascript object that can be added at runtime into In-App Message HTML page to provide native calls and callbacks to Objective-C/Swift.<br/>Example:<br/>Objective-C: 
```Objective-C
@implementation JavaScriptInterface

- (void)nativeCall:(NSString*)str :(PWJavaScriptCallback*)callback {
   [callback executeWithParam:str];
}

@end

...

[[PWInAppManager sharedManager] addJavascriptInterface:[JavaScriptInterface new] withName:@"ObjC"];
```
<br/>JavaScript: 
```Objective-C
ObjC.nativeCall("exampleString", function(str) {
   console.log(str);
});
```

## Members  

<table>
	<tr>
		<td><a href="#1a3f80ab32c8ae666b2ecbd0ac6e7e5ec5">- (void)onWebViewStartLoad:(UIWebView *)webView</a></td>
	</tr>
	<tr>
		<td><a href="#1acc48793492b4a64c723d844815f07060">- (void)onWebViewFinishLoad:(UIWebView *)webView</a></td>
	</tr>
	<tr>
		<td><a href="#1a69ca3a53aa457414e3ba97a6d261ffe4">- (void)onWebViewStartClose:(UIWebView *)webView</a></td>
	</tr>
</table>


----------  
  

#### <a name="1a3f80ab32c8ae666b2ecbd0ac6e7e5ec5"></a>- (void)onWebViewStartLoad:(UIWebView \*)webView  
Tells the delegate that In-App Message load stated 

----------  
  

#### <a name="1acc48793492b4a64c723d844815f07060"></a>- (void)onWebViewFinishLoad:(UIWebView \*)webView  
Tells the delegate that In-App Message load finished 

----------  
  

#### <a name="1a69ca3a53aa457414e3ba97a6d261ffe4"></a>- (void)onWebViewStartClose:(UIWebView \*)webView  
Tells the delegate that In-App Message is closing 