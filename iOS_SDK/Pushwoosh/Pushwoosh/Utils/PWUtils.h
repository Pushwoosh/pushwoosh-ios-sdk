//
//  PWRequest.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2016
//

#import "PWUtils.common.h"

#if TARGET_OS_WATCH

#import "PWUtils.watch.h"

#elif TARGET_OS_OSX

#import "PWUtils.mac.h"

#elif TARGET_OS_IOS || TARGET_OS_TV

#import "PWUtils.ios.h"

#endif
