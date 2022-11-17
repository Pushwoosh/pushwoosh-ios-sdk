//
//  PWInAppManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2018
//

#import "PWRichMediaManager.h"
#import "PWResource.h"

@interface PWRichMedia ()

@property (nonatomic) PWResource *resource;

- (instancetype)initWithSource:(PWRichMediaSource)source resource:(PWResource *)resource;
- (instancetype)initWithSource:(PWRichMediaSource)source resource:(PWResource *)resource pushPayload:(NSDictionary *)pushPayload;

@end
