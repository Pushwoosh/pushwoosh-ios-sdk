#import <XCTest/XCTest.h>
#import "PWRetryEntry.h"
#import "PWRequest.h"

@interface PWStubTransportRequest : PWRequest
@end

@implementation PWStubTransportRequest
- (BOOL)shouldWrapRequest { return NO; }
- (NSString *)baseUrl { return @"https://custom.example.com/"; }
@end

@interface PWRetryEntryTest : XCTestCase
@end

@implementation PWRetryEntryTest

- (PWRetryEntry *)makeEntryWithAttempt:(NSUInteger)attempt {
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:1000];
    return [[PWRetryEntry alloc] initWithRequestIdentifier:@"uuid-1"
                                               methodName:@"registerDevice"
                                        requestDictionary:@{@"hwid": @"HW", @"n": @42}
                                             attemptCount:attempt
                                          nextAttemptDate:now
                                        firstEnqueuedDate:now];
}

/// Verifies a fresh entry snapshots the request's method/payload/identifier and starts at attempt 0.
- (void)testInitFromRequest_snapshotsFields {
    PWRequest *request = [[PWRequest alloc] init];
    NSDate *now = [NSDate date];

    PWRetryEntry *entry = [[PWRetryEntry alloc] initWithRequest:request now:now];

    XCTAssertEqualObjects(entry.requestIdentifier, request.requestIdentifier);
    XCTAssertEqualObjects(entry.methodName, request.methodName);
    XCTAssertNotNil(entry.requestDictionary);
    XCTAssertEqual(entry.attemptCount, 0u);
    XCTAssertEqualObjects(entry.firstEnqueuedDate, now);
    XCTAssertEqualObjects(entry.nextAttemptDate, now);
}

/// Verifies a fresh entry freezes the request's shouldWrapRequest/baseUrl so the replay matches the original send.
- (void)testInitFromRequest_freezesTransportFields {
    PWStubTransportRequest *request = [[PWStubTransportRequest alloc] init];

    PWRetryEntry *entry = [[PWRetryEntry alloc] initWithRequest:request now:[NSDate date]];

    XCTAssertFalse(entry.shouldWrapRequest);
    XCTAssertEqualObjects(entry.baseUrl, @"https://custom.example.com/");
}

/// Verifies the convenience initializer defaults to the standard transport (wrap on, no base URL override).
- (void)testConvenienceInit_defaultsToStandardTransport {
    PWRetryEntry *entry = [self makeEntryWithAttempt:0];

    XCTAssertTrue(entry.shouldWrapRequest);
    XCTAssertNil(entry.baseUrl);
}

/// Verifies incrementing produces a new entry (attempt+1, new date) and leaves the original untouched.
- (void)testIncrementAttempt_isImmutable {
    PWRetryEntry *original = [self makeEntryWithAttempt:2];
    NSDate *newDate = [NSDate dateWithTimeIntervalSince1970:5000];

    PWRetryEntry *next = [original entryByIncrementingAttemptWithNextDate:newDate];

    XCTAssertEqual(original.attemptCount, 2u);
    XCTAssertEqual(next.attemptCount, 3u);
    XCTAssertEqualObjects(next.nextAttemptDate, newDate);
    XCTAssertEqualObjects(next.requestIdentifier, original.requestIdentifier);
    XCTAssertEqualObjects(next.firstEnqueuedDate, original.firstEnqueuedDate);
}

/// Verifies NSSecureCoding round-trip preserves every field including retry metadata.
- (void)testSecureCodingRoundTrip {
    PWRetryEntry *entry = [self makeEntryWithAttempt:3];

    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:entry requiringSecureCoding:YES error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(data);

    PWRetryEntry *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[PWRetryEntry class] fromData:data error:&error];
    XCTAssertNil(error);

    XCTAssertEqualObjects(decoded.requestIdentifier, @"uuid-1");
    XCTAssertEqualObjects(decoded.methodName, @"registerDevice");
    XCTAssertEqualObjects(decoded.requestDictionary[@"hwid"], @"HW");
    XCTAssertEqualObjects(decoded.requestDictionary[@"n"], @42);
    XCTAssertEqual(decoded.attemptCount, 3u);
    XCTAssertEqualObjects(decoded.nextAttemptDate, entry.nextAttemptDate);
    XCTAssertEqualObjects(decoded.firstEnqueuedDate, entry.firstEnqueuedDate);
    XCTAssertTrue(decoded.shouldWrapRequest);
    XCTAssertNil(decoded.baseUrl);
}

/// Verifies NSSecureCoding round-trip preserves a non-default transport (wrap off + base URL override).
- (void)testSecureCodingRoundTrip_preservesTransportFields {
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:1000];
    PWRetryEntry *entry = [[PWRetryEntry alloc] initWithRequestIdentifier:@"uuid-2"
                                                              methodName:@"messageDeliveryEvent"
                                                       requestDictionary:@{@"k": @"v"}
                                                       shouldWrapRequest:NO
                                                                 baseUrl:@"https://custom.example.com/"
                                                            attemptCount:1
                                                         nextAttemptDate:now
                                                       firstEnqueuedDate:now];

    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:entry requiringSecureCoding:YES error:&error];
    XCTAssertNil(error);

    PWRetryEntry *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[PWRetryEntry class] fromData:data error:&error];
    XCTAssertNil(error);

    XCTAssertFalse(decoded.shouldWrapRequest);
    XCTAssertEqualObjects(decoded.baseUrl, @"https://custom.example.com/");
}

/// Verifies supportsSecureCoding is advertised.
- (void)testSupportsSecureCoding {
    XCTAssertTrue([PWRetryEntry supportsSecureCoding]);
}

@end
