//
//  OGImageFileTests.m
//  OGImage
//
//  Created by Sixten Otto on 2/17/16.
//  Copyright © 2016 Origami Labs. All rights reserved.
//

@import XCTest;
@import OGImage;
#import "OGTestImageObserver.h"

static CGSize const OGExpectedSize = {1024.f, 768.f};

@interface OGImageFileTests : XCTestCase

@end

@implementation OGImageFileTests

- (void)setUp {
  [[OGImageCache shared] purgeCache:YES];
}

- (void)testFileURL {
  NSURL *imageURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"Origami" withExtension:@"jpg"];
  XCTAssertNotNil(imageURL, @"Couldn't get URL for test image");
  XCTestExpectation *expectation = [self expectationWithDescription:@"Got asset"];
  
  OGCachedImage *image = [[OGCachedImage alloc] initWithURL:imageURL key:nil];
  NS_VALID_UNTIL_END_OF_SCOPE OGTestImageObserver *observer = [[OGTestImageObserver alloc] initWithImage:image andBlock:^(OGImage *img, NSString *keyPath) {
    if ([keyPath isEqualToString:@"image"]) {
      XCTAssertNotNil(img.image, @"Got success notification, but no image.");
      if (nil != img.image) {
        XCTAssertTrue(CGSizeEqualToSize(OGExpectedSize, image.image.size), @"Expected image of size %@, got %@", NSStringFromCGSize(OGExpectedSize), NSStringFromCGSize(image.image.size));
      }
    }
    else if ([keyPath isEqualToString:@"error"]) {
      XCTFail(@"Got error loading image: %@", image.error);
    }
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:5. handler:nil];
}

// TODO: test coverage for OGEXIFOrientationToUIImageOrientation()

// TODO: test coverage for -[__OGImage initWithCGImage:type:info:alphaInfo:]

// TODO: test failure cases in -[__OGImage initWithData:scale:]

// TODO: test PNG write in -[__OGImage writeToURL:error:]

// TODO: test image destination failure in -[__OGImage writeToURL:error:]

@end
