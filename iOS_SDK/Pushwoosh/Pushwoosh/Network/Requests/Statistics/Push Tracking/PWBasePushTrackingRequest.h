//
//  PWBasePushTrackingRequest.h
//  Pushwoosh
//
//  Created by Fectum on 25/06/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import "PWRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface PWBasePushTrackingRequest : PWRequest

@property (nonatomic, copy) NSDictionary *pushDict;

@end

NS_ASSUME_NONNULL_END
