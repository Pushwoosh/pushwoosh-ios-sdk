//
//  PWRichMediaConfig
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PushwooshLog.h>
#import <PushwooshCore/PWSettings.h>

@interface PWRichMediaConfig : NSObject

- (instancetype)initWithContentsOfFile:(NSString *)filePath;

@property (nonatomic, readonly, copy) NSDictionary *localizedStrings;

@property (nonatomic, assign, readonly) BOOL iosCloseButton;
@property (nonatomic, assign, readonly) NSString *presentationStyleKey;

@end
