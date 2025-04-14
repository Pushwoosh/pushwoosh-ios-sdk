//
//  PWPushwooshJSBridge.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2017
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PushwooshLog.h>

#import "PWWebClient.h"

@interface PWPushwooshJSBridge : NSObject

- (id)initWithClient:(PWWebClient *)webClient;

@end
