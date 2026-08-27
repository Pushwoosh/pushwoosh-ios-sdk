//
//  PWUniversalLinkResolver.m
//  PushwooshCore
//
//  Created by André Kis on 21.08.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import "PWUniversalLinkResolver.h"
#import <PushwooshCore/PushwooshLog.h>

static NSString * const kPWAASAVerdictCacheKeyPrefix = @"com.pushwoosh.universalLinkVerdict.";
static NSTimeInterval const kPWAASAVerdictTTL = 24.0 * 60.0 * 60.0;
static NSTimeInterval const kPWAASAUnknownTTL = 5.0 * 60.0;
static NSUInteger const kPWAASAMaxSize = 2 * 1024 * 1024;
static NSTimeInterval const kPWAASATimeout = 5.0;

@interface PWAASASessionDelegate : NSObject <NSURLSessionDataDelegate>

- (void)registerCompletion:(void (^)(NSData *, NSURLResponse *, NSError *))completion forTask:(NSURLSessionTask *)task;

@end

@implementation PWAASASessionDelegate {
    NSMutableDictionary<NSNumber *, NSMutableData *> *_bodies;
    NSMutableDictionary<NSNumber *, void (^)(NSData *, NSURLResponse *, NSError *)> *_completions;
}

- (instancetype)init {
    if (self = [super init]) {
        _bodies = [NSMutableDictionary dictionary];
        _completions = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)registerCompletion:(void (^)(NSData *, NSURLResponse *, NSError *))completion forTask:(NSURLSessionTask *)task {
    @synchronized (self) {
        _completions[@(task.taskIdentifier)] = [completion copy];
        _bodies[@(task.taskIdentifier)] = [NSMutableData data];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler {
    completionHandler(nil);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    BOOL oversized = NO;
    @synchronized (self) {
        NSMutableData *body = _bodies[@(dataTask.taskIdentifier)];
        [body appendData:data];
        oversized = body.length > kPWAASAMaxSize;
    }
    if (oversized) {
        [dataTask cancel];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    void (^completion)(NSData *, NSURLResponse *, NSError *) = nil;
    NSData *body = nil;
    @synchronized (self) {
        NSNumber *key = @(task.taskIdentifier);
        completion = _completions[key];
        body = _bodies[key];
        [_completions removeObjectForKey:key];
        [_bodies removeObjectForKey:key];
    }
    if (completion) {
        completion(body, task.response, error);
    }
}

@end

@implementation PWUniversalLinkResolver

+ (void)resolveURL:(NSURL *)url completion:(void (^)(PWUniversalLinkVerdict))completion {
    NSString *host = url.host.lowercaseString;
    NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
    if (host.length == 0 || bundleIdentifier.length == 0) {
        [self completeOnMain:completion verdict:PWUniversalLinkVerdictUnknown];
        return;
    }

    NSDictionary *cachedAASA = nil;
    BOOL cachedNoAASA = NO;
    BOOL cachedUnparseable = NO;
    if ([self cachedResultForHost:host now:[NSDate date] aasa:&cachedAASA noAASAPublished:&cachedNoAASA unparseableBody:&cachedUnparseable]) {
        PWUniversalLinkVerdict verdict = [self verdictForFetchedAASA:cachedAASA noAASAPublished:cachedNoAASA unparseableBody:cachedUnparseable url:url bundleIdentifier:bundleIdentifier];
        [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:[NSString stringWithFormat:@"AASA verdict for %@ (cached): %@", host, [self stringForVerdict:verdict]]];
        [self completeOnMain:completion verdict:verdict];
        return;
    }

    [self fetchAASAForHost:host completion:^(NSDictionary *aasa, BOOL noAASAPublished, BOOL unparseableBody) {
        [self storeAASA:aasa noAASAPublished:noAASAPublished unparseableBody:unparseableBody forHost:host date:[NSDate date]];
        PWUniversalLinkVerdict verdict = [self verdictForFetchedAASA:aasa noAASAPublished:noAASAPublished unparseableBody:unparseableBody url:url bundleIdentifier:bundleIdentifier];
        [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:[NSString stringWithFormat:@"AASA verdict for %@: %@", host, [self stringForVerdict:verdict]]];
        [self completeOnMain:completion verdict:verdict];
    }];
}

+ (PWUniversalLinkVerdict)verdictForFetchedAASA:(NSDictionary *)aasa noAASAPublished:(BOOL)noAASAPublished unparseableBody:(BOOL)unparseableBody url:(NSURL *)url bundleIdentifier:(NSString *)bundleIdentifier {
    if (aasa) {
        return [self verdictForAASADictionary:aasa url:url bundleIdentifier:bundleIdentifier];
    }
    if (unparseableBody || noAASAPublished) {
        return PWUniversalLinkVerdictNoMatch;
    }
    return PWUniversalLinkVerdictUnknown;
}

+ (NSString *)stringForVerdict:(PWUniversalLinkVerdict)verdict {
    switch (verdict) {
        case PWUniversalLinkVerdictMatch: return @"match";
        case PWUniversalLinkVerdictNoMatch: return @"no match";
        case PWUniversalLinkVerdictUnknown: return @"unknown";
    }
    return @"unknown";
}

+ (void)completeOnMain:(void (^)(PWUniversalLinkVerdict))completion verdict:(PWUniversalLinkVerdict)verdict {
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(verdict);
    });
}

#pragma mark - AASA verdict

+ (PWUniversalLinkVerdict)verdictForAASADictionary:(NSDictionary *)aasa url:(NSURL *)url bundleIdentifier:(NSString *)bundleIdentifier {
    NSDictionary *applinks = [self dictionaryValue:aasa[@"applinks"]];
    if (!applinks) {
        return PWUniversalLinkVerdictNoMatch;
    }

    NSArray *details = [applinks[@"details"] isKindOfClass:[NSArray class]] ? applinks[@"details"] : nil;
    if (!details) {
        return PWUniversalLinkVerdictNoMatch;
    }

    for (id entryObject in details) {
        NSDictionary *entry = [self dictionaryValue:entryObject];
        if (!entry || ![self entry:entry matchesBundleIdentifier:bundleIdentifier]) {
            continue;
        }
        if ([self entry:entry allowsURL:url]) {
            return PWUniversalLinkVerdictMatch;
        }
    }

    return PWUniversalLinkVerdictNoMatch;
}

+ (NSDictionary *)parsedAASABody:(NSData *)data {
    if (data.length == 0) {
        return nil;
    }
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [json isKindOfClass:[NSDictionary class]] ? json : nil;
}

+ (NSDictionary *)dictionaryValue:(id)object {
    return [object isKindOfClass:[NSDictionary class]] ? object : nil;
}

+ (BOOL)entry:(NSDictionary *)entry matchesBundleIdentifier:(NSString *)bundleIdentifier {
    NSMutableArray<NSString *> *appIDs = [NSMutableArray array];
    if ([entry[@"appID"] isKindOfClass:[NSString class]]) {
        [appIDs addObject:entry[@"appID"]];
    }
    if ([entry[@"appIDs"] isKindOfClass:[NSArray class]]) {
        for (id appID in entry[@"appIDs"]) {
            if ([appID isKindOfClass:[NSString class]]) {
                [appIDs addObject:appID];
            }
        }
    }
    for (NSString *appID in appIDs) {
        NSRange teamSeparator = [appID rangeOfString:@"."];
        if (teamSeparator.location == NSNotFound) {
            continue;
        }
        NSString *appIDBundle = [appID substringFromIndex:teamSeparator.location + 1];
        if ([appIDBundle isEqualToString:bundleIdentifier]) {
            return YES;
        }
    }
    return NO;
}

+ (BOOL)entry:(NSDictionary *)entry allowsURL:(NSURL *)url {
    id components = entry[@"components"];
    if ([components isKindOfClass:[NSArray class]]) {
        return [self components:components allowURL:url];
    }
    id paths = entry[@"paths"];
    if ([paths isKindOfClass:[NSArray class]]) {
        return [self legacyPaths:paths allowPath:[self normalizedPathForURL:url]];
    }
    return YES;
}

+ (NSString *)normalizedPathForURL:(NSURL *)url {
    return url.path.length > 0 ? url.path : @"/";
}

+ (BOOL)components:(NSArray *)components allowURL:(NSURL *)url {
    NSMutableArray<NSDictionary *> *interpretableComponents = [NSMutableArray array];
    for (id componentObject in components) {
        NSDictionary *component = [self dictionaryValue:componentObject];
        if (component && [self isInterpretableComponent:component]) {
            [interpretableComponents addObject:component];
        }
    }
    if (interpretableComponents.count == 0) {
        return YES;
    }
    for (NSDictionary *component in interpretableComponents) {
        if ([self component:component matchesURL:url]) {
            id excludeValue = component[@"exclude"];
            BOOL excluded = [excludeValue isKindOfClass:[NSNumber class]] && [excludeValue boolValue];
            return !excluded;
        }
    }
    return NO;
}

+ (BOOL)isInterpretableComponent:(NSDictionary *)component {
    for (NSString *key in @[@"/", @"?", @"#"]) {
        if ([component[key] isKindOfClass:[NSString class]]) {
            return YES;
        }
    }
    return NO;
}

+ (BOOL)component:(NSDictionary *)component matchesURL:(NSURL *)url {
    NSDictionary<NSString *, NSString *> *urlParts = @{@"/": [self normalizedPathForURL:url],
                                                       @"?": url.query ?: @"",
                                                       @"#": url.fragment ?: @""};
    for (NSString *key in urlParts) {
        NSString *pattern = [component[key] isKindOfClass:[NSString class]] ? component[key] : nil;
        if (!pattern) {
            continue;
        }
        if (![self pattern:pattern matchesPart:urlParts[key]]) {
            return NO;
        }
    }
    return YES;
}

+ (BOOL)legacyPaths:(NSArray *)paths allowPath:(NSString *)path {
    NSMutableArray<NSString *> *interpretablePatterns = [NSMutableArray array];
    for (id patternObject in paths) {
        if ([patternObject isKindOfClass:[NSString class]]) {
            [interpretablePatterns addObject:patternObject];
        }
    }
    if (interpretablePatterns.count == 0) {
        return YES;
    }
    for (NSString *patternEntry in interpretablePatterns) {
        NSString *pattern = patternEntry;
        BOOL excluded = [pattern hasPrefix:@"NOT "];
        if (excluded) {
            pattern = [pattern substringFromIndex:4];
        }
        if ([self pattern:pattern matchesPath:path]) {
            return !excluded;
        }
    }
    return NO;
}

+ (BOOL)pattern:(NSString *)pattern matchesPath:(NSString *)path {
    if (path.length == 0) {
        return NO;
    }
    return [self pattern:pattern matchesPart:path];
}

+ (BOOL)pattern:(NSString *)pattern matchesPart:(NSString *)part {
    if (pattern.length == 0) {
        return NO;
    }
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF LIKE %@", pattern];
    return [predicate evaluateWithObject:part ?: @""];
}

#pragma mark - AASA fetch

+ (void)fetchAASAForHost:(NSString *)host completion:(void (^)(NSDictionary *, BOOL, BOOL))completion {
    NSURL *wellKnownURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/.well-known/apple-app-site-association", host]];
    NSURL *rootURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/apple-app-site-association", host]];

    __block NSData *wellKnownData = nil;
    __block NSError *wellKnownError = nil;
    __block NSInteger wellKnownStatus = 0;
    __block NSData *rootData = nil;
    __block NSError *rootError = nil;
    __block NSInteger rootStatus = 0;

    dispatch_group_t downloads = dispatch_group_create();

    dispatch_group_enter(downloads);
    [self downloadAASAFromURL:wellKnownURL completion:^(NSData *data, NSError *error, NSInteger statusCode) {
        wellKnownData = data;
        wellKnownError = error;
        wellKnownStatus = statusCode;
        dispatch_group_leave(downloads);
    }];

    dispatch_group_enter(downloads);
    [self downloadAASAFromURL:rootURL completion:^(NSData *data, NSError *error, NSInteger statusCode) {
        rootData = data;
        rootError = error;
        rootStatus = statusCode;
        dispatch_group_leave(downloads);
    }];

    dispatch_group_notify(downloads, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSDictionary *wellKnownAASA = [self parsedAASABody:wellKnownData];
        if (wellKnownAASA) {
            completion(wellKnownAASA, NO, NO);
            return;
        }
        NSDictionary *rootAASA = [self parsedAASABody:rootData];
        if (rootAASA) {
            completion(rootAASA, NO, NO);
            return;
        }
        if (wellKnownData != nil || rootData != nil) {
            completion(nil, NO, YES);
            return;
        }
        BOOL wellKnownMissing = (wellKnownError == nil) && [self isDefinitiveNoAASAStatusCode:wellKnownStatus];
        BOOL rootMissing = (rootError == nil) && [self isDefinitiveNoAASAStatusCode:rootStatus];
        completion(nil, wellKnownMissing && rootMissing, NO);
    });
}

/// Whether the response proves Apple would not get an association file from this location either.
///
/// Apple's own fetcher wants a 200 and does not follow redirects, so a 3xx (moved — the case of
/// every host that redirects the apex to www), a 404/410 (absent) or any other 4xx (refused) all
/// mean the same thing: universal links cannot work for this host. That is an answer about the
/// domain, not a failure to reach it, so it settles the verdict as NoMatch.
///
/// Deliberately excluded: 5xx and a transport error. Those say the server is broken at this
/// moment, nothing about the domain — they stay Unknown and are re-checked after the short cache
/// window. A 200 never reaches here: a parseable body already returned a verdict, an unparseable
/// one is NoMatch by `unparseableBody`.
+ (BOOL)isDefinitiveNoAASAStatusCode:(NSInteger)statusCode {
    return statusCode >= 200 && statusCode < 500;
}

+ (void)downloadAASAFromURL:(NSURL *)url completion:(void (^)(NSData *, NSError *, NSInteger))completion {
    if (!url) {
        completion(nil, nil, 0);
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = kPWAASATimeout;
    NSURLSessionDataTask *task = [[self aasaSession] dataTaskWithRequest:request];
    [(PWAASASessionDelegate *)[self aasaSession].delegate registerCompletion:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger statusCode = [response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 0;
        completion([self isAcceptableAASAResponse:response data:data error:error] ? data : nil, error, statusCode);
    } forTask:task];
    [task resume];
}

+ (BOOL)isAcceptableAASAResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error {
    if (error || data.length == 0 || data.length > kPWAASAMaxSize) {
        return NO;
    }
    if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
        return NO;
    }
    return ((NSHTTPURLResponse *)response).statusCode == 200;
}

+ (NSURLSession *)aasaSession {
    static NSURLSession *session;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        configuration.timeoutIntervalForRequest = kPWAASATimeout;
        configuration.timeoutIntervalForResource = kPWAASATimeout;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        NSOperationQueue *delegateQueue = [NSOperationQueue new];
        delegateQueue.maxConcurrentOperationCount = 1;
        session = [NSURLSession sessionWithConfiguration:configuration delegate:[PWAASASessionDelegate new] delegateQueue:delegateQueue];
    });
    return session;
}

