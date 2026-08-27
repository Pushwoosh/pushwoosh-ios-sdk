#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWUniversalLinkResolver.h"

@interface PWUniversalLinkResolver (Test)
+ (NSDictionary *)parsedAASABody:(NSData *)data;
+ (PWUniversalLinkVerdict)verdictForFetchedAASA:(NSDictionary *)aasa noAASAPublished:(BOOL)noAASAPublished unparseableBody:(BOOL)unparseableBody url:(NSURL *)url bundleIdentifier:(NSString *)bundleIdentifier;
+ (BOOL)isAcceptableAASAResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error;
+ (BOOL)isDefinitiveNoAASAStatusCode:(NSInteger)statusCode;
+ (void)fetchAASAForHost:(NSString *)host completion:(void (^)(NSDictionary *aasa, BOOL noAASAPublished, BOOL unparseableBody))completion;
+ (void)downloadAASAFromURL:(NSURL *)url completion:(void (^)(NSData *data, NSError *error, NSInteger statusCode))completion;
+ (void)storeAASA:(NSDictionary *)aasa noAASAPublished:(BOOL)noAASAPublished unparseableBody:(BOOL)unparseableBody forHost:(NSString *)host date:(NSDate *)date;
+ (BOOL)cachedResultForHost:(NSString *)host now:(NSDate *)now aasa:(NSDictionary **)outAASA noAASAPublished:(BOOL *)outNoAASAPublished unparseableBody:(BOOL *)outUnparseableBody;
+ (void)clearCache;
@end

static NSData *PWAASAData(NSString *json) {
    return [json dataUsingEncoding:NSUTF8StringEncoding];
}

// Mirrors the production resolve chain: parsedAASABody: -> verdictForFetchedAASA:...
static PWUniversalLinkVerdict PWVerdictForBody(NSData *body, NSURL *url, NSString *bundleIdentifier) {
    NSDictionary *aasa = [PWUniversalLinkResolver parsedAASABody:body];
    return [PWUniversalLinkResolver verdictForFetchedAASA:aasa
                                          noAASAPublished:NO
                                          unparseableBody:(aasa == nil)
                                                      url:url
                                         bundleIdentifier:bundleIdentifier];
}

static NSURL *PWLink(NSString *urlString) {
    return [NSURL URLWithString:urlString];
}

@interface PWUniversalLinkResolverTest : XCTestCase
@end

@implementation PWUniversalLinkResolverTest

- (void)setUp {
    [super setUp];
    [PWUniversalLinkResolver clearCache];
}

- (void)tearDown {
    [PWUniversalLinkResolver clearCache];
    [super tearDown];
}

#pragma mark - Verdict matcher

/// Verifies that an appID with a matching bundle-id and no path rules yields Match by domain.
- (void)testAppIDSuffixMatchesByDomain {
    NSData *data = PWAASAData(@"{\"applinks\":{\"apps\":[],\"details\":[{\"appID\":\"TEAM123.com.example.app\"}]}}");
    PWUniversalLinkVerdict verdict = PWVerdictForBody(data, PWLink(@"https://example.com/anything"), @"com.example.app");
    XCTAssertEqual(verdict, PWUniversalLinkVerdictMatch);
}

/// Verifies that a matching entry inside an appIDs array yields Match.
- (void)testAppIDsArrayMatches {
    NSData *data = PWAASAData(@"{\"applinks\":{\"details\":[{\"appIDs\":[\"TEAM123.com.other\",\"TEAM123.com.example.app\"]}]}}");
    PWUniversalLinkVerdict verdict = PWVerdictForBody(data, PWLink(@"https://example.com/x"), @"com.example.app");
    XCTAssertEqual(verdict, PWUniversalLinkVerdictMatch);
}

/// Verifies that a foreign-appID-only AASA yields NoMatch.
- (void)testForeignAppIDYieldsNoMatch {
    NSData *data = PWAASAData(@"{\"applinks\":{\"details\":[{\"appID\":\"TEAM123.com.somebody.else\"}]}}");
    PWUniversalLinkVerdict verdict = PWVerdictForBody(data, PWLink(@"https://example.com/x"), @"com.example.app");
    XCTAssertEqual(verdict, PWUniversalLinkVerdictNoMatch);
}

/// Verifies that the bundle id must match the whole component after the team id, not merely be a suffix.
- (void)testAppIDBundleBoundaryRequired {
    NSData *data = PWAASAData(@"{\"applinks\":{\"details\":[{\"appID\":\"TEAM2.foo.com.example.app\"}]}}");
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/x"), @"com.example.app"), PWUniversalLinkVerdictNoMatch);
    NSData *noDot = PWAASAData(@"{\"applinks\":{\"details\":[{\"appID\":\"comexampleapp\"}]}}");
    XCTAssertEqual(PWVerdictForBody(noDot, PWLink(@"https://example.com/x"), @"com.example.app"), PWUniversalLinkVerdictNoMatch);
}

/// Verifies that the matching entry is found among multiple details entries.
- (void)testMultipleDetailsEntriesSecondMatches {
    NSData *data = PWAASAData(@"{\"applinks\":{\"details\":[{\"appID\":\"T.com.foreign\"},{\"appID\":\"T.com.example.app\",\"paths\":[\"/products/*\"]}]}}");
    PWUniversalLinkVerdict verdict = PWVerdictForBody(data, PWLink(@"https://example.com/products/42"), @"com.example.app");
    XCTAssertEqual(verdict, PWUniversalLinkVerdictMatch);
}

