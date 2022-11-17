//
//  PWLog.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2016
//

#import "PWPreferences.h"
#import "PWLog+Internal.h"

PWLogLevel const PWLogLevelNone = @"PWLogLevelNone";
PWLogLevel const PWLogLevelError = @"PWLogLevelError";
PWLogLevel const PWLogLevelWarning = @"PWLogLevelWarning";
PWLogLevel const PWLogLevelInfo = @"PWLogLevelInfo";
PWLogLevel const PWLogLevelDebug = @"PWLogLevelDebug";
PWLogLevel const PWLogLevelVerbose = @"PWLogLevelVerbose";

static NSString *pw_logLevelTags[] = {@"[N]", @"[E]", @"[W]", @"[I]", @"[D]", @"[V]"};
NSArray *pw_logLevels;

@interface PWLog ()

@property (nonatomic) void(^logsHandler)(PWLogLevel level, NSString *description);

@end

@implementation PWLog

void PWLogInternal(const char *function, LogLevel logLevel, NSString *format, ...) {
    if (logLevel > kLogVerbose || logLevel < kLogNone) {
        // unknown level
        return;
    }
    
    LogLevel currentLevel = [PWPreferences preferences].logLevel;
    
    if (currentLevel < logLevel || currentLevel == kLogNone)
        return;
    
    va_list ap;
    
    va_start(ap, format);
    
    if (![format hasSuffix:@"\n"]) {
        format = [format stringByAppendingString:@"\n"];
    }
    
    NSString *body = [[NSString alloc] initWithFormat:format arguments:ap];
    NSString *prefix = @"[PW]";
    NSString *logLevelTag = pw_logLevelTags[logLevel];
    NSString *functionStr = @(function);
    NSString *className = [[[functionStr componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]] firstObject] stringByAppendingString:@"]"];
    
    NSString *resultString = nil;
    if (currentLevel == kLogVerbose) {
        resultString = [NSString stringWithFormat:@"%@ %@ %s %@", prefix, logLevelTag, function, body];
    } else {
        resultString = [NSString stringWithFormat:@"%@ %@ %@ %@", prefix, logLevelTag, className, body];
    }
    NSLog(@"%@", resultString);
    
    va_end(ap);
    
    if ([PWLog sharedInstance].logsHandler) {
        [PWLog sharedInstance].logsHandler(pw_logLevels[logLevel], resultString);
    }
}

+ (instancetype)sharedInstance {
    static dispatch_once_t once;
    static PWLog *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [self new];
        pw_logLevels = @[PWLogLevelNone, PWLogLevelError, PWLogLevelWarning, PWLogLevelInfo, PWLogLevelDebug, PWLogLevelVerbose];
    });
    return sharedInstance;
}

+ (void)setLogsHandler:(void (^)(PWLogLevel, NSString *))logsHandler {
    [PWLog sharedInstance].logsHandler = logsHandler;
}

+ (void)removeLogsHandler {
    [self setLogsHandler:nil];
}

@end

