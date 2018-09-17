//
//  OGImageLoader.m
//
//  Created by Art Gillespie on 11/26/12.
//  Copyright (c) 2012 Origami Labs, Inc.. All rights reserved.
//

#import "OGImageLoader.h"
#import "OGImageRequest.h"
#import "__OGImage.h"

#pragma mark - Constants

NSString * const OGImageLoadingErrorDomain = @"OGImageLoadingErrorDomain";
NSString * const OGImageLoadingHTTPStatusErrorKey = @"HTTPStatus";

static OGImageLoader * OGImageLoaderInstance;

#pragma mark -

@implementation OGImageLoader {
    NSURLSession *_urlSession;
    
    // The queue on which our OGImageRequest completion blocks are executed.
    dispatch_queue_t _imageCompletionQueue;
    // A LIFO queue of _OGImageLoaderInfo instances
    NSMutableArray *_requests;
    // Serializes access to the the request queue
    dispatch_queue_t _requestsSerializationQueue;

    NSInteger _inFlightRequestCount;
    // We use this timer to periodically check _requestSerializationQueue for requests to fire off
    dispatch_source_t _timer;
    // A queue solely for file-loading work (e.g., when we get a `file:` URL)
    dispatch_queue_t _fileWorkQueue;
    // key -> url, value -> NSArray of id<OGImageLoaderDelegate>
    // we use this to track multiple interested parties on a single url
    NSMutableDictionary *_loaderDelegates;
    // key -> url, value -> OGImageRequest
    // we use this to find the actual request object associated with a URL
    NSMutableDictionary *_requestLookup;
}

+ (OGImageLoader *)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        OGImageLoaderInstance = [[OGImageLoader alloc] init];
    });
    return OGImageLoaderInstance;
}

- (id)init {
    self = [super init];
    if (nil != self) {
        self.maxConcurrentNetworkRequests = 4;
        _requests = [NSMutableArray arrayWithCapacity:128];
        _requestsSerializationQueue = dispatch_queue_create("com.origamilabs.requestSerializationQueue", DISPATCH_QUEUE_SERIAL);
        self.priority = OGImageLoaderPriority_Low;
        
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        // TODO: any additional customization
        _urlSession = [NSURLSession sessionWithConfiguration:configuration];
        // FIXME: _urlSession.delegate = self;
        
        _imageCompletionQueue = dispatch_queue_create("com.origamilabs.imageCompletionQueue", DISPATCH_QUEUE_SERIAL);
        _fileWorkQueue = dispatch_queue_create("com.origamilabs.fileWorkQueue", DISPATCH_QUEUE_CONCURRENT);
        _loaderDelegates = [NSMutableDictionary dictionaryWithCapacity:64];
        _requestLookup = [NSMutableDictionary dictionaryWithCapacity:128];
        
        _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _requestsSerializationQueue);
        // 33ms timer w/10 ms leeway
        dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, 33000000, 10000000);
        dispatch_source_set_event_handler(_timer, ^{
            [self checkForWork];
        });
        dispatch_resume(_timer);
    }
    return self;
}

- (void)dealloc {
    dispatch_suspend(_timer);
}


#pragma mark - Public API

- (void)setPriority:(OGImageLoaderPriority)priority {
    _priority = priority;
    dispatch_queue_priority_t newPriority = DISPATCH_QUEUE_PRIORITY_LOW;
    if (OGImageLoaderPriority_High == _priority) {
        newPriority = DISPATCH_QUEUE_PRIORITY_HIGH;
    } else if (OGImageLoaderPriority_Default) {
        newPriority = DISPATCH_QUEUE_PRIORITY_DEFAULT;
    }
    dispatch_set_target_queue(_requestsSerializationQueue, dispatch_get_global_queue(newPriority, 0));
}

- (void)setUserAgent:(NSString *)userAgent
{
    _userAgent = [userAgent copy];
    [_urlSession.configuration.HTTPAdditionalHeaders setValue:userAgent forKey:@"User-Agent"];
}

