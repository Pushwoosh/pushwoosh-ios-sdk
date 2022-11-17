//
//  PWRequestManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import <Foundation/Foundation.h>
#import "PWRequest.h"

typedef void (^PWRequestDownloadCompleteBlock)(NSString *, NSError *);

@interface PWRequestManager : NSObject

- (void)sendRequest:(PWRequest *)request completion:(void (^)(NSError *error))completion;
- (void)downloadDataFromURL:(NSURL *)url withCompletion:(PWRequestDownloadCompleteBlock)completion;
- (void)setReverseProxyUrl:(NSString *)url;
- (void)disableReverseProxy;

@end
