//
//  OGImageProcessing.m
//
//  Created by Art Gillespie on 11/29/12.
//  Copyright (c) 2012 Origami Labs, Inc.. All rights reserved.
//

#import "OGImageProcessing.h"
#import "__OGImage.h"
#import <tgmath.h>
#import <Accelerate/Accelerate.h>

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

void OGClearVImageBuffer(vImage_Buffer *buffer) {
    Pixel_8888 c = {0, 0, 0, 0};
    vImageBufferFill_ARGB8888(buffer, c, 0);
}

/*
 * Don't forget to free buffer->data.
 */
OSStatus UIImageToVImageBuffer(UIImage *image, vImage_Buffer *buffer, CGImageAlphaInfo alphaInfo) {
    OSStatus err = noErr;
    CGImageRef cgImage = image.CGImage;
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    //
    // If the image orientation isn't Up or Down, we create the buffer in the
    // target orientation's dimensions (i.e., the resulting buffer *does* have 'Up' orientation)
    //
    if (UIImageOrientationRight == image.imageOrientation ||
        UIImageOrientationLeft == image.imageOrientation ||
        UIImageOrientationRightMirrored == image.imageOrientation ||
        UIImageOrientationLeftMirrored == image.imageOrientation) {
        size_t nh = width;
        width = height;
        height = nh;
    }
    buffer->data = malloc(width * height * 4);
    buffer->width = width;
    buffer->height = height;
    buffer->rowBytes = width * 4;
    OGClearVImageBuffer(buffer);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(buffer->data,
                                             buffer->width,
                                             buffer->height, 8,
                                             buffer->rowBytes, colorSpace, alphaInfo);
    if (NULL == ctx) {
        free(buffer->data);
        buffer->data = NULL;
        err = OGImageProcessingError;
    } else {
        switch( image.imageOrientation ) {
            case UIImageOrientationUp:
                // nothing to do: already right side up
                break;
            case UIImageOrientationUpMirrored:
                CGContextScaleCTM(ctx, -1.f, 1.f);
                CGContextTranslateCTM(ctx, -(CGFloat)width, 0.f);
                break;
            case UIImageOrientationRight:
                CGContextRotateCTM(ctx, -M_PI_2);
                CGContextTranslateCTM(ctx, -(CGFloat)height, 0.f);
                break;
            case UIImageOrientationRightMirrored:
                CGContextRotateCTM(ctx, -M_PI_2);
                CGContextScaleCTM(ctx, -1.f, 1.f);
                break;
            case UIImageOrientationLeft:
                CGContextRotateCTM(ctx, M_PI_2);
                CGContextTranslateCTM(ctx, 0.f, -(CGFloat)width);
                break;
            case UIImageOrientationLeftMirrored:
                CGContextScaleCTM(ctx, -1.f, 1.f);
                CGContextRotateCTM(ctx, -M_PI_2);
                CGContextTranslateCTM(ctx, -(CGFloat)height, -(CGFloat)width);
                break;
            case UIImageOrientationDown:
                CGContextRotateCTM(ctx, M_PI);
                CGContextTranslateCTM(ctx, -(CGFloat)width, -(CGFloat)height);
                break;
            case UIImageOrientationDownMirrored:
                CGContextScaleCTM(ctx, 1.f, -1.f);
                CGContextTranslateCTM(ctx, 0.f, -(CGFloat)height);
                break;
        }
        CGContextDrawImage(ctx, CGRectMake(0.f, 0.f, CGImageGetWidth(cgImage), CGImageGetHeight(cgImage)), cgImage);
        CGContextRelease(ctx);
    }
    CGColorSpaceRelease(colorSpace);
    return err;
}

