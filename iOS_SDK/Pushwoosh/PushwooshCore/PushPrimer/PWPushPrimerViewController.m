//
//  PWPushPrimerViewController.m
//  PushwooshCore
//
//  Created by André Kis on 15.06.2026.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if TARGET_OS_IOS

#import "PWPushPrimerViewController.h"

@interface PWPushPrimerViewController ()

@property (nonatomic) PWPushPrimerPosition position;
@property (nonatomic, strong) PWPushPrimerConfig *config;
@property (nonatomic, copy) void (^onAccept)(void);
@property (nonatomic, copy) void (^onDecline)(void);
@property (nonatomic, strong) UIView *sheet;
@property (nonatomic, strong) UIImageView *heroImageView;
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@property (nonatomic, assign) BOOL didSetInitial;
@property (nonatomic, assign) BOOL didAnimateIn;

@end

@implementation PWPushPrimerViewController

- (instancetype)initWithConfig:(PWPushPrimerConfig *)config
                      onAccept:(void (^)(void))onAccept
                     onDecline:(void (^)(void))onDecline {
    if (self = [super init]) {
        _config = config;
        _position = config.position;
        _onAccept = [onAccept copy];
        _onDecline = [onDecline copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];

    UIColor *accent = self.config.acceptButtonColor ?: [UIColor systemBlueColor];

    CGFloat radius;
    CACornerMask corners;
    CGSize shadowOffset;
    switch (self.position) {
        case PWPushPrimerPositionTop:
            radius = 22;
            corners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
            shadowOffset = CGSizeMake(0, 6);
            break;
        case PWPushPrimerPositionCenter:
            radius = 24;
            corners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
            shadowOffset = CGSizeMake(0, 10);
            break;
        case PWPushPrimerPositionBottom:
        default:
            radius = 28;
            corners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
            shadowOffset = CGSizeMake(0, -8);
            break;
    }
    if (self.config.cornerRadiusSet) {
        radius = self.config.cornerRadius;
    }

    self.sheet = [UIView new];
    self.sheet.translatesAutoresizingMaskIntoConstraints = NO;
    self.sheet.backgroundColor = self.config.backgroundColor ?: [UIColor systemBackgroundColor];
    self.sheet.layer.cornerRadius = radius;
    self.sheet.layer.cornerCurve = kCACornerCurveContinuous;
    self.sheet.layer.maskedCorners = corners;
    self.sheet.layer.shadowColor = [UIColor blackColor].CGColor;
    self.sheet.layer.shadowOpacity = 0.18;
    self.sheet.layer.shadowRadius = 22;
    self.sheet.layer.shadowOffset = shadowOffset;
    [self.view addSubview:self.sheet];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped:)];
    [self.view addGestureRecognizer:tap];

    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray array];

    [self applyGradientBackgroundIfNeededWithRadius:radius corners:corners];

    switch (self.position) {
        case PWPushPrimerPositionTop:
            [constraints addObjectsFromArray:@[
                [self.sheet.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:15],
                [self.sheet.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-15],
                [self.sheet.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
            ]];
            break;
        case PWPushPrimerPositionCenter:
            [constraints addObjectsFromArray:@[
                [self.sheet.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
                [self.sheet.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:15],
                [self.sheet.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-15],
            ]];
            break;
        case PWPushPrimerPositionBottom:
        default:
            [constraints addObjectsFromArray:@[
                [self.sheet.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
                [self.sheet.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
                [self.sheet.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
            ]];
            break;
    }

    if (self.position == PWPushPrimerPositionTop) {
        [self buildBannerContentWithAccent:accent constraints:constraints];
    } else {
        [self buildCenteredContentWithAccent:accent constraints:constraints];
    }

    [NSLayoutConstraint activateConstraints:constraints];
    [self loadImageIfNeeded];
}

- (void)applyGradientBackgroundIfNeededWithRadius:(CGFloat)radius corners:(CACornerMask)corners {
    NSArray<UIColor *> *colors = self.config.backgroundGradientColors;
    if (colors.count == 0) {
        return;
    }

    NSMutableArray *cgColors = [NSMutableArray arrayWithCapacity:colors.count];
    for (UIColor *color in colors) {
        [cgColors addObject:(id)color.CGColor];
    }

    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.colors = cgColors;
    gradient.startPoint = CGPointMake(0.0, 0.0);
    gradient.endPoint = CGPointMake(1.0, 1.0);
    gradient.cornerRadius = radius;
    gradient.cornerCurve = kCACornerCurveContinuous;
    gradient.maskedCorners = corners;
    gradient.masksToBounds = YES;
    [self.sheet.layer insertSublayer:gradient atIndex:0];
    self.gradientLayer = gradient;
}

- (void)buildBannerContentWithAccent:(UIColor *)accent constraints:(NSMutableArray<NSLayoutConstraint *> *)constraints {
    UIView *iconView = [self bannerIconViewWithAccent:accent];

    UILabel *titleLabel = [self bannerLabelWithText:(self.config.title ?: @"")
                                               font:[self roundedFontOfSize:15 weight:UIFontWeightSemibold]
                                              color:(self.config.titleColor ?: [UIColor labelColor])
                                              lines:1];
    UILabel *subtitleLabel = [self bannerLabelWithText:(self.config.message ?: @"")
                                                  font:[self roundedFontOfSize:14 weight:UIFontWeightRegular]
                                                 color:(self.config.messageColor ?: [UIColor secondaryLabelColor])
                                                 lines:2];
    UILabel *nowLabel = [self bannerLabelWithText:@"now"
                                             font:[UIFont systemFontOfSize:12 weight:UIFontWeightRegular]
                                            color:[UIColor tertiaryLabelColor]
                                            lines:1];
    [nowLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [nowLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, subtitleLabel]];
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.alignment = UIStackViewAlignmentFill;
    textStack.spacing = 2;
    textStack.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *header = [UIView new];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:iconView];
    [header addSubview:nowLabel];
    [header addSubview:textStack];

    UIButton *acceptButton = [self bannerButtonWithTitle:(self.config.acceptButtonTitle ?: @"Allow")
                                              background:accent
                                               textColor:(self.config.acceptButtonTextColor ?: [UIColor whiteColor])
                                                  weight:UIFontWeightSemibold
                                                  action:@selector(acceptTapped)];
    UIButton *declineButton = [self bannerButtonWithTitle:(self.config.declineButtonTitle ?: @"Not now")
                                               background:(self.config.declineButtonColor ?: [UIColor tertiarySystemFillColor])
                                                textColor:(self.config.declineButtonTextColor ?: [UIColor labelColor])
                                                   weight:UIFontWeightMedium
                                                   action:@selector(declineTapped)];

    UIStackView *buttonsRow = [[UIStackView alloc] initWithArrangedSubviews:@[declineButton, acceptButton]];
    buttonsRow.axis = UILayoutConstraintAxisHorizontal;
    buttonsRow.distribution = UIStackViewDistributionFillEqually;
    buttonsRow.alignment = UIStackViewAlignmentFill;
    buttonsRow.spacing = 10;
    buttonsRow.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *outer = [[UIStackView alloc] initWithArrangedSubviews:@[header, buttonsRow]];
    outer.axis = UILayoutConstraintAxisVertical;
    outer.alignment = UIStackViewAlignmentFill;
    outer.spacing = 14;
    outer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.sheet addSubview:outer];

    [constraints addObjectsFromArray:@[
        [outer.topAnchor constraintEqualToAnchor:self.sheet.topAnchor constant:14],
        [outer.leadingAnchor constraintEqualToAnchor:self.sheet.leadingAnchor constant:16],
        [outer.trailingAnchor constraintEqualToAnchor:self.sheet.trailingAnchor constant:-16],
        [outer.bottomAnchor constraintEqualToAnchor:self.sheet.bottomAnchor constant:-14],

        [iconView.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [iconView.topAnchor constraintEqualToAnchor:header.topAnchor],
        [iconView.widthAnchor constraintEqualToConstant:40],
        [iconView.heightAnchor constraintEqualToConstant:40],
        [iconView.bottomAnchor constraintLessThanOrEqualToAnchor:header.bottomAnchor],

        [nowLabel.topAnchor constraintEqualToAnchor:header.topAnchor constant:1],
        [nowLabel.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],

        [textStack.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:10],
        [textStack.topAnchor constraintEqualToAnchor:header.topAnchor],
        [textStack.trailingAnchor constraintLessThanOrEqualToAnchor:nowLabel.leadingAnchor constant:-8],
        [textStack.bottomAnchor constraintEqualToAnchor:header.bottomAnchor],

        [buttonsRow.heightAnchor constraintEqualToConstant:42],
    ]];
}

- (UIView *)bannerIconViewWithAccent:(UIColor *)accent {
    UIImage *icon = self.config.image ?: [self appIconImage];
    if (icon != nil) {
        UIImageView *iv = [[UIImageView alloc] initWithImage:icon];
        iv.translatesAutoresizingMaskIntoConstraints = NO;
        iv.contentMode = UIViewContentModeScaleAspectFill;
        iv.clipsToBounds = YES;
        iv.layer.cornerRadius = 9;
        iv.layer.cornerCurve = kCACornerCurveContinuous;
        return iv;
    }

    UIView *square = [UIView new];
    square.translatesAutoresizingMaskIntoConstraints = NO;
    square.backgroundColor = [accent colorWithAlphaComponent:0.16];
    square.layer.cornerRadius = 9;
    square.layer.cornerCurve = kCACornerCurveContinuous;

    UIImageView *glyph = [UIImageView new];
    glyph.translatesAutoresizingMaskIntoConstraints = NO;
    glyph.contentMode = UIViewContentModeScaleAspectFit;
    glyph.tintColor = accent;
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightSemibold];
    glyph.image = [UIImage systemImageNamed:@"bell.badge.fill" withConfiguration:cfg];
    [square addSubview:glyph];
    [NSLayoutConstraint activateConstraints:@[
        [glyph.centerXAnchor constraintEqualToAnchor:square.centerXAnchor],
        [glyph.centerYAnchor constraintEqualToAnchor:square.centerYAnchor],
    ]];
    return square;
}

- (UIImage *)appIconImage {
    NSDictionary *icons = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIcons"];
    NSDictionary *primary = icons[@"CFBundlePrimaryIcon"];
    NSArray *files = primary[@"CFBundleIconFiles"];
    NSString *name = files.lastObject;
    return name.length > 0 ? [UIImage imageNamed:name] : nil;
}

- (UILabel *)bannerLabelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = lines;
    label.textAlignment = NSTextAlignmentLeft;
    return label;
}

- (UIButton *)bannerButtonWithTitle:(NSString *)title
                         background:(UIColor *)background
                          textColor:(UIColor *)textColor
                             weight:(UIFontWeight)weight
                             action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = background;
    button.layer.cornerRadius = 12;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:textColor forState:UIControlStateNormal];
    button.titleLabel.font = [self roundedFontOfSize:15 weight:weight];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self applyCustomButtonStyleTo:button];
    return button;
}

