//
//  Publisher.h
//  Newsstand
//

#import <Foundation/Foundation.h>
#import <NewsstandKit/NewsstandKit.h>

extern NSString *PublisherDidUpdateNotification;
extern NSString *PublisherFailedUpdateNotification;

// retrieves the plist file with the list of the current issues available
// manages issue cover downloads and issue content URL handling
@interface Publisher : NSObject {
	NSArray *issues;
}

@property (nonatomic, readonly, getter=isReady) BOOL ready;

// adds the issues to the NKLibrary
- (void)addIssuesInNewsstand;

// downloads the issues list from the server
- (void)getIssuesList;

// gets the index in the issues array by name
- (int)getIssueIndexByName:(NSString *)name;

// simple self descriptive getters
- (NSInteger)numberOfIssues;
- (NSString *)titleOfIssueAtIndex:(NSInteger)index;
- (NSString *)nameOfIssueAtIndex:(NSInteger)index;

// downloads the image if it is not cached and applies completion block
- (void)setCoverOfIssueAtIndex:(NSInteger)index completionBlock:(void (^)(UIImage *img))block;

// finds the issue by name and gets the URL for the issue
- (NSURL *)contentURLForIssueWithName:(NSString *)name;

// path to the file on disk for the issue
- (NSString *)downloadPathForIssue:(NKIssue *)nkIssue;

// gets the image for the issue from the cached dir, may be null if it is not cached
- (UIImage *)coverImageForIssue:(NKIssue *)nkIssue;

@end
