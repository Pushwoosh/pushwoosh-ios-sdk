//  PWPreferencesKeychainHWIDTest.m
//  Created by André Kis

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWPreferences.h"
#import "PWConfig.h"
#import "PWUtils.h"
#import "PushwooshModuleRegistry.h"
#import "PushwooshModuleIdentifier.h"
#import "PWKeychainPersistentHWIDProvider.h"
#import "PushwooshLog.h"

static NSString *const kSavedHWIDKey = @"PWDeviceHwid";
static NSString *const kSavedUserIdKey = @"PWInAppUserId";
static NSString *const kKeychainHWID = @"KEYCHAIN-HWID-1111";
static NSString *const kInstallationHWID = @"INSTALLATION-HWID-2222";
static NSString *const kModuleCreatedHWID = @"MODULE-CREATED-HWID-3333";
static NSString *const kAppGroupSuiteName = @"group.com.pushwoosh.keychain_hwid_unit_tests";

@interface PWPreferences (PWPreferencesKeychainHWIDTest)
@property (nonatomic, assign) BOOL awaitsKeychainProvider;
@property (nonatomic, copy) NSString *installationHWIDAtLaunch;
- (instancetype)initObservingKeychainProvider:(BOOL)observesKeychainProvider;
- (void)keychainProviderDidRegister:(NSNotification *)notification;
@end

@interface PWFakeKeychainProvider : NSObject <PWKeychainPersistentHWIDProvider>
@property (nonatomic) BOOL isPersistentHWIDEnabled;
@property (nonatomic, copy) NSString *keychainValue;
@property (nonatomic) NSUInteger writeCount;
@property (nonatomic) BOOL rejectsWrites;
@end

@implementation PWFakeKeychainProvider

- (BOOL)isPersistentHWIDEnabled {
    [PushwooshLog pushwooshLog:PW_LL_INFO className:self message:@"Detected environment"];
    return _isPersistentHWIDEnabled;
}

- (NSString *)persistentHWID {
    self.writeCount++;
    if (self.rejectsWrites) {
        return nil;
    }
    self.keychainValue = kModuleCreatedHWID;
    return kModuleCreatedHWID;
}

- (NSString *)storedPersistentHWID {
    return self.keychainValue;
}

- (BOOL)storePersistentHWID:(NSString *)hwid {
    self.writeCount++;
    if (self.rejectsWrites) {
        return NO;
    }
    self.keychainValue = hwid;
    return YES;
}

@end

@interface PWPreferencesKeychainHWIDTest : XCTestCase
@property (nonatomic, copy) NSString *originalSavedHWID;
@property (nonatomic, copy) NSString *originalSavedUserId;
@property (nonatomic) BOOL sharedAwaitedKeychainProvider;
@property (nonatomic, copy) NSString *sharedInstallationHWID;
@property (nonatomic, copy) NSString *sharedPreviousHWID;
@end

@implementation PWPreferencesKeychainHWIDTest

- (void)setUp {
    [super setUp];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.originalSavedHWID = [defaults objectForKey:kSavedHWIDKey];
    self.originalSavedUserId = [defaults objectForKey:kSavedUserIdKey];
    [defaults removeObjectForKey:kSavedUserIdKey];
    PWPreferences *shared = [PWPreferences preferences];
    self.sharedAwaitedKeychainProvider = shared.awaitsKeychainProvider;
    self.sharedInstallationHWID = shared.installationHWIDAtLaunch;
    self.sharedPreviousHWID = shared.previosHWID;
    shared.awaitsKeychainProvider = NO;
    [PushwooshModuleRegistry _resetForTesting];
}

- (void)tearDown {
    [PushwooshModuleRegistry _resetForTesting];
    PWPreferences *shared = [PWPreferences preferences];
    shared.awaitsKeychainProvider = self.sharedAwaitedKeychainProvider;
    shared.installationHWIDAtLaunch = self.sharedInstallationHWID;
    [self restoreKeychainProviderSubscriptionOf:shared];
    [shared setValue:self.sharedPreviousHWID forKey:@"previosHWID"];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [self restoreDefaultsKey:kSavedHWIDKey value:self.originalSavedHWID];
    [self restoreDefaultsKey:kSavedUserIdKey value:self.originalSavedUserId];
    [defaults synchronize];
    [super tearDown];
}

