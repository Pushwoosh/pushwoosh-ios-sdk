
# PWRichMedia #

| Header | [PWRichMediaManager.h](../Framework/Pushwoosh.framework/Versions/A/Headers/PWRichMediaManager.h) |
| ------ | ---------------------------------------------------------------------------------------- |

Represents Rich Media page object.

## Summary
[source](#source) *property*  
[content](#content) *property*  
[required](#required) *property*  

## Properties

### source

Rich Media presenter type.


```objc
@property (nonatomic, readonly) PWRichMediaSource source;
```

---
### content

Content of the Rich Media. For PWRichMediaSourceInApp it's equal to In-App code, for PWRichMediaSourcePush it's equal to Rich Media code.


```objc
@property (nonatomic, readonly) NSString *content;
```

---
### required

Checks if PWRichMediaSourceInApp is a required In-App. Always returns YES for PWRichMediaSourcePush.


```objc
@property (nonatomic, readonly, getter=isRequired) BOOL required;
```

---
