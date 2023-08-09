//
//  PWRichMediaAction.h
//  Pushwoosh
//
//  Created by Andrei Kiselev on 14.6.23..
//  Copyright © 2023 Pushwoosh. All rights reserved.
//

#import "PWRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface PWRichMediaActionRequest : PWRequest

@property (nonatomic) NSString *inAppCode;
@property (nonatomic) NSString *richMediaCode;
@property (nonatomic) NSNumber *actionType;
@property (nonatomic) NSString *messageHash;
@property (nonatomic) NSString *actionAttributes;

@end

NS_ASSUME_NONNULL_END
