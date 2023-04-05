//
//  PWToastView.h
//  Pushwoosh
//
//  Created by Andrei Kiselev on 10.2.23..
//  Copyright © 2023 Pushwoosh. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PWResource.h"

NS_ASSUME_NONNULL_BEGIN

@interface PWToastView : UIView

+ (void)closeToastViewAfter:(NSTimeInterval)interval;

- (void)createToastView:(PWResource *)resource position:(IAResourcePresentationStyle)position;

@end

NS_ASSUME_NONNULL_END