/// Verifies legacy paths * wildcard matching and non-matching paths.
- (void)testLegacyPathsWildcard {
    NSData *data = PWAASAData(@"{\"applinks\":{\"details\":[{\"appID\":\"T.com.example.app\",\"paths\":[\"/products/*\"]}]}}");
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/products/42"), @"com.example.app"), PWUniversalLinkVerdictMatch);
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/about"), @"com.example.app"), PWUniversalLinkVerdictNoMatch);
}

/// Verifies legacy paths ? single-character wildcard.
- (void)testLegacyPathsQuestionMarkWildcard {
    NSData *data = PWAASAData(@"{\"applinks\":{\"details\":[{\"appID\":\"T.com.example.app\",\"paths\":[\"/item/?\"]}]}}");
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/item/7"), @"com.example.app"), PWUniversalLinkVerdictMatch);
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/item/77"), @"com.example.app"), PWUniversalLinkVerdictNoMatch);
}

/// Verifies legacy NOT prefix excludes a path even when a later pattern would match.
- (void)testLegacyPathsNOTExcludes {
    NSData *data = PWAASAData(@"{\"applinks\":{\"details\":[{\"appID\":\"T.com.example.app\",\"paths\":[\"NOT /private/*\",\"*\"]}]}}");
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/private/x"), @"com.example.app"), PWUniversalLinkVerdictNoMatch);
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/public"), @"com.example.app"), PWUniversalLinkVerdictMatch);
}

/// Verifies components "/" pattern matching.
- (void)testComponentsSlashPattern {
    NSData *data = PWAASAData(@"{\"applinks\":{\"details\":[{\"appIDs\":[\"T.com.example.app\"],\"components\":[{\"/\":\"/buy/*\"}]}]}}");
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/buy/1"), @"com.example.app"), PWUniversalLinkVerdictMatch);
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/sell"), @"com.example.app"), PWUniversalLinkVerdictNoMatch);
}

/// Verifies components exclude:true rejects the path while a later catch-all still matches others.
- (void)testComponentsExclude {
    NSData *data = PWAASAData(@"{\"applinks\":{\"details\":[{\"appIDs\":[\"T.com.example.app\"],\"components\":[{\"/\":\"/help/*\",\"exclude\":true},{\"/\":\"*\"}]}]}}");
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/help/x"), @"com.example.app"), PWUniversalLinkVerdictNoMatch);
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/other"), @"com.example.app"), PWUniversalLinkVerdictMatch);
}

/// Verifies malformed exclude values (null, object, array) from remote AASA content do not crash and are treated as non-excluding.
- (void)testComponentsExcludeMalformedValuesDoNotCrash {
    NSData *data = PWAASAData(@"{\"applinks\":{\"details\":[{\"appIDs\":[\"T.com.example.app\"],\"components\":[{\"/\":\"/a/*\",\"exclude\":null},{\"/\":\"/b/*\",\"exclude\":{}},{\"/\":\"/c/*\",\"exclude\":[]}]}]}}");
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/a/1"), @"com.example.app"), PWUniversalLinkVerdictMatch);
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/b/1"), @"com.example.app"), PWUniversalLinkVerdictMatch);
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/c/1"), @"com.example.app"), PWUniversalLinkVerdictMatch);
}

/// Verifies that a malformed element inside components is skipped and later exclude rules still apply.
- (void)testComponentsMalformedElementDoesNotBypassExclude {
    NSData *data = PWAASAData(@"{\"applinks\":{\"details\":[{\"appIDs\":[\"T.com.example.app\"],\"components\":[42,{\"/\":\"/private/*\",\"exclude\":true},{\"/\":\"*\"}]}]}}");
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/private/x"), @"com.example.app"), PWUniversalLinkVerdictNoMatch);
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/other"), @"com.example.app"), PWUniversalLinkVerdictMatch);
}

/// Verifies that a malformed element inside legacy paths is skipped and later NOT rules still apply.
- (void)testLegacyPathsMalformedElementDoesNotBypassNOT {
    NSData *data = PWAASAData(@"{\"applinks\":{\"details\":[{\"appID\":\"T.com.example.app\",\"paths\":[\"NOT /admin/*\",42,\"NOT /private/*\",\"*\"]}]}}");
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/private/x"), @"com.example.app"), PWUniversalLinkVerdictNoMatch);
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/public"), @"com.example.app"), PWUniversalLinkVerdictMatch);
}

/// Verifies that a downloaded body that is not an AASA dictionary (catch-all HTML, broken JSON) is a definitive NoMatch.
- (void)testMalformedBodyYieldsNoMatch {
    XCTAssertEqual(PWVerdictForBody(PWAASAData(@"{not json at all"), PWLink(@"https://example.com/x"), @"com.example.app"), PWUniversalLinkVerdictNoMatch);
    XCTAssertEqual(PWVerdictForBody(PWAASAData(@"<!DOCTYPE html><html><body>SPA</body></html>"), PWLink(@"https://example.com/x"), @"com.example.app"), PWUniversalLinkVerdictNoMatch);
}

/// Verifies that a fragment-only exclude component excludes matching URLs and a catch-all still matches others.
- (void)testComponentsFragmentExcludeRuleApplies {
    NSData *data = PWAASAData(@"{\"applinks\":{\"details\":[{\"appIDs\":[\"T.com.example.app\"],\"components\":[{\"#\":\"no_universal_links\",\"exclude\":true},{\"/\":\"*\"}]}]}}");
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/page#no_universal_links"), @"com.example.app"), PWUniversalLinkVerdictNoMatch);
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/page"), @"com.example.app"), PWUniversalLinkVerdictMatch);
}

