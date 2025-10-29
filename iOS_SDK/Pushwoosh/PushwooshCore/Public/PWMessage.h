//
//  PWMessage.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2024
//

#import <Foundation/Foundation.h>

@interface PWMessage : NSObject

@property (nonatomic, readonly) NSString * _Nullable title;
@property (nonatomic, readonly) NSString * _Nullable subTitle;
@property (nonatomic, readonly) NSString * _Nullable message;
@property (nonatomic, readonly) NSUInteger badge;
@property (nonatomic, readonly) NSString *_Nullable messageCode;
@property (nonatomic, readonly) uint64_t messageId;
@property (nonatomic, readonly) uint64_t campaignId;
@property (nonatomic, readonly) NSUInteger badgeExtension;
@property (nonatomic, readonly) NSString * _Nullable link;
@property (nonatomic, readonly, getter=isForegroundMessage) BOOL foregroundMessage;
@property (nonatomic, readonly, getter=isContentAvailable) BOOL contentAvailable;
@property (nonatomic, readonly, getter=isInboxMessage) BOOL inboxMessage;
@property (nonatomic, readonly) NSDictionary * _Nullable customData;
@property (nonatomic, readonly) NSDictionary * _Nullable payload;
@property (nonatomic, readonly) NSString * _Nullable actionIdentifier;

+ (BOOL)isPushwooshMessage:(NSDictionary *_Nonnull)userInfo;

@end
