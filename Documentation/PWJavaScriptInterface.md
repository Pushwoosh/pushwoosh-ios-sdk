# PWJavaScriptInterface Protocol #

`PWJavaScriptInterface` protocol is a representation of Javascript object that can be added at runtime into In-App Message HTML page to provide native calls and callbacks to Objective-C/Swift.

## Tasks
[– onWebViewStartLoad](#onwebviewstartload)  
[- onWebViewFinishLoad](#onwebviewfinishload)  
[- onWebViewStartClose](#onwebviewstartclose)  

## Class methods

### onWebViewStartLoad

WebView lifecycle callback. Is called when In-App html starts loading.

```objc
- (void)onWebViewStartLoad:(UIWebView*)webView
```

### onWebViewFinishLoad

WebView lifecycle callback. Is called when In-App html loading is finished.


```objc
- (void)onWebViewFinishLoad:(UIWebView*)webView
```

### onWebViewStartClose

WebView lifecycle callback. Is called when In-App html page is about to close.

```objc
- (void)onWebViewStartClose:(UIWebView*)webView
```

