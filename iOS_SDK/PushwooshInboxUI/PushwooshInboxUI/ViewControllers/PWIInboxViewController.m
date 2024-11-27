//
//  PWIInboxViewController.m
//  PushwooshInboxUI
//
//  Created by Pushwoosh on 01/11/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWIInboxViewController.h"
#import "PWIInboxMessageViewCell.h"
#import "PWIPushwooshHelper.h"
#import "PWIInboxStyle.h"
#import "PWInbox.h"
#import "NSBundle+PWIHelper.h"
#import "PWIInboxAttachmentViewController.h"

@interface PWIInboxViewController () <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UIView *errorView;
@property (weak, nonatomic) IBOutlet UIImageView *errorImageView;
@property (weak, nonatomic) IBOutlet UILabel *errorMessageLabel;

@property (weak, nonatomic) IBOutlet UIView *emptyView;
@property (weak, nonatomic) IBOutlet UIImageView *emptyImageView;
@property (weak, nonatomic) IBOutlet UILabel *emptyMessageLabel;

@property (nonatomic) NSMutableDictionary *estimatedHeights;
@property (nonatomic) PWIInboxStyle *style;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicatorView;
@property (nonatomic) NSMutableArray<NSObject<PWInboxMessageProtocol> *> *messages;
@property (weak, nonatomic) UIRefreshControl *refreshControl;
@property (weak, nonatomic) NSObject *observer;
@property (nonatomic) BOOL isLoading;
@property (nonatomic) CGFloat tableViewHeight;

@end

@implementation PWIInboxViewController

- (instancetype)initWithStyle:(PWIInboxStyle *)style {
    NSString *stringName = self.nibName;
    if (self = [super initWithNibName:stringName bundle:[NSBundle pwi_bundleForClass:self.class]]) {
        _style = style;
        self.title = NSLocalizedString(@"Inbox",);
    }
    return self;
}

- (instancetype)initWithStyle:(PWIInboxStyle *)style andContentHeight:(CGFloat)contentHeight {
    NSString *stringName = self.nibName;
    if (self = [super initWithNibName:stringName bundle:[NSBundle pwi_bundleForClass:self.class]]) {
        _style = style;
        _tableViewHeight = contentHeight;
        self.title = NSLocalizedString(@"Inbox",);
    }
    return self;
}

- (NSString *)nibName {
    return @"PWIInboxViewController";
}

- (void)loadView {
    [[NSBundle pwi_bundleForClass:self.class] loadNibNamed:self.nibName owner:self options:nil];
    if (!_style) {
        _style = [PWIInboxStyle defaultStyle];
    }
}

- (void)updateStyle:(PWIInboxStyle *)style {
    _style = style;
    self.view.tintColor = _style.accentColor;
    self.view.backgroundColor = _style.backgroundColor;
    _refreshControl.tintColor = _style.accentColor;
    _activityIndicatorView.color = _style.accentColor;
    _tableView.separatorColor = _style.separatorColor;

    _emptyMessageLabel.font = _style.defaultFont;
    _emptyMessageLabel.textColor = _style.defaultTextColor;
    _errorMessageLabel.font = _style.defaultFont;
    _errorMessageLabel.textColor = _style.defaultTextColor;

    _errorImageView.image = _style.listErrorImage;
    _errorMessageLabel.text = _style.listErrorMessage;
    _emptyImageView.image = _style.listEmptyImage;
    _emptyMessageLabel.text = _style.listEmptyMessage;

    [self initStyleNavigationBar];
}

- (void)initStyleNavigationBar {
    NSString *title = _style.barTitle;
    if (title) {
        self.navigationItem.title = title;
    }
    UINavigationBar *bar = self.navigationController.navigationBar;
    UIColor *barAccentColor = _style.barAccentColor;
    if (barAccentColor) {
        bar.tintColor = barAccentColor;
    }
    UIColor *backgroundColor = _style.barBackgroundColor;
    if (backgroundColor) {
        bar.barTintColor = backgroundColor;
    }
    UIColor *barTextColor = _style.barTextColor;
    if (barTextColor) {
        bar.titleTextAttributes = @{NSForegroundColorAttributeName: barTextColor};
    }
}

#pragma mark -

