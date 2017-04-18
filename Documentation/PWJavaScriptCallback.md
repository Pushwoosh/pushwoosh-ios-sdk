# PWJavaScriptCallback #

| Header | [PWInAppManager.h](../Framework/Pushwoosh.framework/Versions/A/Headers/PWInAppManager.h) |
| ------ | ---------------------------------------------------------------------------------------- |

`PWJavaScriptCallback` is a representation of Javascript function. Can be used to pass JavaScript functions into Swift/Objective-C code.
Supports only string(NSString) arguments.

## Summary
[– execute](#execute)  
[- executeWithParam:](#executewithparam)  
[- executeWithParams:](#executewithparams)  

## Instance Methods

### execute

Invokes callback with no arguments.

```objc
- (NSString*)execute
```

---

### executeWithParam:

Invokes callback with one argument.

```objc
- (NSString*)executeWithParam:(NSString*)param
```

---

### executeWithParams:

Invokes callback with multiple arguments.

```objc
- (NSString*)executeWithParams:(NSArray*)params
```

