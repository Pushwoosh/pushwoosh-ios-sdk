//
//  StoreViewController.m
//  Newsstand
//

#import "StoreViewController.h"

@interface StoreViewController (Private)

- (void)showIssues;
- (void)loadIssues;
- (void)readIssue:(NKIssue *)nkIssue;
- (void)downloadIssueAtIndex:(NSInteger)index;

- (void)errorWithTransaction:(SKPaymentTransaction *)transaction;
- (void)finishedTransaction:(SKPaymentTransaction *)transaction;
- (void)checkReceipt:(NSData *)receipt;

@end

@implementation StoreViewController
@synthesize table, publisher;

static NSString *issueTableCellId = @"IssueTableCell";

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self) {
		// Custom initialization
		publisher = [[Publisher alloc] init];
	}
	return self;
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
	[super viewDidLoad];

	// define right bar button items
	refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
																  target:self
																  action:@selector(loadIssues)];

	// simple loading animator
	UIActivityIndicatorView *loadingActivity = [
		[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite] autorelease];
	[loadingActivity startAnimating];

	// wrap activity indicator in a bar button
	loadingButton = [[UIBarButtonItem alloc] initWithCustomView:loadingActivity];
	[loadingButton setTarget:nil];
	[loadingButton setAction:nil];

	// left bar button item
	self.navigationItem.leftBarButtonItem =
		[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
													   target:self
													   action:@selector(trashContent)] autorelease];

	// table
	[table registerNib:[UINib nibWithNibName:@"IssueTableCell" bundle:[NSBundle mainBundle]]
		forCellReuseIdentifier:issueTableCellId];

	// present or load the issues
	if ([publisher isReady]) {
		[self showIssues];
	} else {
		[self loadIssues];
	}
}

- (void)viewDidUnload {
	self.table = nil;

	[loadingButton release];
	[refreshButton release];

	[super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Publisher interaction

// ask publisher to get a list of available issues
- (void)loadIssues {
	// hide the tableView
	table.alpha = 0.0;

	[self.navigationItem setRightBarButtonItem:loadingButton];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(publisherReady:)
												 name:PublisherDidUpdateNotification
											   object:publisher];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(publisherFailed:)
												 name:PublisherFailedUpdateNotification
											   object:publisher];

	[publisher getIssuesList];
}

// present available issues on the main tableview
- (void)showIssues {
	[self.navigationItem setRightBarButtonItem:refreshButton];

	//bring the tableview back
	table.alpha = 1.0;
	[table reloadData];
}

// publisher downloaded a list of available issues
- (void)publisherReady:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:PublisherDidUpdateNotification object:publisher];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:PublisherFailedUpdateNotification object:publisher];

	[self showIssues];
}

// publisher failed to download a list of available issues
- (void)publisherFailed:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:PublisherDidUpdateNotification object:publisher];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:PublisherFailedUpdateNotification object:publisher];

	NSLog(@"Published download failed: %@", notification);
	UIAlertView *alert =
		[[UIAlertView alloc] initWithTitle:@"Error"
								   message:@"Cannot get issues from publisher server. Please try again later."
								  delegate:nil
						 cancelButtonTitle:@"Close"
						 otherButtonTitles:nil];
	[alert show];
	[alert release];

	// activate the refresh button
	[self.navigationItem setRightBarButtonItem:refreshButton];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [publisher numberOfIssues];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:issueTableCellId];
	NSLog(@"%@", cell);

	NSInteger index = indexPath.row;
	UILabel *titleLabel = (UILabel *)[cell viewWithTag:101];
	titleLabel.text = [publisher titleOfIssueAtIndex:index];

	UIImageView *imageView = (UIImageView *)[cell viewWithTag:100];
	imageView.image = nil;  // reset image as it will be retrieved asychronously

	// asychronously download and set the image using completionBlock
	[publisher setCoverOfIssueAtIndex:index
					  completionBlock:^(UIImage *img) {
						  dispatch_async(dispatch_get_main_queue(), ^{
							  // update the imageview for the cell
							  UITableViewCell *cell =
								  [table cellForRowAtIndexPath:[NSIndexPath indexPathForRow:indexPath.row inSection:0]];
							  UIImageView *imageView = (UIImageView *)[cell viewWithTag:100];
							  imageView.image = img;
						  });
					  }];

	// get the issue for the cell
	NKLibrary *nkLib = [NKLibrary sharedLibrary];
	NKIssue *nkIssue = [nkLib issueWithName:[publisher nameOfIssueAtIndex:index]];

	// get the label and progress
	UIProgressView *downloadProgress = (UIProgressView *)[cell viewWithTag:102];
	UILabel *tapLabel = (UILabel *)[cell viewWithTag:103];

	// update label and progress based on the status of the issue associated with the cell
	if (nkIssue.status == NKIssueContentStatusAvailable) {
		tapLabel.text = @"TAP TO READ";
		tapLabel.alpha = 1.0;
		downloadProgress.alpha = 0.0;
	} else {
		if (nkIssue.status == NKIssueContentStatusDownloading) {
			downloadProgress.alpha = 1.0;
			tapLabel.alpha = 0.0;
		} else {
			downloadProgress.alpha = 0.0;
			tapLabel.alpha = 1.0;
			tapLabel.text = @"TAP TO DOWNLOAD";
		}
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	// get the issue associated with the cell
	NKLibrary *nkLib = [NKLibrary sharedLibrary];
	NKIssue *nkIssue = [nkLib issueWithName:[publisher nameOfIssueAtIndex:indexPath.row]];

	// possible actions: read or download
	if (nkIssue.status == NKIssueContentStatusAvailable) {
		[self readIssue:nkIssue];
	} else if (nkIssue.status == NKIssueContentStatusNone) {
		[self downloadIssueAtIndex:indexPath.row];
	}
}