- (void)restoreKeychainProviderSubscriptionOf:(PWPreferences *)shared {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:shared name:PWKeychainPersistentHWIDProviderDidRegisterNotification object:nil];
    if (self.sharedAwaitedKeychainProvider) {
        [center addObserver:shared
                   selector:@selector(keychainProviderDidRegister:)
                       name:PWKeychainPersistentHWIDProviderDidRegisterNotification
                     object:nil];
    }
}

- (void)restoreDefaultsKey:(NSString *)key value:(id)value {
    if (value) {
        [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    }
}

- (void)setInstallationHWID:(NSString *)hwid {
    if (hwid) {
        [[NSUserDefaults standardUserDefaults] setObject:hwid forKey:kSavedHWIDKey];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSavedHWIDKey];
    }
}

- (PWFakeKeychainProvider *)providerWithKeychainValue:(NSString *)value {
    PWFakeKeychainProvider *provider = [PWFakeKeychainProvider new];
    provider.isPersistentHWIDEnabled = YES;
    provider.keychainValue = value;
    return provider;
}

- (void)loadKeychainModule:(PWFakeKeychainProvider *)provider {
    [PushwooshModuleRegistry registerHandler:provider forIdentifier:PWModuleIdentifierKeychain];
    [[NSNotificationCenter defaultCenter] postNotificationName:PWKeychainPersistentHWIDProviderDidRegisterNotification
                                                        object:nil];
}

- (PWPreferences *)launchWithModuleLoadedBeforePreferences:(PWFakeKeychainProvider *)provider {
    [self loadKeychainModule:provider];
    return [[PWPreferences alloc] init];
}

- (PWPreferences *)launchWithModuleLoadedAfterPreferences:(PWFakeKeychainProvider *)provider {
    PWPreferences *preferences = [[PWPreferences alloc] initObservingKeychainProvider:YES];
    [self loadKeychainModule:provider];
    return preferences;
}

- (void)assertPreferences:(PWPreferences *)preferences
                 useHWID:(NSString *)hwid
                provider:(PWFakeKeychainProvider *)provider
              keychainHWID:(NSString *)keychainHWID
              writeCount:(NSUInteger)writeCount {
    XCTAssertEqualObjects(preferences.hwid, hwid);
    XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] objectForKey:kSavedHWIDKey], hwid);
    XCTAssertNil(preferences.previosHWID);
    XCTAssertEqualObjects(provider.keychainValue, keychainHWID);
    XCTAssertEqual(provider.writeCount, writeCount);
}

#pragma mark - Row 0: Keychain and installation agree

/// Verifies that a Keychain HWID equal to the installation HWID is used without rewriting the Keychain (module loaded first).
- (void)testMatchingKeychainHWIDWithModuleLoadedFirst {
    [self setInstallationHWID:kKeychainHWID];
    PWFakeKeychainProvider *provider = [self providerWithKeychainValue:kKeychainHWID];

    PWPreferences *preferences = [self launchWithModuleLoadedBeforePreferences:provider];

    [self assertPreferences:preferences useHWID:kKeychainHWID provider:provider keychainHWID:kKeychainHWID writeCount:0];
}

/// Verifies that a Keychain HWID equal to the installation HWID is used without rewriting the Keychain (module loaded later).
- (void)testMatchingKeychainHWIDWithModuleLoadedLater {
    [self setInstallationHWID:kKeychainHWID];
    PWFakeKeychainProvider *provider = [self providerWithKeychainValue:kKeychainHWID];

    PWPreferences *preferences = [self launchWithModuleLoadedAfterPreferences:provider];

    [self assertPreferences:preferences useHWID:kKeychainHWID provider:provider keychainHWID:kKeychainHWID writeCount:0];
}

#pragma mark - Row 1: reinstall, Keychain only