- (void)buildCenteredContentWithAccent:(UIColor *)accent constraints:(NSMutableArray<NSLayoutConstraint *> *)constraints {
    CGFloat titleSize, msgSize, badgeSize, glyphPt, heroH, acceptH, declineH, stackTop, hInset;
    BOOL showGrabber;
    NSLayoutYAxisAnchor *contentBottomAnchor;
    CGFloat contentBottomConst;

    if (self.position == PWPushPrimerPositionCenter) {
        titleSize = 22; msgSize = 15; badgeSize = 64; glyphPt = 26; heroH = 88;
        acceptH = 52; declineH = 46; stackTop = 26; hInset = 24; showGrabber = NO;
        contentBottomAnchor = self.sheet.bottomAnchor; contentBottomConst = -24;
    } else {
        titleSize = 24; msgSize = 15.5; badgeSize = 72; glyphPt = 30; heroH = 104;
        acceptH = 54; declineH = 48; stackTop = 34; hInset = 24; showGrabber = YES;
        contentBottomAnchor = self.sheet.safeAreaLayoutGuide.bottomAnchor; contentBottomConst = -16;
    }

    UIView *accessory = [self centeredAccessoryWithAccent:accent badgeSize:badgeSize glyphPoint:glyphPt heroDiameter:heroH];
    UILabel *titleLabel = [self centeredLabelWithText:self.config.title
                                                 font:[self roundedFontOfSize:titleSize weight:UIFontWeightBold]
                                                color:self.config.titleColor ?: [UIColor labelColor]];
    UILabel *messageLabel = [self centeredLabelWithText:self.config.message
                                                   font:[self roundedFontOfSize:msgSize weight:UIFontWeightRegular]
                                                  color:self.config.messageColor ?: [UIColor secondaryLabelColor]];
    UIButton *acceptButton = [self centeredPrimaryButtonWithAccent:accent];
    UIButton *declineButton = [self centeredSecondaryButton];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[accessory, titleLabel, messageLabel, acceptButton, declineButton]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.spacing = 8;
    [stack setCustomSpacing:22 afterView:accessory];
    [stack setCustomSpacing:26 afterView:messageLabel];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.sheet addSubview:stack];

    [constraints addObjectsFromArray:@[
        [stack.topAnchor constraintEqualToAnchor:self.sheet.topAnchor constant:stackTop],
        [stack.leadingAnchor constraintEqualToAnchor:self.sheet.leadingAnchor constant:hInset],
        [stack.trailingAnchor constraintEqualToAnchor:self.sheet.trailingAnchor constant:-hInset],
        [stack.bottomAnchor constraintEqualToAnchor:contentBottomAnchor constant:contentBottomConst],
        [acceptButton.heightAnchor constraintEqualToConstant:acceptH],
        [declineButton.heightAnchor constraintEqualToConstant:declineH],
    ]];

    if (showGrabber) {
        UIView *grabber = [UIView new];
        grabber.translatesAutoresizingMaskIntoConstraints = NO;
        grabber.backgroundColor = [UIColor tertiaryLabelColor];
        grabber.layer.cornerRadius = 2.5;
        [self.sheet addSubview:grabber];
        [constraints addObjectsFromArray:@[
            [grabber.topAnchor constraintEqualToAnchor:self.sheet.topAnchor constant:10],
            [grabber.centerXAnchor constraintEqualToAnchor:self.sheet.centerXAnchor],
            [grabber.widthAnchor constraintEqualToConstant:38],
            [grabber.heightAnchor constraintEqualToConstant:5],
        ]];
    }
}

