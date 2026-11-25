//
//  PWMessageDeliveryRequest+Internal.h
//  PushwooshCore
//
//  Created by André Kis
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <PushwooshCore/PWMessageDeliveryRequest.h>

NS_ASSUME_NONNULL_BEGIN

@interface PWMessageDeliveryRequest ()

/// Moment the push reached the device, sent as `receivedAt` (RFC 3339, UTC, whole seconds); nil sends no field.
@property (nonatomic, copy, nullable) NSDate *receivedDate;

@end

NS_ASSUME_NONNULL_END
