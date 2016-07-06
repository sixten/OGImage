//
//  OGImageCache.m
//
//  Created by Art Gillespie on 11/27/12.
//  Copyright (c) 2012 Origami Labs, Inc.. All rights reserved.
//

#import "OGImageCache.h"
#import "OGImage.h"
#import "__OGImage.h"
#import <CommonCrypto/CommonDigest.h>
#import <ImageIO/ImageIO.h>

static OGImageCache *OGImageCacheShared;

static NSURL *OGImageCacheDefaultURL() {
    // generate the cache path: <app>/Library/Application Support/<bundle identifier>/OGImageCache,
    // creating the directories as needed
    NSArray *array = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    if (nil == array || 0 == [array count]) {
        return nil;
    }
    NSURL *cacheURL = [[array[0] URLByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]] URLByAppendingPathComponent:@"OGImageCache"];
    return cacheURL;
}

static NSString *OGMD5(NSString *string) {
    const char *d = [string UTF8String];
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(d, (CC_LONG)strlen(d), r);
    NSMutableString *hexString = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH];
    for (int ii = 0; ii < CC_MD5_DIGEST_LENGTH; ++ii) {
        [hexString appendFormat:@"%02x", r[ii]];
    }
    return [NSString stringWithString:hexString];
}


@interface OGImageCache ()

@property (copy,   nonatomic) NSURL *directoryURL;
@property (strong, nonatomic) NSCache *memoryCache;
@property (strong, nonatomic) dispatch_queue_t cacheFileReadQueue;
@property (strong, nonatomic) dispatch_queue_t cacheFileTasksQueue;

@end

@implementation OGImageCache

+ (OGImageCache *)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        OGImageCacheShared = [[OGImageCache alloc] initWithDirectoryURL:OGImageCacheDefaultURL()];
    });
    return OGImageCacheShared;
}

