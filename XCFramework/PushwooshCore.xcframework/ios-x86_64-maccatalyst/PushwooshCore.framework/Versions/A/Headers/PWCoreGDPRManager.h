//
//  PWCoreGDPRManager.h
//  PushwooshCore
//
//  Created by André Kis on 17.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PushwooshLog.h>

NS_ASSUME_NONNULL_BEGIN

@protocol PWGDPR <NSObject>

/**
 Enable/disable all communication with Pushwoosh. Enabled by default.
 */
- (void)setCommunicationEnabled:(BOOL)enabled completion:(void (^)(NSError *error))completion;

/**
 Removes all device data from Pushwoosh and stops all interactions and communication permanently.
 */
- (void)removeAllDeviceDataWithCompletion:(void (^)(NSError *error))completion;

- (void)showGDPRConsentUI;

- (void)showGDPRDeletionUI;

@end

@interface PWCoreGDPRManager : NSObject <PWGDPR>

+ (Class<PWGDPR>_Nonnull)GDPR;

/**
Indicates availability of the GDPR compliance solution.
*/
@property (nonatomic, readonly, getter=isAvailable) BOOL available;

@property (nonatomic, readonly, getter=isCommunicationEnabled) BOOL communicationEnabled;

@property (nonatomic, readonly, getter=isDeviceDataRemoved) BOOL deviceDataRemoved;

+ (instancetype)sharedManager;

@end

NS_ASSUME_NONNULL_END
