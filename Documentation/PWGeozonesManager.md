# PWGeozonesManager #

| Header | [PWGeozonesManager.h](../Framework/PushwooshGeozones.framework/Versions/A/Headers/PWGeozonesManager.h) |
| ------ | ---------------------------------------------------------------------------------------- |

Geozones API.

## Summary
[enabled](#enabled) *__property__*  
[delegate](#delegate) *__property__*  

[+ sharedManager](#sharedmanager)  

[- startLocationTracking](#startlocationtracking)  
[- stopLocationTracking](#stoplocationtracking)  
[- sendLocation:](#sendlocation)  

## Properties
### enabled
Indicates that location tracking has started.
```objc
@property (nonatomic, readonly) BOOL enabled;
```

### delegate
Delegate that would receive the information about events for geozones manager.
```objc
@property (nonatomic, weak) id<PWGeozonesDelegate> delegate;
```
---

##  Class Methods

### sharedManager
A singleton object that represents the geozones manager.
```objc
+ (instancetype)sharedManager;
```
---

## Instance Methods

### startLocationTracking
Starts location tracking.
```objc
- (void)startLocationTracking;
```

### stopLocationTracking
Stops location tracking.
```objc
- (void)stopLocationTracking;
```

### sendLocation:
Explicitly sends geolocation to the server for GeoFencing push technology. Also called internally in `startLocationTracking` and `stopLocationTracking` functions.
```objc
- (void)sendLocation:(CLLocation *)location;
```
* **location** Location to be sent.
