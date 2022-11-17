//
//  PWGeozone.h
//	Pushwoosh SDK
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface PWGeozone : NSObject

@property (nonatomic, assign) CLLocationCoordinate2D center;
@property (nonatomic, assign) CLLocationDistance radius;
@property (nonatomic, assign) CLLocationDistance distance;
@property (nonatomic, assign) CLLocationDistance pwdist;

@property (nonatomic, strong) NSString *name;

+ (instancetype)geozoneWithCenter:(CLLocationCoordinate2D)center radius:(CLLocationDistance)radius distance:(CLLocationDistance)distance name:(NSString *)name;

@end
