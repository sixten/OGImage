//
//  OGImageRequest.h
//  OGImageDemo
//
//  Created by Art Gillespie on 1/2/13.
//  Copyright (c) 2013 Origami Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OGImageLoader.h"

/// Encapsulates the details of loading an image from a specific URL.
/// The image requests are managed by `OGImageLoader`, and are an implementation
/// detail of the overall system.
@interface OGImageRequest : NSObject <NSURLConnectionDelegate, NSURLConnectionDataDelegate, NSProgressReporting>

- (id)initWithURL:(NSURL *)imageURL completionBlock:(OGImageLoaderCompletionBlock)completionBlock queue:(NSOperationQueue *)queue;

/// Instructs the receiver to initiate the network operation to retrieve the image.
/// Has no effect if the request has already been started.
- (void)retrieveImage;

/// `YES` if the receiver has received a `retrieveImage` message.
@property (nonatomic, assign, readonly, getter=hasStarted) BOOL started;

/// The URL of the image to retrieve.
@property (nonatomic, strong, readonly) NSURL *url;

/// @abstract The current progress of the download operation.
/// @description Will be indeterminate from the point the receiver is created
///   until the initial response is received. If that response has a Content-Length
///   header, the progress will then report the number of bytes received.
@property (nonatomic, strong, readonly) NSProgress *progress;

/// If the image request fails, details of the nature of that failure.
@property (nonatomic, strong, readonly) NSError *error;

@end
