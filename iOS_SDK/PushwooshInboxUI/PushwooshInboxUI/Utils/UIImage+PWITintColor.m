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
    if (!color || self.size.width <= 0 || self.size.height <= 0) return self;

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = self.scale;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:self.size format:format];

    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *rendererContext) {
        [color set];
        [[self imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] drawInRect:CGRectMake(0, 0, self.size.width, self.size.height)];
    }];
}

@end
