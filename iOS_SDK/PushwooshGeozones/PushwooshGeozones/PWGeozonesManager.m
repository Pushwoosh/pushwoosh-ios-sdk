//
//  PWRichMediaManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2018
//

#import "PWGeozonesManager.h"
#import "PWRegionMonitoring.h"
#import "PWLocationLog.h"
#import "PWGetNearestZoneRequest.h"
#import "PWRemoveLocationRequest.h"
#import "PWLocationHelper.h"
#import "PWSignificantLocationTracker.h"
#import "PWSDKInterface.h"
#import "PWGeozonesManager.h"

#import <UIKit/UIKit.h>

@interface PWGeozonesManager ()

@property (nonatomic) NSObject<PWLocationTrackerProtocol> *locationTracker;
@property (nonatomic) PWRegionMonitoring *regionMonitoring;
@property (nonatomic) PWLocationHelper *locationHelper;

@property (nonatomic) BOOL enabled;

@end


@implementation PWGeozonesManager

+ (instancetype)sharedManager {
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        if (![self isSDKLinked]) {
            [NSException raise:@"PWIntegrityException" format:@"Pushwoosh SDK is need to be linked in order to use Geozones"];
        } else {
            [self setupWithLocationTracker:[PWSignificantLocationTracker new]];
        }
    }
    return self;
}

- (BOOL)isSDKLinked {
    Class class = NSClassFromString(@"PushNotificationManager");
    return class != nil;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    if ([PWGeozonesManager sharedManager].enabled) {
        [self startLocationTracking];
    }
}

- (void)applicationDidBecomeActive {
    [_locationHelper removeLocationIfNeeded];
}

#pragma mark -

- (void)dependencySetup {
    __weak typeof(self) wself = self;
    
    _regionMonitoring = [PWRegionMonitoring new];
    
    [_regionMonitoring updateSendLocationBlock:^(CLLocation *sendLocation) {
        [wself sendLocation:sendLocation];
    }];
    
    _locationHelper = [[PWLocationHelper alloc] initWithRemoveLocationBlock:^{
        [wself removeLocation];
    }];
}

- (void)setupWithLocationTracker:(NSObject<PWLocationTrackerProtocol> *)locationTracker {
    [self dependencySetup];
    
    __weak typeof(self) wself = self;
    
    _locationTracker = locationTracker;
    
    [_locationTracker updateSendLocationBlock:^(CLLocation *sendLocation) {
        [wself sendLocation:sendLocation];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunching:) name:UIApplicationDidFinishLaunchingNotification object:nil];
}

#pragma mark - Public

- (void)startLocationTracking {
    __weak typeof(self) wself = self;
    
    [_locationHelper requestLocationAuthorization:^(CLAuthorizationStatus status) {
        if ([wself.locationTracker validAuthorizationStatusForStartTracking:status]) {
            wself.enabled = YES;
            [wself.locationTracker startTracking];
            
            if ([wself.delegate respondsToSelector:@selector(didStartLocationTrackingWithManager:)]) {
                [wself.delegate didStartLocationTrackingWithManager:wself];
            }
        } else if ([wself.delegate respondsToSelector:@selector(geozonesManager:startingLocationTrackingDidFail:)]) {
            [wself.delegate geozonesManager:wself startingLocationTrackingDidFail:[NSError errorWithDomain:@"com.pushwoosh.geozones" code:404 userInfo:@{NSLocalizedDescriptionKey : @"Access to the users's location is not authorized"}]];
        }
    }];
}

- (void)stopLocationTracking {
    _enabled = NO;
    [_locationTracker stopTracking];
    [self removeLocation];
}

#pragma mark - Network

- (void)sendLocation:(CLLocation *)location {
    PWLogInfo(@"Sending location: %@", location);
    
    NSNumber *bgTask = [PWLocationHelper startBackgroundTask];
    PWGetNearestZoneRequest *request = [[PWGetNearestZoneRequest alloc] init];
    request.userCoordinate = location.coordinate;
    __weak typeof(self) wself = self;
    [[PWNetworkModule module].requestManager sendRequest:request completion:^(NSError *error) {
        if (error == nil) {
            if ([wself.delegate respondsToSelector:@selector(geozonesManager:didSendLocation:)]) {
                [wself.delegate geozonesManager:wself didSendLocation:location];
            }
            
            PWLogDebug(@"getNearestZone completed");
            
            [wself.regionMonitoring setupNearestGeozone:request.nearestGeozones];
            [wself.locationHelper saveSuccessfulSendLocation];
            
            NSString *message = [NSString stringWithFormat:@"Location sent. Received nearest geozones: %d, location", (int)[request.nearestGeozones count]];
            [PWLocationLog reportLocation:location
                              withMessage:message
                                  tracker:wself.locationTracker];
        } else {
            PWLogError(@"getNearestZone failed");
        }
        
        PWLogDebug(@"Location sent");
        [PWLocationHelper stopBackgroundTask:bgTask];
    }];
}

- (void)removeLocation {
    PWLogInfo(@"Remove location");
    
    NSNumber *bgTask = [PWLocationHelper startBackgroundTask];
    PWRemoveLocationRequest *request = [[PWRemoveLocationRequest alloc] init];
    __weak typeof(self) wself = self;
    [[PWNetworkModule module].requestManager sendRequest:request completion:^(NSError *error) {
        if (error == nil) {
            PWLogDebug(@"Remove location completed");
            
            [wself.regionMonitoring stopRegionMonitoring];
            [wself.locationHelper removeSuccessfulSendLocation];
        } else {
            PWLogError(@"Remove location failed");
        }
        [PWLocationHelper stopBackgroundTask:bgTask];
    }];
}

#pragma mark -

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


@end
