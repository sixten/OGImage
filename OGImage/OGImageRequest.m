//
//  OGImageRequest.m
//  OGImageDemo
//
//  Created by Art Gillespie on 1/2/13.
//  Copyright (c) 2013 Origami Labs. All rights reserved.
//

#import "OGImageRequest.h"
#import "__OGImage.h"
#import <ImageIO/ImageIO.h>

@interface OGImageRequest ()

@property (nonatomic, assign, readwrite, getter=hasStarted) BOOL started;
@property (nonatomic, strong, readwrite) NSURL *url;
@property (nonatomic, strong, readwrite) NSProgress *progress;
@property (nonatomic, strong, readwrite) NSError *error;

@end

@implementation OGImageRequest {
    NSDate *_startTime;
    OGImageLoaderCompletionBlock _completionBlock;
    NSOperationQueue *_delegateQueue;
    NSMutableData *_data;
    long long _contentLength;
    NSHTTPURLResponse *_httpResponse;
}

- (id)initWithURL:(NSURL *)imageURL completionBlock:(OGImageLoaderCompletionBlock)completionBlock queue:(NSOperationQueue *)queue {
    self = [super init];
    if (nil != self) {
        self.url = imageURL;
        _delegateQueue = queue;
        _completionBlock = completionBlock;
        _started = NO;
        
        NSProgress *progress = [NSProgress progressWithTotalUnitCount:0];
        progress.kind = NSProgressKindFile;
        [progress setUserInfoObject:NSProgressFileOperationKindDownloading
                             forKey:NSProgressFileOperationKindKey];
        self.progress = progress;
    }
    return self;
}

- (void)retrieveImage {
    NSURLRequest *request = [NSURLRequest requestWithURL:self.url];
    NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [conn setDelegateQueue:_delegateQueue];
    _startTime = [[NSDate alloc] init];
    [conn start];
    self.started = YES;
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(__unused NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.error = error;
    self.progress.totalUnitCount = 1;
    self.progress.completedUnitCount = 1;
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_completionBlock(nil, self.error, 0.);
    });
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(__unused NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    _httpResponse = (NSHTTPURLResponse *)response;
    if( NSURLResponseUnknownLength == _httpResponse.expectedContentLength ) {
        _data = [NSMutableData data];
    }
    else {
        _contentLength = _httpResponse.expectedContentLength;
        _data = [NSMutableData dataWithCapacity:(NSUInteger)_contentLength];
        _progress.totalUnitCount = _contentLength;
    }
}

- (void)connection:(__unused NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_data appendData:data];
    if( NSURLResponseUnknownLength != _httpResponse.expectedContentLength ) {
        self.progress.completedUnitCount = _data.length;
    }
}

- (void)connectionDidFinishLoading:(__unused NSURLConnection *)connection {
    [self prepareImageAndNotify];
}

- (void)prepareImageAndNotify {
    __OGImage *tmpImage = nil;
    NSError *tmpError = nil;
    if (200 == _httpResponse.statusCode) {
        if (nil != _data) {
            tmpImage = [[__OGImage alloc] initWithData:_data];
            if (nil == tmpImage) {
                // data isn't nil, but we couldn't create an image out of it...
                tmpError = [NSError errorWithDomain:OGImageLoadingErrorDomain code:OGImageLoadingInvalidImageDataError userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"OGImage: Received %lu bytes of data from url, but couldn't create __OGImage instance", (unsigned long)_data.length], NSURLErrorFailingURLErrorKey : self.url}];
            }
        }
    } else {
        // if we get here, we have an http status code other than 200
        tmpError = [NSError errorWithDomain:OGImageLoadingErrorDomain code:OGImageLoadingHTTPError userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"OGImage: Received http status code: %ld", (long)_httpResponse.statusCode], NSURLErrorFailingURLErrorKey : self.url, OGImageLoadingHTTPStatusErrorKey : @(_httpResponse.statusCode)}];
    }
    NSAssert((nil == tmpImage && nil != tmpError) || (nil != tmpImage && nil == tmpError), @"One of tmpImage or tmpError should be non-nil");
    
    if( self.progress.totalUnitCount <= 0 ) {
        self.progress.totalUnitCount = 1;
    }
    if( self.progress.completedUnitCount < self.progress.totalUnitCount ) {
        self.progress.completedUnitCount = self.progress.totalUnitCount;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_completionBlock(tmpImage, tmpError, -[self->_startTime timeIntervalSinceNow]);
    });
}

@end