- (void)viewDidLoad {
    [super viewDidLoad];
    if (![PWIPushwooshHelper checkPushwooshFrameworkAvailableAndRunExaptionIfNeeded]) {
        [self updateStyle:_style];
        [self showEmptyView];
        return;
    }
    __weak typeof(self) wself = self;
    _observer = [PWIPushwooshHelper.pwInbox addObserverForDidReceiveInPushNotificationCompletion:^(NSArray<NSObject<PWInboxMessageProtocol> *> *messagesAdded) {
        if (messagesAdded.count) {
            [wself reloadData];
        }
    }];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    if ([_tableView respondsToSelector:@selector(setContentInsetAdjustmentBehavior:)]) {
        _tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
#pragma clang diagnostic pop
#endif
    _errorView.hidden = YES;
    _emptyView.hidden = YES;

    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 150;
    
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(reloadData) forControlEvents:UIControlEventValueChanged];
    [_tableView addSubview:refreshControl];
    _refreshControl = refreshControl;
    [self updateStyle:_style];
    [_activityIndicatorView startAnimating];
    [self reloadData];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    _tableView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height-self.tableViewHeight);

    if (self.navigationController.navigationBar.translucent) {
        CGRect navigationBarRect = self.navigationController.navigationBar.frame;
        float insetsY = navigationBarRect.size.height + navigationBarRect.origin.y;
        UIEdgeInsets inset = UIEdgeInsetsMake(insetsY, 0, 0, 0);
        _tableView.contentInset = inset;
        _tableView.scrollIndicatorInsets = inset;
        if (_tableView.visibleCells.count) {
            [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    __weak typeof(self) wself = self;
    _observer = [PWIPushwooshHelper.pwInbox addObserverForDidReceiveInPushNotificationCompletion:^(NSArray<NSObject<PWInboxMessageProtocol> *> *messagesAdded) {
        if (messagesAdded.count) {
            [wself reloadData];
        }
    }];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [PWIPushwooshHelper.pwInbox removeObserver:_observer];
}

#pragma mark -

- (void)showErrorView {
    _tableView.hidden = YES;
    _emptyView.hidden = YES;
    [_activityIndicatorView stopAnimating];
    _errorView.hidden = NO;
}

- (void)showEmptyView {
    _tableView.hidden = YES;
    _errorView.hidden = YES;
    [_activityIndicatorView stopAnimating];
    _emptyView.hidden = NO;
}

- (void)updateMessage:(NSArray<NSObject<PWInboxMessageProtocol> *> *)messages withError:(NSError *)error {
    _errorView.hidden = YES;
    _emptyView.hidden = YES;
    if (error && !messages.count) {
        [self showErrorView];
    }
    else if (!messages.count) {
        [self showEmptyView];
    }
    
    [_activityIndicatorView stopAnimating];
    _tableView.hidden = !messages.count;
    _estimatedHeights = [NSMutableDictionary new];
    _messages = [messages mutableCopy];
    [_tableView reloadData];
}

- (void)reloadData {
    __weak typeof(self) wself = self;
    [PWIPushwooshHelper.pwInbox loadMessagesWithCompletion:^(NSArray<NSObject<PWInboxMessageProtocol> *> *messages, NSError *error) {
        [wself updateMessage:messages withError:error];
        [wself.refreshControl endRefreshing];
    }];
}

#pragma mark - UITableViewDelegate && UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSObject<PWInboxMessageProtocol> *message = _messages[indexPath.row];
    PWIInboxMessageViewCell *cell = [PWIInboxMessageViewCell pwi_cellForTableView:tableView style:_style];
    __weak typeof(self) wself = self;
    [cell setInboxAttachmentTappedCallback:^void (UIImageView *imageView, NSString *attachmentUrl) {
        [wself showInboxAttachmentViewControllerForImageView:imageView withAttachment:attachmentUrl];
    }];
    [cell updateMessage:message];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSObject<PWInboxMessageProtocol> *message = _messages[indexPath.row];
    [PWIPushwooshHelper.pwInbox performActionForMessageWithCode:message.code];
    
    if (_onMessageClickBlock) {
        _onMessageClickBlock(message);
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        PWIInboxMessageViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        [cell updateMessage:cell.message];
    });
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSObject<PWInboxMessageProtocol> *message = _messages[indexPath.row];
    NSValue *value = [NSValue valueWithNonretainedObject:message];
    if (value) {
        NSNumber *estimatedHeight = _estimatedHeights[value];
        if (estimatedHeight) {
            return estimatedHeight.floatValue;
        }
    }
    return _tableView.estimatedRowHeight;
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(PWIInboxMessageViewCell *)cell forRowAtIndexPath:(NSIndexPath*)indexPath {
    NSObject<PWInboxMessageProtocol> *message = cell.message;
    NSValue *value = [NSValue valueWithNonretainedObject:message];
    if (value) {
        _estimatedHeights[value] = @(cell.bounds.size.height);
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [PWIPushwooshHelper.pwInbox deleteMessagesWithCodes:@[_messages[indexPath.row].code]];
        [_messages removeObject:_messages[indexPath.row]];
        [_tableView beginUpdates];
        [_tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        [_tableView endUpdates];
        if (_messages.count == 0) {
            [self updateMessage:_messages withError:nil];
        }
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}

- (void)showInboxAttachmentViewControllerForImageView:(UIImageView *)imageView withAttachment:(NSString *)attachmentUrl {
    PWIInboxAttachmentViewController *attachmentViewController = [[PWIInboxAttachmentViewController alloc] initWithStyle:_style];
    attachmentViewController.modalPresentationStyle = UIModalPresentationCustom;
    attachmentViewController.transitioningDelegate = attachmentViewController;
    attachmentViewController.attachmentUrl = attachmentUrl;
    attachmentViewController.animationBeginView = imageView;
    [self presentViewController:attachmentViewController animated:YES completion:nil];
}

@end