/// Verifies that after a reinstall the Keychain HWID is restored and saved for the installation (module loaded first).
- (void)testReinstallRestoresKeychainHWIDWithModuleLoadedFirst {
    [self setInstallationHWID:nil];
    PWFakeKeychainProvider *provider = [self providerWithKeychainValue:kKeychainHWID];

    PWPreferences *preferences = [self launchWithModuleLoadedBeforePreferences:provider];

    [self assertPreferences:preferences useHWID:kKeychainHWID provider:provider keychainHWID:kKeychainHWID writeCount:0];
    XCTAssertEqualObjects(preferences.userId, kKeychainHWID);
}

/// Verifies that after a reinstall the Keychain HWID wins over the identifier generated before the module loaded.
- (void)testReinstallRestoresKeychainHWIDWithModuleLoadedLater {
    [self setInstallationHWID:nil];
    PWFakeKeychainProvider *provider = [self providerWithKeychainValue:kKeychainHWID];

    PWPreferences *preferences = [self launchWithModuleLoadedAfterPreferences:provider];

    [self assertPreferences:preferences useHWID:kKeychainHWID provider:provider keychainHWID:kKeychainHWID writeCount:0];
    XCTAssertEqualObjects(preferences.userId, kKeychainHWID);
}

#pragma mark - Row 2: existing installation, empty Keychain

/// Verifies that an existing installation keeps its HWID and stores it in an empty Keychain (module loaded first).
- (void)testExistingInstallationSavesCurrentHWIDWithModuleLoadedFirst {
    [self setInstallationHWID:kInstallationHWID];
    PWFakeKeychainProvider *provider = [self providerWithKeychainValue:nil];

    PWPreferences *preferences = [self launchWithModuleLoadedBeforePreferences:provider];

    [self assertPreferences:preferences useHWID:kInstallationHWID provider:provider keychainHWID:kInstallationHWID writeCount:1];
}

/// Verifies that an existing installation keeps its HWID and stores it in an empty Keychain (module loaded later).
- (void)testExistingInstallationSavesCurrentHWIDWithModuleLoadedLater {
    [self setInstallationHWID:kInstallationHWID];
    PWFakeKeychainProvider *provider = [self providerWithKeychainValue:nil];

    PWPreferences *preferences = [self launchWithModuleLoadedAfterPreferences:provider];

    [self assertPreferences:preferences useHWID:kInstallationHWID provider:provider keychainHWID:kInstallationHWID writeCount:1];
}

#pragma mark - Row 3: first install

/// Verifies that on a first install the module creates the HWID and it is saved for the installation (module loaded first).
- (void)testFirstInstallUsesModuleCreatedHWIDWithModuleLoadedFirst {
    [self setInstallationHWID:nil];
    PWFakeKeychainProvider *provider = [self providerWithKeychainValue:nil];

    PWPreferences *preferences = [self launchWithModuleLoadedBeforePreferences:provider];

    [self assertPreferences:preferences useHWID:kModuleCreatedHWID provider:provider keychainHWID:kModuleCreatedHWID writeCount:1];
}

/// Verifies that on a first install the module creates the HWID and it is saved for the installation (module loaded later).
- (void)testFirstInstallUsesModuleCreatedHWIDWithModuleLoadedLater {
    [self setInstallationHWID:nil];
    PWFakeKeychainProvider *provider = [self providerWithKeychainValue:nil];

    PWPreferences *preferences = [self launchWithModuleLoadedAfterPreferences:provider];

    [self assertPreferences:preferences useHWID:kModuleCreatedHWID provider:provider keychainHWID:kModuleCreatedHWID writeCount:1];
}

#pragma mark - Row 4: Keychain and installation differ

/// Verifies that the installation HWID wins over a different Keychain HWID and overwrites it (module loaded first).
- (void)testDifferentKeychainHWIDIsOverwrittenWithModuleLoadedFirst {
    [self setInstallationHWID:kInstallationHWID];
    PWFakeKeychainProvider *provider = [self providerWithKeychainValue:kKeychainHWID];

    PWPreferences *preferences = [self launchWithModuleLoadedBeforePreferences:provider];

    [self assertPreferences:preferences useHWID:kInstallationHWID provider:provider keychainHWID:kInstallationHWID writeCount:1];
}

