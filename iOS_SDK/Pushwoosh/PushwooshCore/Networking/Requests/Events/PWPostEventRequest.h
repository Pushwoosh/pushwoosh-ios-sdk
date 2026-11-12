//
//
//  PWPostEventRequest.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#import "PWRequest.h"
#import <PushwooshCore/PushwooshLog.h>

@interface PWPostEventRequest : PWRequest

@property (nonatomic, strong) NSString *event;
@property (nonatomic, strong) NSDictionary *attributes;

//response
@property (nonatomic, readonly, strong) NSString *resultCode;
@property (nonatomic, readonly, strong) NSDictionary *richMedia;
@property (nonatomic, readonly, strong) NSString *messageHash;
@property (nonatomic, readonly, strong) id inlineContent;

/// The user id and app code of the last body built for sending, the ones the answer is for.
@property (atomic, readonly, copy) NSString *sentUserId;
@property (atomic, readonly, copy) NSString *sentAppCode;

@end
