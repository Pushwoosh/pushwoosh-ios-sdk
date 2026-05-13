//
//  PWSetAdvertisingIdRequest.h
//  PushwooshCore
//
//  Created by André Kis on 25.03.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import "PWRequest.h"

@interface PWSetAdvertisingIdRequest : PWRequest

@property (nonatomic, copy, nullable) NSString *advertisingId;

@end