/// Verifies that a string query rule matches the URL query part.
- (void)testComponentsQueryRuleApplies {
    NSData *data = PWAASAData(@"{\"applinks\":{\"details\":[{\"appIDs\":[\"T.com.example.app\"],\"components\":[{\"?\":\"promo=*\"}]}]}}");
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/p?promo=1"), @"com.example.app"), PWUniversalLinkVerdictMatch);
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/p"), @"com.example.app"), PWUniversalLinkVerdictNoMatch);
}

/// Verifies that a '*' query rule matches a URL without a query part (SELF LIKE '*' accepts the empty string).
- (void)testComponentsWildcardQueryMatchesEmptyQuery {
    NSData *data = PWAASAData(@"{\"applinks\":{\"details\":[{\"appIDs\":[\"T.com.example.app\"],\"components\":[{\"/\":\"/x\",\"?\":\"*\"}]}]}}");
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/x"), @"com.example.app"), PWUniversalLinkVerdictMatch);
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/x?a=1"), @"com.example.app"), PWUniversalLinkVerdictMatch);
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/y"), @"com.example.app"), PWUniversalLinkVerdictNoMatch);
}

/// Verifies that a dictionary-form query part is ignored while the component's path rule still applies.
- (void)testComponentsDictQueryPartIgnoredButPathApplies {
    NSData *data = PWAASAData(@"{\"applinks\":{\"details\":[{\"appIDs\":[\"T.com.example.app\"],\"components\":[{\"/\":\"/products/*\",\"?\":{\"id\":\"?*\"}}]}]}}");
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/products/1"), @"com.example.app"), PWUniversalLinkVerdictMatch);
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/legal/terms"), @"com.example.app"), PWUniversalLinkVerdictNoMatch);
}

/// Verifies that a component with a dictionary-form query rule only is uninterpretable and skipped, falling back to match by domain.
- (void)testComponentsUninterpretableQueryDictIgnored {
    NSData *data = PWAASAData(@"{\"applinks\":{\"details\":[{\"appIDs\":[\"T.com.example.app\"],\"components\":[{\"?\":{\"promo\":\"1\"}}]}]}}");
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/anything"), @"com.example.app"), PWUniversalLinkVerdictMatch);
}

/// Verifies that an appID-matched entry with unparseable rule structure yields Match by domain.
- (void)testUnrecognizedRuleStructureMatchesByDomain {
    NSData *data = PWAASAData(@"{\"applinks\":{\"details\":[{\"appID\":\"T.com.example.app\",\"paths\":\"oops-not-an-array\"}]}}");
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/x"), @"com.example.app"), PWUniversalLinkVerdictMatch);
}

/// Verifies that legacy paths consisting only of malformed elements match by domain.
- (void)testLegacyPathsAllMalformedMatchByDomain {
    NSData *data = PWAASAData(@"{\"applinks\":{\"details\":[{\"appID\":\"T.com.example.app\",\"paths\":[42,{}]}]}}");
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/x"), @"com.example.app"), PWUniversalLinkVerdictMatch);
}

/// Verifies valid JSON without an applinks section yields NoMatch.
- (void)testJSONWithoutApplinksYieldsNoMatch {
    NSData *data = PWAASAData(@"{\"webcredentials\":{\"apps\":[\"T.com.example.app\"]}}");
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com/x"), @"com.example.app"), PWUniversalLinkVerdictNoMatch);
}

/// Verifies a URL with empty path is normalized to "/" for matching.
- (void)testEmptyPathNormalizedToSlash {
    NSData *data = PWAASAData(@"{\"applinks\":{\"details\":[{\"appID\":\"T.com.example.app\",\"paths\":[\"/\"]}]}}");
    XCTAssertEqual(PWVerdictForBody(data, PWLink(@"https://example.com"), @"com.example.app"), PWUniversalLinkVerdictMatch);
}

#pragma mark - Fetch-result cache

/// Verifies that a stored AASA dictionary is a cache hit within the 24h TTL and is returned intact.
- (void)testAASAResultCachedWithinTTL {
    NSDictionary *aasa = @{@"applinks": @{@"details": @[]}};
    [PWUniversalLinkResolver storeAASA:aasa noAASAPublished:NO unparseableBody:NO forHost:@"example.com" date:[NSDate date]];
    NSDictionary *cached = nil;
    BOOL noAASA = YES;
    BOOL unparseable = YES;
    XCTAssertTrue([PWUniversalLinkResolver cachedResultForHost:@"example.com" now:[NSDate date] aasa:&cached noAASAPublished:&noAASA unparseableBody:&unparseable]);
    XCTAssertEqualObjects(cached, aasa);
    XCTAssertFalse(noAASA);
    XCTAssertFalse(unparseable);
}

/// Verifies that a stored AASA result older than 24h is a cache miss.
- (void)testAASAResultExpiresAfterTTL {
    NSDate *past = [NSDate dateWithTimeIntervalSinceNow:-25.0 * 60.0 * 60.0];
    [PWUniversalLinkResolver storeAASA:@{@"applinks": @{}} noAASAPublished:NO unparseableBody:NO forHost:@"example.com" date:past];
    NSDictionary *cached = nil;
    BOOL noAASA = NO;
    BOOL unparseable = NO;
    XCTAssertFalse([PWUniversalLinkResolver cachedResultForHost:@"example.com" now:[NSDate date] aasa:&cached noAASAPublished:&noAASA unparseableBody:&unparseable]);
}

