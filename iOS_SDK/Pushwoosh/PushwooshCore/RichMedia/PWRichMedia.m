//
//  PWRichMedia.m
//  PushwooshCore
//
//  Created by André Kis on 20.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#if TARGET_OS_IOS

#import "PWRichMedia.h"
#import "PWRichMedia+Internal.h"
#import "PWResource.h"

@implementation PWRichMedia

- (instancetype)initWithSource:(PWRichMediaSource)source resource:(PWResource *)resource {
    return [self initWithSource:source resource:resource pushPayload:nil];
}

- (instancetype)initWithSource:(PWRichMediaSource)source resource:(PWResource *)resource pushPayload:(NSDictionary *)pushPayload {
    self = [super init];

    if (self) {
        _source = source;
        _resource = resource;
        _pushPayload = pushPayload;
    }

    return self;
}

- (NSString *)content {
    return _resource.code;
}

- (BOOL)isRequired {
    return _source == PWRichMediaSourceInApp ? _resource.required : YES;
}

@end

#endif
