
#import "PushNotificationManager+Mock.h"

#import <objc/runtime.h>

static BOOL gMock = NO;

static id gProxy = nil;

@interface PushNotificationManager (MockProtected)

- (instancetype)initPrivateWithApplicationCode:(NSString *)appCode appName:(NSString *)appName;

@end

@implementation PushNotificationManager (Mock)

+ (void)setMock:(BOOL)mock {
	gMock = mock;
}

+ (void)setProxy:(id)proxy {
	gProxy = proxy;
}

- (id) mock_initWithApplicationCode:(NSString *)appCode appName:(NSString *)appName {
	if (gMock) {
		// Stub
		NSLog(@"PushNotificationManager mock_initWithApplicationCode");
		return [super init];
	}
	
	// Real method
	return [self mock_initWithApplicationCode:appCode appName:appName];
}

- (void) mock_postEvent: (NSString*) event withAttributes: (NSDictionary*) attributes completion: (void(^)(NSError* error)) completion {
	if (gMock) {
		// Stub
		NSLog(@"PushNotificationManager mock_postEvent");
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:@selector(postEvent:withAttributes:completion:)]];
		[invocation setTarget:gProxy];
		[invocation setArgument:&event atIndex:2];
		[invocation setArgument:&attributes atIndex:3];
		[invocation setArgument:&completion atIndex:4];
		[invocation setSelector:@selector(postEvent:withAttributes:completion:)];
		[invocation retainArguments];
		[invocation invokeWithTarget:gProxy];
	}
	
	// Real method
	return [self mock_postEvent:event withAttributes:attributes completion:completion];
}

- (void) mock_setTags: (NSDictionary *) tags withCompletion: (PushwooshErrorHandler) completion {
	if (gMock) {
		// Stub
		NSLog(@"PushNotificationManager mock_setTags:withCompletion:");
		[gProxy performSelector:@selector(setTags:withCompletion:) withObject:tags withObject:completion];
	}
	
	// Real method
	return [self mock_setTags:tags withCompletion:completion];
}

- (void) mock_setTags: (NSDictionary *) tags {
    if (gMock) {
        // Stub
        NSLog(@"PushNotificationManager mock_setTags");
        [gProxy performSelector:@selector(setTags:) withObject:tags];
    }
    
    // Real method
    return [self mock_setTags:tags];
}

+ (void) load {
	NSLog(@"initializing PushNotificationManager (Mock)");
	
	method_exchangeImplementations(class_getInstanceMethod(self, @selector(mock_initWithApplicationCode: appName:)), class_getInstanceMethod(self, @selector(initPrivateWithApplicationCode: appName:)));
	method_exchangeImplementations(class_getInstanceMethod(self, @selector(mock_setTags:withCompletion:)), class_getInstanceMethod(self, @selector(setTags:withCompletion:)));
    method_exchangeImplementations(class_getInstanceMethod(self, @selector(mock_setTags:)), class_getInstanceMethod(self, @selector(setTags:)));
	method_exchangeImplementations(class_getInstanceMethod(self, @selector(mock_postEvent:withAttributes:completion:)), class_getInstanceMethod(self, @selector(postEvent:withAttributes:completion:)));
}

@end
