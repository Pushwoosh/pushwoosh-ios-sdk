//
//  PushNotificationsApp
//
//  (c) Pushwoosh 2014
//

#import "CustomPageViewController.h"

@implementation CustomPageViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.view.backgroundColor = self.bgColor;
	self.titleLabel.text = [NSString stringWithFormat:@"Custom page with id %ld", (long)self.pageId];
}

- (IBAction)closeAction:(id)sender {
	[self dismissViewControllerAnimated:YES completion:nil];
}

@end
