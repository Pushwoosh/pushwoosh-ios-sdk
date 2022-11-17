//
//  PWRequest.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2016
//

#import "PWUtils.common.h"

@interface PWUtilsCommon (Internal)

+ (NSString *)generateIdentifier;
+ (void)applicationOpenURL:(NSURL *)url;

@end