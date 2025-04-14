//
//  PWCUtils.m
//  PushwooshCore
//
//  Created by André Kis on 10.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import "PWCoreUtils.h"
#import "PWCConfig.h"

NSErrorDomain const PWCoreErrorDomain = @"pushwoosh";

@implementation PWCoreUtils

+ (NSString *)uniqueGlobalDeviceIdentifier {
    return [self generateIdentifier];
}

+ (NSString *)generateIdentifier {
    return [[NSUUID new] UUIDString];
}

+ (BOOL)isValidHwid:(NSString*)hwid {
    if (![hwid isKindOfClass:[NSString class]]) {
        return NO;
    }
    
    if ([hwid length] == 0) {
        return NO;
    }
    
    if ([hwid isEqualToString:@"00000000-0000-0000-0000-000000000000"]) {
        return NO;
    }
    
    if ([hwid isEqualToString:@"0f607264fc6318a92b9e13c65db7cd3c"]) {
        return NO;
    }
    
    return YES;
}

+ (NSString *)preferredLanguage {
    NSString *appLocale = @"en";
    if ([PWCConfig config].allowCollectingDeviceLocale == NO) {
        return appLocale;
    }
    
    NSLocale *locale = (NSLocale *)CFBridgingRelease(CFLocaleCopyCurrent());
    NSString *localeId = [locale localeIdentifier];

    if ([localeId length] > 2)
        localeId = [localeId stringByReplacingCharactersInRange:NSMakeRange(2, [localeId length] - 2) withString:@""];

    appLocale = localeId;

    NSArray *languagesArr = (NSArray *)CFBridgingRelease(CFLocaleCopyPreferredLanguages());
    if ([languagesArr count] > 0) {
        NSString *value = languagesArr[0];

        NSDictionary *languageDictionary = [NSLocale componentsFromLocaleIdentifier:value];
        NSString *languageCode = [languageDictionary objectForKey:@"kCFLocaleLanguageCodeKey"];
        NSString *description = [languageDictionary objectForKey:@"kCFLocaleScriptCodeKey"];
        
        if ([value length] > 2) {
            value = description != nil ? [NSString stringWithFormat:@"%@-%@", languageCode, description] : languageCode;
        }

        appLocale = [value copy];
    }

    return appLocale;
}

+ (BOOL)getAPSProductionStatus:(BOOL)canShowAlert {
#if TARGET_OS_SIMULATOR
    return NO;
#endif
    
    NSString *provisioning = [[NSBundle mainBundle] pathForResource:@"embedded.mobileprovision" ofType:nil];
    if (!provisioning)
        return YES;  //AppStore
    
    NSString *contents = [NSString stringWithContentsOfFile:provisioning encoding:NSASCIIStringEncoding error:nil];
    if (!contents)
        return YES;
    
    NSRange start = [contents rangeOfString:@"<?xml"];
    NSRange end = [contents rangeOfString:@"</plist>"];
    start.length = end.location + end.length - start.location;
    
    NSString *profile = [contents substringWithRange:start];
    if (!profile)
        return YES;
    
    NSData *profileData = [profile dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSPropertyListFormat format;
    NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:profileData options:NSPropertyListImmutable format:&format error:&error];
    
    NSDictionary *entitlements = plist[@"Entitlements"];
    
    //could be development or production
    NSString *apsGateway = entitlements[@"aps-environment"];
    if (!apsGateway && canShowAlert) {
        [self showAlertWithTitle:@"Pushwoosh Error" message:@"Your provisioning profile does not have APS entry. Please make your profile push compatible."];
    }
    
    if ([apsGateway isEqualToString:@"development"])
        return NO;
    
    return YES;
}

+ (NSError *)pushwooshError:(NSString *)description {
    return [self pushwooshErrorWithCode:PWCoreErrorUnknown description:description];
}

+ (NSError *)pushwooshErrorWithCode:(NSInteger)errorCode description:(NSString *)description {
    return [NSError errorWithDomain:PWCoreErrorDomain code:errorCode userInfo:@{NSLocalizedDescriptionKey : description}];
}

+ (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"stub"];
}

@end
