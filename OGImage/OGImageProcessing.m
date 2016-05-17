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

/*
 * Return the size that aspect fits `from` into `to`
 */
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
        return CGSizeMake(ceil(from.width * to.height/from.height), ceil(to.height));
    } else {
        return CGSizeMake(ceil(to.width), ceil(from.height * (to.width / from.width)));
    }
}

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
        offset->x = floor(ret.width / 2.f - to.width / 2.f);
    }
    if (ret.height > to.height) {
        offset->y = floor(ret.height / 2.f - to.height / 2.f);
    }
    return ret;
}

CGImageRef CreateCGImageFromUIImageAtSize(__unused UIImage *image, CGSize size, CGImageAlphaInfo alphaInfo) {
    CGImageRef cgImage = NULL;
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault | alphaInfo;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, (size_t)size.width, (size_t)size.height, 8, 0, colorSpace, bitmapInfo);
    if( NULL != ctx ) {
        switch( image.imageOrientation ) {
            case UIImageOrientationUp:
                // nothing to do: already right side up
                break;
            case UIImageOrientationUpMirrored:
                CGContextScaleCTM(ctx, -1.f, 1.f);
                CGContextTranslateCTM(ctx, -image.size.width, 0.f);
                break;
            case UIImageOrientationRight:
                CGContextRotateCTM(ctx, -M_PI_2);
                CGContextTranslateCTM(ctx, -image.size.height, 0.f);
                break;
            case UIImageOrientationRightMirrored:
                CGContextRotateCTM(ctx, -M_PI_2);
                CGContextScaleCTM(ctx, -1.f, 1.f);
                break;
            case UIImageOrientationLeft:
                CGContextRotateCTM(ctx, M_PI_2);
                CGContextTranslateCTM(ctx, 0.f, -image.size.width);
                break;
            case UIImageOrientationLeftMirrored:
                CGContextScaleCTM(ctx, -1.f, 1.f);
                CGContextRotateCTM(ctx, -M_PI_2);
                CGContextTranslateCTM(ctx, -image.size.height, -image.size.width);
                break;
            case UIImageOrientationDown:
                CGContextRotateCTM(ctx, M_PI);
                CGContextTranslateCTM(ctx, -image.size.width, -image.size.height);
                break;
            case UIImageOrientationDownMirrored:
                CGContextScaleCTM(ctx, 1.f, -1.f);
                CGContextTranslateCTM(ctx, 0.f, -image.size.height);
                break;
        }
        CGRect bounds = CGRectMake(0, 0, CGImageGetWidth(image.CGImage), CGImageGetHeight(image.CGImage));
        CGContextDrawImage(ctx, bounds, image.CGImage);
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
                
                // TODO: need to deal with the offset, either in or after this step
                CGImageRef cgImage = CreateCGImageFromUIImageAtSize(image, targetSize, alphaInfo);
                if( nil != cgImage ) {
                    resultImage = [[__OGImage alloc] initWithCGImage:cgImage type:image.originalFileType info:image.originalFileProperties alphaInfo:alphaInfo scale:screenScale orientation:UIImageOrientationUp];
                    CGImageRelease(cgImage);
                }
                else {
                    // TODO: error code
                    resultImage = nil;
                    error = [NSError errorWithDomain:OGImageProcessingErrorDomain code:1 userInfo:@{ NSLocalizedDescriptionKey : @"Error converting UIImage to CGImage" }];
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
    if (0.f == cornerRadius)
        return origImage;
    CGSize _size = origImage.size;
    CGFloat _cornerRadius = cornerRadius;
    // If we're on a retina display, make sure everything is @2x
    if ([[UIScreen mainScreen] scale] > 1.f) {
        _size.width *= origImage.scale;
        _size.height *= origImage.scale;
        _cornerRadius *= origImage.scale;
    }

    // Lots of weird math
    size_t bitsPerComponent = 8;
    size_t numberOfComponents = 4;
    size_t bytesPerRow = (size_t)_size.width * (numberOfComponents * bitsPerComponent) / 8;
    size_t dataSize = (size_t)_size.height * bytesPerRow;
    uint8_t *data = (uint8_t *)malloc(dataSize);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    bzero(data, dataSize);

    CGImageAlphaInfo alphaInfo = kCGImageAlphaPremultipliedLast;
    CGContextRef context = CGBitmapContextCreate(data, (size_t)_size.width, (size_t)_size.height, bitsPerComponent, bytesPerRow, colorSpace, alphaInfo);

    // Let's round the corners, if desired
    if (_cornerRadius != 0.0) {
        CGContextSaveGState(context);
        CGContextMoveToPoint(context, 0.f, _cornerRadius);
        CGContextAddArc(context, _cornerRadius, _cornerRadius, _cornerRadius, M_PI, 1.5 * M_PI, 0);
        CGContextAddLineToPoint(context, _size.width - _cornerRadius, 0.f);
        CGContextAddArc(context, _size.width - _cornerRadius, _cornerRadius, _cornerRadius, 1.5 * M_PI, 0.f, 0);
        CGContextAddLineToPoint(context, _size.width, _size.height - _cornerRadius);
        CGContextAddArc(context, _size.width - _cornerRadius, _size.height - _cornerRadius, _cornerRadius, 0.f, 0.5 * M_PI, 0);
        CGContextAddLineToPoint(context, _cornerRadius, _size.height);
        CGContextAddArc(context, _cornerRadius, _size.height - _cornerRadius, _cornerRadius, 0.5 * M_PI, M_PI, 0);
        CGContextAddLineToPoint(context, 0.f, _cornerRadius);
        CGContextSaveGState(context);
        CGContextClip(context);
    }

    // Create a fresh image from the context
    CGContextDrawImage(context, CGRectMake(0.f, 0.f, _size.width, _size.height), [origImage CGImage]);
    if (_cornerRadius != 0.0)
        CGContextRestoreGState(context);
    CGImageRef image = CGBitmapContextCreateImage(context);
    __OGImage *ret = [[__OGImage alloc] initWithCGImage:image type:@"public.png" info:origImage.originalFileProperties alphaInfo:alphaInfo scale:origImage.scale orientation:origImage.imageOrientation];
    if (image)
        CFRelease(image);

    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    free(data);
    context = NULL;
    return ret;
}

@end
