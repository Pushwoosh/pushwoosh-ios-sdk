//
//  PWResource.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#if TARGET_OS_IOS || TARGET_OS_TV
#import "PWPushRuntime.h"
#import "PWResource.h"
#import "PWZipArchive.h"
#import "PWRequestManager.h"
#import "PWNetworkModule.h"
#import "NSDictionary+PWDictUtils.h"
#import "PWUtils.h"
#import "PWCache.h"
#import "PWConfig.h"
#if TARGET_OS_IOS
#import <WebKit/WebKit.h>
#endif

@interface PWResource ()

@property (nonatomic, strong) NSString *presentationStyleKey;

@property (nonatomic, strong) PWRichMediaConfig *config;

@property (nonatomic, strong) NSMutableArray *downloadListeners;

@property (nonatomic, strong) NSError *lastError;

@property (nonatomic, assign, getter=isDownloading) BOOL downloading;

@end

/// ISO codes as `/getTags` returns them, mapped to names. Kept byte-identical to Android's
/// `InAppTagFormatModifier` table so one creative reads the same on both platforms.
static NSDictionary<NSString *, NSString *> *PWCountryNameByCode(void) {
    static NSDictionary *codes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        codes = @{
            @"AD": @"Andorra", @"AE": @"United Arab Emirates", @"AF": @"Afghanistan",
            @"AG": @"Antigua and Barbuda", @"AI": @"Anguilla", @"AL": @"Albania",
            @"AM": @"Armenia", @"AO": @"Angola", @"AP": @"Asia/Pacific Region",
            @"AQ": @"Antarctica", @"AR": @"Argentina", @"AS": @"American Samoa",
            @"AT": @"Austria", @"AU": @"Australia", @"AW": @"Aruba",
            @"AX": @"Aland Islands", @"AZ": @"Azerbaijan", @"BA": @"Bosnia and Herzegovina",
            @"BB": @"Barbados", @"BD": @"Bangladesh", @"BE": @"Belgium",
            @"BF": @"Burkina Faso", @"BG": @"Bulgaria", @"BH": @"Bahrain",
            @"BI": @"Burundi", @"BJ": @"Benin", @"BL": @"Saint Bartelemey",
            @"BM": @"Bermuda", @"BN": @"Brunei Darussalam", @"BO": @"Bolivia",
            @"BQ": @"Bonaire, Saint Eustatius and Saba", @"BR": @"Brazil", @"BS": @"Bahamas",
            @"BT": @"Bhutan", @"BV": @"Bouvet Island", @"BW": @"Botswana",
            @"BY": @"Belarus", @"BZ": @"Belize", @"CA": @"Canada",
            @"CC": @"Cocos (Keeling) Islands", @"CD": @"Congo, The Democratic Republic of the", @"CF": @"Central African Republic",
            @"CG": @"Congo", @"CH": @"Switzerland", @"CI": @"Cote d'Ivoire",
            @"CK": @"Cook Islands", @"CL": @"Chile", @"CM": @"Cameroon",
            @"CN": @"China", @"CO": @"Colombia", @"CR": @"Costa Rica",
            @"CU": @"Cuba", @"CV": @"Cape Verde", @"CW": @"Curacao",
            @"CX": @"Christmas Island", @"CY": @"Cyprus", @"CZ": @"Czech Republic",
            @"DE": @"Germany", @"DJ": @"Djibouti", @"DK": @"Denmark",
            @"DM": @"Dominica", @"DO": @"Dominican Republic", @"DZ": @"Algeria",
            @"EC": @"Ecuador", @"EE": @"Estonia", @"EG": @"Egypt",
            @"EH": @"Western Sahara", @"ER": @"Eritrea", @"ES": @"Spain",
            @"ET": @"Ethiopia", @"EU": @"Europe", @"FI": @"Finland",
            @"FJ": @"Fiji", @"FK": @"Falkland Islands (Malvinas)", @"FM": @"Micronesia, Federated States of",
            @"FO": @"Faroe Islands", @"FR": @"France", @"GA": @"Gabon",
            @"GB": @"United Kingdom", @"GD": @"Grenada", @"GE": @"Georgia",
            @"GF": @"French Guiana", @"GG": @"Guernsey", @"GH": @"Ghana",
            @"GI": @"Gibraltar", @"GL": @"Greenland", @"GM": @"Gambia",
            @"GN": @"Guinea", @"GP": @"Guadeloupe", @"GQ": @"Equatorial Guinea",
            @"GR": @"Greece", @"GS": @"South Georgia and the South Sandwich Islands", @"GT": @"Guatemala",
            @"GU": @"Guam", @"GW": @"Guinea-Bissau", @"GY": @"Guyana",
            @"HK": @"Hong Kong", @"HM": @"Heard Island and McDonald Islands", @"HN": @"Honduras",
            @"HR": @"Croatia", @"HT": @"Haiti", @"HU": @"Hungary",
            @"ID": @"Indonesia", @"IE": @"Ireland", @"IL": @"Israel",
            @"IM": @"Isle of Man", @"IN": @"India", @"IO": @"British Indian Ocean Territory",
            @"IQ": @"Iraq", @"IR": @"Iran, Islamic Republic of", @"IS": @"Iceland",
            @"IT": @"Italy", @"JE": @"Jersey", @"JM": @"Jamaica",
            @"JO": @"Jordan", @"JP": @"Japan", @"KE": @"Kenya",
            @"KG": @"Kyrgyzstan", @"KH": @"Cambodia", @"KI": @"Kiribati",
            @"KM": @"Comoros", @"KN": @"Saint Kitts and Nevis", @"KP": @"Korea, Democratic People's Republic of",
            @"KR": @"Korea, Republic of", @"KW": @"Kuwait", @"KY": @"Cayman Islands",
            @"KZ": @"Kazakhstan", @"LA": @"Lao People's Democratic Republic", @"LB": @"Lebanon",
            @"LC": @"Saint Lucia", @"LI": @"Liechtenstein", @"LK": @"Sri Lanka",
            @"LR": @"Liberia", @"LS": @"Lesotho", @"LT": @"Lithuania",
            @"LU": @"Luxembourg", @"LV": @"Latvia", @"LY": @"Libyan Arab Jamahiriya",
            @"MA": @"Morocco", @"MC": @"Monaco", @"MD": @"Moldova, Republic of",
            @"ME": @"Montenegro", @"MF": @"Saint Martin", @"MG": @"Madagascar",
            @"MH": @"Marshall Islands", @"MK": @"Macedonia", @"ML": @"Mali",
            @"MM": @"Myanmar", @"MN": @"Mongolia", @"MO": @"Macao",
            @"MP": @"Northern Mariana Islands", @"MQ": @"Martinique", @"MR": @"Mauritania",
            @"MS": @"Montserrat", @"MT": @"Malta", @"MU": @"Mauritius",
            @"MV": @"Maldives", @"MW": @"Malawi", @"MX": @"Mexico",
            @"MY": @"Malaysia", @"MZ": @"Mozambique", @"NA": @"Namibia",
            @"NC": @"New Caledonia", @"NE": @"Niger", @"NF": @"Norfolk Island",
            @"NG": @"Nigeria", @"NI": @"Nicaragua", @"NL": @"Netherlands",
            @"NO": @"Norway", @"NP": @"Nepal", @"NR": @"Nauru",
            @"NU": @"Niue", @"NZ": @"New Zealand", @"OM": @"Oman",
            @"PA": @"Panama", @"PE": @"Peru", @"PF": @"French Polynesia",
            @"PG": @"Papua New Guinea", @"PH": @"Philippines", @"PK": @"Pakistan",
            @"PL": @"Poland", @"PM": @"Saint Pierre and Miquelon", @"PN": @"Pitcairn",
            @"PR": @"Puerto Rico", @"PS": @"Palestinian Territory", @"PT": @"Portugal",
            @"PW": @"Palau", @"PY": @"Paraguay", @"QA": @"Qatar",
            @"RE": @"Reunion", @"RO": @"Romania", @"RS": @"Serbia",
            @"RU": @"Russian Federation", @"RW": @"Rwanda", @"SA": @"Saudi Arabia",
            @"SB": @"Solomon Islands", @"SC": @"Seychelles", @"SD": @"Sudan",
            @"SE": @"Sweden", @"SG": @"Singapore", @"SH": @"Saint Helena",
            @"SI": @"Slovenia", @"SJ": @"Svalbard and Jan Mayen", @"SK": @"Slovakia",
            @"SL": @"Sierra Leone", @"SM": @"San Marino", @"SN": @"Senegal",
            @"SO": @"Somalia", @"SR": @"Suriname", @"SS": @"South Sudan",
            @"ST": @"Sao Tome and Principe", @"SV": @"El Salvador", @"SX": @"Sint Maarten",
            @"SY": @"Syrian Arab Republic", @"SZ": @"Swaziland", @"TC": @"Turks and Caicos Islands",
            @"TD": @"Chad", @"TF": @"French Southern Territories", @"TG": @"Togo",
            @"TH": @"Thailand", @"TJ": @"Tajikistan", @"TK": @"Tokelau",
            @"TL": @"Timor-Leste", @"TM": @"Turkmenistan", @"TN": @"Tunisia",
            @"TO": @"Tonga", @"TR": @"Turkey", @"TT": @"Trinidad and Tobago",
            @"TV": @"Tuvalu", @"TW": @"Taiwan", @"TZ": @"Tanzania, United Republic of",
            @"UA": @"Ukraine", @"UG": @"Uganda", @"UM": @"United States Minor Outlying Islands",
            @"US": @"United States", @"UY": @"Uruguay", @"UZ": @"Uzbekistan",
            @"VA": @"Holy See (Vatican City State)", @"VC": @"Saint Vincent and the Grenadines", @"VE": @"Venezuela",
            @"VG": @"Virgin Islands, British", @"VI": @"Virgin Islands, U.S.", @"VN": @"Vietnam",
            @"VU": @"Vanuatu", @"WF": @"Wallis and Futuna", @"WS": @"Samoa",
            @"YE": @"Yemen", @"YT": @"Mayotte", @"ZA": @"South Africa",
            @"ZM": @"Zambia", @"ZW": @"Zimbabwe"
        };
    });
    return codes;
}

