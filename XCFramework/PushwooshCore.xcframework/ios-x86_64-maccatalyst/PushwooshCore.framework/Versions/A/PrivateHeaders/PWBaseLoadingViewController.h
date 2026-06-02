//
//  PWBaseLoadingViewController.h
//  Pushwoosh
//
//  Created by Victor Eysner on 05/12/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#import <PushwooshCore/PWRichMediaStyle.h>

@interface PWBaseLoadingViewController : UIViewController
@property (nonatomic, readonly) PWRichMediaStyle *richMediaStyle;
@property (nonatomic, weak) PWLoadingView *loadingView;

- (void)presentInWindow:(UIWindow *)window;
- (instancetype)initWithWindow:(UIWindow *)window richMediaStyle:(PWRichMediaStyle *)style;
+ (UIWindow *)presentedWindow;

- (void)closeController;

@end
#endif
