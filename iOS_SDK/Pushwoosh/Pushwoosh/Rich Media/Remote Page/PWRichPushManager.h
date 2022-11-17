//
//  RichPushManager.h
//	Pushwoosh SDK
//

#import <Foundation/Foundation.h>

@interface PWRichPushManager : NSObject

- (void)showPushPage:(NSString *)pageId;

- (void)showCustomPushPageWithURLString:(NSString *)URLString;

@end
