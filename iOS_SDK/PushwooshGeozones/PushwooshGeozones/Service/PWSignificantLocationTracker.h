//
//  PWSignificantLocationTracker.h
//  Pushwoosh
//
//  Created by Victor Eysner on 04/09/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PWLocationTrackerProtocol.h"

@interface PWSignificantLocationTracker : NSObject<PWLocationTrackerProtocol>

@property (nonatomic, readonly) BOOL enabled;

@end
