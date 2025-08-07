//
//  PWPreferences.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2016
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PushwooshLog.h>

@interface PWPreferences : NSObject

+ (instancetype)preferences;

@property (copy) NSString *appCode;

+ (BOOL)checkAppCodeforChanges:(NSString *)appCode;

@end