CGImageRef VImageBufferToCGImage(vImage_Buffer *buffer, __unused CGFloat scale, CGImageAlphaInfo alphaInfo) {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreateWithData(buffer->data,
                                                     buffer->width,
                                                     buffer->height,
                                                     8, buffer->rowBytes, colorSpace, alphaInfo, NULL, NULL);
    CGImageRef theImage = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpace);
    return theImage;
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
    NSString *lsnrKey = [NSString stringWithFormat:@"%p.%@.%f", image, NSStringFromCGSize(size), cornerRadius];
    dispatch_async(_delegateSerialQueue, ^{
        NSMutableArray *lsnrs = self->_delegates[lsnrKey];
        if (nil != lsnrs) {
            // we already have a queued block for this combination, so
            // just register our delegate and return
            [lsnrs addObject:delegate];
            return;
        }
        // we didn't already have a queued block for this combination, so create
        // the delegate array, add our delegate to it, set it using the combination's key
        // and queue the processing operation for it
        lsnrs = [NSMutableArray arrayWithObject:delegate];
        [self->_delegates setValue:lsnrs forKey:lsnrKey];
        dispatch_async(self->_imageProcessingQueue, ^{
            CGFloat scale = [UIScreen mainScreen].scale;
            CGSize newSize = CGSizeZero;
            CGPoint offset = CGPointZero;
            CGSize fromSize = image.size;
            fromSize.width *= image.scale;
            fromSize.height *= image.scale;
            CGSize toSize = size;
            toSize.width *= scale;
            toSize.height *= scale;
            // if the two sizes are the same, I mean, come on
            if (CGSizeEqualToSize(fromSize, toSize) && 0.f == cornerRadius) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self notifyDelegatesForKey:lsnrKey withImage:image error:nil];
                });
                return;
            }

            CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(image.CGImage);
            if (kCGImageAlphaNone == alphaInfo) {
                // kCGImageAlphaNone w/8-bit channels not supported
                alphaInfo = kCGImageAlphaNoneSkipLast;
            } else if (kCGImageAlphaFirst == alphaInfo || kCGImageAlphaLast == alphaInfo) {
                // non-premultiplied contexts are not supported
                alphaInfo = kCGImageAlphaPremultipliedFirst;
            }
            if (0.f < cornerRadius) {
                alphaInfo = kCGImageAlphaPremultipliedFirst;
            }

            if (OGImageProcessingScale_AspectFit == method) {
                newSize = OGAspectFit(image.size, size);
            } else {
                newSize = OGAspectFill(image.size, size, &offset);
            }
            newSize.width *= scale;
            newSize.height *= scale;
            offset.x *= scale;
            offset.y *= scale;

            vImage_Buffer vBuffer;
            OSStatus err = UIImageToVImageBuffer(image, &vBuffer, alphaInfo);
            if (noErr != err) {
                NSError *error = [NSError errorWithDomain:OGImageProcessingErrorDomain
                                                     code:err userInfo:@{NSLocalizedDescriptionKey : @"Error converting UIImage to vImage"}];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self notifyDelegatesForKey:lsnrKey withImage:nil error:error];
                });
                return;
            }
            vImage_Buffer dBuffer;
            dBuffer.width = (vImagePixelCount)newSize.width;
            dBuffer.height = (vImagePixelCount)newSize.height;
            dBuffer.rowBytes = (size_t)newSize.width * 4;
            CGFloat xHeight = 0.f;
            if (0.f < offset.x) {
                xHeight = 1;
            }
            dBuffer.data = malloc((size_t)(newSize.width * (newSize.height + xHeight)) * 4);
            OGClearVImageBuffer(&dBuffer);
            vImage_Error vErr = vImageScale_ARGB8888(&vBuffer, &dBuffer, NULL, kvImageNoFlags);
            if (kvImageNoError != vErr) {
                free(dBuffer.data);
                NSError *error = [NSError errorWithDomain:OGImageProcessingErrorDomain
                                                     code:err userInfo:@{NSLocalizedDescriptionKey : @"Error scaling image"}];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self notifyDelegatesForKey:lsnrKey withImage:nil error:error];
                });
                return;
            }

            void *origDataPtr = dBuffer.data;

            if (OGImageProcessingScale_AspectFill == method) {
                if (0.f < offset.x) {
                    dBuffer.data = dBuffer.data + ((int)offset.x * 4);
                    dBuffer.width = (vImagePixelCount)toSize.width;
                } else if (0.f < offset.y) {
                    int row_offset = (int)offset.y;
                    row_offset *= dBuffer.rowBytes;
                    dBuffer.data = dBuffer.data + row_offset;
                    dBuffer.height = (vImagePixelCount)toSize.height;
                }
            }
            CGImageRef cgImage = VImageBufferToCGImage(&dBuffer, [UIScreen mainScreen].scale, alphaInfo);
            __OGImage *scaledImage = [[__OGImage alloc] initWithCGImage:cgImage type:image.originalFileType info:image.originalFileProperties alphaInfo:alphaInfo scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];
            CGImageRelease(cgImage);
            free(vBuffer.data);
            free(origDataPtr);
            if (0.f < cornerRadius) {
                scaledImage = [self applyCornerRadius:cornerRadius toImage:scaledImage];
            }

            // notify the interested delegates
            [self notifyDelegatesForKey:lsnrKey withImage:scaledImage error:nil];
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