#pragma mark - AASA fetch-result cache

+ (NSMutableDictionary<NSString *, NSDictionary *> *)memoryCache {
    static NSMutableDictionary *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSMutableDictionary dictionary];
    });
    return cache;
}

+ (NSString *)cacheKeyForHost:(NSString *)host {
    return [kPWAASAVerdictCacheKeyPrefix stringByAppendingString:host];
}

+ (void)storeAASA:(NSDictionary *)aasa noAASAPublished:(BOOL)noAASAPublished unparseableBody:(BOOL)unparseableBody forHost:(NSString *)host date:(NSDate *)date {
    if (host.length == 0) {
        return;
    }
    BOOL shortLived = (aasa == nil) && !noAASAPublished;
    if (shortLived) {
        NSDictionary *existingEntry;
        @synchronized (self) {
            existingEntry = [self memoryCache][host];
        }
        BOOL existingIsAuthoritative = existingEntry && ![existingEntry[@"shortLived"] boolValue];
        NSTimeInterval existingAge = date.timeIntervalSince1970 - [existingEntry[@"timestamp"] doubleValue];
        if (existingIsAuthoritative && existingAge >= 0 && existingAge <= kPWAASAVerdictTTL) {
            return;
        }
    }
    NSMutableDictionary *entry = [NSMutableDictionary dictionary];
    entry[@"timestamp"] = @(date.timeIntervalSince1970);
    entry[@"shortLived"] = @(shortLived);
    entry[@"noAASAPublished"] = @(noAASAPublished);
    entry[@"unparseableBody"] = @(unparseableBody);
    if (aasa) {
        entry[@"aasa"] = aasa;
    }
    @synchronized (self) {
        [self memoryCache][host] = entry;
    }
    if (shortLived) {
        return;
    }
    NSMutableDictionary *persistedEntry = [entry mutableCopy];
    if (aasa) {
        NSData *body = [NSJSONSerialization dataWithJSONObject:aasa options:0 error:nil];
        if (!body) {
            return;
        }
        [persistedEntry removeObjectForKey:@"aasa"];
        persistedEntry[@"body"] = body;
    }
    [[NSUserDefaults standardUserDefaults] setObject:persistedEntry forKey:[self cacheKeyForHost:host]];
}

