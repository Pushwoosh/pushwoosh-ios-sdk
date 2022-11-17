//
//  PWUtils.m
//  PushNotificationManager
//
//  Created by Kaizer on 07/06/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWUtils.h"
#import "PWUtils+Internal.h"
#import <CommonCrypto/CommonDigest.h>
#import <SystemConfiguration/SystemConfiguration.h>

#include <sys/socket.h>
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>

@implementation PWUtils

+ (NSString *)deviceName {
	return (__bridge NSString *)SCDynamicStoreCopyComputerName(NULL, NULL);
}

+ (NSString *)macaddress {
	int mib[6];
	size_t len;
	char *buf;
	unsigned char *ptr;
	struct if_msghdr *ifm;
	struct sockaddr_dl *sdl;

	mib[0] = CTL_NET;
	mib[1] = AF_ROUTE;
	mib[2] = 0;
	mib[3] = AF_LINK;
	mib[4] = NET_RT_IFLIST;

	if ((mib[5] = if_nametoindex("en0")) == 0) {
		printf("Error: if_nametoindex error\n");
		return NULL;
	}

	if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0) {
		printf("Error: sysctl, take 1\n");
		return NULL;
	}

	if ((buf = malloc(len)) == NULL) {
		printf("Could not allocate memory. error!\n");
		return NULL;
	}

	if (sysctl(mib, 6, buf, &len, NULL, 0) < 0) {
		printf("Error: sysctl, take 2");
		free(buf);
		return NULL;
	}

	ifm = (struct if_msghdr *)buf;
	sdl = (struct sockaddr_dl *)(ifm + 1);
	ptr = (unsigned char *)LLADDR(sdl);
	NSString *outstring = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X",
													 *ptr, *(ptr + 1), *(ptr + 2), *(ptr + 3), *(ptr + 4), *(ptr + 5)];
	free(buf);

	return outstring;
}

+ (NSString *)stringFromMD5:(NSString *)val {
	if (val == nil || [val length] == 0)
		return nil;

	const char *value = [val UTF8String];

	unsigned char outputBuffer[CC_MD5_DIGEST_LENGTH];
	CC_MD5(value, (CC_LONG)strlen(value), outputBuffer);

	NSMutableString *outputString = [[NSMutableString alloc] initWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
	for (NSInteger count = 0; count < CC_MD5_DIGEST_LENGTH; count++) {
		[outputString appendFormat:@"%02x", outputBuffer[count]];
	}

	return outputString;
}

+ (NSString *)generateIdentifier {
	NSString *macaddress = [self macaddress];
	return [self stringFromMD5:macaddress];
}

+ (BOOL)getAPSProductionStatus:(BOOL)canShowAlert {
	NSString *provisioning = [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents"] stringByAppendingPathComponent:@"embedded.provisionprofile"];
	if (![[NSFileManager defaultManager] fileExistsAtPath:provisioning])
		return YES;  //AppStore or without codesign

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

	NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:profileData options:NSPropertyListImmutable format:NULL error:NULL];

	NSDictionary *entitlements = plist[@"Entitlements"];

	//could be development or production
	NSString *apsGateway = entitlements[@"com.apple.developer.aps-environment"];
	if (!apsGateway && canShowAlert) {
		[self showAlertWithTitle:@"Pushwoosh Error" message:@"Your provisioning profile does not have APS entry. Please make your profile push compatible."];
	}

	if ([apsGateway isEqualToString:@"development"])
		return NO;

	return YES;
}

+ (void)applicationOpenURL:(NSURL *)url {
	[[NSWorkspace sharedWorkspace] openURL:url];
}

+ (NSString *)systemVersion {
	NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
	return [NSString stringWithFormat:@"%ld.%ld.%ld", version.majorVersion, version.minorVersion, version.patchVersion];
}

+ (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"OK"];
	[alert setInformativeText:message];
	[alert setMessageText:title];
	[alert performSelectorOnMainThread:@selector(runModal) withObject:nil waitUntilDone:NO];
}

+ (BOOL)isValidHwid:(NSString*)hwid {
    if (![hwid isKindOfClass:[NSString class]]) {
        return NO;
    }
    
    if ([hwid length] == 0) {
        return NO;
    }
    
    return YES;
}

+ (BOOL)isValidUserId:(NSString*)userId {
    return [self isValidHwid:userId];
}

@end
