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
#import "NoOpAssertionHandler.h"

static const CGSize TEST_SCALE_SIZE = {100.f, 19.f};

extern CGImageRef CreateCGImageFromUIImageAtSize(UIImage *image, CGSize size, CGPoint offset, CGImageAlphaInfo alphaInfo);


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
  NSURL *url = [[NSBundle bundleForClass:[self class]] URLForResource:@"moldex-logo" withExtension:@"gif"];
  
  OGScaledImage *image = [[OGScaledImage alloc] initWithURL:url size:TEST_SCALE_SIZE key:nil];
  [self keyValueObservingExpectationForObject:image keyPath:@"scaledImage" handler:^BOOL(OGScaledImage *img, __unused NSDictionary *change){
    XCTAssertNotNil(img.image, @"Got success notification, but no image.");
    if (nil != img.scaledImage) {
      XCTAssertTrue(CGSizeEqualToSize(TEST_SCALE_SIZE, image.scaledImage.size), @"Expected image of size %@, got %@", NSStringFromCGSize(TEST_SCALE_SIZE), NSStringFromCGSize(image.scaledImage.size));
    }
    return YES;
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
  
  CGImageRef cgImage = CreateCGImageFromUIImageAtSize(image, image.size, CGPointZero, kCGImageAlphaLast);
  XCTAssertEqual(NULL, cgImage, @"Image creation should fail");
}

- (void)testConvertingBadAlpha_First
{
  NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"moldex-logo" ofType:@"gif"];
  UIImage *image = [[UIImage alloc] initWithContentsOfFile:path];
  
  CGImageRef cgImage = CreateCGImageFromUIImageAtSize(image, image.size, CGPointZero, kCGImageAlphaFirst);
  XCTAssertEqual(NULL, cgImage, @"Image creation should fail");
}

@end
