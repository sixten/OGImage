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
  [self waitForExpectationsWithTimeout:5. handler:^(NSError * _Nullable error) {
    NSLog(@"Could not copy test image to assets library: %@", error);
  }];
}

- (void)testAssetsLibrary {
    XCTAssertNotNil(self.assetURL, @"Expect assetURL to be populated by setUp");
    
    OGCachedImage *image = [[OGCachedImage alloc] initWithURL:_assetURL key:nil];
    [self keyValueObservingExpectationForObject:image keyPath:@"image" handler:^BOOL(OGImage * _Nonnull img, __unused NSDictionary * _Nonnull change) {
        XCTAssertNil(img.error);
        XCTAssertNotNil(img.image, @"Got success notification, but no image.");
        XCTAssertNotNil(img.progress);
        XCTAssertGreaterThanOrEqual(img.progress.fractionCompleted, 1.0);
        XCTAssertTrue(CGSizeEqualToSize(OGExpectedSize, img.image.size), @"Expected image of size %@, got %@", NSStringFromCGSize(OGExpectedSize), NSStringFromCGSize(img.image.size));
        return YES;
    }];
    
    [self waitForExpectationsWithTimeout:3. handler:^(NSError * _Nullable error) {
        NSLog(@"Could not fetch test image from assets library: %@", error);
    }];
}

@end
