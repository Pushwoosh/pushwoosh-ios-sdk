//
//  PushNotificationsApp
//
//  (c) Pushwoosh 2014
//

#import "ViewController.h"
#import "CustomPageViewController.h"

@interface ViewController ()

@property (nonatomic, weak) IBOutlet UITextField *aliasField;
@property (nonatomic, weak) IBOutlet UITextField *favNumField;
@property (nonatomic, weak) IBOutlet UILabel *statusLabel;

@end

@implementation ViewController

- (void)startTracking {
	NSLog(@"Start tracking");
	PushNotificationManager *pushManager = [PushNotificationManager pushManager];
	[pushManager startBeaconTracking];
}

- (void)stopTracking {
	NSLog(@"Stop tracking");
	PushNotificationManager *pushManager = [PushNotificationManager pushManager];
	[pushManager stopBeaconTracking];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	if (textField == _aliasField) {
		[_favNumField becomeFirstResponder];
	} else if (textField == _favNumField) {
		[self submitAction:_favNumField];
	}

	return YES;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	[self startTracking];
}

- (void)submitAction:(id)sender {
	NSLog(@"Submitting");

	[_aliasField resignFirstResponder];
	[_favNumField resignFirstResponder];

	NSDictionary *tags =
		[NSDictionary dictionaryWithObjectsAndKeys:[_aliasField text], @"Alias",
												   [NSNumber numberWithInt:[_favNumField.text intValue]], @"FavNumber",
												   [NSArray arrayWithObjects:@"Item1", @"Item2", @"Item3", nil],
												   @"List", [PWTags incrementalTagWithInteger:5], @"price", nil];

	[[PushNotificationManager pushManager] setTags:tags];

	[[PushNotificationManager pushManager] loadTags];
	_statusLabel.text = @"Tags sent";
}

- (void)setViewBackgroundColorWithRed:(NSString *)redString green:(NSString *)greenString blue:(NSString *)blueString {
	CGFloat red = [redString floatValue] / 255.0f;
	CGFloat green = [greenString floatValue] / 255.0f;
	CGFloat blue = [blueString floatValue] / 255.0f;

	UIColor *color = [UIColor colorWithRed:red green:green blue:blue alpha:1.0f];
	[UIView animateWithDuration:0.3
					 animations:^{
						 self.view.backgroundColor = color;
						 self.presentedViewController.view.backgroundColor = color;
					 }];
}

- (void)showPageWithId:(NSString *)pageId {
	CustomPageViewController *vc = [[CustomPageViewController alloc] init];
	vc.bgColor = self.view.backgroundColor;
	vc.pageId = [pageId integerValue];
	vc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

	if (self.presentedViewController) {
		[self dismissViewControllerAnimated:YES
								 completion:^{
									 [self presentViewController:vc animated:YES completion:nil];
								 }];
	} else {
		[self presentViewController:vc animated:YES completion:nil];
	}
}

#pragma mark - PushNotificationDelegate

//succesfully registered for push notifications
- (void)onDidRegisterForRemoteNotificationsWithDeviceToken:(NSString *)token {
	_statusLabel.text = [NSString stringWithFormat:@"Registered with push token: %@", token];
}

//failed to register for push notifications
- (void)onDidFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
	_statusLabel.text = [NSString stringWithFormat:@"Failed to register: %@", [error description]];
}

//user pressed OK on the push notification
- (void)onPushAccepted:(PushNotificationManager *)pushManager withNotification:(NSDictionary *)pushNotification {
	[PushNotificationManager clearNotificationCenter];

	_statusLabel.text = [NSString stringWithFormat:@"Received push notification: %@", pushNotification];

	// Parse custom JSON data string.
	// You can set background color with custom JSON data in the following format: { "r" : "10", "g" : "200", "b" : "100" }
	// Or open specific screen of the app with custom page ID (set ID in the { "id" : "2" } format)
	NSString *customDataString = [pushManager getCustomPushData:pushNotification];

	NSDictionary *jsonData = nil;

	if (customDataString) {
		jsonData = [NSJSONSerialization JSONObjectWithData:[customDataString dataUsingEncoding:NSUTF8StringEncoding]
												   options:NSJSONReadingMutableContainers
													 error:nil];
	}

	NSString *redStr = [jsonData objectForKey:@"r"];
	NSString *greenStr = [jsonData objectForKey:@"g"];
	NSString *blueStr = [jsonData objectForKey:@"b"];

	if (redStr || greenStr || blueStr) {
		[self setViewBackgroundColorWithRed:redStr green:greenStr blue:blueStr];
	}

	NSString *pageId = [jsonData objectForKey:@"id"];

	if (pageId) {
		[self showPageWithId:pageId];
	}
}

//received tags from the server
- (void)onTagsReceived:(NSDictionary *)tags {
	NSLog(@"getTags: %@", tags);
}

//error receiving tags from the server
- (void)onTagsFailedToReceive:(NSError *)error {
	NSLog(@"getTags error: %@", error);
}

@end
