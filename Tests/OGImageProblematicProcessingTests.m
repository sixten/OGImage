//
//  OGImageProblematicProcessingTests.m
//  OGImage
//
//  Created by Sixten Otto on 2/20/16.
//  Copyright © 2016 Origami Labs. All rights reserved.
//

@import Accelerate;
@import XCTest;
@import OGImage;
#import "__OGImage.h"
#import "OGTestImageObserver.h"
#import "NoOpAssertionHandler.h"

static const CGSize TEST_SCALE_SIZE = {100.f, 20.f};

extern CGImageRef CreateCGImageFromUIImageAtSize(UIImage *image, CGSize size, CGImageAlphaInfo alphaInfo);


@interface OGImageProblematicProcessingTests : XCTestCase

@end

@implementation OGImageProblematicProcessingTests

- (void)setUp {
    // make sure we get the image from the network
    [[OGImageCache shared] purgeCache:YES];
}

- (void)tearDown {
    // clean up the in-memory and disk cache when we're done
    [[OGImageCache shared] purgeCache:YES];
}

- (void)testScalingGif
{
  XCTestExpectation *expectation = [self expectationWithDescription:@"Got scaled image"];
  NSURL *url = [[NSBundle bundleForClass:[self class]] URLForResource:@"moldex-logo" withExtension:@"gif"];
  
  OGScaledImage *image = [[OGScaledImage alloc] initWithURL:url size:TEST_SCALE_SIZE key:nil];
  NS_VALID_UNTIL_END_OF_SCOPE OGTestImageObserver *observer = [[OGTestImageObserver alloc] initWithImage:image andBlock:^(OGImage *img, NSString *keyPath) {
    if ([keyPath isEqualToString:@"scaledImage"]) {
      XCTAssertNotNil(img.image, @"Got success notification, but no image.");
      if (nil != img.image) {
        XCTAssertTrue(CGSizeEqualToSize(TEST_SCALE_SIZE, image.scaledImage.size), @"Expected image of size %@, got %@", NSStringFromCGSize(TEST_SCALE_SIZE), NSStringFromCGSize(image.image.size));
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
}

- (void)testCachingNil
{
  NSURL *url = [[NSBundle bundleForClass:[self class]] URLForResource:@"moldex-logo" withExtension:@"gif"];
  __OGImage *image = [[__OGImage alloc] initWithDataAtURL:url];
  XCTAssertNotNil(image, @"Couldn't decode test image");
  
  // make sure that the test isn't interrupted by assert failure
  NSAssertionHandler *oldHandler = [[[NSThread currentThread] threadDictionary] valueForKey:NSAssertionHandlerKey];
  NSAssertionHandler *tempHandler = [NoOpAssertionHandler new];
  [[[NSThread currentThread] threadDictionary] setValue:tempHandler forKey:NSAssertionHandlerKey];
  
  XCTAssertNoThrowSpecificNamed([[OGImageCache shared] setImage:nil forKey:@"foo"], NSException, NSInvalidArgumentException, @"Attempting to insert a nil image should not throw");
  XCTAssertNoThrowSpecificNamed([[OGImageCache shared] setImage:image forKey:nil], NSException, NSInvalidArgumentException, @"Attempting to insert with a nil key should not throw");
  
  [[[NSThread currentThread] threadDictionary] setValue:oldHandler forKey:NSAssertionHandlerKey];
}

- (void)testConvertingBadAlpha_Last
{
  NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"moldex-logo" ofType:@"gif"];
  UIImage *image = [[UIImage alloc] initWithContentsOfFile:path];
  
  CGImageRef cgImage = CreateCGImageFromUIImageAtSize(image, image.size, kCGImageAlphaLast);
  XCTAssertEqual(NULL, cgImage, @"Image creation should fail");
}

- (void)testConvertingBadAlpha_First
{
  NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"moldex-logo" ofType:@"gif"];
  UIImage *image = [[UIImage alloc] initWithContentsOfFile:path];
  
  CGImageRef cgImage = CreateCGImageFromUIImageAtSize(image, image.size, kCGImageAlphaFirst);
  XCTAssertEqual(NULL, cgImage, @"Image creation should fail");
}

@end
