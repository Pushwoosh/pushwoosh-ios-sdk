//
//  PWRegionMonitoring.h
//  Pushwoosh
//
//  Created by Victor Eysner on 08/09/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PWLocationTrackerProtocol.h"

@class PWGeozone;
@interface PWRegionMonitoring : NSObject

- (void)updateSendLocationBlock:(PWSendLocationBlock)block;
- (void)setupNearestGeozone:(NSArray<PWGeozone *> *)nearestGeozones;
- (void)stopRegionMonitoring;

@end
