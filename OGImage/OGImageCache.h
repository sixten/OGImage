//
//  OGImageCache.h
//
//  Created by Art Gillespie on 11/27/12.
//  Copyright (c) 2012 Origami Labs, Inc.. All rights reserved.
//

@import UIKit;

@class __OGImage;

/// Block signature for cache lookup completion callbacks.
typedef void (^OGImageCacheCompletionBlock)(__OGImage * _Nullable image);

/**
 * Straightforward cache for image loading and processing results.
 */
@interface OGImageCache : NSObject

/**
 * The shared cache instance.
 */
+ (OGImageCache * _Nonnull)shared;

/**
 * Creates a new cache that will store its on-disk data to the specified directory.
 */
- (nonnull instancetype)initWithDirectoryURL:(NSURL * _Nonnull)directoryURL;

/**
 * Check in-memory and on-disk caches for image corresponding to `key`. `block`
 * called on main queue when check is complete. If `image` parameter is `nil`,
 * no image corresponding to `key` was found.
 */
- (void)imageForKey:(NSString * _Nonnull)key block:(OGImageCacheCompletionBlock _Nullable)block;

/**
 * Adds an image to the cache with the specified `key`.
 * The process of saving the data is asynchronous; this method returns immediately.
 */
- (void)setImage:(__OGImage * _Nullable)image forKey:(NSString * _Nullable)key;

/**
 * Adds an image to the in-memory cache with the specified `key`.
 */
- (void)setMemoryCacheImage:(__OGImage * _Nullable)image forKey:(NSString * _Nullable)key;

/**
 * Remove all cached images from in-memory and on-disk caches. If `wait` is `YES`
 * this will block the calling thread until the purge is complete. In either case,
 * this method manages its own `UIBackgroundTaskIdentifier` — it's safe to call it
 * from `applicationDidEnterBackground`
 */
- (void)purgeCache:(BOOL)wait;

/**
 * Remove a single cached image from in-memory and on-disk caches. If `wait` is `YES`
 * this will block the calling thread until the purge is complete.
 */
- (void)purgeCacheForKey:(NSString * _Nonnull)key andWait:(BOOL)wait;

/**
 * Remove a single cached image from in-memory caches. If `wait` is `YES`
 * this will block the calling thread until the purge is complete.
 */
- (void)purgeMemoryCacheForKey:(NSString * _Nonnull)key andWait:(BOOL)wait;

/**
 * Remove cached images from disk that haven't been accessed since `date`
 * This method manages its own `UIBackgroundTaskIdentifier` — it's safe to call it
 * from `applicationDidEnterBackground`
 */
- (void)purgeDiskCacheOfImagesLastAccessedBefore:(NSDate * _Nonnull)date;

@end
