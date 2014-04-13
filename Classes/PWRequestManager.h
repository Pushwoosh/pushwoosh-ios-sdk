//
//  PWRequestManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import <Foundation/Foundation.h>
#import "PWRequest.h"

@interface PWRequestManager : NSObject

+ (PWRequestManager *) sharedManager;
- (BOOL) sendRequest: (PWRequest *) request;
- (BOOL) sendRequest: (PWRequest *) request error:(NSError **)error;

@end
