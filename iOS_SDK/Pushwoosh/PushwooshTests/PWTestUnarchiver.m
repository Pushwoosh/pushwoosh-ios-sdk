//
//  PWTestUnarchiver.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 21.12.2021.
//  Copyright © 2021 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>
#import <OCMock/OCMock.h>

#import "PWUnarchiver.h"
#import "PWResource.h"
#import "PWCache.h"
#import "PWCachedRequest.h"
#import "PWRequestsCacheManager.h"

@interface PWTestUnarchiver : XCTestCase

@property (nonatomic) PWUnarchiver *unarchiver;
@property (atomic, strong) NSDictionary *resources;
@property (nonatomic, copy) NSString *tagsCacheFile;

@end

@implementation PWTestUnarchiver

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.unarchiver = [[PWUnarchiver alloc] init];
    self.resources = [[NSDictionary alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testUnarchivedObjectPWInAppStorage {
    NSSet *set = [NSSet setWithObjects:[PWResource class], [NSDictionary class], nil];
    NSDictionary *parameters = @{@"ASDFA-ASDAS": @{@"url": @"test1",
                                           @"code": @"ASDFA-ASDAS",
                                           @"updated": @"12.9837",
                                           @"layout": @"layout4"}};
    _resources = parameters;
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:_resources requiringSecureCoding:YES error:&error];
    
    id returnValue = [self.unarchiver unarchivedObjectOfClasses:set data:data];
    
    XCTAssertTrue([parameters isEqualToDictionary:returnValue], @"Output result (%@) does not match input (%@)", returnValue, parameters);
}

- (void)testUnarchivedObjectPWRequestsCacheManager {
    NSFileManager *fileManager = [NSFileManager new];
    NSString *cachePath = [self cachePath:fileManager];
    NSURL *url = [NSURL fileURLWithPath:cachePath];
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:url requiringSecureCoding:YES error:&error];
    NSSet *set = [NSSet setWithObjects:[PWCachedRequest class], [NSMutableArray class], [NSURL class], nil];
    
    id returnValue = [self.unarchiver unarchivedObjectOfClasses:set data:data];
    
    XCTAssertNotNil(returnValue);
}

- (NSString *)cachePath:(NSFileManager *)fileManager {
    NSArray *urls = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSString *directory = [(NSURL *)urls[0] path];
    return [directory stringByAppendingPathComponent:@"PWRequestCache"];
}

- (void)testUnarchivedObjectOfClassesWithUnarchivedFailed {
    // NSSet with wrong objects declaration [NSData class] instead of [NSDictionary class]
    NSSet *set = [NSSet setWithObjects:[NSData class], nil];
    NSDictionary *inputParameters = @{@"test1": @"test1",
                                 @"test2": @"test2"
    };
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:inputParameters requiringSecureCoding:YES error:&error];
    
    id returnValue = [self.unarchiver unarchivedObjectOfClasses:set data:data];
    
    XCTAssertNil(returnValue);
}

@end
