//
//  InteractivePush.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2016
//

#import "PWPreferences.h"

#import "PWInteractivePush.h"
#import "PWPlatformModule.h"
#import "PWNotificationCategoryBuilder.h"

@implementation PWInteractivePush

+ (void)savePushwooshCategories:(NSArray *)categories {
	[PWPreferences preferences].categories = categories;
}

+ (void)getCategoriesWithCompletion:(void (^)(NSSet*))completion {
	NSArray *categories = [PWPreferences preferences].categories;

	PWNotificationCategoryBuilder *categoryBuilder = [[PWPlatformModule module] createCategoryBuilder];
	
	@try {
		categoryBuilder = [PWInteractivePush arrayToCategories:categories];
	}
	@catch (NSException *exception) {
		PWLogError(@"Invalid categories: %@", categories);
	}
	
	[categoryBuilder addCurrentCategoriesWithCompletion:^() {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
		completion([categoryBuilder build]);
#pragma clang diagnostic pop
	}];
}

+ (void)addActions:(NSArray *)buttons withBuilder:(PWNotificationCategoryBuilder*)builder {
	int i = 0;
	for (NSDictionary *button in buttons) {
		i++;
		id actionId = button[@"id"];
		if ([actionId isKindOfClass:[NSNumber class]]) {
			actionId = [actionId stringValue];
		}
		if (![actionId isKindOfClass:[NSString class]]) {
			actionId = [@(i) stringValue];
		}
		
		NSString *label = button[@"label"];
		BOOL destructive = [button[@"type"] boolValue];
		BOOL launchApp = [button[@"startApplication"] boolValue];

		if (![label isKindOfClass:[NSString class]]) {
			PWLogError(@"Invalid action label: %@", label);
			return;
		}
		
		NSString *behaviour = button[@"behavior"];
		BOOL textInput = [behaviour isKindOfClass:[NSString class]] && [behaviour isEqualToString:@"text_input"];
		NSString *textInputTitle = button[@"text_input_title"];
		if (![textInputTitle isKindOfClass:[NSString class]]) {
			textInputTitle = nil;
		}
		NSString *textInputPlaceholder = button[@"text_input_placeholder"];
		if (![textInputPlaceholder isKindOfClass:[NSString class]]) {
			textInputPlaceholder = nil;
		}
		
		[builder pushAction];
		[builder setActionIdentifier:actionId];
		[builder setActionTitle:NSLocalizedString(label, @"title for push action")];
		[builder setActionStartApplication:launchApp];
		[builder setActionDestructive:destructive];
		[builder setActionAuthRequired:NO];
		
		if (textInput) {
			[builder setActionTextInputWithTitle:textInputTitle placeholder:textInputPlaceholder];
		}
	}
}

+ (PWNotificationCategoryBuilder *)arrayToCategories:(NSArray *)array {
	PWNotificationCategoryBuilder *builder = [[PWPlatformModule module] createCategoryBuilder];
	
	for (NSDictionary *category in array) {
		if (![category isKindOfClass:[NSDictionary class]]) {
			PWLogError(@"Invalid category: %@", category);
			continue;
		}
        NSNumber *categoryNumberId = category[@"categoryId"];
        if (![categoryNumberId isKindOfClass:[NSNumber class]]) {
            PWLogError(@"Invalid categoryId: %@", category);
            continue;
        }

		NSString *categoryId = [categoryNumberId stringValue];
		NSArray *buttons = category[@"buttons"];

		if (![categoryId isKindOfClass:[NSString class]] || ![buttons isKindOfClass:[NSArray class]]) {
			PWLogError(@"Invalid category: %@", category);
			continue;
		}
		
		[builder pushCategory];
		[builder setCategoryIdentifier:categoryId];

		[PWInteractivePush addActions:buttons withBuilder:builder];
	}
	
	return builder;
}

@end
