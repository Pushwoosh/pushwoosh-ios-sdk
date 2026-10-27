//  PWInboxTabsFactory.h
//  Created by André Kis

#import <Foundation/Foundation.h>

@class PWInboxTabs;

/// Parses the server's `inbox_tabs` payload into a `PWInboxTabs` value.
@interface PWInboxTabsFactory : NSObject

+ (nullable PWInboxTabs *)tabsFromPayload:(nullable id)payload;

@end