/// Verifies that a definitive no-AASA result is persisted to NSUserDefaults and survives the memory cache being cleared.
- (void)testNoAASAResultPersistedToDefaults {
    [PWUniversalLinkResolver storeAASA:nil noAASAPublished:YES unparseableBody:NO forHost:@"persisted.com" date:[NSDate date]];
    XCTAssertNotNil([[NSUserDefaults standardUserDefaults] dictionaryForKey:@"com.pushwoosh.universalLinkVerdict.persisted.com"]);
    NSDictionary *cached = nil;
    BOOL noAASA = NO;
    BOOL unparseable = NO;
    XCTAssertTrue([PWUniversalLinkResolver cachedResultForHost:@"persisted.com" now:[NSDate date] aasa:&cached noAASAPublished:&noAASA unparseableBody:&unparseable]);
    XCTAssertTrue(noAASA);
}

/// Verifies that a persisted AASA dictionary round-trips through NSUserDefaults as JSON data.
- (void)testAASADictionaryPersistedAndRestored {
    NSDictionary *aasa = @{@"applinks": @{@"details": @[@{@"appID": @"T.com.example.app"}]}};
    [PWUniversalLinkResolver storeAASA:aasa noAASAPublished:NO unparseableBody:NO forHost:@"roundtrip.com" date:[NSDate date]];
    NSDictionary *stored = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"com.pushwoosh.universalLinkVerdict.roundtrip.com"];
    XCTAssertNotNil(stored[@"body"]);
    NSDictionary *cached = nil;
    BOOL noAASA = NO;
    BOOL unparseable = NO;
    XCTAssertTrue([PWUniversalLinkResolver cachedResultForHost:@"roundtrip.com" now:[NSDate date] aasa:&cached noAASAPublished:&noAASA unparseableBody:&unparseable]);
    XCTAssertEqualObjects(cached, aasa);
}

/// Verifies that an unknown fetch result is a short-lived in-memory hit that is never written to NSUserDefaults.
- (void)testUnknownResultShortCachedInMemoryOnly {
    [PWUniversalLinkResolver storeAASA:nil noAASAPublished:NO unparseableBody:NO forHost:@"flaky.com" date:[NSDate date]];
    XCTAssertNil([[NSUserDefaults standardUserDefaults] objectForKey:@"com.pushwoosh.universalLinkVerdict.flaky.com"]);
    NSDictionary *cached = nil;
    BOOL noAASA = NO;
    BOOL unparseable = NO;
    XCTAssertTrue([PWUniversalLinkResolver cachedResultForHost:@"flaky.com" now:[NSDate date] aasa:&cached noAASAPublished:&noAASA unparseableBody:&unparseable]);
    XCTAssertNil(cached);
    XCTAssertFalse(noAASA);
    XCTAssertFalse(unparseable);
    XCTAssertFalse([PWUniversalLinkResolver cachedResultForHost:@"flaky.com" now:[NSDate dateWithTimeIntervalSinceNow:6.0 * 60.0] aasa:&cached noAASAPublished:&noAASA unparseableBody:&unparseable]);
}

/// Verifies that an unparseable-body result is a short-lived in-memory hit expiring after five minutes.
- (void)testUnparseableResultShortCachedInMemoryOnly {
    [PWUniversalLinkResolver storeAASA:nil noAASAPublished:NO unparseableBody:YES forHost:@"portal.com" date:[NSDate date]];
    XCTAssertNil([[NSUserDefaults standardUserDefaults] objectForKey:@"com.pushwoosh.universalLinkVerdict.portal.com"]);
    NSDictionary *cached = nil;
    BOOL noAASA = NO;
    BOOL unparseable = NO;
    XCTAssertTrue([PWUniversalLinkResolver cachedResultForHost:@"portal.com" now:[NSDate date] aasa:&cached noAASAPublished:&noAASA unparseableBody:&unparseable]);
    XCTAssertTrue(unparseable);
    XCTAssertFalse([PWUniversalLinkResolver cachedResultForHost:@"portal.com" now:[NSDate dateWithTimeIntervalSinceNow:6.0 * 60.0] aasa:&cached noAASAPublished:&noAASA unparseableBody:&unparseable]);
}

/// Verifies that a short-lived fetch result does not overwrite a fresh authoritative cache entry for the same host.
- (void)testShortLivedResultDoesNotDowngradeAuthoritativeEntry {
    NSDictionary *aasa = @{@"applinks": @{@"details": @[]}};
    [PWUniversalLinkResolver storeAASA:aasa noAASAPublished:NO unparseableBody:NO forHost:@"race.com" date:[NSDate date]];
    [PWUniversalLinkResolver storeAASA:nil noAASAPublished:NO unparseableBody:NO forHost:@"race.com" date:[NSDate date]];

    NSDictionary *cached = nil;
    BOOL noAASA = NO;
    BOOL unparseable = NO;
    XCTAssertTrue([PWUniversalLinkResolver cachedResultForHost:@"race.com" now:[NSDate date] aasa:&cached noAASAPublished:&noAASA unparseableBody:&unparseable]);
    XCTAssertEqualObjects(cached, aasa);
}

