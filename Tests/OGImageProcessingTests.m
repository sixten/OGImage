//
//  OGImageProcessingTests.m
//  OGImage
//
//  Created by Sixten Otto on 2/17/16.
//  Copyright © 2016 Origami Labs. All rights reserved.
//

@import XCTest;
@import Accelerate;
@import OGImage;
#import "OGTestImageObserver.h"
#import "__OGImage.h"

extern CGSize OGAspectFit(CGSize from, CGSize to);
extern CGSize OGAspectFill(CGSize from, CGSize to, CGPoint *offset);
extern CGImageRef CreateCGImageFromUIImageAtSize(UIImage *image, CGSize size, CGPoint offset, CGImageAlphaInfo alphaInfo);

static BOOL OGCompareImages(CGImageRef left, CGImageRef right);

static NSString * const TEST_IMAGE_URL_STRING = @"http://easyquestion.net/thinkagain/wp-content/uploads/2009/05/james-bond.jpg";
static const CGSize TEST_IMAGE_SIZE = {317.f, 400.f};
static const CGSize TEST_SCALE_SIZE = {128.f, 128.f};

@interface OGImageProcessing (Privates)
- (__OGImage *)applyCornerRadius:(CGFloat)cornerRadius toImage:(__OGImage *)origImage;
@end

@interface OGImageProcessingTests : XCTestCase

@end

@implementation OGImageProcessingTests

- (void)testAspectFit_1 {
  CGSize newSize = OGAspectFit(CGSizeMake(600.f, 1024.f), CGSizeMake(64.f, 64.f));
  XCTAssertTrue(CGSizeEqualToSize(newSize, CGSizeMake(38.f, 64.f)), @"Invalid dimensions...");
}

- (void)testAspectFit_2 {
  CGSize newSize = OGAspectFit(CGSizeMake(1024.f, 1024.f), CGSizeMake(64.f, 64.f));
  XCTAssertTrue(CGSizeEqualToSize(newSize, CGSizeMake(64.f, 64.f)), @"Invalid dimensions...");
}

- (void)testAspectFit_3 {
  CGSize newSize = OGAspectFit(CGSizeMake(64.f, 100.f), CGSizeMake(128.f, 128.f));
  XCTAssertTrue(CGSizeEqualToSize(newSize, CGSizeMake(82.f, 128.f)), @"Invalid dimensions...");
}

- (void)testAspectFit_4 {
  CGSize newSize = OGAspectFit(CGSizeMake(64.f, 100.f), CGSizeMake(64.f, 100.f));
  XCTAssertTrue(CGSizeEqualToSize(newSize, CGSizeMake(64.f, 100.f)), @"Invalid dimensions...");
}

- (void)testAspectFit_5 {
  XCTAssertThrows(OGAspectFit(CGSizeMake(0.f, 0.f), CGSizeMake(0.f, 0.f)), @"Expect OGAspectFit to throw when any dimension is zero.");
}

- (void)testAspectFit_6 {
  CGSize newSize = OGAspectFit(CGSizeMake(100.f, 100.f), CGSizeMake(7.f, 13.f));
  XCTAssertTrue(CGSizeEqualToSize(newSize, CGSizeMake(7.f, 7.f)), @"Invalid dimensions...");
}

- (void)testAspectFit_7 {
  CGSize newSize = OGAspectFit(CGSizeMake(100.f, 100.f), CGSizeMake(7.8f, 13.f));
  XCTAssertTrue(CGSizeEqualToSize(newSize, CGSizeMake(8.f, 8.f)), @"Invalid dimensions...");
}

- (void)testAspectFill_1 {
  CGPoint pt = CGPointZero;
  XCTAssertThrows(OGAspectFill(CGSizeMake(0.f, 0.f), CGSizeMake(0.f, 0.f), &pt), @"Expect OGAspectFill to throw when any dimension is zero.");
}

- (void)testAspectFill_2 {
  XCTAssertThrows(OGAspectFill(CGSizeMake(128.f, 128.f), CGSizeMake(1024.f, 1024.f), NULL), @"Expect OGAspectFill to throw when `offset` parameter is NULL.");
}

- (void)testAspectFill_3 {
  CGPoint pt = CGPointZero;
  CGSize newSize = OGAspectFill(CGSizeMake(1920.f, 1024.f), CGSizeMake(256.f, 256.f), &pt);
  XCTAssertTrue(CGSizeEqualToSize(newSize, CGSizeMake(256.f, 256.f)), @"Expected 256, 256");
  XCTAssertTrue(pt.x == 112.f && pt.y == 0.f, @"Expected offset point at 112, 0");
}

