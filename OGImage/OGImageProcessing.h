//
//  OGImageProcessing.h
//
//  Created by Art Gillespie on 11/29/12.
//  Copyright (c) 2012 Origami Labs, Inc.. All rights reserved.
//

@import UIKit;

@class OGImageProcessing, __OGImage;


@protocol OGImageProcessingDelegate

@required

- (void)imageProcessing:(OGImageProcessing *)processing didProcessImage:(__OGImage *)image;
- (void)imageProcessingFailed:(OGImageProcessing *)processing error:(NSError *)error;

@end


extern NSString * const OGImageProcessingErrorDomain;

enum {
    OGImageProcessingError = -65535,
};

typedef NS_ENUM(NSInteger, OGImageProcessingScaleMethod) {
    OGImageProcessingScale_AspectFit,
    OGImageProcessingScale_AspectFill
};

@interface OGImageProcessing : NSObject

+ (OGImageProcessing *)shared;

- (void)scaleImage:(__OGImage *)image toSize:(CGSize)size cornerRadius:(CGFloat)cornerRadius method:(OGImageProcessingScaleMethod)method delegate:(id<OGImageProcessingDelegate>)delegate;

@end