/// Verifies that a short-lived result still replaces an expired authoritative entry.
- (void)testShortLivedResultReplacesExpiredAuthoritativeEntry {
    NSDictionary *aasa = @{@"applinks": @{@"details": @[]}};
    NSDate *past = [NSDate dateWithTimeIntervalSinceNow:-25.0 * 60.0 * 60.0];
    [PWUniversalLinkResolver storeAASA:aasa noAASAPublished:NO unparseableBody:NO forHost:@"stale.com" date:past];
    [PWUniversalLinkResolver storeAASA:nil noAASAPublished:NO unparseableBody:NO forHost:@"stale.com" date:[NSDate date]];

    NSDictionary *cached = nil;
    BOOL noAASA = NO;
    BOOL unparseable = NO;
    XCTAssertTrue([PWUniversalLinkResolver cachedResultForHost:@"stale.com" now:[NSDate date] aasa:&cached noAASAPublished:&noAASA unparseableBody:&unparseable]);
    XCTAssertNil(cached);
    XCTAssertFalse(noAASA);
    XCTAssertFalse(unparseable);
}

#pragma mark - Resolve flow

/// Verifies that resolveURL yields Unknown when the AASA download fails.
- (void)testResolveURLUnknownWhenFetchFails {
    id resolverMock = OCMClassMock([PWUniversalLinkResolver class]);
    OCMStub(ClassMethod([resolverMock fetchAASAForHost:[OCMArg any] completion:[OCMArg any]])).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained void (^completion)(NSDictionary *, BOOL, BOOL) = nil;
        [invocation getArgument:&completion atIndex:3];
        completion(nil, NO, NO);
    });

    XCTestExpectation *expectation = [self expectationWithDescription:@"resolved"];
    [PWUniversalLinkResolver resolveURL:[NSURL URLWithString:@"https://dead.example.com/x"] completion:^(PWUniversalLinkVerdict verdict) {
        XCTAssertEqual(verdict, PWUniversalLinkVerdictUnknown);
        XCTAssertTrue([NSThread isMainThread]);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:5 handler:nil];
    [resolverMock stopMocking];
}

/// Verifies that a second resolve for the same host is served from cache without a network fetch.
- (void)testSecondResolveForSameHostSkipsFetch {
    __block NSInteger fetchCount = 0;
    NSString *appID = [NSString stringWithFormat:@"T.%@", [NSBundle mainBundle].bundleIdentifier];
    NSDictionary *aasa = @{@"applinks": @{@"details": @[@{@"appID": appID}]}};
    id resolverMock = OCMClassMock([PWUniversalLinkResolver class]);
    OCMStub(ClassMethod([resolverMock fetchAASAForHost:[OCMArg any] completion:[OCMArg any]])).andDo(^(NSInvocation *invocation) {
        fetchCount++;
        __unsafe_unretained void (^completion)(NSDictionary *, BOOL, BOOL) = nil;
        [invocation getArgument:&completion atIndex:3];
        completion(aasa, NO, NO);
    });

    XCTestExpectation *first = [self expectationWithDescription:@"first"];
    [PWUniversalLinkResolver resolveURL:[NSURL URLWithString:@"https://cached.example.com/a"] completion:^(PWUniversalLinkVerdict verdict) {
        XCTAssertEqual(verdict, PWUniversalLinkVerdictMatch);
        [first fulfill];
    }];
    [self waitForExpectationsWithTimeout:5 handler:nil];

    XCTestExpectation *second = [self expectationWithDescription:@"second"];
    [PWUniversalLinkResolver resolveURL:[NSURL URLWithString:@"https://cached.example.com/b"] completion:^(PWUniversalLinkVerdict verdict) {
        XCTAssertEqual(verdict, PWUniversalLinkVerdictMatch);
        [second fulfill];
    }];
    [self waitForExpectationsWithTimeout:5 handler:nil];

    XCTAssertEqual(fetchCount, 1);
    [resolverMock stopMocking];
}

/// Verifies that path rules are re-evaluated per URL from the cached AASA: a NoMatch on one path must not poison another path of the same host.
- (void)testPerPathVerdictsReevaluatedFromCachedAASA {
    __block NSInteger fetchCount = 0;
    NSString *appID = [NSString stringWithFormat:@"T.%@", [NSBundle mainBundle].bundleIdentifier];
    NSDictionary *aasa = @{@"applinks": @{@"details": @[@{@"appID": appID, @"paths": @[@"/deeplink/*"]}]}};
    id resolverMock = OCMClassMock([PWUniversalLinkResolver class]);
    OCMStub(ClassMethod([resolverMock fetchAASAForHost:[OCMArg any] completion:[OCMArg any]])).andDo(^(NSInvocation *invocation) {
        fetchCount++;
        __unsafe_unretained void (^completion)(NSDictionary *, BOOL, BOOL) = nil;
        [invocation getArgument:&completion atIndex:3];
        completion(aasa, NO, NO);
    });

    XCTestExpectation *first = [self expectationWithDescription:@"other path"];
    [PWUniversalLinkResolver resolveURL:[NSURL URLWithString:@"https://host.example.com/other"] completion:^(PWUniversalLinkVerdict verdict) {
        XCTAssertEqual(verdict, PWUniversalLinkVerdictNoMatch);
        [first fulfill];
    }];
    [self waitForExpectationsWithTimeout:5 handler:nil];

    XCTestExpectation *second = [self expectationWithDescription:@"deeplink path"];
    [PWUniversalLinkResolver resolveURL:[NSURL URLWithString:@"https://host.example.com/deeplink/foo"] completion:^(PWUniversalLinkVerdict verdict) {
        XCTAssertEqual(verdict, PWUniversalLinkVerdictMatch);
        [second fulfill];
    }];
    [self waitForExpectationsWithTimeout:5 handler:nil];

    XCTAssertEqual(fetchCount, 1);
    [resolverMock stopMocking];
}

