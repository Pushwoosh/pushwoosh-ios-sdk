//
//  PWPushStatRequest
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWPushStatRequest.h"
#import "PWActionButton.h"
#import "PWActionButtonsParser.h"

@interface PWPushStatRequest ()

@end

@implementation PWPushStatRequest

- (NSString *)methodName {
	return @"pushStat";
}

- (NSDictionary *)requestDictionary {
    NSMutableDictionary *dict = [super requestDictionary].mutableCopy;
    NSString *metadata = self.pushDict[@"md"];

    if (metadata != nil) {
        dict[@"metaData"] = metadata;
    }

    PWActionButton *button = [PWActionButtonsParser buttonForActionIdentifier:self.pushDict[PWActionIdentifierKey]
                                                                  inUserInfo:self.pushDict];

    if (button != nil) {
        dict[PWActionButtonStatField] = button.identifier;
    }

    return dict;
}


@end
