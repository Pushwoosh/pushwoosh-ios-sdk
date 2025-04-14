//
//  PWResource.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#import "PWPushRuntime.h"
#import "PWResource.h"
#import "PWZipArchive.h"
#import "PWRequestManager.h"
#import "PWNetworkModule.h"
#import "NSDictionary+PWDictUtils.h"
#import "PWUtils.h"
#import "PWGDPRManager+Internal.h"
#import "PWCache.h"
#import "PWConfig.h"
#import <WebKit/WebKit.h>

@interface PWResource ()

@property (nonatomic, strong) NSString *presentationStyleKey;

@property (nonatomic, strong) PWRichMediaConfig *config;

@property (nonatomic, strong) NSMutableArray *downloadListeners;

@property (nonatomic, strong) NSError *lastError;

@end

@implementation PWResource

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject:_code forKey:@"code"];
	[aCoder encodeObject:_url forKey:@"url"];
	[aCoder encodeDouble:_updated forKey:@"updated"];
    [aCoder encodeBool:_required forKey:@"required"];
	[aCoder encodeBool:_closeButton forKey:@"closeButton"];
	[aCoder encodeObject:_presentationStyleKey forKey:@"presentationStyleKey"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
	if (self = [self init]) {
        _code = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"code"];
        _url = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"url"];
        _updated = [aDecoder decodeDoubleForKey:@"updated"];
        _required = [aDecoder decodeBoolForKey:@"required"];
		_closeButton = [aDecoder decodeBoolForKey:@"closeButton"];
        _presentationStyleKey = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"presentationStyleKey"];
		_downloadListeners = [NSMutableArray new];
		_locked = NO;
	}
	return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
	if (self = [self init]) {
		_code = [dictionary pw_stringForKey:@"code"];
        _url = [dictionary pw_stringForKey:@"url"];
		id updatedValue = [dictionary pw_objectForKey:@"updated" ofTypes:@[ [NSString class], [NSNumber class] ]];
		_updated = [updatedValue doubleValue];
        id requiredValue = [dictionary pw_objectForKey:@"required" ofTypes:@[ [NSString class], [NSNumber class] ]];
        _required = [requiredValue boolValue];
        _presentationStyleKey = [dictionary pw_stringForKey:@"presentationStyleKey"];
		id closeButtonValue = [dictionary pw_objectForKey:@"closeButtonType" ofTypes:@[ [NSString class], [NSNumber class] ]];
		_closeButton = [closeButtonValue boolValue];
		_tags = [dictionary pw_dictionaryForKey:@"tags"];
        _businessCase = [dictionary pw_stringForKey:@"businessCase"];
        
        NSString *gdprString = [dictionary pw_stringForKey:@"gdpr"];
        
        if (gdprString.length > 0) {
            if ([gdprString isEqualToString:@"Consent"]) {
                [PWGDPRManager sharedManager].gdprConsentResource = self;
            } else if ([gdprString isEqualToString:@"Delete"]) {
                [PWGDPRManager sharedManager].gdprDeletionResource = self;
            }
            
            [PWGDPRManager sharedManager].available = YES;
        }

		if (!_code || !updatedValue || !_url) {
            [PushwooshLog pushwooshLog:PW_LL_ERROR
                             className:self
                               message:[NSString stringWithFormat:@"Invalid inapp: %@", dictionary]];
			return nil;
		}

		_downloadListeners = [NSMutableArray new];
		_locked = NO;
	}
	return self;
}

- (IAResourcePresentationStyle)presentationStyle {
	if ([_presentationStyleKey isEqualToString:@"fullscreen"]) {
		return IAResourcePresentationFullScreen;
	} else if ([_presentationStyleKey isEqualToString:@"centerbox"]) {
		return IAResourcePresentationCenter;
	} else if ([_presentationStyleKey isEqualToString:@"topbanner"]) {
		return IAResourcePresentationTopBanner;
	} else if ([_presentationStyleKey isEqualToString:@"bottombanner"]) {
		return IAResourcePresentationBottomBanner;
	} else {
		return IAResourcePresentationUndefined;
	}
}

