//
//  InteractivePush.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2016
//

#import <Foundation/Foundation.h>

@interface PWInteractivePush : NSObject

/**
 * Returns all categories including saved pushwoosh remote categories and local categories
 */
+ (void)getCategoriesWithCompletion:(void (^)(NSSet*))completion;

/**
 * Save pushwoosh remote categories
 */
+ (void)savePushwooshCategories:(NSArray *)categories;

@end
