//
//  UIImage+PWITintColor.m
//  PushwooshInboxUI
//
//  Created by Pushwoosh on 03/11/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "UIImage+PWITintColor.h"

@implementation UIImage (PWITintColor)

- (UIImage *)pwi_imageWithTintColor:(UIColor *)color {
    UIImage *image = [self imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIGraphicsBeginImageContextWithOptions(self.size, NO, image.scale);
    [color set];
    [image drawInRect:CGRectMake(0, 0, self.size.width, image.size.height)];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end