- (IAResourcePresentationStyle)presentationStyle:(NSString *)presentationKey {
    if ([presentationKey isEqualToString:@"fullscreen"]) {
        return IAResourcePresentationFullScreen;
    } else if ([presentationKey isEqualToString:@"centerbox"]) {
        return IAResourcePresentationCenter;
    } else if ([presentationKey isEqualToString:@"topbanner"]) {
        return IAResourcePresentationTopBanner;
    } else if ([presentationKey isEqualToString:@"bottombanner"]) {
        return IAResourcePresentationBottomBanner;
    } else {
        return IAResourcePresentationUndefined;
    }
}

- (double)priority {
    return _required ? 100 : 0;
}

- (BOOL)isDownloaded {
	return [[NSFileManager defaultManager] fileExistsAtPath:[self localPath]];
}

- (NSString *)localPath {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *urls = [fileManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask];
	NSString *directory = [(NSURL *)urls[0] path];
    
    if ([WKWebView instancesRespondToSelector:@selector(loadFileURL:allowingReadAccessToURL:)]) { //>=iOS 9
        directory = [directory stringByAppendingPathComponent:@"InAppMessages"];
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
        return [directory stringByAppendingPathComponent:_code];
    } else {  // fix for iOS 8 (https://stackoverflow.com/a/26054170/9770357)
        directory = NSTemporaryDirectory();
        directory = [[directory stringByAppendingPathComponent:@"InAppMessages"] stringByAppendingPathComponent:_code];
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
        return [directory stringByAppendingPathComponent:@"www"];
    }
}

- (NSString *)configUrl {
	return [[self localPath] stringByAppendingPathComponent:@"pushwoosh.json"];
}

- (NSString *)pageUrl {
	return [[self localPath] stringByAppendingPathComponent:@"index.html"];
}

- (void)deleteData {
	if ([self localPath].length > 0) {
		[[NSFileManager defaultManager] removeItemAtPath:[self localPath] error:nil];
	}
}

- (void)downloadDataWithCompletion:(PWResourceDownloadCompleteBlock)completion {
	[self deleteData];

	@synchronized(_downloadListeners) {
		_lastError = nil;
	}

	[self registerDownloadListener:completion];

    void (^innerCompletionHandler)(NSError *error) = ^(NSError *error) {
        @synchronized(_downloadListeners) {
            _lastError = error;
            for (PWResourceDownloadCompleteBlock listener in _downloadListeners) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    listener(error);
                });
            }
            [_downloadListeners removeAllObjects];
        }
    };
	[[PWNetworkModule module].requestManager downloadDataFromURL:[NSURL URLWithString:_url] withCompletion:^(NSString *location, NSError *error) {
		if (!error) {
            NSString *temporaryLocation = NSTemporaryDirectory();
            temporaryLocation = [[temporaryLocation stringByAppendingPathComponent:[location lastPathComponent]] stringByAppendingString:@"_42"];
            [[NSFileManager defaultManager] moveItemAtPath:location toPath:temporaryLocation error:nil];
            
			[self processZipFileAtLocation:temporaryLocation completion:^(NSError *error) {
                innerCompletionHandler(error);
            }];
        } else {
            innerCompletionHandler(error);
        }
	}];
}

- (void)processZipFileAtLocation:(NSString *)location completion:(void (^)(NSError *error))completion{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        void (^completionWrapper)(NSString *errorString) = ^(NSString *errorString) {
            NSError *error = nil;
            if (errorString) {
                [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:errorString];
                error = [PWUtils pushwooshError:errorString];
            }
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(error);
                });
            }
        };
        NSString *temporaryDict = NSTemporaryDirectory();
        temporaryDict = [temporaryDict stringByAppendingPathComponent:_code];
        [[NSFileManager defaultManager] createDirectoryAtPath:temporaryDict withIntermediateDirectories:NO attributes:nil error:nil];

        PWZipArchive *archive = [PWZipArchive new];
        BOOL result = [archive unzipOpenFile:location];
        
        if (!result) {
            completionWrapper([NSString stringWithFormat:@"InApp: %@ is not a zip archive!", _url]);
            return;
        }

        result = [archive unzipFileTo:temporaryDict overWrite:YES];
        if (!result) {
            completionWrapper([NSString stringWithFormat:@"InApp: %@ failed to extract!", _url]);
            return;
        }

        [archive unzipCloseFile];
        [self deleteData];

        NSError *error = nil;
        if (![[NSFileManager defaultManager] moveItemAtPath:temporaryDict toPath:[self localPath] error:&error]) {
            completionWrapper([NSString stringWithFormat:@"Failed to move %@, error: %@", _url, error.localizedDescription]);
            return;
        }
        completionWrapper(nil);
    });
}

