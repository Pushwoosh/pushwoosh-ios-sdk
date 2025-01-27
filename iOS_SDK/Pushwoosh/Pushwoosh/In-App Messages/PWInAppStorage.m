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
			[wSelf updateLocalResources:request.resources];
		} else {
			[wSelf completionLoad];
		}
        completion(error);
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

- (void)updateLocalResources:(NSDictionary *)resources {
	NSMutableDictionary *currentResources = [_resources mutableCopy];

	NSMutableSet *oldResources = [NSMutableSet new];

	// find old resources
	for (PWResource *resource in currentResources.allValues) {
		PWResource *newResource = resources[resource.code];
		if (newResource.updated != resource.updated && ![resource isRichMedia]) {
			[oldResources addObject:resource];
		}
	}
    
	// remove old resources
	for (PWResource *resource in oldResources.allObjects) {
		if (!resource.locked) {
			// do not touch inapp if it is currently showing
			[resource deleteData];
			[currentResources removeObjectForKey:resource.code];
		}
	}
    
	//sort for priority
    NSMutableArray<PWResource *> *priorityResources = [NSMutableArray new];
    [priorityResources addObjectsFromArray:resources.allValues];
    [priorityResources sortUsingComparator:^NSComparisonResult(PWResource *obj1, PWResource *obj2) {
        if (obj1.priority > obj2.priority) {
            return NSOrderedAscending;
        } else {
            return NSOrderedDescending;
        }
    }];
    
    // find and update new resources
	for (PWResource *resource in priorityResources) {
		PWResource *existingResource = currentResources[resource.code];
		if (existingResource.locked) {
			// do not touch inapp if it is currently showing
			continue;
		}
		
		if (!resource.isDownloaded || existingResource.updated != resource.updated) {
			[resource downloadDataWithCompletion:nil];
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

	[self completionLoad];
}

+ (void)destroy {
	inAppStorageInstance = nil;
	inAppStorageOncePred = 0;
}

@end
