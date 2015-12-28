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
	self.titleLabel.text = [NSString stringWithFormat:@"Only today get %ld%% discount!", (long)self.discount];
}

- (IBAction)closeAction:(id)sender {
	[self dismissViewControllerAnimated:YES completion:nil];
}

@end