- (void)testAspectFill_4 {
  CGPoint pt = CGPointZero;
  CGSize newSize = OGAspectFill(CGSizeMake(512.f, 1024.f), CGSizeMake(256.f, 256.f), &pt);
  XCTAssertTrue(CGSizeEqualToSize(newSize, CGSizeMake(256.f, 256.f)), @"Expected 256, 256");
  XCTAssertTrue(pt.x == 0.f && pt.y == 128.f, @"Expected offset point at 0, 128");
}

- (void)testRightOrientedImageGetsRotated
{
  NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"westside" ofType:@"jpg"];
  UIImage *image = [[UIImage alloc] initWithContentsOfFile:path];
  XCTAssertTrue(CGSizeEqualToSize(CGSizeMake(200.f, 50.f), image.size), @"Image should be 200x50 px.");
  XCTAssertEqual(UIImageOrientationRight, image.imageOrientation, @"Image should be right-oriented.");
  
  CGImageRef cgImage = CreateCGImageFromUIImageAtSize(image, image.size, CGPointZero, kCGImageAlphaNoneSkipLast);
  XCTAssertNotEqual(NULL, cgImage, @"Image creation should succeed");
  XCTAssertEqual(200, CGImageGetWidth(cgImage), @"Image should be 200px wide");
  XCTAssertEqual( 50, CGImageGetHeight(cgImage), @"Image should be 50px tall");
  CGImageRelease(cgImage);
}

- (void)testLeftOrientedImageGetsRotated
{
  NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"eastside" ofType:@"jpg"];
  UIImage *image = [[UIImage alloc] initWithContentsOfFile:path];
  XCTAssertTrue(CGSizeEqualToSize(CGSizeMake(200.f, 50.f), image.size), @"Image should be 50x200 px.");
  XCTAssertEqual(UIImageOrientationLeft, image.imageOrientation, @"Image should be left-oriented.");
  
  CGImageRef cgImage = CreateCGImageFromUIImageAtSize(image, image.size, CGPointZero, kCGImageAlphaNoneSkipLast);
  XCTAssertNotEqual(NULL, cgImage, @"Image creation should succeed");
  XCTAssertEqual(200, CGImageGetWidth(cgImage), @"Image should be 200px wide");
  XCTAssertEqual( 50, CGImageGetHeight(cgImage), @"Image should be 50px tall");
  CGImageRelease(cgImage);
}

- (void)testScaledImage1 {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Got scaled image"];
  
  // make sure we get the image from the network
  [[OGImageCache shared] purgeCache:YES];
  
  OGScaledImage *image = [[OGScaledImage alloc] initWithURL:[NSURL URLWithString:TEST_IMAGE_URL_STRING] size:TEST_SCALE_SIZE key:nil];
  NS_VALID_UNTIL_END_OF_SCOPE OGTestImageObserver *observer = [[OGTestImageObserver alloc] initWithImage:image andBlock:^(OGImage *img, NSString *keyPath) {
    if ([keyPath isEqualToString:@"scaledImage"]) {
      XCTAssertNotNil(img.image, @"Got success notification, but no image.");
      if (nil != img.image) {
        CGSize expectedSize = OGAspectFit(TEST_IMAGE_SIZE, TEST_SCALE_SIZE);
        XCTAssertTrue(CGSizeEqualToSize(expectedSize, image.scaledImage.size), @"Expected image of size %@, got %@", NSStringFromCGSize(expectedSize), NSStringFromCGSize(image.scaledImage.size));
      }
      [expectation fulfill];
    }
    else if ([keyPath isEqualToString:@"image"]) {
      // should get this, before scaling
    }
    else {
      XCTFail(@"Got unexpected KVO notification: %@", keyPath);
      [expectation fulfill];
    }
  }];
  
  [self waitForExpectationsWithTimeout:5. handler:nil];
  
  // clean up the in-memory and disk cache when we're done
  [[OGImageCache shared] purgeCache:YES];
}

