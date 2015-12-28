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
@property (nonatomic, weak) IBOutlet UILabel *payloadLabel;
@property (nonatomic, weak) IBOutlet UILabel *tokenInfoLabel;

@end

@implementation ViewController

- (void)startTracking {
	NSLog(@"Start tracking");
	PushNotificationManager *pushManager = [PushNotificationManager pushManager];
	[pushManager startLocationTracking];
	[pushManager startBeaconTracking];
}

- (void)stopTracking {
	NSLog(@"Stop tracking");
	PushNotificationManager *pushManager = [PushNotificationManager pushManager];
	[pushManager stopLocationTracking];
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

	UITapGestureRecognizer *copyRecognizer =
		[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapAction)];
	copyRecognizer.numberOfTapsRequired = 2;
	[self.view addGestureRecognizer:copyRecognizer];

	UITapGestureRecognizer *hideKeyBoardRecognizer =
		[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard)];
	[self.view addGestureRecognizer:hideKeyBoardRecognizer];

	[self submitAction:nil];
}

- (void)doubleTapAction {
	if ([[PushNotificationManager pushManager] getPushToken]) {
		[UIPasteboard generalPasteboard].string = [[PushNotificationManager pushManager] getPushToken];

		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
														message:@"Device token copied to clipboard"
													   delegate:nil
											  cancelButtonTitle:@"OK"
											  otherButtonTitles:nil];
		[alert show];
	}
}

- (void)hideKeyboard {
	[self.view endEditing:YES];
}

- (void) onRichPageButtonTapped:(NSString *)customData {
	NSLog(@"onRichPageButtonTapped: %@", customData);
}

- (void) onRichPageBackTapped {
	NSLog(@"onRichPageBackTapped");
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

	_payloadLabel.text = @"Tags sent";
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

- (void)showPromoPage:(NSString *)discount {
	CustomPageViewController *vc = [[CustomPageViewController alloc] init];
	vc.bgColor = self.view.backgroundColor;
	vc.discount = [discount integerValue];
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
	_statusLabel.text = [NSString stringWithFormat:@"Registered with push token:\n%@", token];
	_tokenInfoLabel.hidden = NO;

	NSLog(@"Delegate called: %@", _statusLabel.text);
}

//failed to register for push notifications
- (void)onDidFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
	_statusLabel.text = [NSString stringWithFormat:@"Failed to register: %@", [error description]];
}

//user pressed OK on the push notification
- (void)onPushAccepted:(PushNotificationManager *)pushManager withNotification:(NSDictionary *)pushNotification {
	[PushNotificationManager clearNotificationCenter];

	_payloadLabel.text = [NSString stringWithFormat:@"Received push notification: %@", pushNotification];
	NSLog(@"%@", _payloadLabel.text);

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

	NSString *discount = [jsonData objectForKey:@"d"];

	if (discount) {
		[self showPromoPage:discount];
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
