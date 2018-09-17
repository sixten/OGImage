//
//  OGImageRequest.m
//  OGImageDemo
//
//  Created by Art Gillespie on 1/2/13.
//  Copyright (c) 2013 Origami Labs. All rights reserved.
//

@import ImageIO;
#import "OGImageRequest.h"
#import "__OGImage.h"

@interface OGImageRequest ()

@property (nonatomic, assign, readwrite, getter=hasStarted) BOOL started;
@property (nonatomic, strong, readwrite) NSURL *url;
@property (nonatomic, strong, readwrite) NSError *error;

@property (nonatomic, strong) NSURLSessionDataTask *task;
@property (nonatomic, copy) OGImageLoaderCompletionBlock completionBlock;

@end

@implementation OGImageRequest

- (id)initWithURL:(NSURL *)imageURL completionBlock:(OGImageLoaderCompletionBlock)completionBlock {
    self = [super init];
    if (nil != self) {
        self.url = imageURL;
        self.completionBlock = completionBlock;
        _started = NO;
    }
    return self;
}

- (NSProgress *)progress
{
    return self.task.progress;
}

- (void)retrieveImageInSession:(NSURLSession *)session {
    __weak __typeof(self) weakSelf = self;
    NSDate *startTime = [[NSDate alloc] init];
    
    self.task = [session dataTaskWithURL:self.url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if( nil == strongSelf ) return;
        
        __OGImage *tmpImage = nil;
        NSError *tmpError = nil;
        if( [response isKindOfClass:[NSHTTPURLResponse class]] ) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if( 200 == httpResponse.statusCode ) {
                tmpImage = [[__OGImage alloc] initWithData:data];
                if (nil == tmpImage) {
                    // data isn't nil, but we couldn't create an image out of it...
                    tmpError = [NSError errorWithDomain:OGImageLoadingErrorDomain code:OGImageLoadingInvalidImageDataError userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"OGImage: Received %lu bytes of data from url, but couldn't create __OGImage instance", (unsigned long)data.length], NSURLErrorFailingURLErrorKey : strongSelf.url}];
                }
            }
            else {
                tmpError = [NSError errorWithDomain:OGImageLoadingErrorDomain code:OGImageLoadingHTTPError userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"OGImage: Received http status code: %ld", (long)httpResponse.statusCode], NSURLErrorFailingURLErrorKey : strongSelf.url, OGImageLoadingHTTPStatusErrorKey : @(httpResponse.statusCode)}];
            }
        }
        else if( nil != data ) {
            // valid data, but a non-HTTP response? no idea how this could happen
            NSCAssert(NO, @"Got %lu bytes of data, but a %@", (unsigned long)data.length, response);
        }
        else {
            tmpError = error;
        }
        
        NSCAssert((nil == tmpImage && nil != tmpError) || (nil != tmpImage && nil == tmpError), @"One of tmpImage or tmpError should be non-nil");
        strongSelf.error = tmpError;
        strongSelf.completionBlock(tmpImage, tmpError, -[startTime timeIntervalSinceNow]);
    }];
    
    [self.task resume];
    self.started = YES;
}

@end
