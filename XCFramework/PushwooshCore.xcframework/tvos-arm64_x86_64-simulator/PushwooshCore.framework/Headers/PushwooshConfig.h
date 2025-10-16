//
//  PushwooshConfig.h
//  PushwooshCore
//
//  Created by André Kis on 16.04.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PWSettings.h>

@protocol PWConfiguration <NSObject>

+ (void)setApiToken:(NSString *_Nonnull)apiToken;
+ (NSString *_Nullable)getApiToken;

@end

@interface PushwooshConfig : NSObject<PWConfiguration>

+ (Class<PWConfiguration>_Nonnull)Configuration;

@end
