//
//  PWRequestManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PushwooshLog.h>
#import <PushwooshCore/PushwooshConfig.h>
#import <PushwooshCore/PWPreferences.h>
#import <PushwooshCore/PWRequest.h>

typedef void (^PWRequestDownloadCompleteBlock)(NSString *, NSError *);

@interface PWRequestManager : NSObject

/// Indicates whether gRPC transport is available.
/// Returns YES when PushwooshGRPC module is linked to the project.
@property (nonatomic, readonly) BOOL isGRPCAvailable;

- (void)sendRequest:(PWRequest *)request completion:(void (^)(NSError *error))completion;
- (void)downloadDataFromURL:(NSURL *)url withCompletion:(PWRequestDownloadCompleteBlock)completion;
- (void)setReverseProxyUrl:(NSString *)url headers:(NSDictionary<NSString *, NSString *> *)headers;
- (void)loadReverseProxyFromAppGroups;

/// Loads reverse proxy settings shared by the host app from the given App Group suite.
/// Pass the App Group resolved by the Notification Service Extension (e.g. from
/// `pushwooshAppGroupsName`) so the read suite matches the one the host app wrote to.
/// When `appGroupsName` is nil or empty, falls back to `PWConfig.appGroupsName`.
- (void)loadReverseProxyFromAppGroups:(NSString *)appGroupsName;

@end
