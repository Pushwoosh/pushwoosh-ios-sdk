//
//  PWRichMedia.h
//  PushwooshCore
//
//  Created by André Kis on 20.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IOS

typedef NS_ENUM(NSUInteger, PWRichMediaSource) {
    PWRichMediaSourcePush,
    PWRichMediaSourceInApp
};

@interface PWRichMedia: NSObject

@property (nonatomic, readonly) PWRichMediaSource source;
@property (nonatomic, readonly) NSString *content;
@property (nonatomic, readonly) NSDictionary *pushPayload;
@property (nonatomic, readonly, getter=isRequired) BOOL required;

@end

#endif
