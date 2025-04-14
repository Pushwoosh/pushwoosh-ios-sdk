//
//  PWCoreServerCommunicationManager.h
//  PushwooshCore
//
//  Created by André Kis on 17.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PWSettings.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kPWCoreServerCommunicationStarted;

@interface PWCoreServerCommunicationManager : NSObject

@property (class, nonatomic, readonly) PWCoreServerCommunicationManager *sharedInstance;
@property (nonatomic, readonly, getter=isServerCommunicationAllowed) BOOL serverCommunicationAllowed;

- (void)startServerCommunication;
- (void)stopServerCommunication;

@end

NS_ASSUME_NONNULL_END
