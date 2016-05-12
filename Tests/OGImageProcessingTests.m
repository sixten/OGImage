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

extern CGSize OGAspectFit(CGSize from, CGSize to);
extern CGSize OGAspectFill(CGSize from, CGSize to, CGPoint *offset);

extern OSStatus UIImageToVImageBuffer(UIImage *image, vImage_Buffer *buffer, CGImageAlphaInfo alphaInfo);

static NSString * const TEST_IMAGE_URL_STRING = @"http://easyquestion.net/thinkagain/wp-content/uploads/2009/05/james-bond.jpg";
static const CGSize TEST_IMAGE_SIZE = {317.f, 400.f};
static const CGSize TEST_SCALE_SIZE = {128.f, 128.f};

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
  XCTAssertTrue(CGSizeEqualToSize(newSize, CGSizeMake(480.f, 256.f)), @"Expected 480, 256");
  XCTAssertTrue(pt.x == 112.f && pt.y == 0.f, @"Expected offset point at 112, 0");
}

- (void)testRightOrientedImageGetsRotated
{
  NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"westside" ofType:@"jpg"];
  UIImage *image = [[UIImage alloc] initWithContentsOfFile:path];
  XCTAssertTrue(CGSizeEqualToSize(CGSizeMake(200.f, 50.f), image.size), @"Image should be 200x50 px.");
  XCTAssertEqual(UIImageOrientationRight, image.imageOrientation, @"Image should be right-oriented.");
  
  vImage_Buffer vBuffer;
  OSStatus result = UIImageToVImageBuffer(image, &vBuffer, kCGImageAlphaNoneSkipLast);
  XCTAssertEqual(noErr, result, @"Operation should succeed");
  XCTAssertNotEqual(NULL, vBuffer.data, @"Buffer should have data pointer");
  XCTAssertEqual(200, vBuffer.width, @"Buffer should be 200px wide");
  XCTAssertEqual( 50, vBuffer.height, @"Buffer should be 50px tall");
}

- (void)testLeftOrientedImageGetsRotated
{
  NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"eastside" ofType:@"jpg"];
  UIImage *image = [[UIImage alloc] initWithContentsOfFile:path];
  XCTAssertTrue(CGSizeEqualToSize(CGSizeMake(200.f, 50.f), image.size), @"Image should be 50x200 px.");
  XCTAssertEqual(UIImageOrientationLeft, image.imageOrientation, @"Image should be left-oriented.");
  
  vImage_Buffer vBuffer;
  OSStatus result = UIImageToVImageBuffer(image, &vBuffer, kCGImageAlphaNoneSkipLast);
  XCTAssertEqual(noErr, result, @"Operation should succeed");
  XCTAssertNotEqual(NULL, vBuffer.data, @"Buffer should have data pointer");
  XCTAssertEqual(200, vBuffer.width, @"Buffer should be 200px wide");
  XCTAssertEqual( 50, vBuffer.height, @"Buffer should be 50px tall");
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
        XCTAssertTrue(CGSizeEqualToSize(expectedSize, image.scaledImage.size), @"Expected image of size %@, got %@", NSStringFromCGSize(expectedSize), NSStringFromCGSize(image.image.size));
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

// TODO: test coverage for other orientations (need to test image data, not just dimensions)

// TODO: test coverage for rounded corners

@end
