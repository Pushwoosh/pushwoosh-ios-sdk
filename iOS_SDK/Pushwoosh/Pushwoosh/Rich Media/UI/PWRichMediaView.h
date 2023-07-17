//
//  PWRichMediaView.h
//  Pushwoosh.ios
//
//  Created by Fectum on 22/10/2018.
//  Copyright © 2018 Pushwoosh. All rights reserved.
//

#import "PWEasyJSWKWebView.h"
#import "PWWebClient.h"

@class PWRichMedia;

#if TARGET_OS_IOS
@interface PWRichMediaView : UIView<PWWebClientDelegate>
#else
@interface PWRichMediaView : NSView<PWWebClientDelegate>
#endif

@property (nonatomic, readonly) PWRichMedia *richMedia;
@property (nonatomic, strong) PWWebClient *webClient;
@property (nonatomic, readonly) CGSize contentSize;
@property (nonatomic) dispatch_block_t closeActionBlock;
@property (nonatomic) dispatch_block_t contentSizeDidChangeBlock;

- (instancetype)initWithFrame:(CGRect)frame
                      payload:(NSDictionary *)payload
                         code:(NSString *)code
                    inAppCode:(NSString *)inAppCode;
- (void)loadRichMedia:(PWRichMedia *)richMedia completion:(void (^)(NSError *error))completion;

@end
