//
//  PushwooshLog.m
//  PushwooshCore
//
//  Created by André Kis on 11.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import "PushwooshLog.h"
#import "PWConfig.h"

@implementation PushwooshLog

static PUSHWOOSH_LOG_LEVEL _llPushwooshLogLevel = PW_LL_INFO;

+ (Class<PWDebug>)debug {
    return self;
}

+ (void)pushwooshLog:(PUSHWOOSH_LOG_LEVEL)logLevel className:(id)object message:(NSString * _Nonnull)message {
    pushwoosh_Log(object, logLevel, @"%@", message);
}

void pushwoosh_Log(id object, PUSHWOOSH_LOG_LEVEL logLevel, NSString *format, ...) {
    if (logLevel > PW_LL_VERBOSE || logLevel < PW_LL_NONE) {
        return;
    }

    // Use default level when either singleton is mid-initialization — otherwise
    // a log emitted from inside +[PWConfig config] or +[PWPreferences preferences]
    // would re-enter the same dispatch_once and deadlock (SIGTRAP).
    PUSHWOOSH_LOG_LEVEL currentLevel;
    if ([PWConfig isInitializing] || [PWPreferences isInitializing]) {
        currentLevel = PW_LL_INFO;
    } else {
        currentLevel = [PWPreferences preferences].logLevel;
    }

    if (_llPushwooshLogLevel != PW_LL_INFO) {
        currentLevel = _llPushwooshLogLevel;
    }

    if (currentLevel < logLevel || currentLevel == PW_LL_NONE)
        return;
    
    va_list ap;
    va_start(ap, format);
    
    if (![format hasSuffix:@"\n"]) {
        format = [format stringByAppendingString:@"\n"];
    }
    
    NSString *body = [[NSString alloc] initWithFormat:format arguments:ap];
    va_end(ap);
    
    NSString *prefix = @"[PW]";
    NSString *logLevelTag;
    
    switch (logLevel) {
        case PW_LL_ERROR: logLevelTag = @"[ERROR]"; break;
        case PW_LL_WARN: logLevelTag = @"[WARNING]"; break;
        case PW_LL_DEBUG: logLevelTag = @"[DEBUG]"; break;
        case PW_LL_INFO: logLevelTag = @"[INFO]"; break;
        case PW_LL_VERBOSE: logLevelTag = @"[VERBOSE]"; break;
        default: logLevelTag = @"[UNKNOWN]"; break;
    }
    
    NSString *classNameStr = [NSString stringWithFormat:@"[%@]", NSStringFromClass([object class])];
    NSString *resultString = [NSString stringWithFormat:@"%@ %@ %@\n%@", prefix, logLevelTag, classNameStr, body];
    
    NSLog(@"%@", resultString);
}


+ (void)setLogLevel:(PUSHWOOSH_LOG_LEVEL)logLevel { 
    _llPushwooshLogLevel = logLevel;
}

@end
