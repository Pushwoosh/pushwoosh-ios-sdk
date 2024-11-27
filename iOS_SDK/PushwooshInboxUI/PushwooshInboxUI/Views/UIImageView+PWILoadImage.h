//
//  Pushwoosh SDK
//  (c) Pushwoosh 2016
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface UIImageView (PWILoadImage)

- (void)pwi_loadImageFromUrl:(NSString *)url callback:(void (^)(UIImage *image))callback;
- (BOOL)pwi_isLoading;

@end
