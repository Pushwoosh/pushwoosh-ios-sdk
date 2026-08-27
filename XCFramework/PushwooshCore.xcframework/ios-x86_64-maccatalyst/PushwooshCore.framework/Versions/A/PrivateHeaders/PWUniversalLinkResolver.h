//
//  PWUniversalLinkResolver.h
//  PushwooshCore
//
//  Created by André Kis on 21.08.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PWUniversalLinkVerdict) {
    PWUniversalLinkVerdictUnknown = 0,
    PWUniversalLinkVerdictMatch = 1,
    PWUniversalLinkVerdictNoMatch = 2
};

@interface PWUniversalLinkResolver : NSObject

+ (void)resolveURL:(NSURL *)url completion:(void (^)(PWUniversalLinkVerdict verdict))completion;

@end

NS_ASSUME_NONNULL_END
