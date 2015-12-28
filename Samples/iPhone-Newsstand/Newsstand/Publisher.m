//
//  Publisher.m
//  Newsstand
//

#import "Publisher.h"
#import <NewsstandKit/NewsstandKit.h>

NSString *PublisherDidUpdateNotification = @"PublisherDidUpdate";
NSString *PublisherFailedUpdateNotification = @"PublisherFailedUpdate";

@implementation Publisher

@synthesize ready;

- (id)init {
	self = [super init];
	if (self) {
		ready = NO;
		issues = nil;
	}
	return self;
}

// downloads the issues list from the server
- (void)getIssuesList {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
		NSArray *tmpIssues =
			[NSArray arrayWithContentsOfURL:[NSURL URLWithString:@"http://www.pushwoosh.com/data/issues.plist"]];
		if (!tmpIssues) {
			// failure
			dispatch_async(dispatch_get_main_queue(), ^{
				[[NSNotificationCenter defaultCenter] postNotificationName:PublisherFailedUpdateNotification
																	object:self];
			});
		} else {
			// success, update the issue and post the success notification
			[issues release];
			issues = [[NSArray alloc] initWithArray:tmpIssues];
			NSLog(@"%@", issues);

			ready = YES;

			// let NKLibrary know about the issues we have downloaded
			[self addIssuesInNewsstand];

			dispatch_async(dispatch_get_main_queue(), ^{
				[[NSNotificationCenter defaultCenter] postNotificationName:PublisherDidUpdateNotification object:self];
			});
		}
	});
}

// adds the issues to the NKLibrary
- (void)addIssuesInNewsstand {
	NKLibrary *nkLib = [NKLibrary sharedLibrary];
	[issues enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		NSString *name = [(NSDictionary *)obj objectForKey:@"Name"];
		NKIssue *nkIssue = [nkLib issueWithName:name];
		if (!nkIssue) {
			nkIssue = [nkLib addIssueWithName:name date:[(NSDictionary *)obj objectForKey:@"Date"]];
		}

		NSLog(@"Issue: %@", nkIssue);
	}];
}

- (NSInteger)numberOfIssues {
	if ([self isReady] && issues) {
		return [issues count];
	}

	return 0;
}

// gets the index in the issues array by name
- (int)getIssueIndexByName:(NSString *)name {
	int i = 0;
	for (NSDictionary *issueInfo in issues) {
		if ([name isEqualToString:[issueInfo objectForKey:@"Name"]])
			return i;

		++i;
	}

	//oops
	return 0;
}

- (NSDictionary *)issueAtIndex:(NSInteger)index {
	return [issues objectAtIndex:index];
}

- (NSString *)titleOfIssueAtIndex:(NSInteger)index {
	return [[self issueAtIndex:index] objectForKey:@"Title"];
}

- (NSString *)nameOfIssueAtIndex:(NSInteger)index {
	return [[self issueAtIndex:index] objectForKey:@"Name"];
}

// downloads the image if it is not cached and applies completion block
- (void)setCoverOfIssueAtIndex:(NSInteger)index completionBlock:(void (^)(UIImage *img))block {
	// get the cover filename
	NSURL *coverURL = [NSURL URLWithString:[[self issueAtIndex:index] objectForKey:@"Cover"]];
	NSString *coverFileName = [coverURL lastPathComponent];

	// try to get the image from the cache
	NSString *coverFilePath = [CacheDirectory stringByAppendingPathComponent:coverFileName];
	UIImage *image = [UIImage imageWithContentsOfFile:coverFilePath];
	if (image) {
		block(image);
	} else {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
			// download the image
			NSData *imageData = [NSData dataWithContentsOfURL:coverURL];
			UIImage *image = [UIImage imageWithData:imageData];
			if (image) {
				// copy it to the safe place and apply the completion block
				[imageData writeToFile:coverFilePath atomically:YES];
				block(image);
			}
		});
	}
}

// gets the image for the issue from the cached dir, may be null if it is not cached
- (UIImage *)coverImageForIssue:(NKIssue *)nkIssue {
	NSString *name = nkIssue.name;

	for (NSDictionary *issueInfo in issues) {
		if (![name isEqualToString:[issueInfo objectForKey:@"Name"]])
			continue;

		NSString *coverPath = [issueInfo objectForKey:@"Cover"];
		NSString *coverName = [coverPath lastPathComponent];
		NSString *coverFilePath = [CacheDirectory stringByAppendingPathComponent:coverName];
		UIImage *image = [UIImage imageWithContentsOfFile:coverFilePath];
		return image;
	}

	return nil;
}

// finds the issue by name and gets the URL for the issue
- (NSURL *)contentURLForIssueWithName:(NSString *)name {
	__block NSURL *contentURL = nil;
	[issues enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		NSString *aName = [(NSDictionary *)obj objectForKey:@"Name"];
		if ([aName isEqualToString:name]) {
			contentURL = [[NSURL URLWithString:[(NSDictionary *)obj objectForKey:@"Content"]] retain];
			*stop = YES;
		}
	}];

	NSLog(@"Content URL for issue with name %@ is %@", name, contentURL);
	return [contentURL autorelease];
}

// path to the file on disk for the issue
- (NSString *)downloadPathForIssue:(NKIssue *)nkIssue {
	return [[nkIssue.contentURL path] stringByAppendingPathComponent:@"magazine.pdf"];
}

- (void)dealloc {
	[issues release];
	[super dealloc];
}

@end
