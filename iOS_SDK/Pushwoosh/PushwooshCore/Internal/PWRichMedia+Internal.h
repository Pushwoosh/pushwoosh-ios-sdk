//
//  PWRichMedia+Internal.h
//  PushwooshCore
//
//  Created by André Kis on 20.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#if TARGET_OS_IOS

#import "PWRichMedia.h"

@class PWResource;

@interface PWRichMedia ()

@property (nonatomic) PWResource *resource;

- (instancetype)initWithSource:(PWRichMediaSource)source resource:(PWResource *)resource;
- (instancetype)initWithSource:(PWRichMediaSource)source resource:(PWResource *)resource pushPayload:(NSDictionary *)pushPayload;

@end

#endif
