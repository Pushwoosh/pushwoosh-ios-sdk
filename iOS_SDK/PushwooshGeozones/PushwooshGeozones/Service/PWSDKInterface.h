#import <Foundation/Foundation.h>
#import <PushwooshCore/PushwooshLog.h>
#import <PushwooshCore/PWRequest.h>
#import <PushwooshCore/PWRequestManager.h>
#import <PushwooshCore/PWNetworkModule.h>
#import <PushwooshCore/NSDictionary+PWDictUtils.h>

#define PWLogError(fmt, ...) [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:[NSString stringWithFormat:fmt, ##__VA_ARGS__]]
#define PWLogWarn(fmt, ...) [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:[NSString stringWithFormat:fmt, ##__VA_ARGS__]]
#define PWLogInfo(fmt, ...) [PushwooshLog pushwooshLog:PW_LL_INFO className:self message:[NSString stringWithFormat:fmt, ##__VA_ARGS__]]
#define PWLogDebug(fmt, ...) [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:[NSString stringWithFormat:fmt, ##__VA_ARGS__]]
#define PWLogVerbose(fmt, ...) [PushwooshLog pushwooshLog:PW_LL_VERBOSE className:self message:[NSString stringWithFormat:fmt, ##__VA_ARGS__]]

#define kPrefixDelay @"PrefixDelay"
#define kPrefixDate @"PrefixDate"
#define kPrefixRemainDelay @"PrefixRemainDelay"