/// Verifies that a host publishing no AASA (404 on both locations) resolves to NoMatch, not Unknown.
- (void)testResolveNoAASAPublishedYieldsNoMatch {
    id resolverMock = OCMClassMock([PWUniversalLinkResolver class]);
    OCMStub(ClassMethod([resolverMock fetchAASAForHost:[OCMArg any] completion:[OCMArg any]])).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained void (^completion)(NSDictionary *, BOOL, BOOL) = nil;
        [invocation getArgument:&completion atIndex:3];
        completion(nil, YES, NO);
    });

    XCTestExpectation *expectation = [self expectationWithDescription:@"resolved"];
    [PWUniversalLinkResolver resolveURL:[NSURL URLWithString:@"https://news.example.com/article"] completion:^(PWUniversalLinkVerdict verdict) {
        XCTAssertEqual(verdict, PWUniversalLinkVerdictNoMatch);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:5 handler:nil];
    [resolverMock stopMocking];
}

/// Verifies end-to-end that a 200 HTML catch-all resolves to NoMatch but is never persisted (captive portal must not poison the cache for 24h).
- (void)testResolveHtmlCatchAllYieldsTransientNoMatch {
    id resolverMock = OCMClassMock([PWUniversalLinkResolver class]);
    OCMStub(ClassMethod([resolverMock fetchAASAForHost:[OCMArg any] completion:[OCMArg any]])).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained void (^completion)(NSDictionary *, BOOL, BOOL) = nil;
        [invocation getArgument:&completion atIndex:3];
        completion(nil, NO, YES);
    });

    XCTestExpectation *expectation = [self expectationWithDescription:@"resolved"];
    [PWUniversalLinkResolver resolveURL:[NSURL URLWithString:@"https://spa.example.com/page"] completion:^(PWUniversalLinkVerdict verdict) {
        XCTAssertEqual(verdict, PWUniversalLinkVerdictNoMatch);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:5 handler:nil];

    XCTAssertNil([[NSUserDefaults standardUserDefaults] objectForKey:@"com.pushwoosh.universalLinkVerdict.spa.example.com"]);
    [resolverMock stopMocking];
}

