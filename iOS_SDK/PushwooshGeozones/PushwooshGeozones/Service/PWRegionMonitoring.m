//
//  PWRegionMonitoring.m
//  Pushwoosh
//
//  Created by Victor Eysner on 08/09/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWRegionMonitoring.h"
#import "PWSDKInterface.h"
#import "PWLocationLog.h"
#import "PWGeozone.h"
#import "PWLocationHelper.h"

#define kPushwooshRegionPrefix @"com.pushwoosh"
#define kUserPositionRegionIdentifier @"com.pushwoosh.user"

@interface PWRegionMonitoring ()<CLLocationManagerDelegate>

@property (nonatomic) CLLocationManager *locationManager;
@property (nonatomic, copy) PWSendLocationBlock sendLocationBlock;

@end

@implementation PWRegionMonitoring

- (instancetype)init {
    if (self = [super init]) {
        self.locationManager = [CLLocationManager new];
        self.locationManager.delegate = self;
    }
    return self;
}

#pragma mark - Public

- (void)updateSendLocationBlock:(PWSendLocationBlock)block {
    self.sendLocationBlock = block;
}

// this method will put outlined location icon on the status bar in background
// sets up a region around the user and another region around geozone
- (void)setupNearestGeozone:(NSArray<PWGeozone *> *)nearestGeozones {
    
    [PWLocationLog log:[NSString stringWithFormat:@"setting up new regions"] withTracker:self];
    
    //this will give us necessary time to get all the callbacks from regions set-up
    //as they are asynchronoush we have to ask OS for more time or we are going to be killed before they have been set up!
    NSNumber *bgTask = [PWLocationHelper startBackgroundTask];
    
    //as we could run in background thread we need to sync this as we will be receiving callbacks (didMonitoringStart) during the regions creation
    @synchronized(self) {
        NSMutableDictionary<NSString *, CLCircularRegion *> *removeRegions = [self monitoredRegions];
        NSMutableArray<PWGeozone *> *addGeozones = [NSMutableArray new];
        
        for (PWGeozone *geozone in nearestGeozones) {
            
            NSString *regionIdentifier = [self regionIdentifierForGeozone:geozone];
            CLCircularRegion *region = removeRegions[regionIdentifier];
            
            if (region) {
                [PWLocationLog log:[NSString stringWithFormat:@"Old monitoring region: %@ <%+.6f, %+.6f> radius %.0fm", region.identifier, region.center.latitude, region.center.longitude, region.radius]
                       withTracker:self];
                [removeRegions removeObjectForKey:regionIdentifier];
            } else {
                [addGeozones addObject:geozone];
            }
        }
        
        //remove geozones
        [self stopRegionMonitoring:removeRegions];
        
        //add new geozones
        for (PWGeozone *geozone in addGeozones) {
            NSString *regionIdentifier = [self regionIdentifierForGeozone:geozone];
            [self startMonitoringRegionWithCenter:geozone.center radius:geozone.radius identifier:regionIdentifier];
        }
        
        [PWLocationHelper stopBackgroundTask:bgTask];
    }
}

#pragma mark - Start / Stop

- (void)stopRegionMonitoring {
    [self stopRegionMonitoring:[self monitoredRegions]];
}

- (void)stopRegionMonitoring:(NSDictionary<NSString *, CLCircularRegion *> *)stopRegionMonitoring {
    for (CLCircularRegion *region in stopRegionMonitoring.allValues) {
        [self.locationManager stopMonitoringForRegion:region];
        [PWLocationLog log:[NSString stringWithFormat:@"Stop monitoring region: %@ <%+.6f, %+.6f> radius %.0fm", region.identifier, region.center.latitude, region.center.longitude, region.radius]
               withTracker:self];
    }
}

//places a circular region with a radius over the center and starts to monitor it
- (void)startMonitoringRegionWithCenter:(CLLocationCoordinate2D)center radius:(CLLocationDistance)radius identifier:(NSString *)identifier {
    if (radius > self.locationManager.maximumRegionMonitoringDistance) {
        radius = self.locationManager.maximumRegionMonitoringDistance;
    }
    
    CLCircularRegion *region = [[CLCircularRegion alloc] initWithCenter:center radius:radius identifier:identifier];
    [PWLocationLog log:[NSString stringWithFormat:@"Start monitoring region: %@ <%+.6f, %+.6f> radius %.0fm", region.identifier, region.center.latitude, region.center.longitude, region.radius]
           withTracker:self];
    
    //will remove from monitoring any region with the same id and type
    [self.locationManager startMonitoringForRegion:region];
}

#pragma mark - Helpers

- (NSMutableDictionary<NSString *, CLCircularRegion *> *)monitoredRegions {
    NSMutableDictionary<NSString *, CLCircularRegion *> *result = [NSMutableDictionary new];
    NSSet<CLRegion *> *regions = [self.locationManager monitoredRegions];
    
    for (CLCircularRegion *region in regions) {
        if ([self shouldHandleRegion:region]) {
            [result setObject:region forKey:region.identifier];
        }
    }
    return result;
}

- (NSString *)regionIdentifierForGeozone:(PWGeozone *)geozone {
    NSString *regionIdentifier = [NSString stringWithFormat:@"%@.%@.%f.%f.%f",
                                  kPushwooshRegionPrefix,
                                  geozone.name?:@"",
                                  geozone.radius,
                                  geozone.center.latitude,
                                  geozone.center.longitude];
    return regionIdentifier;
}

- (BOOL)shouldHandleRegion:(CLRegion *)region {
    return ([region.identifier hasPrefix:kPushwooshRegionPrefix] && [region isKindOfClass:[CLCircularRegion class]]);
}

- (void)sendLocation:(CLLocation *)location {
    if (self.sendLocationBlock) {
        self.sendLocationBlock(location);
    }
}

#pragma mark - CLLocationManagerDelegate

//enter to region that corresponds nearest pushwoosh geozone
- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)didEnterRegion {
    if (![self shouldHandleRegion:didEnterRegion])
        return;
    
    CLCircularRegion *region = (CLCircularRegion *)didEnterRegion;
    CLLocation *location = [[CLLocation alloc] initWithLatitude:region.center.latitude longitude:region.center.longitude];
    
    [PWLocationLog reportLocation:location
                      withMessage:[NSString stringWithFormat:@"didEnterRegion %@", region.identifier]
                          tracker:self];
    
    //send region center to Pushwoosh
    [self sendLocation:location];
}

//exit from region with center in user position means that now should to update location and recreate regions
- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)didExitRegion {
    if (![self shouldHandleRegion:didExitRegion])
        return;
    CLCircularRegion *region = (CLCircularRegion *)didExitRegion;

    [PWLocationLog reportLocation:manager.location
                      withMessage:[NSString stringWithFormat:@"didExitRegion: %@", region.identifier]
                          tracker:self];
    
    //send location, receive new nearest geozone and then update regions
    [self sendLocation:manager.location];
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
    if (![self shouldHandleRegion:region])
        return;
    
    [PWLocationLog log:[NSString stringWithFormat:@"Region monitoring did fail: %@, error: %@", region.identifier, error.localizedDescription]
           withTracker:self];
    [PWLocationLog logDebug:[NSString stringWithFormat:@"Failed Region %@, accuracy: %f", region.identifier, manager.location.horizontalAccuracy]
                withTracker:self];
}

@end
