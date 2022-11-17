//
//  PWGetNearestZoneRequest.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWGetNearestZoneRequest.h"

static double deg2rad(double deg) {
	return deg * (3.1415926 / 180.0);
}

static double getDistanceInMeters(CLLocationCoordinate2D start, CLLocationCoordinate2D finish) {
	double R = 6371;										  // Radius of the earth in km
	double dLat = deg2rad(finish.latitude - start.latitude);  // deg2rad below
	double dLon = deg2rad(finish.longitude - start.longitude);

	double a =
		sin(dLat / 2) * sin(dLat / 2) +
		cos(deg2rad(start.latitude)) * cos(deg2rad(finish.latitude)) *
			sin(dLon / 2) * sin(dLon / 2);

	double c = 2 * atan2(sqrt(a), sqrt(1 - a));
	double d = R * c;  // Distance in km
	return d * 1000;
}

@implementation PWGetNearestZoneRequest

- (NSString *)methodName {
	return @"getNearestZone";
}

- (NSDictionary *)requestDictionary {
	NSMutableDictionary *dict = [self baseDictionary];

	dict[@"lat"] = @(_userCoordinate.latitude);
	dict[@"lng"] = @(_userCoordinate.longitude);
	dict[@"more"] = @(1);

	return dict;
}

- (PWGeozone *)processGeozone:(NSDictionary *)geozone {
    PWGeozone *zone = nil;
	if (![geozone isKindOfClass:[NSDictionary class]]) {
		return nil;
	}

	NSNumber *distance = [geozone pw_numberForKey:@"distance"];
	NSNumber *lat = [geozone pw_numberForKey:@"lat"];
	NSNumber *lng = [geozone pw_numberForKey:@"lng"];

	if (distance && lat && lng) {
		CLLocationDistance properRadius = 150;

		NSNumber *radius = [geozone pw_objectForKey:@"range" ofType:[NSNumber class]];
		if (radius) {
			properRadius = [radius doubleValue];
		}

		NSString *name = [geozone pw_stringForKey:@"name"];
		if (!name) {
			name = [[NSUUID UUID] UUIDString];
		}

		CLLocationCoordinate2D coord = CLLocationCoordinate2DMake([lat doubleValue], [lng doubleValue]);
		double dist = getDistanceInMeters(_userCoordinate, coord);

		zone = [PWGeozone geozoneWithCenter:coord radius:properRadius distance:dist name:name];
		zone.pwdist = [distance doubleValue];
	}
    return zone;
}

- (void)parseResponse:(NSDictionary *)response {
	NSArray *geozones = [response pw_arrayForKey:@"geozones"];
    NSMutableArray<PWGeozone *> *nearestGeozones = [NSMutableArray new];
    
	for (NSDictionary *geozone in geozones) {
		PWGeozone *zone = [self processGeozone:geozone];
        if (zone) {
            [nearestGeozones addObject:zone];
        }
	}
    
    self.nearestGeozones = nearestGeozones;
}

@end

