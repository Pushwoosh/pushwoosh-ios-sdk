//
//  PWHashDecoder.h
//  Pushwoosh
//
//  Created by André Kis on 02.11.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PWHashDecoder : NSObject

@property (nonatomic, copy, readonly) NSString *messageCode;
@property (nonatomic, readonly) uint64_t messageId;
@property (nonatomic, readonly) uint64_t campaignId;

+ (instancetype)sharedInstance;

- (void)parseMessageHash:(NSString *)hash;

@end

NS_ASSUME_NONNULL_END