@implementation PWResource

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_code forKey:@"code"];
    [aCoder encodeObject:_url forKey:@"url"];
    [aCoder encodeDouble:_updated forKey:@"updated"];
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
        _presentationStyleKey = [dictionary pw_stringForKey:@"presentationStyleKey"];
        id closeButtonValue = [dictionary pw_objectForKey:@"closeButtonType" ofTypes:@[ [NSString class], [NSNumber class] ]];
        _closeButton = [closeButtonValue boolValue];
        _tags = [dictionary pw_dictionaryForKey:@"tags"];

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

- (BOOL)isDownloaded {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self localPath]];
}

- (NSString *)localPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *urls = [fileManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask];
    NSString *directory = [(NSURL *)urls[0] path];

#if TARGET_OS_IOS
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
#elif TARGET_OS_TV
    directory = [directory stringByAppendingPathComponent:@"InAppMessages"];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    return [directory stringByAppendingPathComponent:_code];
#endif
}

- (NSString *)configUrl {
    return [[self localPath] stringByAppendingPathComponent:@"pushwoosh.json"];
}

- (NSString *)pageUrl {
    return [[self localPath] stringByAppendingPathComponent:@"index.html"];
}

- (NSString *)nativeConfigUrl {
    return [[self localPath] stringByAppendingPathComponent:@"native-config.json"];
}