- (void)readConfig {
	if (self.config)
		return;

	self.config = [[PWRichMediaConfig alloc] initWithContentsOfFile:[self configUrl]];
	if (self.config) {
		_closeButton = self.config.iosCloseButton;
        _presentationStyleKey = self.config.presentationStyleKey;
    }
}

- (void)registerDownloadListener:(PWResourceDownloadCompleteBlock)completion {
	if (!completion)
		return;

	@synchronized(_downloadListeners) {
		if (_lastError || [self isDownloaded]) {
            completion(_lastError);
		} else {
			[_downloadListeners addObject:completion];
		}
	}
}

- (void)getHTMLDataWithCompletion:(void (^)(NSString *, NSError *))completion {
	[self registerDownloadListener:^(NSError *error) {
		if (!error) {
			[self loadHTMLDataWithCompletion:^(NSString *htmlData, NSError *error) {
                if (completion)
                    completion(htmlData, error);
            }];
        } else {
            if (completion)
                completion(nil, error);
        }
	}];
}

- (void)loadHTMLDataWithCompletion:(void (^)(NSString *htmlData, NSError *error)) completion {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        void (^completionWrapper)(NSString *htmlData, NSString *errorString) = ^(NSString *htmlData, NSString *errorString) {
            NSError *error = nil;
            if (errorString) {
                [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:errorString];
                error = [PWUtils pushwooshError:errorString];
            }
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(htmlData, error);
                });
            }
        };
        [self readConfig];

        NSError *error = nil;
        NSString *pageContent = [NSString stringWithContentsOfFile:[self pageUrl] encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            completionWrapper(nil, [NSString stringWithFormat:@"Failed to read index file, error: %@", [error localizedDescription]]);
            return;
        }
        
        pageContent = [self postProcessPageWithContent:pageContent];

        completionWrapper(pageContent, nil);
    });
}

- (NSString *)postProcessPageWithContent:(NSString *)pageContent {
    NSDictionary *localizedStrings = self.config.localizedStrings;

    // replace {{tagName|type|defaultValue}} with localization value
    NSString *localizationRegexString = @"\\{\\{(.[^\\}]+?)\\|(.[^\\}]+?)\\|(.[^\\}]*?)\\}\\}";
    pageContent = [self postProcessPageUsingParameters:localizedStrings regex:localizationRegexString pageContent:pageContent options:NSRegularExpressionDotMatchesLineSeparators];

    // replace {placeholderName|type|defaultValue} and {placeholderName|type|} with tag value
    NSString *tagsNoDefaultValueRegexString = @"\\{(.[^\\}]+?)\\|(.[^\\}]+?)\\|\\}";
    NSString *tagsRegexString = @"\\{(.[^\\}]+?)\\|(.[^\\}]+?)\\|(.[^\\}]*?)\\}";
    NSMutableDictionary *tags = _tags.mutableCopy ? : [[PWCache cache] getTags].mutableCopy;
    
    // support template syntax like {{ Placeholder name | Type }}
    NSString *localizationRegexStringDefault = @"\\{\\{(.[^\\}]+?)\\|(.[^\\}]+?)\\}\\}";
    pageContent = [self postProcessPageUsingParameters:localizedStrings regex:localizationRegexStringDefault pageContent:pageContent options:NSRegularExpressionDotMatchesLineSeparators];
    
    if ([PWConfig config].allowCollectingDeviceOsVersion == YES) {
        NSString *systemVersion = [PWUtils systemVersion];
        tags[@"OS Version"] = systemVersion;
    }

    if ([PWConfig config].allowCollectingDeviceModel == YES) {
        NSString *machineName = [PWUtils machineName];
        tags[@"Device Model"] = machineName;
    }
    
    pageContent = [self postProcessPageUsingParameters:tags regex:tagsNoDefaultValueRegexString pageContent:pageContent options:0];
    pageContent = [self postProcessPageUsingParameters:tags regex:tagsRegexString pageContent:pageContent options:0];
    
    return pageContent;
}

