//
//  PWScreenTrackingManager.h
//  Pushwoosh
//
//  Created by Fectum on 17/04/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const defaultScreenOpenEvent;

@interface PWScreenTrackingManager : NSObject

@property (nonatomic) BOOL defaultScreenOpenAllowed;

+ (instancetype)sharedManager;

@end

NS_ASSUME_NONNULL_END
