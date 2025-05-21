//
//  PushwooshCore.h
//  PushwooshCore
//
//  Created by André Kis on 07.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PWSettings.h>
#import <PushwooshCore/PWCConstants.h>
#import <PushwooshCore/PWCConfig.h>
#import <PushwooshCore/PushwooshLog.h>
#import <PushwooshCore/PWCoreRequest.h>
#import <PushwooshCore/PWCoreRequestManager.h>
#import <PushwooshCore/PWCoreGDPRManager.h>
#import <PushwooshCore/PWCoreServerCommunicationManager.h>
#import <PushwooshCore/PushwooshConfig.h>

#define PUSHWOOSH_VERSION @"6.8.6"

@interface PushwooshCoreManager : NSObject

+ (nonnull id<IPWCoreRequestManager>)sharedManager;

@end

