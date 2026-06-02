#import <XCTest/XCTest.h>
#import <objc/runtime.h>

#import "PWVersionTracking.h"

static NSString *gFakeCurrentVersion = nil;
static NSString *gFakeCurrentBuild = nil;

static NSString *PWVT_currentVersion(id self, SEL _cmd) {
    return gFakeCurrentVersion;
}

static NSString *PWVT_currentBuild(id self, SEL _cmd) {
    return gFakeCurrentBuild;
}

@interface PWVersionTrackingTest : XCTestCase

@property (nonatomic) IMP originalCurrentVersionIMP;
@property (nonatomic) IMP originalCurrentBuildIMP;
@property (nonatomic, copy) id originalVersionTrail;

@end

@implementation PWVersionTrackingTest

- (void)setUp {
    [super setUp];

    _originalVersionTrail = [[[NSUserDefaults standardUserDefaults] objectForKey:@"kPWVersionTrail"] copy];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"kPWVersionTrail"];

    Method currentVersionMethod = class_getClassMethod([PWVersionTracking class], @selector(currentVersion));
    _originalCurrentVersionIMP = method_setImplementation(currentVersionMethod, (IMP)PWVT_currentVersion);

    Method currentBuildMethod = class_getClassMethod([PWVersionTracking class], @selector(currentBuild));
    _originalCurrentBuildIMP = method_setImplementation(currentBuildMethod, (IMP)PWVT_currentBuild);

    gFakeCurrentVersion = @"1.0";
    gFakeCurrentBuild = @"100";

    [PWVersionTracking reset];
}

- (void)tearDown {
    Method currentVersionMethod = class_getClassMethod([PWVersionTracking class], @selector(currentVersion));
    method_setImplementation(currentVersionMethod, _originalCurrentVersionIMP);

    Method currentBuildMethod = class_getClassMethod([PWVersionTracking class], @selector(currentBuild));
    method_setImplementation(currentBuildMethod, _originalCurrentBuildIMP);

    if (_originalVersionTrail) {
        [[NSUserDefaults standardUserDefaults] setObject:_originalVersionTrail forKey:@"kPWVersionTrail"];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"kPWVersionTrail"];
    }
    [PWVersionTracking reset];

    [super tearDown];
}

#pragma mark - Helper

- (void)setFakeVersion:(NSString *)version build:(NSString *)build {
    gFakeCurrentVersion = version;
    gFakeCurrentBuild = build;
}

#pragma mark - reset

/// Verifies that reset clears the version trail in NSUserDefaults and sets the first-launch flags.
- (void)testReset_clearsStateAndFlagsFirstLaunch {
    [PWVersionTracking reset];

    XCTAssertNil([[NSUserDefaults standardUserDefaults] objectForKey:@"kPWVersionTrail"]);
    XCTAssertTrue([PWVersionTracking isFirstLaunchEver]);
    XCTAssertTrue([PWVersionTracking isFirstLaunchForVersion]);
    XCTAssertTrue([PWVersionTracking isFirstLaunchForBuild]);
}

#pragma mark - track on a clean install

/// Verifies that the very first track call sets isFirstLaunchEver/forVersion/forBuild=YES and persists the trail.
- (void)testTrack_firstLaunchEver_flagsAllFirstAndPersistsTrail {
    [PWVersionTracking track];

    XCTAssertTrue([PWVersionTracking isFirstLaunchEver]);
    XCTAssertTrue([PWVersionTracking isFirstLaunchForVersion]);
    XCTAssertTrue([PWVersionTracking isFirstLaunchForBuild]);
    XCTAssertNotNil([[NSUserDefaults standardUserDefaults] objectForKey:@"kPWVersionTrail"]);
    XCTAssertEqualObjects([PWVersionTracking versionHistory], @[@"1.0"]);
    XCTAssertEqualObjects([PWVersionTracking buildHistory], @[@"100"]);
}

#pragma mark - track on repeat launch

/// Verifies that calling track a second time with the same version reports isFirstLaunchEver=NO and isFirstLaunchForVersion/Build=NO.
- (void)testTrack_sameVersionTwice_secondLaunchAllNo {
    [PWVersionTracking track];

    [PWVersionTracking track];

    XCTAssertFalse([PWVersionTracking isFirstLaunchEver]);
    XCTAssertFalse([PWVersionTracking isFirstLaunchForVersion]);
    XCTAssertFalse([PWVersionTracking isFirstLaunchForBuild]);
    XCTAssertEqualObjects([PWVersionTracking versionHistory], @[@"1.0"]);
}

#pragma mark - track on app update (new version)

/// Verifies that an app update (new version, new build) flips isFirstLaunchEver to NO but isFirstLaunchForVersion/Build to YES.
- (void)testTrack_versionUpdate_firstLaunchForVersionYesEverNo {
    [PWVersionTracking track];

    [self setFakeVersion:@"1.1" build:@"110"];
    [PWVersionTracking track];

    XCTAssertFalse([PWVersionTracking isFirstLaunchEver]);
    XCTAssertTrue([PWVersionTracking isFirstLaunchForVersion]);
    XCTAssertTrue([PWVersionTracking isFirstLaunchForBuild]);
    XCTAssertEqualObjects([PWVersionTracking versionHistory], (@[@"1.0", @"1.1"]));
    XCTAssertEqualObjects([PWVersionTracking buildHistory], (@[@"100", @"110"]));
}

