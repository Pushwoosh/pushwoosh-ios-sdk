
# PWGeozonesDelegate #

| Header | [PWGeozonesManager.h](../Framework/Pushwoosh.framework/Versions/A/Headers/PWGeozonesManager.h) |
| ------ | ---------------------------------------------------------------------------------------- |

Delegate that would receive the information about events for geozones manager.

## Summary

[- didStartLocationTrackingWithManager:](#didstartlocationtrackingwithmanager)
[- geozonesManager:startingLocationTrackingDidFail:](#geozonesmanagerstartinglocationtrackingdidfail)
[- geozonesManager:didSendLocation:](#geozonesmanagerdidsendlocation)


## Instance Methods

### didStartLocationTrackingWithManager:
Tells the delegate that location tracking did start.
```objc
- (void)didStartLocationTrackingWithManager:(PWGeozonesManager *)geozonesManager;
```

### geozonesManager:startingLocationTrackingDidFail:
Tells the delegate that location tracking did fail.
```objc
- (void)geozonesManager:(PWGeozonesManager *)geozonesManager startingLocationTrackingDidFail:(NSError *)error;
```

### geozonesManager:didSendLocation:
Tells the delegate that location was successfully sent.
```objc
- (void)geozonesManager:(PWGeozonesManager *)geozonesManager didSendLocation:(CLLocation *)location;
```
