//
//  PWRichMediaConfig
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#import "PWUtils.h"
#import "PWRichMediaConfig.h"
#import "PWPreferences.h"

@interface PWRichMediaConfig ()

@property (nonatomic, copy) NSDictionary *localizedStrings;

@property (nonatomic, assign) BOOL iosCloseButton;
@property (nonatomic) NSString *presentationStyleKey;

@end

@implementation PWRichMediaConfig

- (instancetype)initWithContentsOfFile:(NSString *)filePath {
	self = [super init];
	if (self) {
		HEAVY_OPERATION();
		
		NSError *error = nil;
		NSData *rawContent = [NSData dataWithContentsOfFile:filePath];
		if (!rawContent) {
			PWLogError(@"Unable to read pushwoosh config file");
			return nil;
		}

		NSDictionary *parsedConfig = [NSJSONSerialization JSONObjectWithData:rawContent options:0 error:&error];
		if (error) {
			PWLogError(@"Failed to parse pushwoosh config file: @$", [error localizedDescription]);
			return nil;
		}

		if (![parsedConfig isKindOfClass:[NSDictionary class]]) {
			PWLogError(@"Invalid pushwoosh config file structure, expected top level dictionary");
			return nil;
		}

		NSDictionary *localization = parsedConfig[@"localization"];
		if (!localization || ![localization isKindOfClass:[NSDictionary class]]) {
			PWLogError(@"Invalid pushwoosh config file structure, expected \"localization\" dicrionary");
			return nil;
		}

		PWLogDebug(@"Current device preferred language: %@", [PWPreferences preferences].language);

		self.localizedStrings = localization[[PWPreferences preferences].language];

		if (!self.localizedStrings) {
			NSString *defaultLanguage = parsedConfig[@"default_language"];
            PWLogDebug(@"Device preferred language not found, using default language: %@", defaultLanguage);
			self.localizedStrings = localization[defaultLanguage];
            
            if (![_localizedStrings isKindOfClass:[NSDictionary class]]) {
                _localizedStrings = nil;
            }
		}

		PWLogDebug(@"Localized strings: %@", self.localizedStrings);

		NSNumber *iosCloseButtonObj = parsedConfig[@"ios_close_button"];
		if (iosCloseButtonObj && [iosCloseButtonObj isKindOfClass:[NSNumber class]]) {
			self.iosCloseButton = iosCloseButtonObj.boolValue;
		} else {
			self.iosCloseButton = YES;
		}
        
        NSString *presentationStyleKeyObj = parsedConfig[@"presentationStyleKey"];
        self.presentationStyleKey = presentationStyleKeyObj != nil ? presentationStyleKeyObj : @"";

		PWLogDebug(@"iosCloseButton: %d", self.iosCloseButton);
	}

	return self;
}

@end
