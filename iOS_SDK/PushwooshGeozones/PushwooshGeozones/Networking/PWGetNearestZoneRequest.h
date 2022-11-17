//
//  PWGetNearestZoneRequest.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import <CoreLocation/CoreLocation.h>
#import "PWSDKInterface.h"
#import "PWGeozone.h"

@interface PWGetNearestZoneRequest : PWRequest

@property CLLocationCoordinate2D userCoordinate;

@property (nonatomic, strong) NSArray<PWGeozone *> *nearestGeozones;

@end

