//
//  PWInAppStorage.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2016
//

#if TARGET_OS_IOS || TARGET_OS_TV
#import "PWInAppStorage.h"
#import "PWResource.h"
#import "PWRequestManager.h"
#import "PWNetworkModule.h"
#import "PWGetResourcesRequest.h"
#import "PWUtils.h"
#import <PushwooshCore/PushwooshLog.h>

static NSString *const KeyInAppSavedResources = @"InAppSavedResources";

@interface PWInAppStorage ()

@property (nonatomic) NSMutableArray<dispatch_block_t> *listeners;
@property (nonatomic) NSMutableArray<dispatch_block_t> *fullSyncListeners;
@property (atomic, strong) NSDictionary *resources;

@property (atomic, assign) volatile BOOL isUpdating;
@property (atomic, assign) volatile BOOL isSyncing;

// @Inject
@property (nonatomic, strong) PWRequestManager *requestManager;

@end

@implementation PWInAppStorage

- (instancetype)init {
	self = [super init];
	if (self) {
		[[PWNetworkModule module] inject:self];

		NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:KeyInAppSavedResources];
        _listeners = [NSMutableArray new];
        _fullSyncListeners = [NSMutableArray new];

		if (data.length > 0) {
            if (TARGET_OS_IOS || TARGET_OS_TV) {
                NSSet *set = [NSSet setWithObjects:
                              [PWResource class],
                              [NSMutableDictionary class],
                              [NSDictionary class],
                              [NSMutableArray class],
                              [NSArray class],
                              [NSString class],
                              [NSNumber class],
                              [NSDate class],
                              [NSNull class],
                              nil];
                NSError *error = nil;
                _resources = [NSKeyedUnarchiver unarchivedObjectOfClasses:set fromData:data error:&error];
                if (error) {
                    [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:[NSString stringWithFormat:@"Deserialization failed: %@", error.localizedDescription]];
                }
            }
		}
		if (!_resources) {
			_resources = @{};
		}
	}

	return self;
}

static PWInAppStorage *inAppStorageInstance = nil;
static dispatch_once_t inAppStorageOncePred;

+ (PWInAppStorage *)storage {
	dispatch_once(&inAppStorageOncePred, ^{
		inAppStorageInstance = [PWInAppStorage new];
	});

	return inAppStorageInstance;
}

- (PWResource *)resourceForCode:(NSString *)code {
	return _resources[code];
}

- (void)resourcesForCode:(NSString *)code completionBlock:(void (^)(PWResource *resource))completion {
    __weak typeof(self) wself = self;
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        if (!wself.isUpdating && completion) {
            completion([wself resourceForCode:code]);
        }
        else if (wself.isUpdating && completion) {
            [wself.listeners addObject:^{
                completion([wself resourceForCode:code]);
            }];
        }
    }];
}

- (PWResource *)resourceForDictionary:(NSDictionary *)dict {
	PWResource *resource = [[PWResource alloc] initWithDictionary:dict];
	if (!resource)
		return nil;

	PWResource *oldResource = nil;
	oldResource = _resources[resource.code];

	NSMutableDictionary *newResources = [_resources mutableCopy];
	newResources[resource.code] = resource;
	_resources = newResources;

#if TARGET_OS_IOS || TARGET_OS_TV
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:_resources requiringSecureCoding:YES error:&error];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:KeyInAppSavedResources];
#endif

	[[NSUserDefaults standardUserDefaults] synchronize];

	if (resource.isDownloaded && oldResource.updated == resource.updated) {
		return resource;
	}

	[resource downloadDataWithCompletion:nil];

	return resource;
}

- (void)synchronize:(void(^)(NSError *error))completion {
    [self synchronizeWaitingForDownloads:YES completion:completion];
}

- (void)synchronizeCatalog:(void(^)(NSError *error))completion {
    [self synchronizeWaitingForDownloads:NO completion:completion];
}

