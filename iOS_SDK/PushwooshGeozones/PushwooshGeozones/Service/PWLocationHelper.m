//
//  PWLocationHelper.m
//  Pushwoosh
//
//  Created by Victor Eysner on 11/09/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//


#import "PWSDKInterface.h"
#import "PWLocationHelper.h"
#import "PWGeozonesManager.h"

#import <UIKit/UIKit.h>

#define kisSuccessfulSendLocation @"com.pushwoosh.PWLocationHelper.isSuccessfulSendLocation"
typedef void (^PWAuthorizationLocationBlock)(CLAuthorizationStatus status);

@interface PWLocationHelper ()<CLLocationManagerDelegate>

@property (nonatomic) CLLocationManager *locationManager;
@property (nonatomic, copy) dispatch_block_t removeLocationBlock;
@property (nonatomic, copy) PWAuthorizationLocationBlock authorizationBlock;

@end

@implementation PWLocationHelper

- (instancetype)initWithRemoveLocationBlock:(dispatch_block_t)removeLocationBlock {
    if (self = [super init]) {
        _removeLocationBlock = removeLocationBlock;
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
    }
    return self;
}

#pragma mark -

- (BOOL)canRequestAlwaysAuthorization {
    BOOL result = NO;
    if ([CLLocationManager instancesRespondToSelector:@selector(showsBackgroundLocationIndicator)]) { //iOS 11 check
        result = ([[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"] != nil &&
                  [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysAndWhenInUseUsageDescription"] != nil);
    } else {
        result = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysUsageDescription"] != nil;
    }
    return result;
}

- (void)requestLocationAuthorization:(void (^)(CLAuthorizationStatus status))completion {
    _authorizationBlock = completion;
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways) {
        [self locationManager:_locationManager didChangeAuthorizationStatus:kCLAuthorizationStatusAuthorizedAlways];
    } else if ([self canRequestAlwaysAuthorization]) {
        [self.locationManager requestAlwaysAuthorization];
    } else if ([[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"] != nil) {
        PWLogError(@"Did you forget to add NSLocationAlwaysUsageDescription and NSLocationAlwaysAndWhenInUseUsageDescription to your Info.plist file?");
        [self.locationManager requestWhenInUseAuthorization];
    } else {
        PWLogError(@"Did you forget to add NSLocationWhenInUseUsageDescription, NSLocationAlwaysAndWhenInUseUsageDescription or NSLocationAlwaysUsageDescription to your Info.plist file?");
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusNotDetermined) {
        PWLogInfo(@"location services authorization status has not been determined yet");
        return;
    }
    [self removeLocationIfNeeded];
    
    if (_authorizationBlock) {
        _authorizationBlock(status);
    }
}

#pragma mark - Remove location methods

- (BOOL)isNeededRemoveLocation {
    CLAuthorizationStatus authorizationStatus = [CLLocationManager authorizationStatus];
    
    if ((authorizationStatus == kCLAuthorizationStatusAuthorizedAlways && [PWGeozonesManager sharedManager].enabled)
        || authorizationStatus == kCLAuthorizationStatusNotDetermined
        || self.isSuccessfulSendLocation == NO) {
        return NO;
    } else {
        return YES;
    }
}

- (void)removeLocationIfNeeded {
    if (self.isNeededRemoveLocation) {
        self.removeLocationBlock();
    }
}

- (void)removeSuccessfulSendLocation {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kisSuccessfulSendLocation];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)saveSuccessfulSendLocation {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kisSuccessfulSendLocation];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)isSuccessfulSendLocation {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kisSuccessfulSendLocation];
}

+ (NSNumber *)startBackgroundTask {
    __block NSInteger regionMonitoringBGTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:regionMonitoringBGTask];
        regionMonitoringBGTask = UIBackgroundTaskInvalid;
    }];
    
    return @(regionMonitoringBGTask);
}

+ (void)stopBackgroundTask:(NSNumber *)taskId {
    if (!taskId || [taskId integerValue] == UIBackgroundTaskInvalid) {
        return;
    }
    
    [[UIApplication sharedApplication] endBackgroundTask:[taskId integerValue]];
}

@end
