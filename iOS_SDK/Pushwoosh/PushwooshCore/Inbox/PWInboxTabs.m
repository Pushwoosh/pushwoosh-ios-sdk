//  PWInboxTabs.m
//  Created by André Kis

#import "PWInboxTabs.h"

@implementation PWInboxTab

- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title {
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _title = [title copy];
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[PWInboxTab class]]) {
        return NO;
    }
    PWInboxTab *other = (PWInboxTab *)object;
    return [self.identifier isEqualToString:other.identifier] && [self.title isEqualToString:other.title];
}

- (NSUInteger)hash {
    return self.identifier.hash ^ self.title.hash;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.identifier forKey:@"identifier"];
    [coder encodeObject:self.title forKey:@"title"];
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    NSString *identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
    NSString *title = [coder decodeObjectOfClass:[NSString class] forKey:@"title"];
    if (!identifier || !title) {
        self = nil;
        return nil;
    }
    return [self initWithIdentifier:identifier title:title];
}

@end

@implementation PWInboxTabs

- (instancetype)initWithAllTitle:(NSString *)allTitle tabs:(NSArray<PWInboxTab *> *)tabs {
    self = [super init];
    if (self) {
        _allTitle = [allTitle copy];
        _tabs = [tabs copy];
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[PWInboxTabs class]]) {
        return NO;
    }
    PWInboxTabs *other = (PWInboxTabs *)object;
    return [self.allTitle isEqualToString:other.allTitle] && [self.tabs isEqualToArray:other.tabs];
}

- (NSUInteger)hash {
    return self.allTitle.hash ^ self.tabs.hash;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.allTitle forKey:@"allTitle"];
    [coder encodeObject:self.tabs forKey:@"tabs"];
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    NSString *allTitle = [coder decodeObjectOfClass:[NSString class] forKey:@"allTitle"];
    NSSet *tabsClasses = [NSSet setWithObjects:[NSArray class], [PWInboxTab class], nil];
    NSArray<PWInboxTab *> *tabs = [coder decodeObjectOfClasses:tabsClasses forKey:@"tabs"];
    if (!allTitle || !tabs) {
        self = nil;
        return nil;
    }
    return [self initWithAllTitle:allTitle tabs:tabs];
}

@end
