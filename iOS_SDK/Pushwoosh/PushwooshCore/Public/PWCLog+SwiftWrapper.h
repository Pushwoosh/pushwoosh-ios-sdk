//
//  PWCLog+SwiftWrapper.h
//  PushwooshCore
//
//  Created by André Kis on 11.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <PushwooshCore/PWCLog.h>

@interface PWCLog (SwiftWrapper)

+ (void)logDebugWithFormat:(NSString *)format;
+ (void)logErrorWithFormat:(NSString *)format;
+ (void)logWarnWithFormat:(NSString *)format;
+ (void)logInfoWithFormat:(NSString *)format;
+ (void)logVerboseWithFormat:(NSString *)format;

@end
