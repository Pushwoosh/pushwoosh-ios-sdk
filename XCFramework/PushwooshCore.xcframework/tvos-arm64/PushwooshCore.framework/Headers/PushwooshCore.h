//
//  PushwooshCore.h
//  PushwooshCore
//
//  Created by André Kis on 07.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/Constants.h>
#import <PushwooshCore/PushwooshLog.h>
#import <PushwooshCore/PWManagerBridge.h>
#import <PushwooshCore/PWInboxBridge.h>
#import <PushwooshCore/PWTypes.h>
#import <PushwooshCore/PWMessage.h>
#import <PushwooshCore/PWPreferences.h>
#import <PushwooshCore/NSDictionary+PWDictUtils.h>
#import <PushwooshCore/PushwooshConfig.h>
#import <PushwooshCore/PWRequest.h>
#import <PushwooshCore/PWRequestManager.h>
#import <PushwooshCore/PWCoreUtils.h>
#import <PushwooshCore/PWInAppManager.h>
#import <PushwooshCore/PWRichMediaManager.h>
#import <PushwooshCore/PWRichMedia.h>
#import <PushwooshCore/PWModalWindowConfiguration.h>
#import <PushwooshCore/PWMedia.h>
#import <PushwooshCore/PWModalRichMedia.h>
#import <PushwooshCore/PWLegacyRichMedia.h>
#import <PushwooshCore/PWRichMediaStyle.h>
#import <PushwooshCore/PWRichMediaTypes.h>
#import <PushwooshCore/PWInboxTypes.h>
#import <PushwooshCore/PWConfig.h>
#import <PushwooshCore/PWInboxStorage.h>
#import <PushwooshCore/PWInboxService.h>
#import <PushwooshCore/PWInboxMessagesRequest.h>
#import <PushwooshCore/PWInboxUpdateStatusRequest.h>
#import <PushwooshCore/PWBaseInboxRequest.h>
#import <PushwooshCore/PWInboxMessageInternal.h>
#import <PushwooshCore/PWInboxMessageInternal+Status.h>
#import <PushwooshCore/PWNetworkModule.h>
#import <PushwooshCore/PWMessageDeliveryRequest.h>
#import <PushwooshCore/PWBasePushTrackingRequest.h>
#import <PushwooshCore/PWMessage+Internal.h>

#define PUSHWOOSH_VERSION @"7.0.19"

@interface PushwooshCoreManager : NSObject

+ (nonnull PWRequestManager *)sharedManager;

@end
