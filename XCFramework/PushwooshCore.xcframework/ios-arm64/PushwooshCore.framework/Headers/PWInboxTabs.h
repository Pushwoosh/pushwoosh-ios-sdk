//  PWInboxTabs.h
//  Created by André Kis

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A single Control-Panel-configured Inbox tab.
@interface PWInboxTab : NSObject <NSSecureCoding>

/// The tab's `id` in the wire contract and in the Android SDK; named `identifier`
/// here only because `id` is a reserved Objective-C keyword.
@property (readonly, nonatomic) NSString *identifier;

/// The tab's display title.
@property (readonly, nonatomic) NSString *title;

- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

/// A Control-Panel-configured list of Inbox tabs.
@interface PWInboxTabs : NSObject <NSSecureCoding>

/// The title of the synthetic "All" tab that aggregates every Inbox message.
@property (readonly, nonatomic) NSString *allTitle;

/// The configured tabs, non-empty, in server order. The "All" tab is not a member of this array.
@property (readonly, nonatomic) NSArray<PWInboxTab *> *tabs;

- (instancetype)initWithAllTitle:(NSString *)allTitle tabs:(NSArray<PWInboxTab *> *)tabs NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