/// Verifies that the installation HWID wins over a different Keychain HWID and overwrites it (module loaded later).
- (void)testDifferentKeychainHWIDIsOverwrittenWithModuleLoadedLater {
    [self setInstallationHWID:kInstallationHWID];
    PWFakeKeychainProvider *provider = [self providerWithKeychainValue:kKeychainHWID];

    PWPreferences *preferences = [self launchWithModuleLoadedAfterPreferences:provider];

    [self assertPreferences:preferences useHWID:kInstallationHWID provider:provider keychainHWID:kInstallationHWID writeCount:1];
}

/// Verifies that the shared preferences reconcile their HWID with a Keychain module that registers after them.
- (void)testSharedPreferencesReconcileWithModuleLoadedAfterThem {
    PWPreferences *shared = [PWPreferences preferences];
    NSString *sharedHWID = shared.hwid;
    shared.installationHWIDAtLaunch = sharedHWID;
    shared.awaitsKeychainProvider = YES;
    PWFakeKeychainProvider *provider = [self providerWithKeychainValue:nil];

    [self loadKeychainModule:provider];

    XCTAssertEqualObjects(shared.hwid, sharedHWID);
    XCTAssertEqualObjects(provider.keychainValue, sharedHWID);
    XCTAssertEqual(provider.writeCount, 1);
}

/// Verifies that a userId set by the app does not follow the HWID restored from the Keychain.
- (void)testExplicitUserIdIsKeptWhenKeychainHWIDIsRestored {
    [self setInstallationHWID:nil];
    [[NSUserDefaults standardUserDefaults] setObject:@"app-user-id" forKey:kSavedUserIdKey];
    PWFakeKeychainProvider *provider = [self providerWithKeychainValue:kKeychainHWID];

    PWPreferences *preferences = [self launchWithModuleLoadedAfterPreferences:provider];

    XCTAssertEqualObjects(preferences.hwid, kKeychainHWID);
    XCTAssertEqualObjects(preferences.userId, @"app-user-id");
}

/// Verifies that a userId the app set to the device identifier is kept when the installation HWID is restored.
- (void)testExplicitUserIdEqualToDeviceIdentifierIsKept {
    [self setInstallationHWID:kInstallationHWID];
    [[NSUserDefaults standardUserDefaults] setObject:[PWUtils uniqueGlobalDeviceIdentifier] forKey:kSavedUserIdKey];
    PWFakeKeychainProvider *provider = [self providerWithKeychainValue:nil];

    PWPreferences *preferences = [self launchWithModuleLoadedAfterPreferences:provider];

    XCTAssertEqualObjects(preferences.hwid, kInstallationHWID);
    XCTAssertEqualObjects(preferences.userId, [PWUtils uniqueGlobalDeviceIdentifier]);
}

/// Verifies that a userId set before the Keychain module registers does not follow the restored HWID.
- (void)testUserIdSetBeforeModuleLoadsIsKept {
    [self setInstallationHWID:nil];
    PWFakeKeychainProvider *provider = [self providerWithKeychainValue:kKeychainHWID];
    PWPreferences *preferences = [[PWPreferences alloc] initObservingKeychainProvider:YES];
    preferences.userId = [PWUtils uniqueGlobalDeviceIdentifier];

    [self loadKeychainModule:provider];

    XCTAssertEqualObjects(preferences.hwid, kKeychainHWID);
    XCTAssertEqualObjects(preferences.userId, [PWUtils uniqueGlobalDeviceIdentifier]);
}

/// Verifies that with an App Group and no saved userId the default userId follows the HWID restored from the Keychain.
- (void)testAppGroupDefaultUserIdFollowsKeychainHWID {
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:kAppGroupSuiteName];
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(kAppGroupSuiteName);
    [self setInstallationHWID:nil];
    PWFakeKeychainProvider *provider = [self providerWithKeychainValue:kKeychainHWID];

    PWPreferences *preferences = [self launchWithModuleLoadedAfterPreferences:provider];

    [mockConfig stopMocking];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:kAppGroupSuiteName];
    XCTAssertEqualObjects(preferences.hwid, kKeychainHWID);
    XCTAssertEqualObjects(preferences.userId, kKeychainHWID);
}

#pragma mark - Keychain unavailable

