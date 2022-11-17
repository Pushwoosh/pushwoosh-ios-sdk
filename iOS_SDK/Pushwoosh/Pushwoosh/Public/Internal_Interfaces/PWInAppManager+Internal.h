//
//  PWInAppManager+Internal.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2017
//

#import "PWInAppManager.h"
#import "PWInAppMessagesManager.h"

@interface PWInAppManager()

@property (nonatomic, strong) PWInAppMessagesManager *inAppMessagesManager;

+ (void)destroy;

@end
