/*
 *  PWRetryEntry.m
 *  Pushwoosh
 *
 *  Created by André Kis
 */

#import "PWRetryEntry.h"
#import <PushwooshCore/PWRequest.h>
#import "PWRequest+Internal.h"

static NSString *const kKeyRequestIdentifier = @"rid";
static NSString *const kKeyMethodName = @"mn";
static NSString *const kKeyRequestDictionary = @"rd";
static NSString *const kKeyShouldWrapRequest = @"swr";
static NSString *const kKeyBaseUrl = @"bu";
static NSString *const kKeyAttemptCount = @"ac";
static NSString *const kKeyNextAttemptDate = @"nad";
static NSString *const kKeyFirstEnqueuedDate = @"fed";
static NSString *const kKeySurvivesApplicationChange = @"sac";

@implementation PWRetryEntry

- (instancetype)initWithRequest:(PWRequest *)request now:(NSDate *)now {
    return [self initWithRequest:request baseUrl:request.baseUrl now:now];
}

- (instancetype)initWithRequest:(PWRequest *)request baseUrl:(NSString *)baseUrl now:(NSDate *)now {
    self = [self initWithRequestIdentifier:request.requestIdentifier
                               methodName:request.methodName
                        requestDictionary:request.requestDictionary ?: @{}
                        shouldWrapRequest:request.shouldWrapRequest
                                  baseUrl:baseUrl
                             attemptCount:0
                          nextAttemptDate:now
                        firstEnqueuedDate:now];
    if (self) {
        _survivesApplicationChange = request.survivesApplicationChange;
    }
    return self;
}

- (instancetype)initWithRequestIdentifier:(NSString *)requestIdentifier
                               methodName:(NSString *)methodName
                        requestDictionary:(NSDictionary *)requestDictionary
                             attemptCount:(NSUInteger)attemptCount
                          nextAttemptDate:(NSDate *)nextAttemptDate
                        firstEnqueuedDate:(NSDate *)firstEnqueuedDate {
    return [self initWithRequestIdentifier:requestIdentifier
                               methodName:methodName
                        requestDictionary:requestDictionary
                        shouldWrapRequest:YES
                                  baseUrl:nil
                             attemptCount:attemptCount
                          nextAttemptDate:nextAttemptDate
                        firstEnqueuedDate:firstEnqueuedDate];
}

- (instancetype)initWithRequestIdentifier:(NSString *)requestIdentifier
                               methodName:(NSString *)methodName
                        requestDictionary:(NSDictionary *)requestDictionary
                        shouldWrapRequest:(BOOL)shouldWrapRequest
                                  baseUrl:(NSString *)baseUrl
                             attemptCount:(NSUInteger)attemptCount
                          nextAttemptDate:(NSDate *)nextAttemptDate
                        firstEnqueuedDate:(NSDate *)firstEnqueuedDate {
    if (self = [super init]) {
        _requestIdentifier = [requestIdentifier copy];
        _methodName = [methodName copy];
        _requestDictionary = [requestDictionary copy];
        _shouldWrapRequest = shouldWrapRequest;
        _baseUrl = [baseUrl copy];
        _attemptCount = attemptCount;
        _nextAttemptDate = [nextAttemptDate copy];
        _firstEnqueuedDate = [firstEnqueuedDate copy];
    }
    return self;
}

- (PWRetryEntry *)entryByIncrementingAttemptWithNextDate:(NSDate *)nextDate {
    PWRetryEntry *next = [[PWRetryEntry alloc] initWithRequestIdentifier:_requestIdentifier
                                               methodName:_methodName
                                        requestDictionary:_requestDictionary
                                        shouldWrapRequest:_shouldWrapRequest
                                                  baseUrl:_baseUrl
                                             attemptCount:_attemptCount + 1
                                          nextAttemptDate:nextDate
                                        firstEnqueuedDate:_firstEnqueuedDate];
    next->_survivesApplicationChange = _survivesApplicationChange;
    return next;
}

- (PWRetryEntry *)entryByRetargetingToBaseUrl:(NSString *)baseUrl {
    PWRetryEntry *retargeted = [[PWRetryEntry alloc] initWithRequestIdentifier:_requestIdentifier
                                               methodName:_methodName
                                        requestDictionary:_requestDictionary
                                        shouldWrapRequest:_shouldWrapRequest
                                                  baseUrl:baseUrl
                                             attemptCount:_attemptCount
                                          nextAttemptDate:_nextAttemptDate
                                        firstEnqueuedDate:_firstEnqueuedDate];
    retargeted->_survivesApplicationChange = _survivesApplicationChange;
    return retargeted;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    NSSet *payloadClasses = [NSSet setWithObjects:
                             [NSDictionary class], [NSMutableDictionary class],
                             [NSArray class], [NSMutableArray class],
                             [NSString class], [NSNumber class],
                             [NSDate class], [NSNull class], [NSData class], nil];

    NSString *requestIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:kKeyRequestIdentifier];
    NSString *methodName = [coder decodeObjectOfClass:[NSString class] forKey:kKeyMethodName];
    NSDictionary *requestDictionary = [coder decodeObjectOfClasses:payloadClasses forKey:kKeyRequestDictionary];
    BOOL shouldWrapRequest = [coder decodeBoolForKey:kKeyShouldWrapRequest];
    NSString *baseUrl = [coder decodeObjectOfClass:[NSString class] forKey:kKeyBaseUrl];
    NSUInteger attemptCount = (NSUInteger)[coder decodeIntegerForKey:kKeyAttemptCount];
    NSDate *nextAttemptDate = [coder decodeObjectOfClass:[NSDate class] forKey:kKeyNextAttemptDate];
    NSDate *firstEnqueuedDate = [coder decodeObjectOfClass:[NSDate class] forKey:kKeyFirstEnqueuedDate];

    if (requestIdentifier.length == 0 || methodName == nil || nextAttemptDate == nil || firstEnqueuedDate == nil) {
        return nil;
    }

    self = [self initWithRequestIdentifier:requestIdentifier
                               methodName:methodName
                        requestDictionary:requestDictionary ?: @{}
                        shouldWrapRequest:shouldWrapRequest
                                  baseUrl:baseUrl
                             attemptCount:attemptCount
                          nextAttemptDate:nextAttemptDate
                        firstEnqueuedDate:firstEnqueuedDate];
    if (self) {
        _survivesApplicationChange = [coder decodeBoolForKey:kKeySurvivesApplicationChange];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_requestIdentifier forKey:kKeyRequestIdentifier];
    [coder encodeObject:_methodName forKey:kKeyMethodName];
    [coder encodeObject:_requestDictionary forKey:kKeyRequestDictionary];
    [coder encodeBool:_shouldWrapRequest forKey:kKeyShouldWrapRequest];
    [coder encodeObject:_baseUrl forKey:kKeyBaseUrl];
    [coder encodeInteger:(NSInteger)_attemptCount forKey:kKeyAttemptCount];
    [coder encodeObject:_nextAttemptDate forKey:kKeyNextAttemptDate];
    [coder encodeObject:_firstEnqueuedDate forKey:kKeyFirstEnqueuedDate];
    [coder encodeBool:_survivesApplicationChange forKey:kKeySurvivesApplicationChange];
}

@end
