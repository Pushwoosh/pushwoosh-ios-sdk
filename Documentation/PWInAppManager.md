# PWInAppManager #

In-App Messages API.

## Tasks

[+ sharedManager](#sharedmanager)  
[- setUserId](#setiserid)  
[- postEvent](#postevent)  
[- addJavascriptInterface](#addjavascriptinterface)  

## Class Methods

### sharedManager

Returns shared instance of PWInAppManager

```objc
+ (instancetype)sharedManager
```


### setUserId

Set User indentifier. This could be Facebook ID, username or email, or any other user ID.
This allows data and events to be matched across multiple user devices.

```objc
- (void)setUserId:(NSString *)userId
```


### postEvent

Post events for In-App Messages. This can trigger In-App message display as specified in Pushwoosh Control Panel.

```objc
- (void)postEvent:(NSString *)event withAttributes:(NSDictionary *)attributes completion:(void (^)(NSError *error))completion
```

 * **event** name of the event
 * **attributes** dictionary with additianal event parameters
 * **completion** postEvent completion handler

Example:

```objc
[[PWInAppManager sharedManager] setUserId:@"96da2f590cd7246bbde0051047b0d6f7"];
[[PWInAppManager sharedManager] postEvent:@"buttonPressed" withAttributes:@{ @"buttonNumber" : @"4", @"buttonLabel" : @"Banner" } completion:nil];
```


### addJavascriptInterface

Adds ObjC object to be accessible from In-App html page JavaScript. All object methods are exported to JavaScript by removing ":" and whitespaces.

```objc
- (void)addJavascriptInterface:(NSObject<PWJavaScriptInterface>*)interface withName:(NSString*)name;
```

 * **interface** ObjC object accessible from JavaScript
 * **name** name of JavaScript object

Example:

**LoggerJS**
```objc

@interface PWInAppStorage : NSObject<PWJavaScriptInterface>
@end

@implementation LoggerJS

- (void)log:(NSString *)message {
	NSLog(@"%@", message);
}

@end
```

**SomeClass**
```objc
...
[[PWInAppManager sharedManager] addJavascriptInterface:[LoggerJS new] withName:@"nativeLogger"];
```

**index.js**
```js
nativeLogger.log("Some string");
```
