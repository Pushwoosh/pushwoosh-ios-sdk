//
//  PWResource.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PushwooshLog.h>
#import "PWRichMediaConfig.h"

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
@property (nonatomic, readonly) BOOL required;
@property (nonatomic, readonly) double priority;
@property (nonatomic, readonly) BOOL closeButton;
@property (nonatomic, readonly) NSTimeInterval updated;
@property (nonatomic, readonly) NSString *businessCase;

@property (nonatomic, strong, readonly) NSDictionary *tags;

@property (nonatomic, strong, readonly) PWRichMediaConfig *config;

// InApp is currentle showing
@property (nonatomic, assign) BOOL locked;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

- (IAResourcePresentationStyle)presentationStyle;
- (IAResourcePresentationStyle)presentationStyle:(NSString *)presentationKey;
- (BOOL)isDownloaded;
- (void)downloadDataWithCompletion:(PWResourceDownloadCompleteBlock)completion;
- (void)getHTMLDataWithCompletion:(void (^)(NSString *, NSError *))completion;
- (void)deleteData;
- (NSString *)localPath;
- (NSString *)configUrl;
- (BOOL)isRichMedia;
- (NSString *)postProcessPageWithContent:(NSString *)pageContent;

@end
