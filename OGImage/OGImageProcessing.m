//
//  OGImageProcessing.m
//
//  Created by Art Gillespie on 11/29/12.
//  Copyright (c) 2012 Origami Labs, Inc.. All rights reserved.
//

#import "OGImageProcessing.h"
#import "__OGImage.h"
#import <tgmath.h>

NSString * const OGImageProcessingErrorDomain = @"OGImageProcessingErrorDomain";

/// Return the size that aspect fits `from` into `to`.
CGSize OGAspectFit(CGSize from, CGSize to) {
    NSCParameterAssert(0.f != from.width);
    NSCParameterAssert(0.f != from.height);
    NSCParameterAssert(0.f != to.width);
    NSCParameterAssert(0.f != to.height);

    if (CGSizeEqualToSize(from, to)) {
        return to;
    }
    CGFloat r1 = from.width / from.height;
    CGFloat r2 = to.width / to.height;
    if (r2 > r1) {
        CGFloat height = ceil(to.height);
        return CGSizeMake(round(from.width * height / from.height), height);
    } else {
        CGFloat width = ceil(to.width);
        return CGSizeMake(width, round(from.height * width / from.width));
    }
}

/// Return the size at which `from` fills `to`.
CGSize OGAspectFill(CGSize from, CGSize to, CGPoint *offset) {
    NSCParameterAssert(0.f != from.width);
    NSCParameterAssert(0.f != from.height);
    NSCParameterAssert(0.f != to.width);
    NSCParameterAssert(0.f != to.height);
    NSCParameterAssert(nil != offset);
    offset->x = 0.f;
    offset->y = 0.f;
    CGFloat sRatio = from.width / from.height;
    CGFloat dRatio = to.width / to.height;
    CGFloat ratio = (dRatio <= sRatio) ? to.height / from.height : to.width / from.width;
    CGSize ret = CGSizeMake(round(from.width * ratio), round(from.height * ratio));
    if (ret.width > to.width) {
        offset->x = floor((ret.width - to.width) / 2.f);
        ret.width = to.width;
    }
    if (ret.height > to.height) {
        offset->y = floor((ret.height - to.height) / 2.f);
        ret.height = to.height;
    }
    return ret;
}

CGImageRef CreateCGImageFromUIImageAtSize(UIImage *image, CGSize size, CGPoint offset, CGImageAlphaInfo alphaInfo) {
    CGImageRef cgImage = NULL;
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault | alphaInfo;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, (size_t)size.width, (size_t)size.height, 8, 0, colorSpace, bitmapInfo);
    if( NULL != ctx ) {
        CGContextScaleCTM(ctx, 1.f, -1.f);
        CGContextTranslateCTM(ctx, 0.f, -size.height);
        CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
        CGRect bounds = (CGRect){ .origin = CGPointZero, .size = size };
        bounds = CGRectInset(bounds, -offset.x, -offset.y);
        UIGraphicsPushContext(ctx);
        [image drawInRect:bounds];
        UIGraphicsPopContext();
        cgImage = CGBitmapContextCreateImage(ctx);
        CGContextRelease(ctx);
    }
    CGColorSpaceRelease(colorSpace);
    return cgImage;
}

#pragma mark -

@implementation OGImageProcessing {
    dispatch_queue_t _imageProcessingQueue;
    // key -> __OGImage, value -> NSArray of id<OGImageProcessingDelegate>
    NSMutableDictionary *_delegates;
    // mediate access to _delegates;
    dispatch_queue_t _delegateSerialQueue;
}

+ (OGImageProcessing *)shared {
    static OGImageProcessing *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[OGImageProcessing alloc] init];
    });
    return shared;
}