- (UIView *)centeredAccessoryWithAccent:(UIColor *)accent
                              badgeSize:(CGFloat)badgeSize
                             glyphPoint:(CGFloat)glyphPoint
                           heroDiameter:(CGFloat)heroDiameter {
    UIView *wrapper = [UIView new];
    wrapper.translatesAutoresizingMaskIntoConstraints = NO;

    if (self.config.image != nil || self.config.imageURL.length > 0) {
        self.heroImageView = [UIImageView new];
        self.heroImageView.translatesAutoresizingMaskIntoConstraints = NO;
        self.heroImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.heroImageView.clipsToBounds = YES;
        self.heroImageView.layer.cornerRadius = heroDiameter / 2.0;
        self.heroImageView.backgroundColor = [UIColor secondarySystemBackgroundColor];
        self.heroImageView.image = self.config.image;
        [wrapper addSubview:self.heroImageView];
        [NSLayoutConstraint activateConstraints:@[
            [self.heroImageView.topAnchor constraintEqualToAnchor:wrapper.topAnchor],
            [self.heroImageView.bottomAnchor constraintEqualToAnchor:wrapper.bottomAnchor],
            [self.heroImageView.centerXAnchor constraintEqualToAnchor:wrapper.centerXAnchor],
            [self.heroImageView.widthAnchor constraintEqualToConstant:heroDiameter],
            [self.heroImageView.heightAnchor constraintEqualToConstant:heroDiameter],
        ]];
        return wrapper;
    }

    UIView *badge = [UIView new];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.backgroundColor = [accent colorWithAlphaComponent:0.14];
    badge.layer.cornerRadius = badgeSize / 2.0;
    badge.layer.cornerCurve = kCACornerCurveContinuous;
    [wrapper addSubview:badge];

    UIImageView *glyph = [UIImageView new];
    glyph.translatesAutoresizingMaskIntoConstraints = NO;
    glyph.contentMode = UIViewContentModeScaleAspectFit;
    glyph.tintColor = accent;
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:glyphPoint weight:UIImageSymbolWeightSemibold];
    glyph.image = [UIImage systemImageNamed:@"bell.badge.fill" withConfiguration:cfg];
    [badge addSubview:glyph];

    [NSLayoutConstraint activateConstraints:@[
        [badge.topAnchor constraintEqualToAnchor:wrapper.topAnchor],
        [badge.bottomAnchor constraintEqualToAnchor:wrapper.bottomAnchor],
        [badge.centerXAnchor constraintEqualToAnchor:wrapper.centerXAnchor],
        [badge.widthAnchor constraintEqualToConstant:badgeSize],
        [badge.heightAnchor constraintEqualToConstant:badgeSize],
        [glyph.centerXAnchor constraintEqualToAnchor:badge.centerXAnchor],
        [glyph.centerYAnchor constraintEqualToAnchor:badge.centerYAnchor],
    ]];
    return wrapper;
}

