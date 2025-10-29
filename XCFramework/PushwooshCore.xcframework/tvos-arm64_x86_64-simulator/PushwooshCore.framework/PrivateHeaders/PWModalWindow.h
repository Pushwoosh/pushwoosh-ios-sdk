#if TARGET_OS_IOS

//
//  PWModalWindow.h
//  Pushwoosh
//
//  Created by Andrei Kiselev on 10.2.23..
//  Copyright © 2023 Pushwoosh. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <PushwooshCore/PWResource.h>
#import <PushwooshCore/PWRichMediaView.h>
#import <PushwooshCore/PWModalWindowConfiguration.h>

NS_ASSUME_NONNULL_BEGIN

@interface PWModalWindow : UIView

@property (nonatomic) UIButton *closeButton;

- (void)closeModalWindowAfter:(NSTimeInterval)interval;
- (void)presentModalWindow:(PWRichMedia *)richMedia modalWindow:(PWModalWindow *)modalWindow;
- (void)createModalWindow:(PWResource *)resource modalWindow:(PWRichMedia *)richMedia;
- (void)createModalWindowWith:(PWResource *)resource
                    richMedia:(PWRichMedia *)richMedia
                  modalWindow:(PWModalWindow *)modalWindow
                       window:(UIWindow *)window;

@end

NS_ASSUME_NONNULL_END

#endif
