//
//  PWLocationHelper.h
//  Pushwoosh
//
//  Created by Victor Eysner on 11/09/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface PWLocationHelper : NSObject

- (instancetype)initWithRemoveLocationBlock:(dispatch_block_t)removeLocationBlock;

- (void)requestLocationAuthorization:(void (^)(CLAuthorizationStatus status))completion;
- (void)removeLocationIfNeeded;
- (void)removeSuccessfulSendLocation;
- (void)saveSuccessfulSendLocation;

+ (NSNumber *)startBackgroundTask;
+ (void)stopBackgroundTask:(NSNumber *)taskId;

@end