- (void)enqueueImageRequest:(NSURL *)imageURL delegate:(id<OGImageLoaderDelegate>)delegate {
    NSParameterAssert(imageURL);
    NSParameterAssert(delegate);
    
    /**
     *
     * What we basically have here is a LIFO queue (or stack, if you prefer) in `_requests`,
     * access to which
     * is serialized by the serial dispatch queue `_requestsSerializationQueue`.
     * (The overloaded use of the term "queue" here is a possible source of confusion.
     * The former is a data structure, the latter is a GCD queue, used here in
     * place of a lock or mutex.)
     *
     * `OGImageRequest` instances are pushed onto the LIFO queue (stack) on the
     * serialization queue. It's not important when this happens, so we `dispatch_async`
     * it.
     *
     * Periodically, a timer (see the dispatch_source `_timer` ivar) will call
     * `checkForWork` (also on `_requestsSerializationQueue`) and fire off a network
     * request for the most recently added `OGImageRequest` in `_requests`, assuming
     * the number of in-flight requests is not greater or equal to `self.maxConcurrentNetworkRequests`
     *
     * The idea here is that if a bunch of image load requests come in in a short
     * period of time (as might be the case when, e.g., scrolling a `UITableView`)
     * the most recently requested will always have the highest priority for the next
     * available network request.
     *
     */
    // if this is a file:// URL, don't bother with a OGImageRequest
    if ([[imageURL scheme] isEqualToString:@"file"]) {
        dispatch_async(_fileWorkQueue, ^{
            [self loadFileForURL:imageURL delegate:delegate];
        });
        return;
    }

    // it's a network url
    dispatch_async(_requestsSerializationQueue, ^{
        // serialize access to the request LIFO 'queue'
        
        OGImageRequest *request;
        NSString *key = [imageURL absoluteString];

        // check to see if there's already an in-flight request for this url
        request = self->_requestLookup[key];
        if (nil != request) {
            // we already have a request out for this url, so add the loader delegate to the list
            NSMutableArray *listeners = self->_loaderDelegates[key];
            [listeners addObject:delegate];
            
            // and if the request has already started, notify the delegate of the progress
            if( request.hasStarted && [delegate respondsToSelector:@selector(imageLoader:didBeginLoadingForURL:progress:)] ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSProgress *progress = nil;
                    if (@available(iOS 11, *)) {
                        progress = request.progress;
                    }
                    [delegate imageLoader:self didBeginLoadingForURL:imageURL progress:progress];
                });
            }
            
            return;
        }

        // we don't have a request out for this url, so create it...
        request = [[OGImageRequest alloc] initWithURL:imageURL
                                      completionBlock:^(__OGImage *image, NSError *error, __unused double timeElapsed){
            dispatch_async(self->_imageCompletionQueue, ^{
                if (self->_inFlightRequestCount > 0) {
                    self->_inFlightRequestCount--;
                }
                // when the request is complete, notify all interested delegates
                __block NSMutableArray *listeners = nil;
                dispatch_sync(self->_requestsSerializationQueue, ^{
                    // we need to ensure serial access to the delegate array
                    listeners = self->_loaderDelegates[key];
                    [self->_loaderDelegates removeObjectForKey:key];
                    [self->_requestLookup removeObjectForKey:key];
                });
                dispatch_async(dispatch_get_main_queue(), ^{
                    // call back all the delegates on the main queue
                    for (id<OGImageLoaderDelegate> loaderDelegate in listeners) {
                        if (nil == image) {
                            [loaderDelegate imageLoader:self failedForURL:imageURL error:error];
                        } else {
                            [loaderDelegate imageLoader:self didLoadImage:image forURL:imageURL];
                        }
                    }
                });
            });
        }];
        
        // ... enqueue it ...
        [self->_requests addObject:request];
        self->_requestLookup[key] = request;

        // ... and add the delegate to _loaderDelegates
        NSMutableArray *listeners = [NSMutableArray arrayWithCapacity:3];
        [listeners addObject:delegate];
        self->_loaderDelegates[key] = listeners;
    });
}


#pragma mark - Private

- (void)checkForWork {
    if (self.maxConcurrentNetworkRequests > _inFlightRequestCount && 0 < [_requests count]) {
        OGImageRequest *request = [_requests lastObject];
        [_requests removeLastObject];
        [request retrieveImageInSession:_urlSession];
        _inFlightRequestCount++;
        
        NSArray *listeners = [NSArray arrayWithArray:self->_loaderDelegates[[request.url absoluteString]]];
        dispatch_async(dispatch_get_main_queue(), ^{
            for (id<OGImageLoaderDelegate> loaderDelegate in listeners) {
                if( [loaderDelegate respondsToSelector:@selector(imageLoader:didBeginLoadingForURL:progress:)] ) {
                    NSProgress *progress = nil;
                    if (@available(iOS 11, *)) {
                        progress = request.progress;
                    }
                    [loaderDelegate imageLoader:self didBeginLoadingForURL:request.url progress:progress];
                }
            }
        });
    }
}

- (void)loadFileForURL:(NSURL *)imageURL delegate:(id<OGImageLoaderDelegate>)delegate {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:0];
    progress.kind = NSProgressKindFile;
    [progress setUserInfoObject:NSProgressFileOperationKindDecompressingAfterDownloading
                         forKey:NSProgressFileOperationKindKey];
    if( [delegate respondsToSelector:@selector(imageLoader:didBeginLoadingForURL:progress:)] ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate imageLoader:self didBeginLoadingForURL:imageURL progress:progress];
        });
    }
    
    __OGImage *image = [[__OGImage alloc] initWithDataAtURL:imageURL];
    NSError *error = nil;
    if (nil == image) {
        error = [NSError errorWithDomain:OGImageLoadingErrorDomain
                                    code:OGImageLoadingError
                                userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:NSLocalizedString(@"Couldn't load image from file URL:%@", @""), imageURL]}];
    }
    
    progress.totalUnitCount = 1;
    progress.completedUnitCount = 1;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (nil == image) {
            [delegate imageLoader:self failedForURL:imageURL error:error];
        } else {
            [delegate imageLoader:self didLoadImage:image forURL:imageURL];
        }
    });
}

@end
