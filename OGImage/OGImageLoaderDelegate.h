//
//  OGImageLoaderDelegate.h
//  OGImage
//
//  Created by Sixten Otto on 2/20/16.
//  Copyright © 2016 Origami Labs. All rights reserved.
//

@import UIKit;

@class OGImageLoader, __OGImage;

extern NSString * const OGImageLoadingErrorDomain;

extern NSString * const OGImageLoadingDataErrorKey;
extern NSString * const OGImageLoadingHTTPStatusErrorKey;
extern NSString * const OGImageLoadingHTTPResponseErrorKey;

enum {
  OGImageLoadingError = -25555,
  OGImageLoadingHTTPError = -31111,
  OGImageLoadingInvalidImageDataError = -31222,
};

@protocol OGImageLoaderDelegate <NSObject>

@required

- (void)imageLoader:(OGImageLoader*)loader didLoadImage:(__OGImage *)image forURL:(NSURL *)url;
- (void)imageLoader:(OGImageLoader*)loader failedForURL:(NSURL *)url error:(NSError *)error;

@optional

- (void)imageLoader:(OGImageLoader*)loader didBeginLoadingForURL:(NSURL *)url progress:(NSProgress *)progress;

@end
