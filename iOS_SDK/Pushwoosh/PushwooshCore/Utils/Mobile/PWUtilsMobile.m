//
//  PWUtilsMobile.m
//  Pushwoosh
//
//  Created by Fectum on 22/07/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import "PWUtilsMobile.h"
#import "PWUtils+Internal.h"
#import "PWReachability.h"


@implementation PWUtilsMobile

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

+ (PWReachability *)reachability {
    return [PWReachability reachabilityForInternetConnection];
}

+ (BOOL)isSimulator {
    return false;
}

#pragma mark - Background

+ (NSNumber *)startBackgroundTask {
    return nil;
}

+ (void)stopBackgroundTask:(NSNumber *)taskId {}

@end

