//
//  PWTriggerInAppActionRequest.h
//  Pushwoosh
//
//  Created by Fectum on 05/02/2018.
//  Copyright © 2018 Pushwoosh. All rights reserved.
//

#import "PWRequest.h"

@interface PWTriggerInAppActionRequest : PWRequest

@property (nonatomic) NSString *inAppCode;
@property (nonatomic) NSString *messageHash;
@property (nonatomic) NSString *richMediaCode;

@end
