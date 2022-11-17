//
//  PWLocationLog.m
//  Pushwoosh
//
//  Created by Victor Eysner on 04/09/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWLocationLog.h"
#import <CoreLocation/CoreLocation.h>
#import "PWSDKInterface.h"

#import <UIKit/UIKit.h>

#define LOCATIONS_FILE @"PWLocationTracking"
#define LOCATIONS_FILE_TYPE @"log"
#define ReportLocationNotification @"com.pushwoosh.notification.ReportLocationNotification"

@implementation PWLocationLog

+ (NSString *)path {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths[0];
    NSString *path = [NSString stringWithFormat:@"%@/%@.%@", documentsDirectory, LOCATIONS_FILE, LOCATIONS_FILE_TYPE];
    return path;
}

+ (NSDateFormatter *)dateFormatter {
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy/MM/dd HH:mm"];
    return dateFormat;
}

+ (void)createFileAtPathIfNeeded:(NSString *)path {
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        PWLogInfo(@"Creating locations log file");
        NSDate *date = [NSDate date];
        NSDateFormatter *dateFormat = [self dateFormatter];
        NSString *content = [NSString stringWithFormat:@"Location Tracker Log (%@)\n------------------------------------------------------------------\n", [dateFormat stringFromDate:date]];
        NSError *error = nil;
        [content writeToFile:path
                  atomically:NO
                    encoding:NSUTF8StringEncoding
                       error:&error];
        PWLogInfo(@"Path to location file: %@ error:%@", path, error);
    }
}

#pragma mark -

//This is a code to debug geopositioning in background
+ (void)logDebug:(NSString *)message withTracker:(NSObject *)tracker {
#ifdef DEBUG
    [self log:message withTracker:tracker];
    
    UILocalNotification *localNotification = [[UILocalNotification alloc] init];
    
    // Set the fire date/time
    [localNotification setFireDate:[NSDate date]];
    
    // Setup alert notification
    [localNotification setAlertBody:message];
    localNotification.soundName = UILocalNotificationDefaultSoundName;
    [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
#endif
}

#pragma mark - Message

+ (void)sendNotificationLocation:(CLLocation *)location withMessage:(NSString *)message tracker:(NSObject *)tracker {
    NSDictionary *userInfo = @{@"message" : message?:@"",
                               @"location" : location?:@"",
                               @"classTracker" :  NSStringFromClass([tracker class])?:@""
                               };
    [[NSNotificationCenter defaultCenter] postNotificationName:ReportLocationNotification object:tracker userInfo:userInfo];
}

+ (void)reportLocation:(CLLocation *)location withMessage:(NSString *)message tracker:(NSObject *)tracker {
    NSDateFormatter *dateFormat = [self dateFormatter];
    
    NSString *msg = [NSString stringWithFormat:@"%@: %@ <%+.6f, %+.6f> (+/-%.0fm) %.1fkm/h",
                     message,
                     [dateFormat stringFromDate:location.timestamp],
                     location.coordinate.latitude,
                     location.coordinate.longitude,
                     location.horizontalAccuracy,
                     location.speed * 3.6];
    
    if (location.altitude > 0) {
        msg = [NSString stringWithFormat:@"%@ alt: %.2fm (+/-%.0fm)",
               msg,
               location.altitude,
               location.verticalAccuracy];
    }
    
    [self logDebug:msg withTracker:tracker];
}

+ (void)log:(NSString *)message withTracker:(NSObject *)tracker {
    message = [NSString stringWithFormat:@"%@:\n%@\n ", NSStringFromClass([tracker class]), message];
    PWLogInfo(@"%@", message);
    
    NSString *path = [self path];
    NSDateFormatter *dateFormat = [self dateFormatter];
    [self createFileAtPathIfNeeded:path];
    
    message = [NSString stringWithFormat:@"%@: %@", [dateFormat stringFromDate:[NSDate date]], [message stringByAppendingString:@"\n"]];
    
    NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:path];
    NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
    [file seekToEndOfFile];
    [file writeData:data];
    [file closeFile];
}

@end
