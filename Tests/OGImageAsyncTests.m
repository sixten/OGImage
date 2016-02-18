//
//  OGImageAsyncTests.m
//  OGImage
//
//  Created by Sixten Otto on 2/17/16.
//  Copyright © 2016 Origami Labs. All rights reserved.
//

@import XCTest;
@import OGImage;
#import "OGTestImageObserver.h"

static NSString * const TEST_IMAGE_URL_STRING = @"http://easyquestion.net/thinkagain/wp-content/uploads/2009/05/james-bond.jpg";
static NSString * const FAKE_IMAGE_URL_STRING = @"http://easyquestion.net/thinkagain/wp-content/uploads/2009/05/james00.jpg";
static const CGSize TEST_IMAGE_SIZE = {317.f, 400.f};

@interface OGImageAsyncTests : XCTestCase

@end

@implementation OGImageAsyncTests

- (void)test404 {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Got error"];

  OGImage *image = [[OGImage alloc] initWithURL:[NSURL URLWithString:FAKE_IMAGE_URL_STRING]];
  NS_VALID_UNTIL_END_OF_SCOPE OGTestImageObserver *observer = [[OGTestImageObserver alloc] initWithImage:image andBlock:^(__unused OGImage *img, NSString *keyPath) {
    XCTAssertTrue([NSThread isMainThread], @"Expected KVO notification to only be called on main thread");
    if ([keyPath isEqualToString:@"error"]) {
      XCTAssertEqual(OGImageLoadingError, image.error.code, @"Expected loading error, got %@", image.error);
    }
    else {
      XCTFail(@"Didn't get error notification: %@", keyPath);
    }
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:5. handler:nil];
}

- (void)testImageOne {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Got image"];
  
  OGImage *image = [[OGImage alloc] initWithURL:[NSURL URLWithString:TEST_IMAGE_URL_STRING]];
  NS_VALID_UNTIL_END_OF_SCOPE OGTestImageObserver *observer = [[OGTestImageObserver alloc] initWithImage:image andBlock:^(__unused OGImage *img, NSString *keyPath) {
    XCTAssertTrue([NSThread isMainThread], @"Expected KVO notification to only be called on main thread");
    if ([keyPath isEqualToString:@"image"]) {
      XCTAssertNotNil(img.image, @"Got success notification, but no image.");
      XCTAssertTrue(CGSizeEqualToSize(image.image.size, TEST_IMAGE_SIZE), @"Expected image with size %@, got %@", NSStringFromCGSize(TEST_IMAGE_SIZE), NSStringFromCGSize(image.image.size));
    }
    else {
      XCTFail(@"Didn't get image notification: %@", keyPath);
    }
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:5. handler:nil];
}

@end
