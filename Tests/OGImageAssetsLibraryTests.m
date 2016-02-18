//
//  OGImageAssetsLibraryTests.m
//  OGImage
//
//  Created by Sixten Otto on 2/17/16.
//  Copyright © 2016 Origami Labs. All rights reserved.
//

@import AssetsLibrary;
@import XCTest;
@import OGImage;
#import "OGTestImageObserver.h"

static CGSize const OGExpectedSize = {1024.f, 768.f};

@interface OGImageAssetsLibraryTests : XCTestCase
@property (strong, nonatomic) NSURL *assetURL;
@end

@implementation OGImageAssetsLibraryTests

- (void)setUp {
  [super setUp];
  
  [[OGImageCache shared] purgeCache:YES];
  
  // we have to save the test image to the asset library
  NSURL *imageURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"Origami" withExtension:@"jpg"];
  XCTAssertNotNil(imageURL, @"Couldn't get URL for test image");
  
  ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
  UIImage *image = [UIImage imageWithContentsOfFile:[imageURL path]];
  XCTAssertNotNil(image, @"Couldn't load image from URL: %@", imageURL);
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"Copied image"];
  [library writeImageToSavedPhotosAlbum:image.CGImage metadata:nil completionBlock:^(NSURL *assetURL, NSError *error) {
    XCTAssertNil(error, @"Couldn't save test image to photos album: %@", error);
    self.assetURL = assetURL;
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:20. handler:^(NSError * _Nullable error) {
    NSLog(@"Could not copy test image to assets library: %@", error);
  }];
}

- (void)testAssetsLibrary {
  XCTAssertNotNil(self.assetURL, @"Expect assetURL to be populated by setUp");
  XCTestExpectation *expectation = [self expectationWithDescription:@"Got asset"];
  
  OGCachedImage *image = [[OGCachedImage alloc] initWithURL:_assetURL key:nil];
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
  
  [self waitForExpectationsWithTimeout:3. handler:^(NSError * _Nullable error) {
    NSLog(@"Could not fetch test image from assets library: %@", error);
  }];
}

@end