/// Verifies that bumping only the build number (same version) flips isFirstLaunchForBuild=YES but isFirstLaunchForVersion=NO.
- (void)testTrack_buildUpdateSameVersion_firstLaunchForBuildYesForVersionNo {
    [PWVersionTracking track];

    [self setFakeVersion:@"1.0" build:@"101"];
    [PWVersionTracking track];

    XCTAssertFalse([PWVersionTracking isFirstLaunchEver]);
    XCTAssertFalse([PWVersionTracking isFirstLaunchForVersion]);
    XCTAssertTrue([PWVersionTracking isFirstLaunchForBuild]);
    XCTAssertEqualObjects([PWVersionTracking versionHistory], @[@"1.0"]);
    XCTAssertEqualObjects([PWVersionTracking buildHistory], (@[@"100", @"101"]));
}

#pragma mark - previous / firstInstalled

/// Verifies that previousVersion is nil immediately after the first install.
- (void)testPreviousVersion_afterFirstInstallOnly_isNil {
    [PWVersionTracking track];

    XCTAssertNil([PWVersionTracking previousVersion]);
    XCTAssertNil([PWVersionTracking previousBuild]);
}

/// Verifies that previousVersion returns the second-most-recent version after multiple updates.
- (void)testPreviousVersion_afterMultipleUpdates_returnsSecondToLast {
    [PWVersionTracking track];
    [self setFakeVersion:@"1.1" build:@"110"];
    [PWVersionTracking track];
    [self setFakeVersion:@"1.2" build:@"120"];
    [PWVersionTracking track];

    XCTAssertEqualObjects([PWVersionTracking previousVersion], @"1.1");
    XCTAssertEqualObjects([PWVersionTracking previousBuild], @"110");
}

/// Verifies that firstInstalledVersion returns the very first version ever installed.
- (void)testFirstInstalledVersion_returnsFirstEver {
    [PWVersionTracking track];
    [self setFakeVersion:@"1.1" build:@"110"];
    [PWVersionTracking track];
    [self setFakeVersion:@"1.2" build:@"120"];
    [PWVersionTracking track];

    XCTAssertEqualObjects([PWVersionTracking firstInstalledVersion], @"1.0");
    XCTAssertEqualObjects([PWVersionTracking firstInstalledBuild], @"100");
}

#pragma mark - isFirstLaunchForVersion: matching

/// Verifies that isFirstLaunchForVersion: returns YES only when the supplied version equals currentVersion AND it is the first launch for that version.
- (void)testIsFirstLaunchForVersionWithArg_onlyTrueForCurrentVersionOnFirstLaunch {
    [PWVersionTracking track];

    XCTAssertTrue([PWVersionTracking isFirstLaunchForVersion:@"1.0"]);
    XCTAssertFalse([PWVersionTracking isFirstLaunchForVersion:@"9.9"]);

    [PWVersionTracking track];
    XCTAssertFalse([PWVersionTracking isFirstLaunchForVersion:@"1.0"]);
}

/// Verifies that isFirstLaunchForBuild: returns YES only when the supplied build equals currentBuild AND it is the first launch for that build.
- (void)testIsFirstLaunchForBuildWithArg_onlyTrueForCurrentBuildOnFirstLaunch {
    [PWVersionTracking track];

    XCTAssertTrue([PWVersionTracking isFirstLaunchForBuild:@"100"]);
    XCTAssertFalse([PWVersionTracking isFirstLaunchForBuild:@"999"]);
}

#pragma mark - callBlockOnFirstLaunchOf...

/// Verifies that callBlockOnFirstLaunchOfVersion invokes the block when version matches AND it is the first launch.
- (void)testCallBlockOnFirstLaunchOfVersion_matchingVersionFirstLaunch_invokesBlock {
    [PWVersionTracking track];
    __block BOOL called = NO;

    [PWVersionTracking callBlockOnFirstLaunchOfVersion:@"1.0" block:^{
        called = YES;
    }];

    XCTAssertTrue(called);
}

/// Verifies that callBlockOnFirstLaunchOfVersion does NOT invoke the block when the version does not match currentVersion.
- (void)testCallBlockOnFirstLaunchOfVersion_versionMismatch_doesNotInvokeBlock {
    [PWVersionTracking track];
    __block BOOL called = NO;

    [PWVersionTracking callBlockOnFirstLaunchOfVersion:@"9.9" block:^{
        called = YES;
    }];

    XCTAssertFalse(called);
}

/// Verifies that callBlockOnFirstLaunchOfVersion does NOT invoke the block on the second launch of the same version.
- (void)testCallBlockOnFirstLaunchOfVersion_secondLaunch_doesNotInvokeBlock {
    [PWVersionTracking track];
    [PWVersionTracking track];
    __block BOOL called = NO;

    [PWVersionTracking callBlockOnFirstLaunchOfVersion:@"1.0" block:^{
        called = YES;
    }];

    XCTAssertFalse(called);
}

/// Verifies that callBlockOnFirstLaunchOfVersion with nil block is a safe no-op.
- (void)testCallBlockOnFirstLaunchOfVersion_nilBlock_doesNotCrash {
    [PWVersionTracking track];

    XCTAssertNoThrow([PWVersionTracking callBlockOnFirstLaunchOfVersion:@"1.0" block:nil]);
}

@end
