//
//  PWRichMediaConfig
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#if TARGET_OS_IOS || TARGET_OS_TV
#import "PWUtils.h"
#import "PWRichMediaConfig.h"
#import "PWPreferences.h"

@interface PWRichMediaConfig ()

@property (nonatomic, copy) NSDictionary *localizedStrings;

// Legacy properties
@property (nonatomic, assign) BOOL iosCloseButton;
@property (nonatomic) NSString *presentationStyleKey;

// Style settings properties
@property (nonatomic, assign) ModalWindowPosition position;
@property (nonatomic, assign) PresentModalWindowAnimation presentAnimation;
@property (nonatomic, assign) DismissModalWindowAnimation dismissAnimation;
@property (nonatomic, strong) NSArray<NSNumber *> *swipeToDismiss;

+ (ModalWindowPosition)positionFromString:(NSString *)string;
+ (PresentModalWindowAnimation)presentAnimationFromString:(NSString *)string;
+ (DismissModalWindowAnimation)dismissAnimationFromString:(NSString *)string;
+ (DismissSwipeDirection)swipeDirectionFromString:(NSString *)string;

@end

@implementation PWRichMediaConfig

- (instancetype)initWithContentsOfFile:(NSString *)filePath {
    self = [super init];
    if (self) {
        HEAVY_OPERATION();
        
        NSError *error = nil;
        NSData *rawContent = [NSData dataWithContentsOfFile:filePath];
        if (!rawContent) {
            [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"Unable to read pushwoosh config file"];
            return nil;
        }
        
        NSDictionary *parsedConfig = [NSJSONSerialization JSONObjectWithData:rawContent options:0 error:&error];
        if (error) {
            [PushwooshLog pushwooshLog:PW_LL_ERROR
                             className:self
                               message:[NSString stringWithFormat:@"Failed to parse pushwoosh config file: %@", error.localizedDescription]];
            return nil;
        }
        
        if (![parsedConfig isKindOfClass:[NSDictionary class]]) {
            [PushwooshLog pushwooshLog:PW_LL_ERROR
                             className:self
                               message:@"Invalid pushwoosh config file structure, expected top level dictionary"];
            return nil;
        }
        
        NSDictionary *localization = parsedConfig[@"localization"];
        if (!localization || ![localization isKindOfClass:[NSDictionary class]]) {
            [PushwooshLog pushwooshLog:PW_LL_ERROR
                             className:self
                               message:@"Invalid pushwoosh config file structure, expected \"localization\" dicrionary"];
            return nil;
        }
        
        [PushwooshLog pushwooshLog:PW_LL_DEBUG
                         className:self
                           message:[NSString stringWithFormat:@"Current device preferred language: %@", [PWSettings settings].language]];
        self.localizedStrings = localization[[PWSettings settings].language];
        
        if (!self.localizedStrings) {
            NSString *defaultLanguage = parsedConfig[@"default_language"];
            [PushwooshLog pushwooshLog:PW_LL_DEBUG
                             className:self
                               message:[NSString stringWithFormat:@"Device preferred language not found, using default language: %@", defaultLanguage]];
            self.localizedStrings = localization[defaultLanguage];
            
            if (![_localizedStrings isKindOfClass:[NSDictionary class]]) {
                _localizedStrings = nil;
            }
        }
        
        [PushwooshLog pushwooshLog:PW_LL_DEBUG
                         className:self
                           message:[NSString stringWithFormat:@"Localized strings: %@", self.localizedStrings]];
        
        NSNumber *iosCloseButtonObj = parsedConfig[@"ios_close_button"];
        if (iosCloseButtonObj && [iosCloseButtonObj isKindOfClass:[NSNumber class]]) {
            self.iosCloseButton = iosCloseButtonObj.boolValue;
        } else {
            self.iosCloseButton = YES;
        }
        
        NSString *presentationStyleKeyObj = parsedConfig[@"presentationStyleKey"];
        self.presentationStyleKey = presentationStyleKeyObj != nil ? presentationStyleKeyObj : @"";
        
        [self parseModernConfiguration:parsedConfig];
        
        [PushwooshLog pushwooshLog:PW_LL_DEBUG
                         className:self
                           message:[NSString stringWithFormat:@"iosCloseButton: %d", self.iosCloseButton]];
    }
    
    return self;
}

