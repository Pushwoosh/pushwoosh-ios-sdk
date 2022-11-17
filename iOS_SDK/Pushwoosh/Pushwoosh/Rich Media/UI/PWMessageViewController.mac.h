//
//  PWMessageViewController.h
//  PushNotificationManager
//
//  Created by Kaizer on 08/06/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWResource.h"
#import <WebKit/WebKit.h>
#import "PWRichMediaManager.h"
#import <AppKit/AppKit.h>

@interface PWMessageViewController : NSWindowController

+ (void)presentWithRichMedia:(PWRichMedia *)richMedia;

+ (void)presentWithRichMedia:(PWRichMedia *)richMedia completion:(void(^)(BOOL success))completion;

@end