#pragma mark - Issue actions

// display the issue using QLPreviewController
- (void)readIssue:(NKIssue *)nkIssue {
	// set this to prevent the issue from being purged by iOS if it decides to flush the cache
	[[NKLibrary sharedLibrary] setCurrentlyReadingIssue:nkIssue];

	// using QLPreviewController to display the issue
	QLPreviewController *previewController = [[[QLPreviewController alloc] init] autorelease];
	previewController.delegate = self;
	previewController.dataSource = self;
	[self presentModalViewController:previewController animated:YES];
}

- (void)downloadIssueAtIndex:(NSInteger)index {
	NKLibrary *nkLib = [NKLibrary sharedLibrary];

	// get the URL for the asset
	NKIssue *nkIssue = [nkLib issueWithName:[publisher nameOfIssueAtIndex:index]];
	NSURL *downloadURL = [publisher contentURLForIssueWithName:nkIssue.name];
	if (!downloadURL)
		return;

	// simply ask the NKAssetDownload class to download the asset
	NSURLRequest *request = [NSURLRequest requestWithURL:downloadURL];
	NKAssetDownload *assetDownload = [nkIssue addAssetWithRequest:request];
	[assetDownload downloadWithDelegate:self];

	// store the index of the Cell as a custom data. we will use it later to display connection progress
	[assetDownload
		setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:index], @"Index", nil]];
}

#pragma mark - NSURLConnectionDownloadDelegate

- (void)updateProgressOfConnection:(NSURLConnection *)connection
			 withTotalBytesWritten:(long long)totalBytesWritten
				expectedTotalBytes:(long long)expectedTotalBytes {
	// get asset
	NKAssetDownload *assetDownload = connection.newsstandAssetDownload;

	// get the right cell by using our cell index in the custom data associated with the download
	UITableViewCell *cell = [table
		cellForRowAtIndexPath:[NSIndexPath indexPathForRow:[[assetDownload.userInfo objectForKey:@"Index"] intValue]
												 inSection:0]];

	// hide the "download" label in the cell
	[[cell viewWithTag:103] setAlpha:0.0];

	// get the progress bar in the cell by tag
	UIProgressView *progressView = (UIProgressView *)[cell viewWithTag:102];
	progressView.alpha = 1.0;
	progressView.progress = 1.f * totalBytesWritten / expectedTotalBytes;
}

- (void)connection:(NSURLConnection *)connection
	  didWriteData:(long long)bytesWritten
 totalBytesWritten:(long long)totalBytesWritten
expectedTotalBytes:(long long)expectedTotalBytes {
	[self updateProgressOfConnection:connection
			   withTotalBytesWritten:totalBytesWritten
				  expectedTotalBytes:expectedTotalBytes];
}

- (void)connectionDidResumeDownloading:(NSURLConnection *)connection
					 totalBytesWritten:(long long)totalBytesWritten
					expectedTotalBytes:(long long)expectedTotalBytes {
	NSLog(@"Resume downloading %f", 1.f * totalBytesWritten / expectedTotalBytes);
	[self updateProgressOfConnection:connection
			   withTotalBytesWritten:totalBytesWritten
				  expectedTotalBytes:expectedTotalBytes];
}

- (void)connectionDidFinishDownloading:(NSURLConnection *)connection destinationURL:(NSURL *)destinationURL {
	// get the asset associated with the connection
	NKAssetDownload *assetDownload = connection.newsstandAssetDownload;
	NKIssue *nkIssue = assetDownload.issue;

	// get the path on disk for this issue
	NSString *contentPath = [publisher downloadPathForIssue:nkIssue];

	NSError *moveError = nil;
	NSLog(@"File is being copied to %@", contentPath);

	// copy file from the destination URL (in the cache folder) to the safe place
	if ([[NSFileManager defaultManager] moveItemAtPath:[destinationURL path] toPath:contentPath error:&moveError] ==
		NO) {
		NSLog(@"Error copying file from %@ to %@", destinationURL, contentPath);
	}

	// update the Newsstand icon and set the "new" badge
	UIImage *img = [publisher coverImageForIssue:nkIssue];
	if (img) {
		[[UIApplication sharedApplication] setNewsstandIconImage:img];
	}

	[[UIApplication sharedApplication] setApplicationIconBadgeNumber:1];

	[table reloadData];
}

#pragma mark - QuickLook

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
	return 1;
}

- (id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
	NKIssue *nkIssue = [[NKLibrary sharedLibrary] currentlyReadingIssue];
	NSURL *issueURL = [NSURL fileURLWithPath:[publisher downloadPathForIssue:nkIssue]];
	NSLog(@"Issue URL: %@", issueURL);

	return issueURL;
}

#pragma mark - Trash content

// remove all downloaded magazines
- (void)trashContent {
	NKLibrary *nkLib = [NKLibrary sharedLibrary];
	NSLog(@"%@", nkLib.issues);

	[nkLib.issues enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		[nkLib removeIssue:(NKIssue *)obj];
	}];

	// refresh all
	[publisher addIssuesInNewsstand];
	[table reloadData];
}

- (void)dealloc {
	[publisher release];
	[table release];
	[super dealloc];
}

@end