- (instancetype)initWithDirectoryURL:(NSURL *)directoryURL {
    NSParameterAssert(directoryURL);
  
    self = [super init];
    if (self) {
        self.directoryURL = directoryURL;
        [[NSFileManager defaultManager] createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:nil];
      
        self.memoryCache = [[NSCache alloc] init];
        [self.memoryCache setName:@"com.origamilabs.OGImageCache"];
      
        /*
         * We use the 'queue-jumping' pattern outlined in WWDC 2011 Session 201: "Mastering Grand Central Dispatch"
         * We place lower-priority tasks (writing, purging) on a serial queue that has its
         * target queue set to our high-priority (read) queue. Whenever we submit a high-priority
         * block, we suspend the lower-priority queue for the duration of the block.
         *
         * This way, writes and purges never cause cache reads to wait in the queue.
         */
        self.cacheFileReadQueue = dispatch_queue_create("com.origamilabs.OGImageCache.read", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(self.cacheFileReadQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
        self.cacheFileTasksQueue = dispatch_queue_create("com.origamilabs.OGImageCache.filetasks", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(self.cacheFileTasksQueue, self.cacheFileReadQueue);
    }
    return self;
}

- (NSURL *)fileURLForKey:(NSString *)key {
    return [self.directoryURL URLByAppendingPathComponent:OGMD5(key)];
}

- (void)imageForKey:(NSString *)key block:(OGImageCacheCompletionBlock)block {
    NSParameterAssert(nil != key);
    NSParameterAssert(nil != block);
    __OGImage *image = [self.memoryCache objectForKey:key];
    if (nil != image) {
        block(image);
        return;
    }
    dispatch_suspend(self.cacheFileTasksQueue);
    dispatch_async(self.cacheFileReadQueue, ^{
        // Check to see if the image is cached locally
        NSURL *cacheURL = [self fileURLForKey:(key)];
        __OGImage *storedImage = [[__OGImage alloc] initWithDataAtURL:cacheURL];
        // if we have the image in the on-disk cache, store it to the in-memory cache
        if (nil != storedImage) {
            [self.memoryCache setObject:storedImage forKey:key];
        }
        // calls the block with the image if it was cached or nil if it wasn't
        dispatch_async(dispatch_get_main_queue(), ^{
            block(storedImage);
        });
        dispatch_resume(self.cacheFileTasksQueue);
    });
}

- (void)setImage:(__OGImage *)image forKey:(NSString *)key {
    // assert for developers, and guard against production crashes
    NSParameterAssert(nil != image);
    NSParameterAssert(nil != key);
    if (nil == image || nil == key) {
        return;
    }
    
    [self setMemoryCacheImage:image forKey:key];
    
    dispatch_async(self.cacheFileTasksQueue, ^{
        NSURL *fileURL = [self fileURLForKey:key];
        NSError *error;
        if(![image writeToURL:fileURL error:&error]) {
            NSLog(@"[OGImageCache ERROR] failed to write image with error %@ %s %d", error, __FILE__, __LINE__);
            return;
        }
        // make sure the cached file doesn't get backed up to iCloud
        // http://developer.apple.com/library/ios/#qa/qa1719/_index.html
        [fileURL setResourceValue:[NSNumber numberWithBool:YES] forKey: NSURLIsExcludedFromBackupKey error:nil];
    });
}

- (void)setMemoryCacheImage:(__OGImage * _Nullable)image forKey:(NSString * _Nullable)key {
    // assert for developers, and guard against production crashes
    NSParameterAssert(nil != image);
    NSParameterAssert(nil != key);
    if (nil == image || nil == key) {
        return;
    }
    
    [self.memoryCache setObject:image forKey:key];
}

- (void)purgeCache:(BOOL)wait {
    [self.memoryCache removeAllObjects];
    UIBackgroundTaskIdentifier taskId = UIBackgroundTaskInvalid;
    taskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:taskId];
    }];
    void (^purgeFilesBlock)(void) = ^{
        for (NSURL *url in [[NSFileManager defaultManager] enumeratorAtURL:self.directoryURL includingPropertiesForKeys:nil options:(NSDirectoryEnumerationOptions)0 errorHandler:nil]) {
            [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        }
        [[UIApplication sharedApplication] endBackgroundTask:taskId];
    };
    if (YES == wait) {
        dispatch_sync(self.cacheFileTasksQueue, purgeFilesBlock);
    } else {
        dispatch_async(self.cacheFileTasksQueue, purgeFilesBlock);
    }
}

- (void)purgeCacheForKey:(NSString *)key andWait:(BOOL)wait {
    NSParameterAssert(nil != key);

    [self purgeMemoryCacheForKey:key andWait:wait];

    NSURL *cachedFileURL = [self fileURLForKey:key];
    
    void (^purgeFileBlock)(void) =^{
        [[NSFileManager defaultManager] removeItemAtURL:cachedFileURL error:nil];
    };
    
    if (YES == wait) {
        dispatch_sync(self.cacheFileTasksQueue, purgeFileBlock);
    } else {
        dispatch_async(self.cacheFileTasksQueue, purgeFileBlock);
    }
}

- (void)purgeMemoryCacheForKey:(NSString *)key andWait:(__unused BOOL)wait {
    NSParameterAssert(nil != key);
    [self.memoryCache removeObjectForKey:key];
}

- (void)purgeDiskCacheOfImagesLastAccessedBefore:(NSDate *)date {
    UIBackgroundTaskIdentifier taskId = UIBackgroundTaskInvalid;
    taskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:taskId];
    }];
    dispatch_async(self.cacheFileTasksQueue, ^{
        for (NSURL *fileURL in [[NSFileManager defaultManager] enumeratorAtURL:self.directoryURL includingPropertiesForKeys:@[NSURLContentAccessDateKey] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:nil]) {
            NSDate *accessDate;
            if (NO == [fileURL getResourceValue:&accessDate forKey:NSURLContentAccessDateKey error:nil]) {
                return;
            }
            if (NSOrderedDescending == [date compare:accessDate]) {
                [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
            }
        }
        [[UIApplication sharedApplication] endBackgroundTask:taskId];
    });
}

@end
