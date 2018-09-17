//
//  OGImageLoader.h
//
//  Created by Art Gillespie on 11/26/12.
//  Copyright (c) 2012 Origami Labs, Inc.. All rights reserved.
//

@import UIKit;
#import "OGImageLoaderDelegate.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OGImageLoaderPriority) {
    OGImageLoaderPriority_Low,
    OGImageLoaderPriority_Default,
    OGImageLoaderPriority_High
};

/**
 * This block is called when an image is loaded or fails to load. If `error` is
 * nil, `image` should be valid.
 */
typedef void(^OGImageLoaderCompletionBlock)(__OGImage * _Nullable image, NSError * _Nullable error, NSTimeInterval loadTime);

@interface OGImageLoader : NSObject

/**
 * `OGImageLoader` is intended to be used as a singleton.
 */
+ (OGImageLoader *)shared;

/**
 * Enqueues a request to load the image at `imageURL`. `completionBlock` will always
 * be called on the main queue.
 */
- (void)enqueueImageRequest:(NSURL *)imageURL delegate:(id<OGImageLoaderDelegate>)delegate;

/**
 * The maximum number of concurrent network requests that can be in-flight at
 * any one time. (Default: 4)
 */
@property (nonatomic, assign) NSInteger maxConcurrentNetworkRequests;

/**
 * The priority of the image loader request queue. Default: OGImageLoaderPriority_Low
 */
@property (nonatomic, assign) OGImageLoaderPriority priority;

/**
 * A custom string to use as the User-Agent header for HTTP requests.
 */
@property (nonatomic, copy, nullable) NSString *userAgent;

@end

NS_ASSUME_NONNULL_END
