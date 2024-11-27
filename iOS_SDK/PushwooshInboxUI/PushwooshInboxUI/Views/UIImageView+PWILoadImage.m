//
//  Pushwoosh SDK
//  (c) Pushwoosh 2016
//

#import "UIImageView+PWILoadImage.h"
#import "PWIWeakRef.h"
#import <objc/runtime.h>

@interface UIImageView (PWILoadImagePrivate)

- (void)pwi_loadImageFinished:(UIImage *)image memCache:(BOOL)memCache callback:(void (^)(UIImage *image))callback;
- (void)pwi_loadImageStarted;

- (void)setPWILoadingUrl:(NSString *)url;
- (NSString *)pwi_loadingUrl;

@end

static char pwiLoadImageUrl;

@interface PWIImageLoader : NSObject

@property (nonatomic, strong) NSCache *memCache;
@property (nonatomic, strong) NSMutableDictionary *imageViews;

+ (instancetype) sharedInstance;

@end

@implementation PWIImageLoader

- (instancetype)init {
    self = [super init];
    if (self) {
        _memCache = [NSCache new];
        _imageViews = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (instancetype)sharedInstance {
    static id instance = nil;
    static dispatch_once_t pred;
    
    dispatch_once(&pred, ^{
        instance = [[self class] new];
    });
    
    return instance;
}

- (void)loadImageWithUrl:(NSString *)url imageView:(UIImageView *)imageView callback:(void (^)(UIImage *image))callback {
    NSString *prevLoadingUrl = [imageView pwi_loadingUrl];
    if (url.length == 0 || [prevLoadingUrl isEqualToString:url])
        return;
    if (prevLoadingUrl) {
        NSMutableArray *refs = _imageViews[prevLoadingUrl];
        for (NSInteger i = 0; i < refs.count; ++i) {
            PWIWeakRef *ref = refs[i];
            if (ref.object == imageView) {
                [refs removeObject:ref];
            }
        }
        if (refs.count == 0) {
            _imageViews[prevLoadingUrl] = nil;
        }
    }
    imageView.image = nil;
    if (!url)
        return;
    UIImage *image = [_memCache objectForKey:url];
    if (!image) {
        [imageView setPWILoadingUrl:url];
        [imageView pwi_loadImageStarted];
        NSMutableArray *waitingImageViews = _imageViews[url];
        if (!waitingImageViews) {
            waitingImageViews = [NSMutableArray arrayWithObject:[PWIWeakRef refWithObject:imageView]];
            _imageViews[url] = waitingImageViews;
            [self loadImageWithUrl:url fromCache:YES cachedEtag:nil cachedLastModified:nil callback:callback];
        } else {
            [waitingImageViews addObject:[PWIWeakRef refWithObject:imageView]];
        }
    } else {
        [imageView pwi_loadImageFinished:image memCache:YES callback: callback];
    }
}

- (void)loadImageWithUrl:(NSString *)url fromCache:(BOOL)cache cachedEtag:(NSString *)cachedEtag cachedLastModified:(NSString *)cachedLastModified callback:(void (^)(UIImage *image))callback {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:cache ? NSURLRequestReturnCacheDataDontLoad : NSURLRequestUseProtocolCachePolicy timeoutInterval:120];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSString *etag = httpResponse.allHeaderFields[@"etag"];
        NSString *lastModified = httpResponse.allHeaderFields[@"Last-Modified"];
        void (^handleLoadFinished)(void) = ^{
            if (cache) {
                [self loadImageWithUrl:url fromCache:NO cachedEtag:etag cachedLastModified:lastModified callback:callback];
            } else {
                NSArray *refs = _imageViews[url];
                for (PWIWeakRef<UIImageView *> *ref in refs) {
                    [ref.object setPWILoadingUrl:nil];
                }
                _imageViews[url] = nil;
            }
        };
        if (data != nil && ![cachedEtag isEqualToString:etag] && ![cachedLastModified isEqualToString:lastModified]) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                UIImage *image = [UIImage imageWithData:data];
                [self putImageToMemCache:image url:url];
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSArray *refs = _imageViews[url];
                    for (PWIWeakRef<UIImageView *> *ref in refs) {
                        [ref.object pwi_loadImageFinished:image memCache:NO callback:callback];
                    }
                    handleLoadFinished();
                });
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), handleLoadFinished);
        }
    }] resume];
}

- (void)putImageToMemCache:(UIImage *)image url:(NSString *)url {
    CGImageRef cgImage = image.CGImage;
    if (cgImage != NULL) {
        NSUInteger numberOfbytes = (CGImageGetWidth(cgImage) * CGImageGetHeight(cgImage) * CGImageGetBitsPerPixel(cgImage)) / 8;
        [_memCache setObject:image forKey:url cost:numberOfbytes];
    }
}

@end

@implementation UIImageView (PWILoadImage)

- (void)setPWILoadingUrl:(NSString *)url {
    objc_setAssociatedObject(self, &pwiLoadImageUrl, url, OBJC_ASSOCIATION_COPY);
}

- (NSString *)pwi_loadingUrl {
    return objc_getAssociatedObject(self, &pwiLoadImageUrl);
}

- (void)pwi_loadImageFinished:(UIImage *)image memCache:(BOOL)memCache callback:(void (^)(UIImage *image))callback {
    self.image = image;
    if (!memCache && self.alpha < 0.5) {
        [UIView animateWithDuration:0.2 animations:^{
            self.alpha = 1;
        }];
    }
    if (callback != nil) {
        callback(image);
    }
}

- (void)pwi_loadImageStarted {
    self.alpha = 0;
}

- (void)pwi_loadImageFromUrl:(NSString *)url callback:(void (^)(UIImage *image))callback {
    [[PWIImageLoader sharedInstance] loadImageWithUrl:url imageView:self callback:callback];
}

- (BOOL)pwi_isLoading {
    return [self pwi_loadingUrl] != nil;
}

@end
