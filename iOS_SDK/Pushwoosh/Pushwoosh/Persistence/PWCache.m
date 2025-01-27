//
//  PWCache.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#import "PWCache.h"
#import "PWLog+Internal.h"
#import "PWUtils.h"
#import "PWUnarchiver.h"

@interface PWCache ()

@property (nonatomic, copy) NSString *tagsCacheFile;
@property (nonatomic, copy) NSString *emailTagsCacheFile;

@end

@implementation PWCache

- (instancetype)init {
	self = [super init];
	if (self) {
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
		NSString *cacheDir = paths[0];
		self.tagsCacheFile = [cacheDir stringByAppendingPathComponent:@"pwtags"];
        
        NSArray *emailPath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *emailCacheDir = emailPath[0];
        self.emailTagsCacheFile = [emailCacheDir stringByAppendingPathComponent:@"pwemailtags"];
	}

	return self;
}

+ (PWCache *)cache {
	static PWCache *instance = nil;
	static dispatch_once_t pred;

	dispatch_once(&pred, ^{
		instance = [PWCache new];
	});

	return instance;
}

- (void)setTags:(NSDictionary *)tags {
    PWLogVerbose(@"Set cached tags: %@", tags);
    if (TARGET_OS_IOS && [PWUtils isSystemVersionGreaterOrEqualTo:@"11.0"]) {
        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:tags requiringSecureCoding:YES error:&error];
        [data writeToFile:self.tagsCacheFile options:NSDataWritingAtomic error:&error];
    } else {
        [NSKeyedArchiver archiveRootObject:tags toFile:self.tagsCacheFile];
    }
}

- (void)addTags:(NSDictionary *)tags {
	NSDictionary *oldTags = [self getTags];
	if (!oldTags) {
		oldTags = @{};
	}

	NSDictionary *updatedTags = [PWCache mergeTags:tags to:oldTags];
	[self setTags:updatedTags];
}

- (NSDictionary *)getTags {
    NSDictionary *tags = nil;
    
    if (TARGET_OS_IOS) {
        NSURL *url = [NSURL fileURLWithPath:self.tagsCacheFile];
        NSData *data = [NSData dataWithContentsOfURL:url];
        
        NSSet *set = [NSSet setWithObjects:[NSDictionary class], [NSString class], [NSNumber class], [NSArray class], nil];
        PWUnarchiver *unarchiver = [[PWUnarchiver alloc] init];
        tags = [unarchiver unarchivedObjectOfClasses:set data:data];
    }
    
	PWLogVerbose(@"Get cached tags: %@", tags);

	if (tags && ![tags isKindOfClass:[NSDictionary class]]) {
		PWLogWarn(@"Invalid cached tags");

		return nil;
	}

	return tags;
}

- (void)setEmailTags:(NSDictionary *)tags {
    PWLogVerbose(@"Set cached email tags: %@", tags);
    if (TARGET_OS_IOS && [PWUtils isSystemVersionGreaterOrEqualTo:@"11.0"]) {
        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:tags requiringSecureCoding:YES error:&error];
        [data writeToFile:self.emailTagsCacheFile options:NSDataWritingAtomic error:&error];
    } else {
        [NSKeyedArchiver archiveRootObject:tags toFile:self.emailTagsCacheFile];
    }
}

- (void)addEmailTags:(NSDictionary *)tags {
    NSDictionary *oldEmailTags = [self getEmailTags];
    if (!oldEmailTags) {
        oldEmailTags = @{};
    }
    
    NSDictionary *updatedEmailTags = [PWCache mergeTags:tags to:oldEmailTags];
    [self setEmailTags:updatedEmailTags];
}

- (NSDictionary *)getEmailTags {
    NSDictionary *tags = nil;
    
    if (TARGET_OS_IOS) {
        NSURL *url = [NSURL fileURLWithPath:self.emailTagsCacheFile];
        NSData *data = [NSData dataWithContentsOfURL:url];
                
        NSSet *set = [NSSet setWithObjects:[NSString class], [NSDictionary class], nil];
        PWUnarchiver *unarchiver = [[PWUnarchiver alloc] init];
        tags = [unarchiver unarchivedObjectOfClasses:set data:data];
    }

    PWLogVerbose(@"Get cached email tags: %@", tags);

    if (tags && ![tags isKindOfClass:[NSDictionary class]]) {
        PWLogWarn(@"Invalid cached email tags");

        return nil;
    }

    return tags;
}

+ (NSDictionary *)mergeTags:(NSDictionary *)src to:(NSDictionary *)dst {
	NSMutableDictionary *result = [dst mutableCopy];
	for (NSString *key in src) {
		result[key] = src[key];
	}

	return result;
}

- (void)clear {
	[[NSFileManager defaultManager] removeItemAtPath:self.tagsCacheFile error:nil];
}

- (void)clearEmailTags {
    [[NSFileManager defaultManager] removeItemAtPath:self.emailTagsCacheFile error:nil];
}

@end
