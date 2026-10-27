#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWResource.h"
#import "PWCache.h"
#import "PWConfig.h"

/// Golden gate: every real Rich Media template bundled in PlaceholderCorpus must come out
/// of -postProcessPageWithContent: byte for byte as it did before the script-segmentation fix.
/// The expected.html files were recorded against the unmodified PWResource and are never edited afterwards.
/// The single exception is inline-script-pipe, a repro template whose golden was recorded
/// against the fixed PWResource so that reverting the fix breaks this suite.
@interface PWResourcePlaceholderCorpusTest : XCTestCase

@property (nonatomic, strong) PWResource *resource;
@property (nonatomic, strong) id cacheMock;
@property (nonatomic, strong) id configMock;

@end

@implementation PWResourcePlaceholderCorpusTest

- (void)setUp {
    [super setUp];
    self.resource = [[PWResource alloc] initWithDictionary:@{ @"code": @"TEST-CORPUS",
                                                              @"url": @"https://example.com/test.zip",
                                                              @"updated": @1 }];
    [[NSFileManager defaultManager] createDirectoryAtPath:[self.resource localPath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    /// Real device tags would make the recorded goldens machine-dependent.
    self.cacheMock = OCMPartialMock([PWCache cache]);
    OCMStub([self.cacheMock getTags]).andReturn(nil);
    self.configMock = OCMPartialMock([PWConfig config]);
    OCMStub([self.configMock allowCollectingDeviceModel]).andReturn(NO);
    OCMStub([self.configMock allowCollectingDeviceOsVersion]).andReturn(NO);
}

- (void)tearDown {
    /// PWCache and PWConfig are singletons, so a partial mock left standing would leak into every later suite.
    [self.cacheMock stopMocking];
    self.cacheMock = nil;
    [self.configMock stopMocking];
    self.configMock = nil;
    [[NSFileManager defaultManager] removeItemAtPath:[self.resource localPath] error:nil];
    self.resource = nil;
    [super tearDown];
}

- (NSString *)corpusPath {
    return [[[NSBundle bundleForClass:self.class] resourcePath] stringByAppendingPathComponent:@"PlaceholderCorpus"];
}

- (NSArray<NSString *> *)templateNames {
    return @[ @"inline-script-pipe",
              @"rich-media-pages__markup1",
              @"rich-media-pages__markup7",
              @"rich-media-pages__push-register" ];
}

/// Verifies that the substitution output of every listed template matches the recorded goldens.
/// A golden that is absent, or the environment variable PW_CORPUS_RECORD, switches a template to record
/// mode: the output is written under NSTemporaryDirectory()/PlaceholderCorpus and the path is logged as
/// PW_CORPUS_RECORD_DIR=<dir>. Recording never passes silently unless PW_CORPUS_RECORD was asked for.
- (void)testRealTemplatesOutputUnchanged {
    NSArray<NSString *> *names = [self templateNames];

    BOOL recording = NSProcessInfo.processInfo.environment[@"PW_CORPUS_RECORD"] != nil;
    NSString *recordDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"PlaceholderCorpus"];
    NSMutableArray<NSString *> *recorded = [NSMutableArray new];

    for (NSString *name in names) {
        NSString *dir = [[self corpusPath] stringByAppendingPathComponent:name];
        NSString *input = [NSString stringWithContentsOfFile:[dir stringByAppendingPathComponent:@"index.html"]
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil];
        XCTAssertNotNil(input, @"index.html missing for template %@", name);

        NSString *output = [self.resource postProcessPageWithContent:input];
        NSString *expected = [NSString stringWithContentsOfFile:[dir stringByAppendingPathComponent:@"expected.html"]
                                                       encoding:NSUTF8StringEncoding
                                                          error:nil];

        if (recording || expected == nil) {
            NSString *outDir = [recordDir stringByAppendingPathComponent:name];
            [[NSFileManager defaultManager] createDirectoryAtPath:outDir
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:nil];
            NSError *writeError = nil;
            [output writeToFile:[outDir stringByAppendingPathComponent:@"expected.html"]
                     atomically:YES
                       encoding:NSUTF8StringEncoding
                          error:&writeError];
            XCTAssertNil(writeError, @"failed to record template %@", name);
            [recorded addObject:name];
            continue;
        }

        XCTAssertEqualObjects(output, expected, @"template %@", name);
    }

    if (recorded.count > 0) {
        NSLog(@"PW_CORPUS_RECORD_DIR=%@", recordDir);
        if (!recording) {
            XCTFail(@"recorded %lu missing golden(s) into %@ - copy them into PlaceholderCorpus and re-run",
                    (unsigned long)recorded.count, recordDir);
        }
    }
}

@end
