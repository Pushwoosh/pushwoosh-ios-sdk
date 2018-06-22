
# PWRichMediaPresentingDelegate #

| Header | [PWRichMediaManager.h](../Framework/Pushwoosh.framework/Versions/A/Headers/PWRichMediaManager.h) |
| ------ | ---------------------------------------------------------------------------------------- |

Interface for Rich Media presentation managing.


## Summary

[- richMediaManager:shouldPresentRichMedia:](#richmediamanagershouldpresentrichmedia)

[- richMediaManager:didPresentRichMedia:](#richmediamanagerdidpresentrichmedia)

[– richMediaManager:didCloseRichMedia:](#richmediamanagerdidcloserichmedia)

[– richMediaManager:presentingDidFailForRichMedia:withError:](#richmediamanagerpresentingdidfailforrichmediawitherror)

  

## Instance Methods

### richMediaManager:shouldPresentRichMedia:
Checks the delegate whether the Rich Media should be displayed.
```objc

- (BOOL)richMediaManager:(PWRichMediaManager *)richMediaManager shouldPresentRichMedia:(PWRichMedia *)richMedia;

```

---
### richMediaManager:didPresentRichMedia:
Tells the delegate that Rich Media has been displayed.
```objc

- (void)richMediaManager:(PWRichMediaManager *)richMediaManager didPresentRichMedia:(PWRichMedia *)richMedia;

```

---
### richMediaManager:didCloseRichMedia:
Tells the delegate that Rich Media has been closed.
```objc

- (void)richMediaManager:(PWRichMediaManager *)richMediaManager didCloseRichMedia:(PWRichMedia *)richMedia;

```

---
### richMediaManager:presentingDidFailForRichMedia:withError:
Tells the delegate that error during Rich Media presenting has been occured.
```objc

- (void)richMediaManager:(PWRichMediaManager *)richMediaManager presentingDidFailForRichMedia:(PWRichMedia *)richMedia withError:(NSError *)error;

```

---