- (UILabel *)centeredLabelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    return label;
}

- (UIButton *)centeredPrimaryButtonWithAccent:(UIColor *)accent {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = accent;
    button.layer.cornerRadius = 16;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    [button setTitle:(self.config.acceptButtonTitle ?: @"Allow") forState:UIControlStateNormal];
    [button setTitleColor:(self.config.acceptButtonTextColor ?: [UIColor whiteColor]) forState:UIControlStateNormal];
    button.titleLabel.font = [self roundedFontOfSize:17 weight:UIFontWeightSemibold];
    [button addTarget:self action:@selector(acceptTapped) forControlEvents:UIControlEventTouchUpInside];
    [self applyCustomButtonStyleTo:button];
    return button;
}

- (UIButton *)centeredSecondaryButton {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = self.config.declineButtonColor ?: [UIColor clearColor];
    button.layer.cornerRadius = 16;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    [button setTitle:(self.config.declineButtonTitle ?: @"Not now") forState:UIControlStateNormal];
    [button setTitleColor:(self.config.declineButtonTextColor ?: [UIColor secondaryLabelColor]) forState:UIControlStateNormal];
    button.titleLabel.font = [self roundedFontOfSize:16 weight:UIFontWeightMedium];
    [button addTarget:self action:@selector(declineTapped) forControlEvents:UIControlEventTouchUpInside];
    [self applyCustomButtonStyleTo:button];
    return button;
}

