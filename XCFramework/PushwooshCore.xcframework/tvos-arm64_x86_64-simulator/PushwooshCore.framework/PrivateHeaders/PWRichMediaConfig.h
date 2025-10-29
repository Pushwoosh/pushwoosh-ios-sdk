//
//  PWRichMediaConfig
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#if TARGET_OS_IOS || TARGET_OS_TV
#import <Foundation/Foundation.h>
#import <PushwooshCore/PushwooshLog.h>
#import <PushwooshCore/PWPreferences.h>
#import <PushwooshCore/PWRichMediaTypes.h>

NS_ASSUME_NONNULL_BEGIN

@interface PWRichMediaConfig : NSObject

- (instancetype)initWithContentsOfFile:(NSString *)filePath;

@property (nonatomic, readonly, copy) NSDictionary *localizedStrings;

// Legacy properties
@property (nonatomic, assign, readonly) BOOL iosCloseButton;
@property (nonatomic, assign, readonly) NSString *presentationStyleKey;

@property (nonatomic, assign, readonly) ModalWindowPosition position;
@property (nonatomic, assign, readonly) PresentModalWindowAnimation presentAnimation;
@property (nonatomic, assign, readonly) DismissModalWindowAnimation dismissAnimation;
@property (nonatomic, strong, readonly) NSArray<NSNumber *> *swipeToDismiss;

+ (PresentModalWindowAnimation)presentAnimationFromString:(NSString *)string;
+ (DismissModalWindowAnimation)dismissAnimationFromString:(NSString *)string;
+ (ModalWindowPosition)positionFromString:(NSString *)string;

@end

NS_ASSUME_NONNULL_END
#endif
