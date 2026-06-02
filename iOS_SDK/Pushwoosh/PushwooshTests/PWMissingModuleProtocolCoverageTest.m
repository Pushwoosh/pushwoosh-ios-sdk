
#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import <PushwooshBridge/PushwooshBridge-Swift.h>
#import "PWMissingModule.h"

@interface PWMissingModuleProtocolCoverageTest : XCTestCase
@end

@implementation PWMissingModuleProtocolCoverageTest

/// Verifies that every selector declared on the six optional-module protocols and the
/// three back-channel handler protocols is either present in
/// `PWMissingModule.knownSignatures` or safely covered by the `set...:` -> `v@:@` heuristic
/// (object-only setters). Any new protocol method that escapes both checks fails the test —
/// add an explicit entry to `knownSignatures` with the correct type encoding.
- (void)testEverySelectorOnModuleAndBackchannelProtocolsIsCovered {
    NSArray<Protocol *> *protocols = [self protocolsUnderCoverage];
    NSMutableArray<NSString *> *missingEntries = [NSMutableArray array];

    for (Protocol *protocol in protocols) {
        [self collectMissingEntries:missingEntries forProtocol:protocol required:YES instance:NO];
        [self collectMissingEntries:missingEntries forProtocol:protocol required:NO  instance:NO];
        [self collectMissingEntries:missingEntries forProtocol:protocol required:YES instance:YES];
        [self collectMissingEntries:missingEntries forProtocol:protocol required:NO  instance:YES];
    }

    if (missingEntries.count > 0) {
        XCTFail(@"PWMissingModule knownSignatures coverage gap:\n  - %@\nAdd explicit entries in PWMissingModule.knownSignatures.", [missingEntries componentsJoinedByString:@"\n  - "]);
    }
}

- (NSArray<Protocol *> *)protocolsUnderCoverage {
    NSArray<Protocol *> *protocols = @[
        @protocol(PWLiveActivities),
        @protocol(PWInboxKit),
        @protocol(PWVoIP),
        @protocol(PWForegroundPush),
        @protocol(PWTVoS),
        @protocol(PWKeychain),
        @protocol(PWKeychainPersistentHWIDProvider),
        @protocol(PWVoIPConfigureHandler),
        @protocol(PWTVoSInAppHandler),
    ];
    return protocols;
}

- (void)collectMissingEntries:(NSMutableArray<NSString *> *)missingEntries
                  forProtocol:(Protocol *)protocol
                     required:(BOOL)required
                     instance:(BOOL)instance {
    unsigned int count = 0;
    struct objc_method_description *list = protocol_copyMethodDescriptionList(protocol, required, instance, &count);
    if (list == NULL) {
        return;
    }
    NSString *protocolName = [NSString stringWithUTF8String:protocol_getName(protocol)];
    for (unsigned int i = 0; i < count; i++) {
        SEL sel = list[i].name;
        const char *typesEncoding = list[i].types;
        if (sel == NULL || typesEncoding == NULL) {
            continue;
        }
        NSString *selectorName = NSStringFromSelector(sel);
        if ([self isSelectorCovered:selectorName actualEncoding:typesEncoding]) {
            continue;
        }
        NSString *normalised = [self normalisedEncoding:typesEncoding];
        [missingEntries addObject:[NSString stringWithFormat:@"selector '%@' on protocol '%@' (encoding '%@') is not covered by knownSignatures and does not match the safe set...:/'v@:@' heuristic — add an explicit entry",
                                   selectorName, protocolName, normalised]];
    }
    free(list);
}

- (BOOL)isSelectorCovered:(NSString *)selectorName actualEncoding:(const char *)actualEncoding {
    NSMethodSignature *resolvedFromMissingModule = [PWMissingModule methodSignatureForSelector:NSSelectorFromString(selectorName)];
    NSMethodSignature *resolvedFromProtocol = [NSMethodSignature signatureWithObjCTypes:actualEncoding];
    if (resolvedFromMissingModule == nil || resolvedFromProtocol == nil) {
        return NO;
    }
    return [self signaturesAreEquivalent:resolvedFromMissingModule expected:resolvedFromProtocol];
}

- (BOOL)signaturesAreEquivalent:(NSMethodSignature *)a expected:(NSMethodSignature *)b {
    if (a.numberOfArguments != b.numberOfArguments) {
        return NO;
    }
    if (strcmp(a.methodReturnType, b.methodReturnType) != 0) {
        return NO;
    }
    for (NSUInteger i = 0; i < a.numberOfArguments; i++) {
        const char *aArg = [a getArgumentTypeAtIndex:i];
        const char *bArg = [b getArgumentTypeAtIndex:i];
        if (aArg == NULL || bArg == NULL) {
            return NO;
        }
        if (strcmp(aArg, bArg) != 0) {
            return NO;
        }
    }
    return YES;
}

- (NSString *)normalisedEncoding:(const char *)raw {
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:raw];
    if (sig == nil) {
        return [NSString stringWithUTF8String:raw];
    }
    NSMutableString *out = [NSMutableString stringWithUTF8String:sig.methodReturnType];
    for (NSUInteger i = 0; i < sig.numberOfArguments; i++) {
        [out appendString:[NSString stringWithUTF8String:[sig getArgumentTypeAtIndex:i]]];
    }
    return out;
}

@end
