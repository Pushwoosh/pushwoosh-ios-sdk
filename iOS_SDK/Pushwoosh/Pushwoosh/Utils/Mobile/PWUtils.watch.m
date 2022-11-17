//
//  PWUtils.m
//  Pushwoosh.watchOS
//
//  Created by Fectum on 22/07/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import "PWUtils.h"
#import <WatchKit/WatchKit.h>

@implementation PWUtils

+ (NSString *)deviceName {
    return [WKInterfaceDevice currentDevice].name;
}

+ (NSString *)systemVersion {
    return [WKInterfaceDevice currentDevice].systemVersion;
}

+ (NSString *)generateIdentifier {
    return [[NSUUID new] UUIDString];
}

+ (void)openUrl:(NSURL *)url {
    [[WKExtension sharedExtension] openSystemURL:url];
}

@end
