//
//  PWDelayedUploadCapture.m
//  PushwooshTests
//

#import "PWDelayedUploadCapture.h"

#import <OCMock/OCMock.h>

#import "PWDeliveryDelayTestSeams.h"

#if TARGET_OS_IOS

@interface PWDelayedUploadCapture ()

@property (nonatomic, readwrite, nullable) NSURLRequest *request;
@property (nonatomic, readwrite, nullable) NSURL *fileURL;
@property (nonatomic, readwrite, nullable) NSData *body;
@property (nonatomic, readwrite, nullable) NSDate *earliestBeginDate;
@property (nonatomic, readwrite, nullable) NSString *taskDescription;

@end

@implementation PWDelayedUploadCapture

- (instancetype)init {
    self = [super init];
    if (self) {
        __weak typeof(self) weakSelf = self;

        _taskMock = OCMClassMock([NSURLSessionUploadTask class]);
        OCMStub([_taskMock setEarliestBeginDate:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
            __unsafe_unretained NSDate *date = nil;
            [invocation getArgument:&date atIndex:2];
            weakSelf.earliestBeginDate = date;
        });
        OCMStub([_taskMock setTaskDescription:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
            __unsafe_unretained NSString *taskDescription = nil;
            [invocation getArgument:&taskDescription atIndex:2];
            weakSelf.taskDescription = taskDescription;
        });

        _sessionMock = OCMClassMock([NSURLSession class]);
        OCMStub([_sessionMock uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
            __unsafe_unretained NSURLRequest *request = nil;
            __unsafe_unretained NSURL *fileURL = nil;
            [invocation getArgument:&request atIndex:2];
            [invocation getArgument:&fileURL atIndex:3];
            weakSelf.request = request;
            weakSelf.fileURL = fileURL;
            weakSelf.body = [NSData dataWithContentsOfURL:fileURL];
        }).andReturn(_taskMock);

        _uploaderMock = OCMClassMock([PWDelayedDeliveryUploader class]);
        OCMStub([_uploaderMock sessionForAppGroup:OCMOCK_ANY]).andReturn(_sessionMock);
    }
    return self;
}

- (void)reset {
    self.request = nil;
    self.fileURL = nil;
    self.body = nil;
    self.earliestBeginDate = nil;
    self.taskDescription = nil;
}

- (void)stopMocking {
    [_uploaderMock stopMocking];
}

@end

#endif