- (void)synchronizeWaitingForDownloads:(BOOL)waitForDownloads completion:(void(^)(NSError *error))completion {
    BOOL waitingOnMatchingPhase = waitForDownloads ? self.isSyncing : self.isUpdating;
    if (waitingOnMatchingPhase) {
        if (completion) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                dispatch_block_t listener = ^{
                    completion(nil);
                };
                if (waitForDownloads) {
                    [self.fullSyncListeners addObject:listener];
                } else {
                    [self.listeners addObject:listener];
                }
            }];
        }
        return;
    }

    // Catalog already known; a running download phase alone must not block a catalog-only caller.
    if (!waitForDownloads && self.isSyncing) {
        if (completion) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                completion(nil);
            }];
        }
        return;
    }

    self.isSyncing = YES;
    self.isUpdating = YES;

    PWGetResourcesRequest *request = [PWGetResourcesRequest new];
    __weak typeof(self) wSelf = self;
    [_requestManager sendRequest:request completion:^(NSError *error) {
        if (error) {
            [wSelf finishCatalogUpdate:nil];
            [wSelf finishFullSync:nil];
            if (completion)
                completion(error);
            return;
        }

        [wSelf updateLocalResources:request.resources
                       catalogReady:^{
            if (!waitForDownloads && completion)
                completion(nil);
        }
                     downloadsReady:^{
            if (waitForDownloads && completion)
                completion(nil);
        }];
    }];
}

- (void)resetBlocks {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [_listeners removeAllObjects];
        [_fullSyncListeners removeAllObjects];
    }];
}

- (void)finishPhaseWithListeners:(NSMutableArray<dispatch_block_t> *)listeners
                       clearFlag:(void (^)(void))clearFlag
                      completion:(void (^)(void))completion {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        clearFlag();
        NSArray<dispatch_block_t> *pending = [listeners copy];
        [listeners removeAllObjects];
        for (dispatch_block_t block in pending) {
            block();
        }
        if (completion)
            completion();
    }];
}

- (void)finishCatalogUpdate:(void (^)(void))completion {
    [self finishPhaseWithListeners:_listeners
                         clearFlag:^{ self.isUpdating = NO; }
                        completion:completion];
}

- (void)finishFullSync:(void (^)(void))completion {
    [self finishPhaseWithListeners:_fullSyncListeners
                         clearFlag:^{ self.isSyncing = NO; }
                        completion:completion];
}

- (void)updateLocalResources:(NSDictionary *)resources
                catalogReady:(void (^)(void))catalogReady
              downloadsReady:(void (^)(void))downloadsReady {
    NSMutableDictionary *currentResources = [_resources mutableCopy];
    NSMutableSet *oldResources = [NSMutableSet new];

    for (PWResource *resource in currentResources.allValues) {
        PWResource *newResource = resources[resource.code];
        if (newResource.updated != resource.updated && ![resource isRichMedia]) {
            [oldResources addObject:resource];
        }
    }

    for (PWResource *resource in oldResources) {
        if (!resource.locked) {
            [resource deleteData];
            [currentResources removeObjectForKey:resource.code];
        }
    }

    dispatch_group_t group = dispatch_group_create();

    for (PWResource *resource in resources.allValues) {
        PWResource *existingResource = currentResources[resource.code];
        if (existingResource.locked) {
            continue;
        }
        if (!resource.isDownloaded || existingResource.updated != resource.updated) {
            dispatch_group_enter(group);
            [resource downloadDataWithCompletion:^(NSError *error) {
                dispatch_group_leave(group);
            }];
        }
        currentResources[resource.code] = resource;
    }

    _resources = currentResources;

#if TARGET_OS_IOS || TARGET_OS_TV
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:_resources requiringSecureCoding:YES error:&error];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:KeyInAppSavedResources];
#endif
    [[NSUserDefaults standardUserDefaults] synchronize];

    [self finishCatalogUpdate:catalogReady];

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [self finishFullSync:downloadsReady];
    });
}

+ (void)destroy {
	inAppStorageInstance = nil;
	inAppStorageOncePred = 0;
}

@end
#endif
