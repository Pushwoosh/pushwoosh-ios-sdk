//  PWInboxTabsFactory.m
//  Created by André Kis

#import "PWInboxTabsFactory.h"
#import "PWInboxTabs.h"
#import "NSDictionary+PWDictUtils.h"

@implementation PWInboxTabsFactory

+ (nullable PWInboxTabs *)tabsFromPayload:(nullable id)payload {
    if (![payload isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *dictionary = (NSDictionary *)payload;
    NSString *allTitle = [dictionary pw_stringForKey:@"all_title"];
    if (allTitle.length == 0) {
        return nil;
    }

    NSArray *rawTabs = [dictionary pw_arrayForKey:@"tabs"];
    NSMutableArray<PWInboxTab *> *tabs = [NSMutableArray new];
    NSMutableSet<NSString *> *seenIdentifiers = [NSMutableSet new];
    for (id rawTab in rawTabs) {
        if (![rawTab isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *tabDictionary = (NSDictionary *)rawTab;
        NSString *identifier = [tabDictionary pw_stringForKey:@"id"];
        NSString *title = [tabDictionary pw_stringForKey:@"title"];
        if (identifier.length == 0 || title.length == 0 || [seenIdentifiers containsObject:identifier]) {
            continue;
        }
        [seenIdentifiers addObject:identifier];
        [tabs addObject:[[PWInboxTab alloc] initWithIdentifier:identifier title:title]];
    }

    if (tabs.count == 0) {
        return nil;
    }

    return [[PWInboxTabs alloc] initWithAllTitle:allTitle tabs:tabs];
}

@end
