//
//  PWLocationTrackerProtocol.h
//  Pushwoosh
//
//  Created by Victor Eysner on 04/09/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>

typedef void (^PWSendLocationBlock)(CLLocation *sendLocation);

@protocol PWLocationTrackerProtocol <NSObject>

@required

@property (nonatomic, readonly) BOOL enabled;

- (void)startTracking;
- (void)stopTracking;
- (void)updateSendLocationBlock:(PWSendLocationBlock)block;
- (BOOL)validAuthorizationStatusForStartTracking:(CLAuthorizationStatus)status;

@end