/// Verifies that a rejected Keychain write keeps the installation HWID and leaves the Keychain value as it was.
- (void)testRejectedKeychainWriteKeepsInstallationHWID {
    [self setInstallationHWID:kInstallationHWID];
    PWFakeKeychainProvider *provider = [self providerWithKeychainValue:kKeychainHWID];
    provider.rejectsWrites = YES;

    PWPreferences *preferences = [self launchWithModuleLoadedAfterPreferences:provider];

    [self assertPreferences:preferences useHWID:kInstallationHWID provider:provider keychainHWID:kKeychainHWID writeCount:1];
}

/// Verifies that on a first install a module that cannot store a new HWID leaves the default device identifier.
- (void)testRejectedKeychainCreationKeepsDefaultHWID {
    [self setInstallationHWID:nil];
    PWFakeKeychainProvider *provider = [self providerWithKeychainValue:nil];
    provider.rejectsWrites = YES;

    PWPreferences *preferences = [self launchWithModuleLoadedAfterPreferences:provider];

    [self assertPreferences:preferences useHWID:[PWUtils uniqueGlobalDeviceIdentifier] provider:provider keychainHWID:nil writeCount:1];
}

#pragma mark - Invalid Keychain value

/// Verifies that an invalid Keychain HWID counts as empty and is overwritten with the installation HWID.
- (void)testInvalidKeychainHWIDIsReplacedByInstallationHWID {
    [self setInstallationHWID:kInstallationHWID];
    PWFakeKeychainProvider *provider = [self providerWithKeychainValue:@"00000000-0000-0000-0000-000000000000"];

    PWPreferences *preferences = [self launchWithModuleLoadedAfterPreferences:provider];

    [self assertPreferences:preferences useHWID:kInstallationHWID provider:provider keychainHWID:kInstallationHWID writeCount:1];
}

/// Verifies that an invalid Keychain HWID on a first install is replaced by a module-created HWID.
- (void)testInvalidKeychainHWIDOnFirstInstallIsReplacedByModuleCreatedHWID {
    [self setInstallationHWID:nil];
    PWFakeKeychainProvider *provider = [self providerWithKeychainValue:@""];

    PWPreferences *preferences = [self launchWithModuleLoadedAfterPreferences:provider];

    [self assertPreferences:preferences useHWID:kModuleCreatedHWID provider:provider keychainHWID:kModuleCreatedHWID writeCount:1];
}

#pragma mark - Disabled module

/// Verifies that a disabled module leaves the HWID and the Keychain as without the module (module loaded first).
- (void)testDisabledModuleKeepsDefaultHWIDWithModuleLoadedFirst {
    [self setInstallationHWID:nil];
    PWFakeKeychainProvider *provider = [self providerWithKeychainValue:kKeychainHWID];
    provider.isPersistentHWIDEnabled = NO;

    PWPreferences *preferences = [self launchWithModuleLoadedBeforePreferences:provider];

    [self assertPreferences:preferences useHWID:[PWUtils uniqueGlobalDeviceIdentifier] provider:provider keychainHWID:kKeychainHWID writeCount:0];
}

/// Verifies that a disabled module leaves the HWID and the Keychain as without the module (module loaded later).
- (void)testDisabledModuleKeepsDefaultHWIDWithModuleLoadedLater {
    [self setInstallationHWID:nil];
    PWFakeKeychainProvider *provider = [self providerWithKeychainValue:kKeychainHWID];
    provider.isPersistentHWIDEnabled = NO;

    PWPreferences *preferences = [self launchWithModuleLoadedAfterPreferences:provider];

    [self assertPreferences:preferences useHWID:[PWUtils uniqueGlobalDeviceIdentifier] provider:provider keychainHWID:kKeychainHWID writeCount:0];
}

/// Verifies that without the module an installation HWID different from the device identifier still triggers migration.
- (void)testWithoutModuleDifferentInstallationHWIDKeepsMigration {
    [self setInstallationHWID:kInstallationHWID];

    PWPreferences *preferences = [[PWPreferences alloc] init];

    XCTAssertEqualObjects(preferences.hwid, [PWUtils uniqueGlobalDeviceIdentifier]);
    XCTAssertEqualObjects(preferences.previosHWID, kInstallationHWID);
}

@end
