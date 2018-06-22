
# PWRichMediaManager#

| Header | [PWRichMediaManager.h](../Framework/Pushwoosh.framework/Versions/A/Headers/PWRichMediaManager.h) |
| ------ | ---------------------------------------------------------------------------------------- |

Offers access to the singleton-instance of the manager responsible for Rich Media presentation.


## Summary

[delegate](#delegate) *_property_*

[+ sharedManager](#sharedmanager)

[- presentRichMedia:](#presentrichmedia)

## Properties

### delegate
Delegate for Rich Media presentation managing.

```objc

@property (nonatomic) id<PWRichMediaPresentingDelegate> delegate;

```
---

## Class Methods

### sharedManager
A singleton object that represents the rich media manager.
```objc

+ (instancetype)sharedManager;

```

---

## Instance Methods


### presentRichMedia:
Presents the rich media object.
```objc

- (void)presentRichMedia:(PWRichMedia *)richMedia;

```

---