- (void)testOrientationSupport {
  NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"reference" ofType:@"png"];
  UIImage *referenceImage = [[UIImage alloc] initWithContentsOfFile:path];
  
  path = [[NSBundle bundleForClass:[self class]] pathForResource:@"negative" ofType:@"jpg"];
  UIImage *negativeImage = [[UIImage alloc] initWithContentsOfFile:path];
  XCTAssertFalse(OGCompareImages(referenceImage.CGImage, negativeImage.CGImage), @"Images should NOT compare the same");
  
  NSArray *imageNames = @[ @"up", @"down", @"left", @"right", @"up_mirrored", @"down_mirrored", @"left_mirrored", @"right_mirrored", ];
  for (NSString *imageName in imageNames) {
    path = [[NSBundle bundleForClass:[self class]] pathForResource:imageName ofType:@"jpg"];
    UIImage *testImage = [[UIImage alloc] initWithContentsOfFile:path];
    XCTAssertTrue(CGSizeEqualToSize(CGSizeMake(120.f, 80.f), testImage.size), @"Image should be 120x80 px.");
    
    CGImageRef cgImage = CreateCGImageFromUIImageAtSize(testImage, testImage.size, CGPointZero, kCGImageAlphaNoneSkipLast);
    XCTAssertNotEqual(NULL, cgImage, @"Image creation should succeed");
    XCTAssertEqual(120, CGImageGetWidth(cgImage), @"Image should be 120px wide");
    XCTAssertEqual( 80, CGImageGetHeight(cgImage), @"Image should be 80px tall");
    XCTAssertTrue(OGCompareImages(referenceImage.CGImage, cgImage), @"Images should compare the same");
    CGImageRelease(cgImage);
  }
}

- (void)testAspectFillOffset {
  // make sure we get the image from the network
  [[OGImageCache shared] purgeCache:YES];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"Got scaled image"];
  
  NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"aspect_fill@2x" ofType:@"png"];
  UIImage *referenceImage = [[UIImage alloc] initWithContentsOfFile:path];
  path = [[NSBundle bundleForClass:[self class]] pathForResource:@"left" ofType:@"jpg"];
  CGSize toSize = CGSizeMake(80.f, 80.f);
  
  OGScaledImage *image = [[OGScaledImage alloc] initWithURL:[NSURL fileURLWithPath:path] size:toSize method:OGImageProcessingScale_AspectFill key:nil placeholderImage:nil];
  NS_VALID_UNTIL_END_OF_SCOPE OGTestImageObserver *observer = [[OGTestImageObserver alloc] initWithImage:image andBlock:^(OGImage *img, NSString *keyPath) {
    if ([keyPath isEqualToString:@"scaledImage"]) {
      XCTAssertNotNil(img.image, @"Got success notification, but no image.");
      if (nil != img.image) {
        XCTAssertTrue(CGSizeEqualToSize(toSize, image.scaledImage.size), @"Expected image of size %@, got %@", NSStringFromCGSize(toSize), NSStringFromCGSize(image.scaledImage.size));
        XCTAssertTrue(OGCompareImages(referenceImage.CGImage, image.scaledImage.CGImage), @"Images should compare the same");
      }
      [expectation fulfill];
    }
    else if ([keyPath isEqualToString:@"image"]) {
      // should get this, before scaling
    }
    else {
      XCTFail(@"Got unexpected KVO notification: %@", keyPath);
      [expectation fulfill];
    }
  }];
  
  [self waitForExpectationsWithTimeout:2. handler:nil];
  
  // clean up the in-memory and disk cache when we're done
  [[OGImageCache shared] purgeCache:YES];
}

- (void)testCornerRoundingReturnsOriginalImageWithNoRadius {
  NSURL *url = [[NSBundle bundleForClass:[self class]] URLForResource:@"reference" withExtension:@"png"];
  __OGImage *image = [[__OGImage alloc] initWithDataAtURL:url];
  
  __OGImage *result = [[OGImageProcessing shared] applyCornerRadius:0 toImage:image];
  XCTAssertEqual(image, result);
}

