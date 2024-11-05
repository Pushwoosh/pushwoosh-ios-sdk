//
//  PWHashDecoder.m
//  Pushwoosh
//
//  Created by André Kis on 28.10.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#import "PWHashDecoder.h"
#import "PWAlphabetUtils.h"
#import "PWPreferences.h"

static NSString *const messageCodeInnerSplitter = @"-";
static const int messageCodeFirstPartLettersCount = 4;
static const int messageCodeOtherPartLettersCount = 8;

@interface PWHashDecoder ()

@property (nonatomic, copy) NSString *messageCode;
@property (nonatomic) uint64_t messageId;
@property (nonatomic) uint64_t campaignId;

- (NSString *)prependZerosIfNeeded:(BOOL)isFirstPart hexNumber:(NSString *)hexNumber;
- (NSString *)decodeMessageCode:(NSString *)messageCode;

@end

@implementation PWHashDecoder

+ (instancetype)sharedInstance {
    static PWHashDecoder *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

+ (NSString *)getMessageCode {
    return [PWHashDecoder sharedInstance].messageCode;
}

+ (uint64_t)getMessageId {
    return [PWHashDecoder sharedInstance].messageId;
}

+ (uint64_t)getCampaignId {
    return [PWHashDecoder sharedInstance].campaignId;
}

- (NSString *)prependZerosIfNeeded:(BOOL)isFirstPart hexNumber:(NSString *)hexNumber {
    NSUInteger strLen = hexNumber.length;
    NSUInteger normalPartLen = messageCodeOtherPartLettersCount;

    if (isFirstPart) {
        normalPartLen = messageCodeFirstPartLettersCount;
    }

    if (strLen >= normalPartLen) {
        return hexNumber;
    }

    NSMutableString *prefix = [NSMutableString stringWithCapacity:normalPartLen - strLen];
    for (NSUInteger i = 0; i < (normalPartLen - strLen); i++) {
        [prefix appendString:@"0"];
    }

    return [prefix stringByAppendingString:hexNumber];
}

- (NSString *)decodeMessageCode:(NSString *)messageCode {
    NSArray<NSString *> *parts = [messageCode componentsSeparatedByString:messageCodeInnerSplitter];
    if (parts.count == 1) {
        return messageCode;
    }

    NSMutableArray<NSString *> *decodedParts = [NSMutableArray arrayWithCapacity:parts.count];

    for (NSUInteger i = 0; i < parts.count; i++) {
        BOOL isFirstPart = (i == 0);
        uint64_t decodedMessageCodePartAsDecimalNumber = [PWAlphabetUtils alphabetDecode:parts[i]];
        NSString *decodedMessageCodePartAsHexNumber = [NSString stringWithFormat:@"%llX", decodedMessageCodePartAsDecimalNumber];

        [decodedParts addObject:[self prependZerosIfNeeded:isFirstPart hexNumber:decodedMessageCodePartAsHexNumber]];
    }

    return [decodedParts componentsJoinedByString:messageCodeInnerSplitter];
}

- (void)parseMessageHash:(NSString *)hash {
    NSString *hashDelimiter = @"_";
    NSString *hashDelimiterOld = @"-";
    NSUInteger maxSymbolsInRealHash = 64;

    BOOL hasOldDelimiter = [hash containsString:hashDelimiterOld];

    if (hash.length > 0 && !hasOldDelimiter && hash.length <= maxSymbolsInRealHash) {
        _messageCode = @"";
        _messageId = 0;
        _campaignId = 0;
        return;
    }

    NSArray<NSString *> *parts = [hash componentsSeparatedByString:hashDelimiter];
    if (parts.count > 3) {
        uint64_t campaignID = [PWAlphabetUtils alphabetDecode:parts[1]];
        uint64_t messageID = [PWAlphabetUtils alphabetDecode:parts[2]];
        NSString *messageCode = [self decodeMessageCode:parts[3]];
        
        _messageCode = messageCode;
        _messageId = messageID;
        _campaignId = campaignID;
        
        return;
    }
    
    _messageCode = @"";
    _messageId = 0;
    _campaignId = 0;
}


@end
