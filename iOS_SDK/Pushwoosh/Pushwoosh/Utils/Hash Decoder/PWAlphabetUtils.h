//
//  PWAlphabetUtils.h
//  Pushwoosh
//
//  Created by André Kis on 02.11.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PWAlphabetUtils : NSObject

+ (NSDictionary<NSNumber *, NSString *> *)alphabet;
+ (NSDictionary<NSString *, NSNumber *> *)alphabetRevert;

+ (uint64_t)alphabetDecode:(NSString *)hash;

@end

NS_ASSUME_NONNULL_END
