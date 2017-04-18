# PWJavaScriptCallback #

`PWJavaScriptCallback` is a representation of Javascript function. Can be used to pass JavaScript functions into Swift/Objective-C code.
Supports only string(NSString) arguments.

## Tasks
[– execute](#execute)  
[- executeWithParam](#executewithparam)  
[- executeWithParams](#executewithparams)  

## Class methods

### execute

Invokes callback with no arguments.

```objc
- (NSString*)execute
```

### executeWithParam

Invokes callback with one argument.

```objc
- (NSString*)executeWithParam:(NSString*)param
```

### executeWithParams

Invokes callback with multiple arguments.

```objc
- (NSString*)executeWithParams:(NSArray*)params
```

