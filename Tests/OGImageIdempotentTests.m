//
//  OGImageIdempotentTests.m
//  OGImage
//
//  Created by Sixten Otto on 2/17/16.
//  Copyright © 2016 Origami Labs. All rights reserved.
//

@import XCTest;
@import OGImage;
#import "OGTestImageObserver.h"

static NSString * const TEST_IMAGE_URL_STRING = @"https://httpbin.org/image/jpeg";

@interface OGImageIdempotentTests : XCTestCase

@end

@implementation OGImageIdempotentTests

- (void)testIdempotent {
  // we want to make sure that multiple requests for the same URL result in
  // a single network request with notifications
  XCTestExpectation *expectation = [self expectationWithDescription:@"Loaded both images"];
  __block UIImage *image1 = nil;
  __block UIImage *image2 = nil;

  OGImage *_image1 = [[OGImage alloc] initWithURL:[NSURL URLWithString:TEST_IMAGE_URL_STRING]];
  NS_VALID_UNTIL_END_OF_SCOPE OGTestImageObserver *observer1 = [[OGTestImageObserver alloc] initWithImage:_image1 andBlock:^(OGImage *img, NSString *keyPath) {
    if ([keyPath isEqualToString:@"image"]) {
      XCTAssertNotNil(img.image, @"Got success notification #1, but no image.");
      image1 = img.image;
      if( nil != image2 ) {
        [expectation fulfill];
      }
    }
    else {
      XCTFail(@"Got unexpected KVO notification for image1: %@", keyPath);
    }
  }];
  
  OGImage *_image2 = [[OGImage alloc] initWithURL:[NSURL URLWithString:TEST_IMAGE_URL_STRING]];
  NS_VALID_UNTIL_END_OF_SCOPE OGTestImageObserver *observer2 = [[OGTestImageObserver alloc] initWithImage:_image2 andBlock:^(OGImage *img, NSString *keyPath) {
    if ([keyPath isEqualToString:@"image"]) {
      XCTAssertNotNil(img.image, @"Got success notification #2, but no image.");
      image2 = img.image;
      if( nil != image1 ) {
        [expectation fulfill];
      }
    }
    else {
      XCTFail(@"Got unexpected KVO notification for image2: %@", keyPath);
    }
  }];
  
  [self waitForExpectationsWithTimeout:5. handler:nil];
  XCTAssertEqual(image1, image2, @"Both requests should load the same image object.");
}

@end