#pragma mark - Modern Configuration Parsing

- (void)parseModernConfiguration:(NSDictionary *)config {
    NSDictionary *styleDict = config[@"style_settings"];
    if ([styleDict isKindOfClass:[NSDictionary class]]) {
        [self parseStyleSettings:styleDict];
    } else {
        self.position = PWModalWindowPositionDefault;
        self.presentAnimation = PWAnimationPresentNone;
        self.dismissAnimation = PWAnimationDismissDefault;
        self.swipeToDismiss = @[];
    }
}

- (void)parseStyleSettings:(NSDictionary *)styleDict {
    self.position = [self.class positionFromString:styleDict[@"position"]];
    self.presentAnimation = [self.class presentAnimationFromString:styleDict[@"present_animation"]];
    self.dismissAnimation = [self.class dismissAnimationFromString:styleDict[@"dismiss_animation"]];
    
    NSMutableArray *swipeArray = [NSMutableArray array];
    id swipeValue = styleDict[@"swipe_to_dismiss"];
    if ([swipeValue isKindOfClass:[NSArray class]]) {
        NSArray *swipeDirections = (NSArray *)swipeValue;
        for (id direction in swipeDirections) {
            if ([direction isKindOfClass:[NSString class]]) {
                DismissSwipeDirection swipeDirection = [self.class swipeDirectionFromString:(NSString *)direction];
                if (swipeDirection != PWSwipeDismissNone) {
                    [swipeArray addObject:@(swipeDirection)];
                }
            }
        }
    }
    self.swipeToDismiss = [swipeArray copy];
}

#pragma mark - String to Enum Conversion

+ (ModalWindowPosition)positionFromString:(NSString *)string {
    if (!string || ![string isKindOfClass:[NSString class]]) {
        return PWModalWindowPositionDefault;
    }
    
    if ([string isEqualToString:@"fullscreen"]) return PWModalWindowPositionFullScreen;
    if ([string isEqualToString:@"top"]) return PWModalWindowPositionTop;
    if ([string isEqualToString:@"center"]) return PWModalWindowPositionCenter;
    if ([string isEqualToString:@"bottom"]) return PWModalWindowPositionBottom;
    return PWModalWindowPositionDefault;
}

+ (PresentModalWindowAnimation)presentAnimationFromString:(NSString *)string {
    if (!string || ![string isKindOfClass:[NSString class]]) {
        return PWAnimationPresentNone;
    }
    
    if ([string isEqualToString:@"left"]) return PWAnimationPresentFromLeft;
    if ([string isEqualToString:@"right"]) return PWAnimationPresentFromRight;
    if ([string isEqualToString:@"up"]) return PWAnimationPresentFromTop;
    if ([string isEqualToString:@"down"]) return PWAnimationPresentFromBottom;
    return PWAnimationPresentNone;
}

+ (DismissModalWindowAnimation)dismissAnimationFromString:(NSString *)string {
    if (!string || ![string isKindOfClass:[NSString class]]) {
        return PWAnimationDismissDefault;
    }
    
    if ([string isEqualToString:@"left"]) return PWAnimationDismissLeft;
    if ([string isEqualToString:@"right"]) return PWAnimationDismissRight;
    if ([string isEqualToString:@"up"]) return PWAnimationDismissUp;
    if ([string isEqualToString:@"down"]) return PWAnimationDismissDown;
    return PWAnimationDismissDefault;
}

+ (DismissSwipeDirection)swipeDirectionFromString:(NSString *)string {
    if (!string || ![string isKindOfClass:[NSString class]]) {
        return PWSwipeDismissNone;
    }
    
    if ([string isEqualToString:@"left"]) return PWSwipeDismissLeft;
    if ([string isEqualToString:@"right"]) return PWSwipeDismissRight;
    if ([string isEqualToString:@"up"]) return PWSwipeDismissUp;
    if ([string isEqualToString:@"down"]) return PWSwipeDismissDown;
    return PWSwipeDismissNone;
}

@end
#endif
