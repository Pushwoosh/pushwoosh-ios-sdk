//
//  PushUtils.m
//  PushNotificationManager
//
//  Created by User on 23/07/15.
//
//

#import "PWUtils.common.h"
#import "PWConfig.h"

#import <sys/utsname.h>
#import <objc/runtime.h>

NSErrorDomain const PWErrorDomain = @"pushwoosh";

void heavy_operation_impl(const char *function) {
	if ([NSThread isMainThread]) {
        [PushwooshLog pushwooshLog:PW_LL_WARN
                                 className:NSStringFromClass([PWUtilsCommon class])
                                   message:[NSString stringWithFormat:@"[%s] Executing long running operation on main thread", function]];
	}
}

@implementation PWUtilsCommon

+ (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"stub"];
}

+ (NSString *)systemVersion {
	return @"Unknown OS";
}

+ (BOOL)getAPSProductionStatus:(BOOL)canShowAlert {
	return NO;
}

+ (NSString *)deviceName {
	return @"Unknown device";
}

+ (NSString *)machineName {
	struct utsname systemInfo;
	uname(&systemInfo);

	return @(systemInfo.machine);
}

+ (NSString *)appVersion {
	return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

+ (NSString *)bundleId {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
}


+ (NSString *)preferredLanguage {
	NSString *appLocale = @"en";
    if ([PWConfig config].allowCollectingDeviceLocale == NO) {
        return appLocale;
    }

	NSLocale *locale = (NSLocale *)CFBridgingRelease(CFLocaleCopyCurrent());
	NSString *localeId = [locale localeIdentifier];

	if ([localeId length] > 2) {
		localeId = [localeId stringByReplacingCharactersInRange:NSMakeRange(2, [localeId length] - 2) withString:@""];
	}

	if ([localeId length] > 0) {
		appLocale = localeId;
	}

	NSArray *languagesArr = (NSArray *)CFBridgingRelease(CFLocaleCopyPreferredLanguages());
	if ([languagesArr count] > 0) {
		NSString *value = languagesArr.firstObject;

		NSDictionary *languageDictionary = [NSLocale componentsFromLocaleIdentifier:value];
		NSString *languageCode = languageDictionary[NSLocaleLanguageCode];
		NSString *scriptCode = languageDictionary[NSLocaleScriptCode];

		if ([value length] > 2 && languageCode != nil) {
			value = scriptCode != nil ? [NSString stringWithFormat:@"%@-%@", languageCode, scriptCode] : languageCode;
		}

		if ([value length] > 0) {
			appLocale = [value copy];
		}
	}

	return appLocale;
}

+ (NSString *)timezone {
	return [NSString stringWithFormat:@"%ld", (long)[[NSTimeZone localTimeZone] secondsFromGMT]];
}

+ (NSString *)generateIdentifier {
	return [[NSUUID new] UUIDString];
}

+ (NSString *)uniqueGlobalDeviceIdentifier {
	return [self generateIdentifier];
}

+ (NSError *)pushwooshError:(NSString *)description {
    return [self pushwooshErrorWithCode:PWErrorUnknown description:description];
}

+ (NSError *)pushwooshErrorWithCode:(NSInteger)errorCode description:(NSString *)description {
    return [NSError errorWithDomain:PWErrorDomain code:errorCode userInfo:@{NSLocalizedDescriptionKey : description}];
}

+ (BOOL)isShortenedUrl:(NSURL *)url {
	//check for bit.ly
	if ([[url host] hasPrefix:@"bit.ly"])
		return YES;

	//check for Google
	if ([[url host] hasPrefix:@"goo.gl"])
		return YES;

	//check for Baidu
	if ([[url host] hasPrefix:@"dwz.ch"])
		return YES;

	return NO;
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

+ (BOOL)isValidUserId:(NSString*)userId {
    return [self isValidHwid:userId];
}

+ (NSInteger)getStatusesMask {
    return 0;
}

+ (void)applicationOpenURL:(NSURL *)url {
}

//Shortened urls (bit.ly etc.) are resolved to their final destination before opening.
+ (void)openUrl:(NSURL *)url {
	if ([[url scheme] hasPrefix:@"http"] && [self isShortenedUrl:url]) {
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
		request.HTTPMethod = @"HEAD";

		NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
			NSURL *resolvedURL = response.URL ? : url;
			dispatch_async(dispatch_get_main_queue(), ^{
				[self applicationOpenURL:resolvedURL];
			});
		}];
		[task resume];
		return;
	}

	dispatch_async(dispatch_get_main_queue(), ^{
		[self applicationOpenURL:url];
	});
}

+ (void)swizzle:(Class)cls fromSelector:(SEL)fromChange toSelector:(SEL)toChange implementation:(IMP)impl typeEncoding:(const char *)typesEncoding {
	Method method = class_getInstanceMethod(cls, fromChange);

	if (method) {
		IMP originalImp = method_getImplementation(method);
		const char *originalTypes = method_getTypeEncoding(method);

		class_addMethod(cls, toChange, originalImp, originalTypes);
		class_addMethod(cls, fromChange, originalImp, originalTypes);
		method_setImplementation(class_getInstanceMethod(cls, fromChange), impl);
	} else {
		class_addMethod(cls, fromChange, impl, typesEncoding);
	}
}

@end
