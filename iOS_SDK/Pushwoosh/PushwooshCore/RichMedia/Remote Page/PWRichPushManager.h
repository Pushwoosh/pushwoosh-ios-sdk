//
//  RichPushManager.h
//	Pushwoosh SDK
//

#if TARGET_OS_IOS
#import <Foundation/Foundation.h>

@interface PWRichPushManager : NSObject

- (void)showPushPage:(NSString *)pageId;

- (void)showCustomPushPageWithURLString:(NSString *)URLString;

@end
#endif
