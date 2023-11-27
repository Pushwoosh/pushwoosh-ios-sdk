//
//  PWAppLifecycleTrackingManager.h
//  Pushwoosh
//
//  Created by Fectum on 01/04/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const defaultApplicationOpenedEvent;
FOUNDATION_EXPORT NSString * const defaultApplicationClosedEvent;

@interface PWAppLifecycleTrackingManager : NSObject

@property (nonatomic) BOOL defaultAppOpenAllowed;
@property (nonatomic) BOOL defaultAppClosedAllowed;

+ (instancetype)sharedManager;

- (void)startTracking;

@end

NS_ASSUME_NONNULL_END
