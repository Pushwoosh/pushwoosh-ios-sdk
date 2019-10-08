
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
		<td><a href="#1aca9102ee4315b23f4419c92b5d7f34e7">- (void)onWebViewStartLoad:(WKWebView *)webView</a></td>
	</tr>
	<tr>
		<td><a href="#1a9678811c3251738122d3323ae4eb06a8">- (void)onWebViewFinishLoad:(WKWebView *)webView</a></td>
	</tr>
	<tr>
		<td><a href="#1ae1a5e1699ff0dcb2d6a32bac3128d7ad">- (void)onWebViewStartClose:(WKWebView *)webView</a></td>
	</tr>
</table>


----------  
  

#### <a name="1aca9102ee4315b23f4419c92b5d7f34e7"></a>- (void)onWebViewStartLoad:(WKWebView \*)webView  
Tells the delegate that In-App Message load stated 

----------  
  

#### <a name="1a9678811c3251738122d3323ae4eb06a8"></a>- (void)onWebViewFinishLoad:(WKWebView \*)webView  
Tells the delegate that In-App Message load finished 

----------  
  

#### <a name="1ae1a5e1699ff0dcb2d6a32bac3128d7ad"></a>- (void)onWebViewStartClose:(WKWebView \*)webView  
Tells the delegate that In-App Message is closing 