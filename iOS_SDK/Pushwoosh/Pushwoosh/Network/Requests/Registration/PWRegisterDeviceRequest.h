//
//  PWRegisterDeviceRequest
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWRequest.h"
#import "PWAppOpenRequest.h"

@interface PWRegisterDeviceRequest : PWAppOpenRequest

@property (nonatomic, copy) NSString *pushToken;
@property (nonatomic, copy) NSDictionary *customTags;

@end
