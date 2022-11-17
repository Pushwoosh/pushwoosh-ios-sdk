//
//  PWNetworkModule.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2016
//

#import <Foundation/Foundation.h>

#import "PWRequestManager.h"

@interface PWNetworkModule : NSObject

@property (nonatomic, strong) PWRequestManager *requestManager;

+ (PWNetworkModule*)module;

- (void)inject:(id)object;

@end
