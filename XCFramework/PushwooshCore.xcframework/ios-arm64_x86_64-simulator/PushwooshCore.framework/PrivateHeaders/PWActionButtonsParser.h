//
//  PWActionButtonsParser.h
//  PushwooshCore
//
//  Created by André Kis on 08.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PWActionButton.h>

NS_ASSUME_NONNULL_BEGIN

/// Reads the buttons a push carries. Tolerant by design: a payload it cannot make sense of costs the
/// push its buttons, and one button it cannot make sense of costs only that button.
@interface PWActionButtonsParser : NSObject

/// The buttons of a push, in payload order, at most PWActionButtonsLimit of them. Empty when the push
/// carries no buttons, when the value is not a string holding a JSON array, or when no entry is usable.
+ (NSArray<PWActionButton *> *)buttonsFromUserInfo:(nullable NSDictionary *)userInfo;

/// The button a tapped action identifier names, or nil when the identifier is not one of this push's
/// buttons — which is what every old-style category button and every plain tap answers.
+ (nullable PWActionButton *)buttonForActionIdentifier:(nullable NSString *)actionIdentifier
                                            inUserInfo:(nullable NSDictionary *)userInfo;

@end

NS_ASSUME_NONNULL_END
