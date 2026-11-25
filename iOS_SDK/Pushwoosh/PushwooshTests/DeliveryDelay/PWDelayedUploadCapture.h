//
//  PWDelayedUploadCapture.h
//  PushwooshTests
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Swaps the background session of PWDelayedDeliveryUploader for a mock and records what the uploader
/// hands it, so a test sees what the system would be given and nothing is sent. Call -stopMocking in tearDown.
@interface PWDelayedUploadCapture : NSObject

/// Class mock of PWDelayedDeliveryUploader; stub containerURLForAppGroup: on it to give the uploader a container.
@property (nonatomic, readonly) id uploaderMock;
@property (nonatomic, readonly) id sessionMock;
@property (nonatomic, readonly) id taskMock;

@property (nonatomic, readonly, nullable) NSURLRequest *request;
@property (nonatomic, readonly, nullable) NSURL *fileURL;
/// Read when the task is created, while the staged file is guaranteed to exist.
@property (nonatomic, readonly, nullable) NSData *body;
@property (nonatomic, readonly, nullable) NSDate *earliestBeginDate;
@property (nonatomic, readonly, nullable) NSString *taskDescription;

/// Forgets what was recorded, so the next upload is seen on its own.
- (void)reset;
- (void)stopMocking;

@end

NS_ASSUME_NONNULL_END
