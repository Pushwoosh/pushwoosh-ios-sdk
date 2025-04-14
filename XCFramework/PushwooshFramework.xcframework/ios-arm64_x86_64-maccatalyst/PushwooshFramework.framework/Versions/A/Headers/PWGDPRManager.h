//
//  PWGDPRManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2018
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PushwooshLog.h>

/*
 `PWGDPRManager` class offers access to the singleton-instance of the manager responsible for channels management required by GDPR.
 */

FOUNDATION_EXPORT NSString * const PWGDPRStatusDidChangeNotification;

@interface PWGDPRManager : NSObject

/**
Indicates availability of the GDPR compliance solution.
*/
@property (nonatomic, readonly, getter=isAvailable) BOOL available;

@property (nonatomic, readonly, getter=isCommunicationEnabled) BOOL communicationEnabled;

@property (nonatomic, readonly, getter=isDeviceDataRemoved) BOOL deviceDataRemoved;

+ (instancetype)sharedManager;

/**
 Enable/disable all communication with Pushwoosh. Enabled by default.
 */
- (void)setCommunicationEnabled:(BOOL)enabled completion:(void (^)(NSError *error))completion;

/**
 Removes all device data from Pushwoosh and stops all interactions and communication permanently.
 */
- (void)removeAllDeviceDataWithCompletion:(void (^)(NSError *error))completion;

#if TARGET_OS_IOS || TARGET_OS_OSX

- (void)showGDPRConsentUI;

- (void)showGDPRDeletionUI;

#endif

@end