- (BOOL)hasNativeConfig {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self nativeConfigUrl]];
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
        self.downloading = YES;
    }

    [self registerDownloadListener:completion];

    [self beginNetworkDownload];
}

/// Fires the zip request and wires its completion into `_downloadListeners`. Assumes the caller has
/// already raised `downloading` and registered its own listener under `@synchronized(_downloadListeners)`.
- (void)beginNetworkDownload {
    void (^innerCompletionHandler)(NSError *error) = ^(NSError *error) {
        @synchronized(_downloadListeners) {
            _lastError = error;
            self.downloading = NO;
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

- (void)awaitDownloadWithCompletion:(PWResourceDownloadCompleteBlock)completion {
    BOOL alreadyOnDisk = NO;
    BOOL shouldStartDownload = NO;

    @synchronized(_downloadListeners) {
        if ([self isDownloaded]) {
            alreadyOnDisk = YES;
        } else if (self.downloading) {
            if (completion) {
                [_downloadListeners addObject:completion];
            }
        } else {
            /// Flip downloading in the same lock as the check, closing the start-vs-park race.
            shouldStartDownload = YES;
            _lastError = nil;
            self.downloading = YES;
            if (completion) {
                [_downloadListeners addObject:completion];
            }
        }
    }

    if (alreadyOnDisk) {
        if (completion) {
            completion(nil);
        }
        return;
    }

    if (shouldStartDownload) {
        [self deleteData];
        [self beginNetworkDownload];
    }
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
    @synchronized (self) {
        if (self.config)
            return;

        self.config = [[PWRichMediaConfig alloc] initWithContentsOfFile:[self configUrl]];
        if (self.config) {
            _closeButton = self.config.iosCloseButton;
            _presentationStyleKey = self.config.presentationStyleKey;
            _position = self.config.position;
            _presentAnimation = self.config.presentAnimation;
            _dismissAnimation = self.config.dismissAnimation;
            _animationDuration = self.config.animationDuration;
            _swipeToDismiss = self.config.swipeToDismiss;
        }
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

/// Tag values for the HTML path: payload tags win over the cache.
- (nullable NSDictionary *)pw_substitutionTags {
    /// Left nil when neither source exists, so the device-tag writes stay no-ops — creatives that
    /// render their defaults today must keep doing so.
    NSMutableDictionary *tags = _tags.mutableCopy ? : [[PWCache cache] getTags].mutableCopy;
    return [self pw_addDeviceTags:tags];
}

/// Native-config tags: the local cache only, never the payload, mirroring Android's `InAppTags`.
/// Always a dictionary, so the two device tags are substituted even with an empty cache.
- (nonnull NSDictionary *)pw_nativeSubstitutionTags {
    NSMutableDictionary *tags = [[PWCache cache] getTags].mutableCopy ? : [NSMutableDictionary dictionary];
    [self pw_convertGeoTags:tags];
    return [self pw_addDeviceTags:tags];
}

/// Geo tags reach the cache raw — `Country` as an ISO code, `City` as "<code>, <city>". An
/// unresolvable code drops the tag so the placeholder renders its default (Android parity).
- (void)pw_convertGeoTags:(NSMutableDictionary *)tags {
    id country = tags[@"Country"];
    if (country && country != [NSNull null]) {
        NSString *code = [[NSString stringWithFormat:@"%@", country] uppercaseString];
        NSString *name = PWCountryNameByCode()[code];
        if (name) {
            tags[@"Country"] = name;
        } else {
            [tags removeObjectForKey:@"Country"];
        }
    }

    id city = tags[@"City"];
    if (city && city != [NSNull null]) {
        NSMutableArray *components = [[[NSString stringWithFormat:@"%@", city] componentsSeparatedByString:@", "] mutableCopy];
        /// Java's split drops trailing empty components; "Berlin, " must stay "Berlin", not "".
        while (components.count > 1 && [(NSString *)components.lastObject length] == 0) {
            [components removeLastObject];
        }
        tags[@"City"] = components.lastObject;
    }
}

/// The two device tags the server never returns, added locally under their privacy flags.
- (nullable NSMutableDictionary *)pw_addDeviceTags:(nullable NSMutableDictionary *)tags {
    if ([PWConfig config].allowCollectingDeviceOsVersion == YES) {
        tags[@"OS Version"] = [PWUtils systemVersion];
    }

    if ([PWConfig config].allowCollectingDeviceModel == YES) {
        tags[@"Device Model"] = [PWUtils machineName];
    }

    return tags;
}

- (NSString *)postProcessPageWithContent:(NSString *)pageContent {
    NSDictionary *localizedStrings = self.config.localizedStrings;

    // replace {{tagName|type|defaultValue}} with localization value
    NSString *localizationRegexString = @"\\{\\{([^|\\}]+)\\|([^|\\}]+)\\|([^|\\}]*)\\}\\}";
    pageContent = [self postProcessPageUsingParameters:localizedStrings regex:localizationRegexString pageContent:pageContent options:NSRegularExpressionDotMatchesLineSeparators];

    // replace {placeholderName|type|defaultValue} and {placeholderName|type|} with tag value
    NSString *tagsNoDefaultValueRegexString = @"\\{([^|\\}]+)\\|([^|\\}]+)\\|\\}";
    NSString *tagsRegexString = @"\\{([^|\\}]+)\\|([^|\\}]+)\\|([^|\\}]*)\\}";
    NSDictionary *tags = [self pw_substitutionTags];

    // support template syntax like {{ Placeholder name | Type }}
    NSString *localizationRegexStringDefault = @"\\{\\{([^|\\}]+)\\|([^|\\}]+)\\}\\}";
    pageContent = [self postProcessPageUsingParameters:localizedStrings regex:localizationRegexStringDefault pageContent:pageContent options:NSRegularExpressionDotMatchesLineSeparators];

    pageContent = [self postProcessPageUsingParameters:tags regex:tagsNoDefaultValueRegexString pageContent:pageContent options:0];
    pageContent = [self postProcessPageUsingParameters:tags regex:tagsRegexString pageContent:pageContent options:0];

    return [self injectHTMLCharset:pageContent];
}

- (NSDictionary *)localizeConfig:(NSDictionary *)config {
    if (![config isKindOfClass:[NSDictionary class]]) {
        return config;
    }
    @synchronized (self) {
        [self readConfig];
        /// Built once per config, not per string: -getTags reads and unarchives a file every call,
        /// and this walks every string in the tree.
        NSDictionary *tags = [self pw_nativeSubstitutionTags];
        id resolved = [self pw_localizeNode:config tags:tags];
        return [resolved isKindOfClass:[NSDictionary class]] ? resolved : config;
    }
}

- (id)pw_localizeNode:(id)node tags:(NSDictionary *)tags {
    if ([node isKindOfClass:[NSString class]]) {
        return [self pw_localizeString:(NSString *)node tags:tags];
    }
    if ([node isKindOfClass:[NSArray class]]) {
        NSMutableArray *result = [NSMutableArray arrayWithCapacity:[(NSArray *)node count]];
        for (id item in (NSArray *)node) {
            [result addObject:[self pw_localizeNode:item tags:tags]];
        }
        return result;
    }
    if ([node isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[(NSDictionary *)node count]];
        for (id key in (NSDictionary *)node) {
            result[key] = [self pw_localizeNode:((NSDictionary *)node)[key] tags:tags];
        }
        return result;
    }
    return node;
}

- (NSString *)pw_localizeString:(NSString *)string tags:(NSDictionary *)tags {
    if (string.length == 0) {
        return string;
    }
    NSDictionary *localizedStrings = self.config.localizedStrings;
    NSString *result = [self postProcessPageUsingParameters:localizedStrings
                                                      regex:@"\\{\\{([^|\\}]+)\\|([^|\\}]+)\\|([^|\\}]*)\\}\\}"
                                                pageContent:string
                                                    options:NSRegularExpressionDotMatchesLineSeparators] ?: string;
    result = [self postProcessPageUsingParameters:localizedStrings
                                            regex:@"\\{\\{([^|\\}]+)\\|([^|\\}]+)\\}\\}"
                                      pageContent:result
                                          options:NSRegularExpressionDotMatchesLineSeparators] ?: result;
    result = [self postProcessPageUsingParameters:tags
                                            regex:@"\\{([^|\\}]+)\\|([^|\\}]+)\\|\\}"
                                      pageContent:result
                                          options:0] ?: result;
    result = [self postProcessPageUsingParameters:tags
                                            regex:@"\\{([^|\\}]+)\\|([^|\\}]+)\\|([^|\\}]*)\\}"
                                      pageContent:result
                                          options:0] ?: result;
    return result;
}

- (NSString *)pw_applyModifier:(NSString *)modifier toValue:(NSString *)value applyValueFormatters:(BOOL)applyValueFormatters {
    if (value == nil || modifier.length == 0) {
        return value ?: @"";
    }
    if (![value isKindOfClass:[NSString class]]) {
        return [NSString stringWithFormat:@"%@", value];
    }
    if ([modifier isEqualToString:@"CapitalizeFirst"]) {
        return value.length > 0 ? [NSString stringWithFormat:@"%@%@", [value substringToIndex:1].uppercaseString, [value substringFromIndex:1].lowercaseString] : value;
    } else if ([modifier isEqualToString:@"CapitalizeAllFirst"]) {
        return value.capitalizedString;
    } else if ([modifier isEqualToString:@"UPPERCASE"]) {
        return value.uppercaseString;
    } else if ([modifier isEqualToString:@"lowercase"]) {
        return value.lowercaseString;
    }
    if (!applyValueFormatters) {
        return value;
    }
    if ([modifier isEqualToString:@"cent"]) {
        return [self pw_toCent:value];
    } else if ([modifier isEqualToString:@"dollar"]) {
        return value.length == 0 ? @"$0" : [@"$" stringByAppendingString:[self pw_toComma:value]];
    } else if ([modifier isEqualToString:@"euro"]) {
        return value.length == 0 ? @"€0" : [@"€" stringByAppendingString:[self pw_toComma:value]];
    } else if ([modifier isEqualToString:@"jpy"]) {
        return value.length == 0 ? @"¥0" : [@"¥" stringByAppendingString:[self pw_toComma:value]];
    } else if ([modifier isEqualToString:@"lira"]) {
        return value.length == 0 ? @"₤0" : [@"₤" stringByAppendingString:[self pw_toComma:value]];
    } else if ([modifier isEqualToString:@"comma"]) {
        return [self pw_toComma:value];
    }
    NSString *dateFormat = [self pw_dateFormatForModifier:modifier];
    if (dateFormat) {
        return [self pw_formatUnixTimestamp:value withFormat:dateFormat] ?: value;
    }
    return value;
}

- (NSString *)pw_toComma:(NSString *)string {
    if (string.length == 0) {
        return @"";
    }
    NSString *result = @"";
    NSInteger left = (NSInteger)string.length;
    while (left > 0) {
        left -= 3;
        NSInteger start = MAX(left, 0);
        NSInteger end = left + 3;
        result = [NSString stringWithFormat:@"%@,%@", [string substringWithRange:NSMakeRange(start, end - start)], result];
    }
    return [result substringToIndex:result.length - 1];
}

- (NSString *)pw_toCent:(NSString *)string {
    if (string.length == 0) {
        return @"$.00";
    }
    if (string.length == 1) {
        string = [@"0" stringByAppendingString:string];
    }
    NSString *cents = [string substringFromIndex:string.length - 2];
    NSString *dollars = [string substringToIndex:string.length - 2];
    return [NSString stringWithFormat:@"$%@.%@", dollars, cents];
}

- (NSString *)pw_dateFormatForModifier:(NSString *)modifier {
    static NSDictionary *formats;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formats = @{
            @"M-d-y": @"MMM-dd-yy",
            @"m-d-y": @"MM-dd-yy",
            @"M d y": @"MMM dd yy",
            @"M d Y": @"MMM dd yyyy",
            @"l": @"EEEE",
            @"M d": @"MMM dd",
            @"H:i": @"hh:mm",
            @"m-d-y H:i": @"MM-dd-yy hh:mm"
        };
    });
    return formats[modifier];
}

- (NSString *)pw_formatUnixTimestamp:(NSString *)value withFormat:(NSString *)format {
    const char *cString = value.UTF8String;
    if (cString == NULL) {
        return nil;
    }
    char *end = NULL;
    long long timestamp = strtoll(cString, &end, 10);
    if (end == cString || *end != '\0') {
        return nil;
    }
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)timestamp];
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = format;
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    return [formatter stringFromDate:date];
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
            if ([tagsRegexString  isEqual: @"\\{([^|\\}]+)\\|([^|\\}]+)\\|\\}"]) {
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
        BOOL found = (tagReplacement != nil);

        if (!found) {
            tagReplacement = tagDefaultValue;
        }

        tagReplacement = [self pw_applyModifier:modifier toValue:tagReplacement applyValueFormatters:found];

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

    return pageContent;
}

- (NSString *)injectHTMLCharset:(NSString *)pageContent {
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
#endif