- (void)applyCustomButtonStyleTo:(UIButton *)button {
    if (self.config.buttonCornerRadiusSet) {
        button.layer.cornerRadius = self.config.buttonCornerRadius;
    }
    if (self.config.buttonBorderColor != nil) {
        button.layer.borderColor = self.config.buttonBorderColor.CGColor;
        button.layer.borderWidth = 1.0;
    }
}

- (UIFont *)roundedFontOfSize:(CGFloat)size weight:(UIFontWeight)weight {
    UIFont *base = [UIFont systemFontOfSize:size weight:weight];
    if (@available(iOS 13.0, *)) {
        UIFontDescriptor *desc = [base.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
        if (desc) {
            return [UIFont fontWithDescriptor:desc size:size];
        }
    }
    return base;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.gradientLayer != nil) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        self.gradientLayer.frame = self.sheet.bounds;
        [CATransaction commit];
    }
    if (!self.didSetInitial && !CGRectIsEmpty(self.sheet.bounds)) {
        self.didSetInitial = YES;
        [self applyDismissedState];
    }
}

- (void)applyDismissedState {
    switch (self.position) {
        case PWPushPrimerPositionTop:
            self.sheet.transform = CGAffineTransformMakeTranslation(0, -CGRectGetMaxY(self.sheet.frame));
            break;
        case PWPushPrimerPositionCenter:
            self.sheet.transform = CGAffineTransformMakeScale(0.92, 0.92);
            self.sheet.alpha = 0;
            break;
        case PWPushPrimerPositionBottom:
        default:
            self.sheet.transform = CGAffineTransformMakeTranslation(0, CGRectGetHeight(self.sheet.bounds));
            break;
    }
}

- (void)applyPresentedState {
    self.sheet.transform = CGAffineTransformIdentity;
    self.sheet.alpha = 1;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.didAnimateIn) {
        return;
    }
    self.didAnimateIn = YES;

    UIColor *dim = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    if (self.position == PWPushPrimerPositionCenter) {
        [UIView animateWithDuration:0.3
                              delay:0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.view.backgroundColor = dim;
            [self applyPresentedState];
        } completion:nil];
    } else {
        [UIView animateWithDuration:0.5
                              delay:0
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.4
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.view.backgroundColor = dim;
            [self applyPresentedState];
        } completion:nil];
    }
}

- (void)dismissAnimatedThen:(void (^)(void))action {
    [UIView animateWithDuration:0.26
                          delay:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        self.view.backgroundColor = [UIColor clearColor];
        [self applyDismissedState];
    } completion:^(BOOL finished) {
        if (action) {
            action();
        }
    }];
}

- (void)loadImageIfNeeded {
    if (self.config.image != nil) {
        return;
    }
    NSString *urlString = self.config.imageURL;
    if (urlString.length == 0 || self.heroImageView == nil) {
        return;
    }
    NSURL *url = [NSURL URLWithString:urlString];
    if (url == nil) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url
                                                            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data == nil) {
            return;
        }
        UIImage *image = [UIImage imageWithData:data];
        if (image == nil) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.heroImageView.image = image;
        });
    }];
    [task resume];
}

- (void)backgroundTapped:(UITapGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:self.view];
    if (CGRectContainsPoint(self.sheet.frame, location)) {
        return;
    }
    [self declineTapped];
}

- (void)acceptTapped {
    __weak typeof(self) weakSelf = self;
    [self dismissAnimatedThen:^{
        if (weakSelf.onAccept) {
            weakSelf.onAccept();
        }
    }];
}

- (void)declineTapped {
    __weak typeof(self) weakSelf = self;
    [self dismissAnimatedThen:^{
        if (weakSelf.onDecline) {
            weakSelf.onDecline();
        }
    }];
}

@end

#endif
