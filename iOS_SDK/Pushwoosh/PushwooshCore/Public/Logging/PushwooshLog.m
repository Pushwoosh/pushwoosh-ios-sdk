//
//  PushwooshLog.m
//  PushwooshCore
//
//  Created by André Kis on 11.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import "PushwooshLog.h"

@implementation PushwooshLog

static PUSHWOOSH_LOG_LEVEL _llPushwooshLogLevel = PW_LL_INFO;

+ (Class<PWDebug>)Debug {
    return self;
}

+ (void)pushwooshLog:(PUSHWOOSH_LOG_LEVEL)logLevel className:(id)object message:(NSString * _Nonnull)message {
    pushwoosh_Log(object, logLevel, @"%@", message);
}

void pushwoosh_Log(id object, PUSHWOOSH_LOG_LEVEL logLevel, NSString *format, ...) {
    if (logLevel > PW_LL_VERBOSE || logLevel < PW_LL_ERROR) {
        return;
    }
    
    PUSHWOOSH_LOG_LEVEL currentLevel = [PWSettings settings].logLevel;
    
    if (_llPushwooshLogLevel != PW_LL_INFO) {
        currentLevel = _llPushwooshLogLevel;
    }
    
    if (currentLevel < logLevel || currentLevel == kLogNone)
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
    
    NSString *separator = @"-------------------------------------------------";
    NSString *classNameStr = [NSString stringWithFormat:@"[%@]", NSStringFromClass([object class])];
    NSString *resultString = [NSString stringWithFormat:@"%@\n%@ %@\n%@\n%@\n%@", separator, prefix, logLevelTag, classNameStr, separator, body];
    
    NSLog(@"%@", resultString);
}


+ (void)setLogLevel:(PUSHWOOSH_LOG_LEVEL)logLevel { 
    _llPushwooshLogLevel = logLevel;
}

@end
