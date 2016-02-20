//
//  OGImageLoaderDelegate.h
//  OGImage
//
//  Created by Sixten Otto on 2/20/16.
//  Copyright © 2016 Origami Labs. All rights reserved.
//

#import <UIKit/UIKit.h>

@class OGImageLoader, __OGImage;

extern const NSInteger OGImageLoadingError;

extern NSString * const OGImageLoadingErrorDomain;

@protocol OGImageLoaderDelegate <NSObject>

@required

- (void)imageLoader:(OGImageLoader*)loader didLoadImage:(__OGImage *)image forURL:(NSURL *)url;
- (void)imageLoader:(OGImageLoader*)loader failedForURL:(NSURL *)url error:(NSError *)error;

@end