/// Verifies that a URL without a host resolves to Unknown.
- (void)testResolveURLWithoutHostYieldsUnknown {
    XCTestExpectation *expectation = [self expectationWithDescription:@"resolved"];
    [PWUniversalLinkResolver resolveURL:[NSURL URLWithString:@"https:///nohost"] completion:^(PWUniversalLinkVerdict verdict) {
        XCTAssertEqual(verdict, PWUniversalLinkVerdictUnknown);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

#pragma mark - Fetch

/// Verifies that both AASA locations are requested and 404 on both is a definitive no-AASA outcome.
- (void)testFetch404OnBothLocationsIsDefinitive {
    NSMutableArray<NSString *> *requestedURLs = [NSMutableArray array];
    id resolverMock = OCMClassMock([PWUniversalLinkResolver class]);
    OCMStub(ClassMethod([resolverMock downloadAASAFromURL:[OCMArg any] completion:[OCMArg any]])).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSURL *url = nil;
        [invocation getArgument:&url atIndex:2];
        @synchronized (requestedURLs) {
            [requestedURLs addObject:url.absoluteString];
        }
        __unsafe_unretained void (^completion)(NSData *, NSError *, NSInteger) = nil;
        [invocation getArgument:&completion atIndex:3];
        completion(nil, nil, 404);
    });

    XCTestExpectation *expectation = [self expectationWithDescription:@"fetched"];
    [PWUniversalLinkResolver fetchAASAForHost:@"example.com" completion:^(NSDictionary *aasa, BOOL noAASAPublished, BOOL unparseableBody) {
        XCTAssertNil(aasa);
        XCTAssertTrue(noAASAPublished);
        XCTAssertFalse(unparseableBody);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];

    XCTAssertEqual(requestedURLs.count, 2);
    XCTAssertTrue([requestedURLs containsObject:@"https://example.com/.well-known/apple-app-site-association"]);
    XCTAssertTrue([requestedURLs containsObject:@"https://example.com/apple-app-site-association"]);
    [resolverMock stopMocking];
}

/// Verifies that a 404 on .well-known with a server error on root is not treated as a definitive missing AASA.
- (void)testFetch404ThenServerErrorIsNotDefinitive {
    id resolverMock = OCMClassMock([PWUniversalLinkResolver class]);
    OCMStub(ClassMethod([resolverMock downloadAASAFromURL:[OCMArg any] completion:[OCMArg any]])).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSURL *url = nil;
        [invocation getArgument:&url atIndex:2];
        BOOL isWellKnown = [url.absoluteString containsString:@".well-known"];
        __unsafe_unretained void (^completion)(NSData *, NSError *, NSInteger) = nil;
        [invocation getArgument:&completion atIndex:3];
        completion(nil, nil, isWellKnown ? 404 : 500);
    });

    XCTestExpectation *expectation = [self expectationWithDescription:@"fetched"];
    [PWUniversalLinkResolver fetchAASAForHost:@"example.com" completion:^(NSDictionary *aasa, BOOL noAASAPublished, BOOL unparseableBody) {
        XCTAssertNil(aasa);
        XCTAssertFalse(noAASAPublished);
        XCTAssertFalse(unparseableBody);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    [resolverMock stopMocking];
}

/// Verifies that network-level errors on both locations yield the unknown outcome (no false definitive signals).
- (void)testFetchNetworkErrorsOnBothLocationsYieldUnknown {
    NSError *timeoutError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    id resolverMock = OCMClassMock([PWUniversalLinkResolver class]);
    OCMStub(ClassMethod([resolverMock downloadAASAFromURL:[OCMArg any] completion:[OCMArg any]])).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained void (^completion)(NSData *, NSError *, NSInteger) = nil;
        [invocation getArgument:&completion atIndex:3];
        completion(nil, timeoutError, 0);
    });

    XCTestExpectation *expectation = [self expectationWithDescription:@"fetched"];
    [PWUniversalLinkResolver fetchAASAForHost:@"example.com" completion:^(NSDictionary *aasa, BOOL noAASAPublished, BOOL unparseableBody) {
        XCTAssertNil(aasa);
        XCTAssertFalse(noAASAPublished);
        XCTAssertFalse(unparseableBody);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    [resolverMock stopMocking];
}

/// Verifies that an unparseable .well-known body loses to a valid AASA from the root location.
- (void)testFetchPrefersValidRootAASAOverUnparseableWellKnown {
    NSData *html = [@"<!DOCTYPE html>" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *aasa = [@"{\"applinks\":{\"details\":[]}}" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *expectedAASA = @{@"applinks": @{@"details": @[]}};
    id resolverMock = OCMClassMock([PWUniversalLinkResolver class]);
    OCMStub(ClassMethod([resolverMock downloadAASAFromURL:[OCMArg any] completion:[OCMArg any]])).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSURL *url = nil;
        [invocation getArgument:&url atIndex:2];
        BOOL isWellKnown = [url.absoluteString containsString:@".well-known"];
        __unsafe_unretained void (^completion)(NSData *, NSError *, NSInteger) = nil;
        [invocation getArgument:&completion atIndex:3];
        completion(isWellKnown ? html : aasa, nil, 200);
    });

    XCTestExpectation *expectation = [self expectationWithDescription:@"fetched"];
    [PWUniversalLinkResolver fetchAASAForHost:@"example.com" completion:^(NSDictionary *aasaResult, BOOL noAASAPublished, BOOL unparseableBody) {
        XCTAssertEqualObjects(aasaResult, expectedAASA);
        XCTAssertFalse(noAASAPublished);
        XCTAssertFalse(unparseableBody);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    [resolverMock stopMocking];
}

/// Verifies that when both locations return unparseable bodies the outcome is flagged unparseable (transient NoMatch downstream), not a definitive miss.
- (void)testFetchUnparseableBodiesOnBothLocationsFlagged {
    NSData *html = [@"<!DOCTYPE html>" dataUsingEncoding:NSUTF8StringEncoding];
    id resolverMock = OCMClassMock([PWUniversalLinkResolver class]);
    OCMStub(ClassMethod([resolverMock downloadAASAFromURL:[OCMArg any] completion:[OCMArg any]])).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained void (^completion)(NSData *, NSError *, NSInteger) = nil;
        [invocation getArgument:&completion atIndex:3];
        completion(html, nil, 200);
    });

    XCTestExpectation *expectation = [self expectationWithDescription:@"fetched"];
    [PWUniversalLinkResolver fetchAASAForHost:@"example.com" completion:^(NSDictionary *aasaResult, BOOL noAASAPublished, BOOL unparseableBody) {
        XCTAssertNil(aasaResult);
        XCTAssertFalse(noAASAPublished);
        XCTAssertTrue(unparseableBody);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    [resolverMock stopMocking];
}

/// Verifies the response guard: errors, non-200 statuses and oversized bodies are rejected.
- (void)testIsAcceptableAASAResponseGuards {
    NSURL *url = [NSURL URLWithString:@"https://example.com/.well-known/apple-app-site-association"];
    NSHTTPURLResponse *ok = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:nil];
    NSHTTPURLResponse *notFound = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:404 HTTPVersion:@"HTTP/1.1" headerFields:nil];
    NSData *small = [@"{}" dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *huge = [NSMutableData dataWithLength:2 * 1024 * 1024 + 1];
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];

    XCTAssertTrue([PWUniversalLinkResolver isAcceptableAASAResponse:ok data:small error:nil]);
    XCTAssertFalse([PWUniversalLinkResolver isAcceptableAASAResponse:ok data:small error:error]);
    XCTAssertFalse([PWUniversalLinkResolver isAcceptableAASAResponse:notFound data:small error:nil]);
    XCTAssertFalse([PWUniversalLinkResolver isAcceptableAASAResponse:ok data:huge error:nil]);
    XCTAssertFalse([PWUniversalLinkResolver isAcceptableAASAResponse:ok data:nil error:nil]);
}

#pragma mark - Fetch outcome classification

/// Verifies which statuses settle the question and which leave it open.
///
/// Apple wants a 200 and does not follow redirects, so 3xx and 4xx are answers about the domain;
/// 5xx and "no response at all" are outages and must stay open, or a momentary server fault would
/// be cached as a lasting verdict.
- (void)testDefinitiveNoAASAStatusCodes {
    XCTAssertTrue([PWUniversalLinkResolver isDefinitiveNoAASAStatusCode:301]);
    XCTAssertTrue([PWUniversalLinkResolver isDefinitiveNoAASAStatusCode:302]);
    XCTAssertTrue([PWUniversalLinkResolver isDefinitiveNoAASAStatusCode:308]);
    XCTAssertTrue([PWUniversalLinkResolver isDefinitiveNoAASAStatusCode:403]);
    XCTAssertTrue([PWUniversalLinkResolver isDefinitiveNoAASAStatusCode:404]);
    XCTAssertTrue([PWUniversalLinkResolver isDefinitiveNoAASAStatusCode:410]);
    XCTAssertTrue([PWUniversalLinkResolver isDefinitiveNoAASAStatusCode:204]);

    XCTAssertFalse([PWUniversalLinkResolver isDefinitiveNoAASAStatusCode:500]);
    XCTAssertFalse([PWUniversalLinkResolver isDefinitiveNoAASAStatusCode:502]);
    XCTAssertFalse([PWUniversalLinkResolver isDefinitiveNoAASAStatusCode:503]);
    XCTAssertFalse([PWUniversalLinkResolver isDefinitiveNoAASAStatusCode:0]);
}

/// Verifies the pushwoosh.com case end to end: an apex that 301s to www resolves to NoMatch.
///
/// Before this, a redirect fell outside the 404/410 pair the resolver recognized, so the verdict
/// was Unknown and the link was handed to the app on a guess — where a SwiftUI router that did not
/// know the URL dropped it silently.
- (void)testRedirectedAASALocationResolvesToNoMatch {
    id resolverMock = OCMClassMock([PWUniversalLinkResolver class]);
    OCMStub(ClassMethod([resolverMock downloadAASAFromURL:[OCMArg any] completion:[OCMArg any]])).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained void (^completion)(NSData *, NSError *, NSInteger) = nil;
        [invocation getArgument:&completion atIndex:3];
        completion(nil, nil, 301);
    });

    XCTestExpectation *expectation = [self expectationWithDescription:@"resolved"];
    [PWUniversalLinkResolver resolveURL:PWLink(@"https://redirecting.example.com/x") completion:^(PWUniversalLinkVerdict verdict) {
        XCTAssertEqual(verdict, PWUniversalLinkVerdictNoMatch);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:5 handler:nil];
    [resolverMock stopMocking];
}

/// Verifies that a refused location (403 from a CDN or WAF) also resolves to NoMatch.
- (void)testForbiddenAASALocationResolvesToNoMatch {
    id resolverMock = OCMClassMock([PWUniversalLinkResolver class]);
    OCMStub(ClassMethod([resolverMock downloadAASAFromURL:[OCMArg any] completion:[OCMArg any]])).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained void (^completion)(NSData *, NSError *, NSInteger) = nil;
        [invocation getArgument:&completion atIndex:3];
        completion(nil, nil, 403);
    });

    XCTestExpectation *expectation = [self expectationWithDescription:@"resolved"];
    [PWUniversalLinkResolver resolveURL:PWLink(@"https://refusing.example.com/x") completion:^(PWUniversalLinkVerdict verdict) {
        XCTAssertEqual(verdict, PWUniversalLinkVerdictNoMatch);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:5 handler:nil];
    [resolverMock stopMocking];
}

