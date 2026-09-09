//
//  PWResource.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#if TARGET_OS_IOS || TARGET_OS_TV
#import <Foundation/Foundation.h>
#import <PushwooshCore/PushwooshLog.h>
#import <PushwooshCore/PWRichMediaConfig.h>

typedef void (^PWResourceDownloadCompleteBlock)(NSError *);

typedef NS_ENUM(unsigned int, IAResourcePresentationStyle) {
    IAResourcePresentationUndefined = 0,
    IAResourcePresentationFullScreen,
    IAResourcePresentationCenter,
    IAResourcePresentationBottomBanner,
    IAResourcePresentationTopBanner
};

@interface PWResource : NSObject <NSSecureCoding>

@property (nonatomic, strong, readonly) NSString *code;  //identifier
@property (nonatomic, strong, readonly) NSString *url;
@property (nonatomic, readonly) BOOL closeButton;
@property (nonatomic, assign, readonly) ModalWindowPosition position;
@property (nonatomic, assign, readonly) PresentModalWindowAnimation presentAnimation;
@property (nonatomic, assign, readonly) DismissModalWindowAnimation dismissAnimation;
@property (nonatomic, assign, readonly) NSTimeInterval animationDuration;
@property (nonatomic, strong, readonly) NSArray<NSNumber *> *swipeToDismiss;
@property (nonatomic, readonly) NSTimeInterval updated;

@property (nonatomic, strong, readonly) NSDictionary *tags;

@property (nonatomic, strong, readonly) PWRichMediaConfig *config;

// InApp is currently showing
@property (nonatomic, assign) BOOL locked;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

- (IAResourcePresentationStyle)presentationStyle;
- (IAResourcePresentationStyle)presentationStyle:(NSString *)presentationKey;
- (BOOL)isDownloaded;
- (void)downloadDataWithCompletion:(PWResourceDownloadCompleteBlock)completion;

/// YES between the start of a zip download and its completion.
- (BOOL)isDownloading;

/// Reports when this resource's zip is on disk, without deleting a partial file or starting a
/// second download for the same resource, unlike -downloadDataWithCompletion:.
- (void)awaitDownloadWithCompletion:(PWResourceDownloadCompleteBlock)completion;
- (void)getHTMLDataWithCompletion:(void (^)(NSString *, NSError *))completion;

- (BOOL)hasNativeConfig;
- (NSString *)nativeConfigUrl;
- (void)deleteData;
- (NSString *)localPath;
- (NSString *)configUrl;
- (BOOL)isRichMedia;
- (NSString *)postProcessPageWithContent:(NSString *)pageContent;
- (NSDictionary *)localizeConfig:(NSDictionary *)config;
- (void)readConfig;

@end
#endif