- (void)testCornerRounding {
  NSURL *url = [[NSBundle bundleForClass:[self class]] URLForResource:@"corner_radius" withExtension:@"png"];
  UIImage *referenceImage = [[UIImage alloc] initWithContentsOfFile:url.path];
  
  url = [[NSBundle bundleForClass:[self class]] URLForResource:@"reference" withExtension:@"png"];
  __OGImage *image = [[__OGImage alloc] initWithDataAtURL:url];
  
  __OGImage *result = [[OGImageProcessing shared] applyCornerRadius:10 toImage:image];
  XCTAssertNotNil(result, @"Should return an image");
  XCTAssertNotEqual(image, result, @"Should return a new image");
  XCTAssertTrue(CGSizeEqualToSize(image.size, result.size), @"Should maintain the same size");
  XCTAssertEqual(image.scale, result.scale, @"Should maintain the same scale");
  
  // difference-based image compare doesn't work with alpha corners: blend onto a black background for comparison
  UIGraphicsBeginImageContextWithOptions(result.size, YES, result.scale);
  [[UIColor blackColor] setFill];
  UIRectFill(CGRectMake(0, 0, result.size.width, result.size.height));
  [result drawAtPoint:CGPointZero];
  UIImage *test = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  XCTAssertTrue(OGCompareImages(referenceImage.CGImage, test.CGImage), @"Images should compare the same");
}

@end


BOOL OGCompareImages(CGImageRef left, CGImageRef right) {
  // First create the CIImage representations of the CGImage.
  CIImage *ciImage1 = [CIImage imageWithCGImage:left];
  CIImage *ciImage2 = [CIImage imageWithCGImage:right];
  CGRect compareRect = CGRectMake(0.0, 0.0, CGImageGetWidth(left), CGImageGetHeight(left));
  
  // Create the difference blend mode filter and set its properties.
  CIFilter *diffFilter = [CIFilter filterWithName:@"CIDifferenceBlendMode"];
  [diffFilter setDefaults];
  [diffFilter setValue:ciImage1 forKey:kCIInputImageKey];
  [diffFilter setValue:ciImage2 forKey:kCIInputBackgroundImageKey];
  
  // render the difference, for diagnostic purposes
  CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedLast;
  bitmapInfo |= kCGBitmapByteOrderDefault;
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef diffCtx = CGBitmapContextCreateWithData(NULL, CGImageGetWidth(left), CGImageGetHeight(left), 8, 0, colorSpace, bitmapInfo, NULL, NULL);
  CIContext *diffCICtx = [CIContext contextWithCGContext:diffCtx options:nil];
  [diffCICtx drawImage:[diffFilter valueForKey:kCIOutputImageKey] inRect:compareRect fromRect:compareRect];
  CGImageRef cgImage = CGBitmapContextCreateImage(diffCtx);
  UIImage *diff = [UIImage imageWithCGImage:cgImage];
  CGImageRelease(cgImage);
  CGContextRelease(diffCtx);
  (void)diff;
  
  // Create the area max filter and set its properties.
  CIFilter *areaMaxFilter = [CIFilter filterWithName:@"CIAreaMaximum"];
  [areaMaxFilter setDefaults];
  [areaMaxFilter setValue:[diffFilter valueForKey:kCIOutputImageKey]
                   forKey:kCIInputImageKey];
  CIVector *extents = [CIVector vectorWithCGRect:compareRect];
  [areaMaxFilter setValue:extents forKey:kCIInputExtentKey];
  
  // The filters have been setup, now set up the CGContext bitmap context the
  // output is drawn to. Setup the context with our supplied buffer.
  uint8_t buf[16];
  memset(buf, 0, 16);
  CGContextRef context = CGBitmapContextCreate(&buf, 1, 1, 8, 4, colorSpace, bitmapInfo);
  
  // Now create the core image context CIContext from the bitmap context.
  NSDictionary *ciContextOpts = @{
                                  kCIContextWorkingColorSpace : (__bridge id)colorSpace,
                                  kCIContextUseSoftwareRenderer : @NO,
                                  };
  CIContext *ciContext = [CIContext contextWithCGContext:context options:ciContextOpts];
  
  // Get the output CIImage and draw that to the Core Image context.
  CIImage *valueImage = [areaMaxFilter valueForKey:kCIOutputImageKey];
  [ciContext drawImage:valueImage inRect: CGRectMake(0,0,1,1) fromRect: valueImage.extent];
  
  CGColorSpaceRelease(colorSpace);
  CGContextRelease(context);
  
  // This will have modified the contents of the buffer used for the CGContext.
  // Find the maximum value of the different color components. Remember that
  // the CGContext was created with a Premultiplied last meaning that alpha
  // is the fourth component with red, green and blue in the first three.
  int maxVal = MAX(buf[0], MAX(buf[1], buf[2]));
  
  return maxVal < 64;
}