+ (BOOL)cachedResultForHost:(NSString *)host now:(NSDate *)now aasa:(NSDictionary **)outAASA noAASAPublished:(BOOL *)outNoAASAPublished unparseableBody:(BOOL *)outUnparseableBody {
    *outAASA = nil;
    *outNoAASAPublished = NO;
    *outUnparseableBody = NO;
    if (host.length == 0) {
        return NO;
    }

    NSDictionary *memoryEntry;
    @synchronized (self) {
        memoryEntry = [self memoryCache][host];
    }
    NSDictionary *persistedEntry = [[NSUserDefaults standardUserDefaults] dictionaryForKey:[self cacheKeyForHost:host]];

    for (NSDictionary *entry in @[memoryEntry ?: @{}, persistedEntry ?: @{}]) {
        if (!entry[@"timestamp"]) {
            continue;
        }
        NSTimeInterval age = now.timeIntervalSince1970 - [entry[@"timestamp"] doubleValue];
        NSTimeInterval ttl = [entry[@"shortLived"] boolValue] ? kPWAASAUnknownTTL : kPWAASAVerdictTTL;
        if (age < 0 || age > ttl) {
            continue;
        }
        NSDictionary *aasa = [self dictionaryValue:entry[@"aasa"]];
        if (!aasa && [entry[@"body"] isKindOfClass:[NSData class]]) {
            aasa = [self parsedAASABody:entry[@"body"]];
            if (!aasa) {
                continue;
            }
        }
        *outAASA = aasa;
        *outNoAASAPublished = [entry[@"noAASAPublished"] boolValue];
        *outUnparseableBody = [entry[@"unparseableBody"] boolValue];
        return YES;
    }
    return NO;
}

+ (void)clearCache {
    @synchronized (self) {
        [[self memoryCache] removeAllObjects];
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    for (NSString *key in defaults.dictionaryRepresentation.allKeys) {
        if ([key hasPrefix:kPWAASAVerdictCacheKeyPrefix]) {
            [defaults removeObjectForKey:key];
        }
    }
}

@end
