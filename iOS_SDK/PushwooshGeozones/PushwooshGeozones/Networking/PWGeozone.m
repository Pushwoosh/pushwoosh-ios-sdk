//
//  PWGeozone.m
//	Pushwoosh SDK
//

#import "PWGeozone.h"

@implementation PWGeozone

+ (instancetype)geozoneWithCenter:(CLLocationCoordinate2D)center radius:(CLLocationDistance)radius distance:(CLLocationDistance)distance name:(NSString *)name {
	PWGeozone *geozone = [PWGeozone new];
	geozone.center = center;
	geozone.radius = radius;
	geozone.distance = distance;
	geozone.name = name;
	return geozone;
}

@end