/// Verifies that a broken server (5xx) stays Unknown rather than being recorded as NoMatch.
- (void)testServerErrorResolvesToUnknown {
    id resolverMock = OCMClassMock([PWUniversalLinkResolver class]);
    OCMStub(ClassMethod([resolverMock downloadAASAFromURL:[OCMArg any] completion:[OCMArg any]])).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained void (^completion)(NSData *, NSError *, NSInteger) = nil;
        [invocation getArgument:&completion atIndex:3];
        completion(nil, nil, 503);
    });

    XCTestExpectation *expectation = [self expectationWithDescription:@"resolved"];
    [PWUniversalLinkResolver resolveURL:PWLink(@"https://unstable.example.com/x") completion:^(PWUniversalLinkVerdict verdict) {
        XCTAssertEqual(verdict, PWUniversalLinkVerdictUnknown);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:5 handler:nil];
    [resolverMock stopMocking];
}

/// Verifies that one definitive location and one unreachable location still leave the verdict open.
///
/// Both locations must answer before the domain can be ruled out: a 404 on `.well-known` says
/// nothing about the root location that timed out.
- (void)testDefinitiveAndUnreachableLocationsResolveToUnknown {
    __block NSInteger call = 0;
    id resolverMock = OCMClassMock([PWUniversalLinkResolver class]);
    OCMStub(ClassMethod([resolverMock downloadAASAFromURL:[OCMArg any] completion:[OCMArg any]])).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained void (^completion)(NSData *, NSError *, NSInteger) = nil;
        [invocation getArgument:&completion atIndex:3];
        NSError *timeout = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
        BOOL first = (++call == 1);
        completion(nil, first ? nil : timeout, first ? 404 : 0);
    });

    XCTestExpectation *expectation = [self expectationWithDescription:@"resolved"];
    [PWUniversalLinkResolver resolveURL:PWLink(@"https://half.example.com/x") completion:^(PWUniversalLinkVerdict verdict) {
        XCTAssertEqual(verdict, PWUniversalLinkVerdictUnknown);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:5 handler:nil];
    [resolverMock stopMocking];
}

@end
