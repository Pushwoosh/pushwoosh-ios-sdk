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

+ (NSString *)stringWithVisibleFirstAndLastFourCharacters:(NSString *)inputString {
    NSUInteger length = inputString.length;
    
    if (length <= 8) {
        return [@"" stringByPaddingToLength:length withString:@"*" startingAtIndex:0];
    }
    
    NSString *firstFour = [inputString substringToIndex:4]; // Первые 4 символа.
    NSString *lastFour = [inputString substringFromIndex:length - 4]; // Последние 4 символа.
    NSString *maskedMiddle = [@"" stringByPaddingToLength:length - 8 withString:@"*" startingAtIndex:0]; // Маскировка остальных символов.
    
    return [NSString stringWithFormat:@"%@%@%@", firstFour, maskedMiddle, lastFour];
}



+ (NSString *)preferredLanguage {
	NSString *appLocale = @"en";
    if ([PWConfig config].allowCollectingDeviceLocale == NO) {
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


+ (void)applicationOpenURL:(NSURL *)url {
}

#if TARGET_OS_WATCH

+ (void)openUrl:(NSURL *)url {
    //
}

#else
//This method is added to work with shorten urls
//According to ios 6, if user isn't logged in appstore, then when safari opens itunes url system will ask permission to run appstore.
//But still if application open appstore url, system will open it without any alerts.
+ (void)openUrl:(NSURL *)url {
	//When opening nsurlconnection to some url if it has some redirect, then connection will ask delegate what to do.
	//Unshort url and open it by usual way.
	if ([[url scheme] hasPrefix:@"http"] && [self isShortenedUrl:url]) {
		NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:[NSMutableURLRequest requestWithURL:url] delegate:self];
		if (!connection) {
			return;
		}
		return;
	}

	//If url has cusmtom scheme like facebook:// or itms:// we need to open it directly:
	//small fix to prevent app freeezes on iOS7
	//see: http://stackoverflow.com/questions/19356488/openurl-freezes-app-for-over-10-seconds
	dispatch_async(dispatch_get_main_queue(), ^{
		[self applicationOpenURL:url];
	});
}

+ (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request
			redirectResponse:(NSURLResponse *)redirectResponse {
    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:[NSString stringWithFormat:@"Url: %@", [request URL]]];

	NSURL *url = [request URL];
	if ([[url scheme] hasPrefix:@"http"] && [self isShortenedUrl:url]) {
		return request;
	}

	dispatch_async(dispatch_get_main_queue(), ^{
		[self applicationOpenURL:url];
	});

	return nil;
}

+ (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	NSURL *url = [error userInfo][@"NSErrorFailingURLKey"];

	//maybe itms:// or facebook:// url was shortened, try to open it directly
	//iOS9 also fails to open http connections
	dispatch_async(dispatch_get_main_queue(), ^{
		[self applicationOpenURL:url];
	});
}

#endif

+ (void)swizzle:(Class) class fromSelector:(SEL)fromChange toSelector:(SEL)toChange implementation:(IMP)impl typeEncoding:(const char *)typesEncoding {
	Method method = nil;
	method = class_getInstanceMethod(class, fromChange);

	if (method) {
		//method exists add a new method and swap with original
		class_addMethod(class, toChange, impl, typesEncoding);
		method_exchangeImplementations(class_getInstanceMethod(class, fromChange), class_getInstanceMethod(class, toChange));
	} else {
		//just add as orignal method
		class_addMethod(class, fromChange, impl, typesEncoding);
	}
}

@end
