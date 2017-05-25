//
//  Pushwoosh.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2017
//

#import <Foundation/Foundation.h>

/**
 Pushwoosh iBeacon tracking manager.
 
 One of the following keys shoud be added to Info.plist for using iBeacon functionality:
 
 * `NSLocationAlwaysUsageDescription` – if you would like your application to react to beacons while running in the background and when it’s closed;
 * `NSLocationWhenInUseUsageDescription` – if you would like your app to look for beacons only then it’s running in the foreground.
 
 */
@interface PWBeaconManager : NSObject

+ (instancetype)sharedManager;

/**
 Start iBeacon tracking.
 */
- (void)startBeaconTracking;

/**
 Stops iBeacon tracking
 */
- (void)stopBeaconTracking;

@end
