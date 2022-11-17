//
//  PWHtmlWebViewController.h
//  PushNotificationManager
//
//  Created by Kaizer on 07/06/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PWHtmlWebViewController;

@protocol PWHtmlWebViewControllerDelegate <NSObject>
- (void)htmlWebViewControllerReadyForShow:(PWHtmlWebViewController *)viewController;
- (void)htmlWebViewControllerDidClose:(PWHtmlWebViewController *)viewController;
@end

@interface PWHtmlWebViewController : NSWindowController

@property (nonatomic, weak) id<PWHtmlWebViewControllerDelegate> delegate;

- (instancetype)initWithURLString:(NSString *)url;

@end
