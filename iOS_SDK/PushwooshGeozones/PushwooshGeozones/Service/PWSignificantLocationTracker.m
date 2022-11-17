//
//  PWSignificantLocationTracker.m
//  Pushwoosh
//
//  Created by Victor Eysner on 04/09/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "PWSignificantLocationTracker.h"
#import "PWLocationLog.h"

@interface PWSignificantLocationTracker ()<CLLocationManagerDelegate>

@property (nonatomic, copy) dispatch_block_t removeLocationBlock;
@property (nonatomic, copy) PWSendLocationBlock sendLocationBlock;
@property (nonatomic) CLLocationManager *locationManager;

@end

@implementation PWSignificantLocationTracker

- (instancetype)init {
    if (self = [super init]) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.activityType = CLActivityTypeFitness;
    }
    return self;
}

- (BOOL)validAuthorizationStatusForStartTracking:(CLAuthorizationStatus)status {
    return status == kCLAuthorizationStatusAuthorizedAlways;
}

- (void)sendLocation:(CLLocation *)location {
    if (self.sendLocationBlock) {
        self.sendLocationBlock(location);
    }
}

#pragma mark - PWLocationTrackerProtocol

- (void)updateSendLocationBlock:(PWSendLocationBlock)block {
    self.sendLocationBlock = block;
}

// this method will put location icon on the status bar in background, though it will use cell-towers for coordinate
- (void)startTracking {
    if ([CLLocationManager significantLocationChangeMonitoringAvailable]) {
        _enabled = YES;
        [self.locationManager startMonitoringSignificantLocationChanges];
        [PWLocationLog log:@"Start monitoring significant changes" withTracker:self];
    } else {
        [PWLocationLog log:@"Significant changes service not available on this device" withTracker:self];
    }
}

- (void)stopTracking {
    _enabled = NO;
    [self.locationManager stopMonitoringSignificantLocationChanges];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    if ([locations count]) {
        //sometimes location manager sends old coordinate!!! we have to compare timestamps then.
        CLLocation *managerLocation = [self.locationManager location];
        CLLocation *location = [locations lastObject];
        
        if (managerLocation && [managerLocation.timestamp compare:location.timestamp] == NSOrderedDescending) {
            location = managerLocation;
        }
        
        [PWLocationLog reportLocation:location
                          withMessage:[NSString stringWithFormat:@"Significant Location Change Detected"]
                              tracker:self];
        [self sendLocation:location];
        
    }
}

@end