- (NSString *)postProcessPageUsingParameters:(NSDictionary *)parameters regex:(NSString *)tagsRegexString pageContent:(NSString *)pageContent options:(NSRegularExpressionOptions)options {
	if (!pageContent)
		return nil;
    
	NSError *error = nil;
	NSRegularExpression *tagsRegex = [NSRegularExpression regularExpressionWithPattern:tagsRegexString options:options error:&error];
	if (error) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR
                         className:self
                           message:[NSString stringWithFormat:@"Failed to create regex, error: %@", [error localizedDescription]]];
		return nil;
	}

	NSRange pageRange = NSMakeRange(0, [pageContent length]);

	NSMutableDictionary *replaceDict = [NSMutableDictionary new];

	NSArray *matches = [tagsRegex matchesInString:pageContent options:0 range:pageRange];
	for (NSTextCheckingResult *match in matches) {
        
        NSString *tagDefaultValue;
        NSString *tagPlacement = [pageContent substringWithRange:[match rangeAtIndex:0]];
        NSString *tagKey = [pageContent substringWithRange:[match rangeAtIndex:1]];
        NSString *modifier = [pageContent substringWithRange:[match rangeAtIndex:2]];
        if ([match numberOfRanges] == 4) {
            tagDefaultValue = [pageContent substringWithRange:[match rangeAtIndex:3]];
        } else if ([match numberOfRanges] == 3) {
            //handle dynamic content placeholder without a default value
            if ([tagsRegexString  isEqual: @"\\{(.[^\\}]+?)\\|(.[^\\}]+?)\\|\\}"]) {
                tagDefaultValue = @"";
            } else {
                tagDefaultValue = [pageContent substringWithRange:[match rangeAtIndex:1]];
            }
        } else {
            [PushwooshLog pushwooshLog:PW_LL_WARN
                             className:self
                               message:@"Incorrect number of matches"];
        }
        
        [PushwooshLog pushwooshLog:PW_LL_VERBOSE
                         className:self
                           message:[NSString stringWithFormat:@"Found tag placement: %@, key: %@, default value: %@, modifier: %@", tagPlacement, tagKey, tagDefaultValue, modifier]];
        
		NSString *tagReplacement = parameters[tagKey];
        
        if (!tagReplacement) {
			tagReplacement = tagDefaultValue;
        }
        
        if ([modifier isEqualToString:@"CapitalizeFirst"] && tagReplacement.length > 0) {
            tagReplacement = [NSString stringWithFormat:@"%@%@",[tagReplacement substringToIndex:1].uppercaseString, [tagReplacement substringFromIndex:1].lowercaseString];
        } else if ([modifier isEqualToString:@"CapitalizeAllFirst"]) {
            tagReplacement = tagReplacement.capitalizedString;
        } else if ([modifier isEqualToString:@"UPPERCASE"]) {
            tagReplacement = tagReplacement.uppercaseString;
        } else if ([modifier isEqualToString:@"lowercase"]) {
            tagReplacement = tagReplacement.lowercaseString;
        }
        
		replaceDict[tagPlacement] = tagReplacement;
	}

	for (NSString *tagPlacement in replaceDict) {
		NSString *tagReplacement = replaceDict[tagPlacement];
        
        if (![tagReplacement isKindOfClass:[NSString class]]) {
            tagReplacement = [NSString stringWithFormat:@"%@", tagReplacement];
        }
        
        [PushwooshLog pushwooshLog:PW_LL_DEBUG
                         className:self
                           message:[NSString stringWithFormat:@"Replacing: %@, with: %@", tagPlacement, tagReplacement]];
		pageContent = [pageContent stringByReplacingOccurrencesOfString:tagPlacement withString:tagReplacement];
	}
    
    NSString *charsetInject = @"<head><meta charset='UTF-8'>";
    NSRange range = [pageContent rangeOfString:charsetInject options:NSCaseInsensitiveSearch];

    if (range.location == NSNotFound) {
        pageContent = [pageContent stringByReplacingOccurrencesOfString:@"<head>" withString:charsetInject];
    }

	return pageContent;
}

- (BOOL)isRichMedia {
	return [_code hasPrefix:@"r-"];
}

@end
