//
//  PWLiveActivityRequest.h
//  Pushwoosh
//
//  Created by Andrei Kiselev on 22.6.23..
//  Copyright © 2023 Pushwoosh. All rights reserved.
//

#import "PWRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface PWLiveActivityRequest : PWRequest

@property (nonatomic) NSString *token;
@property (nonatomic) NSString *activityId;

@end

NS_ASSUME_NONNULL_END