- (id)init
{
    self = [super init];
    if (self) {
        _imageProcessingQueue = dispatch_queue_create("com.origamilabs.imageProcessing", DISPATCH_QUEUE_CONCURRENT);
        _delegates = [NSMutableDictionary dictionaryWithCapacity:10];
        _delegateSerialQueue = dispatch_queue_create("com.origamilabs.imageProcessing.delegateSerialization", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)scaleImage:(__OGImage *)image toSize:(CGSize)size cornerRadius:(CGFloat)cornerRadius method:(OGImageProcessingScaleMethod)method delegate:(id<OGImageProcessingDelegate>)delegate {
    NSParameterAssert(image);
    NSString *listenerKey = [NSString stringWithFormat:@"%p.%@.%f", image, NSStringFromCGSize(size), cornerRadius];
    dispatch_async(_delegateSerialQueue, ^{
        NSMutableArray *listeners = self->_delegates[listenerKey];
        if( nil != listeners ) {
            // we already have a queued block for this combination, so
            // just register our delegate and return
            [listeners addObject:delegate];
            return;
        }
        
        // we didn't already have a queued block for this combination, so create
        // the delegate array, add our delegate to it, set it using the combination's key
        // and queue the processing operation for it
        listeners = [NSMutableArray arrayWithObject:delegate];
        [self->_delegates setValue:listeners forKey:listenerKey];
        dispatch_async(self->_imageProcessingQueue, ^{
            // calculate current vs target size
            CGSize sourceSize = CGSizeMake(image.size.width * image.scale, image.size.height * image.scale);
          
            CGFloat screenScale = [UIScreen mainScreen].scale;
            CGSize targetSize;
            CGPoint offset = CGPointZero;
            if( OGImageProcessingScale_AspectFit == method ) {
                targetSize = OGAspectFit(image.size, size);
            }
            else {
                targetSize = OGAspectFill(image.size, size, &offset);
            }
            targetSize.width *= screenScale;
            targetSize.height *= screenScale;
            offset.x *= screenScale;
            offset.y *= screenScale;
          
            __OGImage *resultImage = image;
            NSError *error = nil;
          
            // if not matched, create resized image
            if( !CGSizeEqualToSize(sourceSize, targetSize) ) {
                CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(image.CGImage);
                if( kCGImageAlphaNone == alphaInfo ) {
                    // kCGImageAlphaNone w/8-bit channels not supported
                    alphaInfo = kCGImageAlphaNoneSkipLast;
                }
                else if( kCGImageAlphaFirst == alphaInfo || kCGImageAlphaLast == alphaInfo ) {
                    // non-premultiplied contexts are not supported
                    alphaInfo = kCGImageAlphaPremultipliedFirst;
                }
                if( 0.f < cornerRadius ) {
                    alphaInfo = kCGImageAlphaPremultipliedFirst;
                }
                
                CGImageRef cgImage = CreateCGImageFromUIImageAtSize(image, targetSize, offset, alphaInfo);
                if( nil != cgImage ) {
                    resultImage = [[__OGImage alloc] initWithCGImage:cgImage type:image.originalFileType info:image.originalFileProperties alphaInfo:alphaInfo scale:screenScale orientation:UIImageOrientationUp];
                    CGImageRelease(cgImage);
                }
                else {
                    resultImage = nil;
                    error = [NSError errorWithDomain:OGImageProcessingErrorDomain code:OGImageProcessingError userInfo:@{ NSLocalizedDescriptionKey : @"Error converting UIImage to CGImage" }];
                }
            }
          
            // if rounded corners, apply
            if( 0.f < cornerRadius && nil != resultImage ) {
              resultImage = [self applyCornerRadius:cornerRadius toImage:resultImage];
            }
          
            // notify delegates
            [self notifyDelegatesForKey:listenerKey withImage:resultImage error:error];
        });
    });
}

- (void)notifyDelegatesForKey:(NSString *)key withImage:(__OGImage *)image error:(NSError *)error {
    __block NSMutableArray *lsnrs;
    dispatch_sync(_delegateSerialQueue, ^{
        lsnrs = self->_delegates[key];
        [self->_delegates removeObjectForKey:key];
    });
    __weak OGImageProcessing *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        for (id<OGImageProcessingDelegate> delegate in lsnrs) {
            if (nil != error) {
                [delegate imageProcessingFailed:self error:error];
            } else {
                [delegate imageProcessing:weakSelf didProcessImage:image];
            }
        }
    });
}

- (__OGImage *)applyCornerRadius:(CGFloat)cornerRadius toImage:(__OGImage *)origImage {
    if( 0.f >= cornerRadius) {
        return origImage;
    }
    
    // keep the size & scale of the result image consistent with the original
    CGSize _size = CGSizeMake(origImage.size.width * origImage.scale, origImage.size.height * origImage.scale);
    CGFloat _cornerRadius = cornerRadius * origImage.scale;

    // create a new bitmap context
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(origImage.CGImage);
    CGImageAlphaInfo alphaInfo = kCGImageAlphaPremultipliedLast;
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)alphaInfo;
    bitmapInfo |= CGImageGetBitmapInfo(origImage.CGImage) & kCGBitmapByteOrderMask;
    CGContextRef context = CGBitmapContextCreate(NULL, (size_t)_size.width, (size_t)_size.height, 8, 0, colorSpace, bitmapInfo);
    
    __OGImage *result = nil;
    if( NULL != context ) {
        // set a rounded-corner clipping path
        UIBezierPath *roundRect = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, _size.width, _size.height) cornerRadius:_cornerRadius];
        CGContextAddPath(context, roundRect.CGPath);
        CGContextClip(context);

        // draw the image into the new context
        UIGraphicsPushContext(context);
        CGContextScaleCTM(context, 1.f, -1.f);
        CGContextTranslateCTM(context, 0.f, -_size.height);
        [origImage drawAtPoint:CGPointZero];
        UIGraphicsPopContext();

        // create a new image from the result
        CGImageRef image = CGBitmapContextCreateImage(context);
        if( NULL != image ) {
            result = [[__OGImage alloc] initWithCGImage:image type:@"public.png" info:origImage.originalFileProperties alphaInfo:alphaInfo scale:origImage.scale orientation:origImage.imageOrientation];
            CFRelease(image);
        }
        CGContextRelease(context);
    }
    return result;
}

@end
