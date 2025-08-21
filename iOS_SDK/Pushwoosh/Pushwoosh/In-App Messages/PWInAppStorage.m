//
//  PWInAppStorage.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2016
//

#import "PWInAppStorage.h"
#import "PWResource.h"
#import "PWRequestManager.h"
#import "PWNetworkModule.h"
#import "PWGetResourcesRequest.h"
#import "PWBusinessCaseManager.h"
#import "PWGDPRManager+Internal.h"
#import "PWUtils.h"
#import "PWUnarchiver.h"

static NSString *const KeyInAppSavedResources = @"InAppSavedResources";

@interface PWInAppStorage ()

@property (nonatomic) NSMutableArray<dispatch_block_t> *listeners;
@property (atomic, strong) NSDictionary *resources;

@property (atomic, assign) volatile BOOL isUpdating;

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

		if (data) {
            if (TARGET_OS_IOS) {
                NSSet *set = [NSSet setWithObjects:[PWResource class], [NSString class], [NSDictionary class], nil];
                
                PWUnarchiver *unarchiver = [[PWUnarchiver alloc] init];
                _resources = [unarchiver unarchivedObjectOfClasses:set data:data];
            }
		} else {
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

    if (TARGET_OS_IOS && [PWUtils isSystemVersionGreaterOrEqualTo:@"11.0"]) {
        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:_resources requiringSecureCoding:YES error:&error];
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:KeyInAppSavedResources];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:_resources] forKey:KeyInAppSavedResources];
    }
    
	[[NSUserDefaults standardUserDefaults] synchronize];

	if (resource.isDownloaded && oldResource.updated == resource.updated) {
		return resource;
	}

	[resource downloadDataWithCompletion:nil];

	return resource;
}

- (void)synchronize:(void(^)(NSError *error))completion {
    if (self.isUpdating) {
        return;
    }

    self.isUpdating = YES;

    PWGetResourcesRequest *request = [PWGetResourcesRequest new];
    __weak typeof(self) wSelf = self;
    [_requestManager sendRequest:request completion:^(NSError *error) {
        if (error == nil) {
            [wSelf updateLocalResources:request.resources completion:^{
                if (completion)
                    completion(nil);
            }];
        } else {
            [wSelf completionLoad];
            if (completion)
                completion(error);
        }
    }];
}

- (void)resetBlocks {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [_listeners removeAllObjects];
    }];
}

- (void)completionLoad {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        self.isUpdating = NO;
        for (dispatch_block_t block in _listeners) {
            block();
        }
        [_listeners removeAllObjects];
        
        [[PWBusinessCaseManager sharedManager] handleBusinessCaseResources:_resources];
    }];
}

- (void)updateLocalResources:(NSDictionary *)resources
                  completion:(void(^)(void))completion {
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

    NSMutableArray<PWResource *> *priorityResources = [NSMutableArray arrayWithArray:resources.allValues];
    [priorityResources sortUsingComparator:^NSComparisonResult(PWResource *obj1, PWResource *obj2) {
        return obj1.priority > obj2.priority ? NSOrderedAscending : NSOrderedDescending;
    }];

    dispatch_group_t group = dispatch_group_create();

    for (PWResource *resource in priorityResources) {
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

    if (TARGET_OS_IOS && [PWUtils isSystemVersionGreaterOrEqualTo:@"11.0"]) {
        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:_resources requiringSecureCoding:YES error:&error];
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:KeyInAppSavedResources];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:_resources] forKey:KeyInAppSavedResources];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [self completionLoad];
        if (completion)
            completion();
    });
}

+ (void)destroy {
	inAppStorageInstance = nil;
	inAppStorageOncePred = 0;
}

@end
