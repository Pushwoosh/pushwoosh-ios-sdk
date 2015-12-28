//
//  StoreViewController.h
//  Newsstand
//

#import <UIKit/UIKit.h>
#import "Publisher.h"
#import <NewsstandKit/NewsstandKit.h>
#import <QuickLook/QuickLook.h>

// presents a list of current issues on the screen, allowing user to read them
// manages the downloads and progress indications
@interface StoreViewController
	: UIViewController <UITableViewDataSource, UITableViewDelegate, NSURLConnectionDownloadDelegate,
						QLPreviewControllerDelegate, QLPreviewControllerDataSource, NSURLConnectionDelegate> {
	UIBarButtonItem *loadingButton;
	UIBarButtonItem *refreshButton;
}

@property (retain, nonatomic) IBOutlet UITableView *table;
@property (retain, nonatomic) Publisher *publisher;

// remove all downloaded magazines
- (void)trashContent;

@end
