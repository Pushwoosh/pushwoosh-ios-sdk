#import <Foundation/Foundation.h>


typedef NSString *PWLogLevel NS_EXTENSIBLE_STRING_ENUM;

extern PWLogLevel const PWLogLevelNone;
extern PWLogLevel const PWLogLevelError;
extern PWLogLevel const PWLogLevelWarning;
extern PWLogLevel const PWLogLevelInfo;
extern PWLogLevel const PWLogLevelDebug;
extern PWLogLevel const PWLogLevelVerbose;

@interface PWLog : NSObject

+ (void)setLogsHandler:(void(^)(PWLogLevel level, NSString *description))logsHandler;
+ (void)removeLogsHandler;

@end


typedef NS_ENUM(unsigned int, LogLevel) {
    kLogNone = 0,
    kLogError,
    kLogWarning,
    kLogInfo,
    kLogDebug,
    kLogVerbose
};

#define PWLogError(...) PWLogInternal(__FUNCTION__, kLogError, __VA_ARGS__)
#define PWLogWarn(...) PWLogInternal(__FUNCTION__, kLogWarning, __VA_ARGS__)
#define PWLogInfo(...) PWLogInternal(__FUNCTION__, kLogInfo, __VA_ARGS__)
#define PWLogDebug(...) PWLogInternal(__FUNCTION__, kLogDebug, __VA_ARGS__)
#define PWLogVerbose(...) PWLogInternal(__FUNCTION__, kLogVerbose, __VA_ARGS__)

void PWLogInternal(const char *function, LogLevel logLevel, NSString *format, ...);

@interface PWLog (Internal)

@end


#define kPrefixDelay @"PrefixDelay"
#define kPrefixDate @"PrefixDate"
#define kPrefixRemainDelay @"PrefixRemainDelay"

@interface PWRequest : NSObject

@property (nonatomic, assign) NSInteger httpCode;
@property (nonatomic) BOOL cacheable;
@property (nonatomic) BOOL usePreviousHWID;
@property (nonatomic) int startTime;

- (NSString *)uid;
- (NSString *)methodName;
- (NSDictionary *)requestDictionary;
- (NSString *)requestIdentifier;

- (NSMutableDictionary *)baseDictionary;
- (void)parseResponse:(NSDictionary *)response;

@end


typedef void (^PWRequestDownloadCompleteBlock)(NSString *, NSError *);

@interface PWRequestManager : NSObject

- (void)sendRequest:(PWRequest *)request completion:(void (^)(NSError *error))completion;
- (void)downloadDataFromURL:(NSURL *)url withCompletion:(PWRequestDownloadCompleteBlock)completion;
- (void)setReverseProxyUrl:(NSString *)url;
- (void)disableReverseProxy;

@end



@interface PWNetworkModule : NSObject

@property (nonatomic, strong) PWRequestManager *requestManager;

+ (PWNetworkModule*)module;

- (void)inject:(id)object;

@end


@interface NSDictionary (PWDictUtils)

- (id)pw_objectForKey:(id)aKey ofTypes:(NSArray *)types;
- (id)pw_objectForKey:(id)aKey ofType:(Class)type;

- (NSString *)pw_stringForKey:(id)aKey;
- (NSDictionary *)pw_dictionaryForKey:(id)aKey;
- (NSArray *)pw_arrayForKey:(id)aKey;
- (double)pw_doubleForKey:(id)aKey;
- (NSNumber *)pw_numberForKey:(id)aKey;
- (NSNumber *)pw_forceNumberForKey:(id)aKey;
- (NSString *)pw_forceStringForKey:(id)aKey;

@end
