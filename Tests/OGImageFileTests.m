//
//  OGImageFileTests.m
//  OGImage
//
//  Created by Sixten Otto on 2/17/16.
//  Copyright © 2016 Origami Labs. All rights reserved.
//

@import XCTest;
@import OGImage;

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
    
    OGCachedImage *image = [[OGCachedImage alloc] initWithURL:imageURL key:nil];
    [self keyValueObservingExpectationForObject:image keyPath:@"image" handler:^BOOL(OGImage * _Nonnull img, __unused NSDictionary * _Nonnull change) {
        XCTAssertNil(img.error);
        XCTAssertNotNil(img.image, @"Got success notification, but no image.");
        XCTAssertNotNil(img.progress);
        XCTAssertGreaterThanOrEqual(img.progress.fractionCompleted, 1.0);
        XCTAssertTrue(CGSizeEqualToSize(OGExpectedSize, img.image.size), @"Expected image of size %@, got %@", NSStringFromCGSize(OGExpectedSize), NSStringFromCGSize(img.image.size));
        return YES;
    }];
    
    [self waitForExpectationsWithTimeout:0.5 handler:nil];
}

- (void)testInvalidFileURL {
    NSURL *imageURL = [[[NSBundle bundleForClass:[self class]] resourceURL] URLByAppendingPathComponent:@"OrigamiXXX.jpg"];
    XCTAssertNotNil(imageURL, @"Couldn't get URL for test image");
    
    OGImage *image = [[OGImage alloc] initWithURL:imageURL];
    [self keyValueObservingExpectationForObject:image keyPath:@"error" handler:^BOOL(OGImage * _Nonnull img, __unused NSDictionary * _Nonnull change) {
        XCTAssertNil(img.image);
        XCTAssertNotNil(img.error);
        XCTAssertEqualObjects(img.error.domain, OGImageLoadingErrorDomain);
        XCTAssertEqual(img.error.code, OGImageLoadingError);
        return YES;
    }];
    
    [self waitForExpectationsWithTimeout:0.5 handler:nil];
}

// TODO: test coverage for OGEXIFOrientationToUIImageOrientation()

// TODO: test coverage for -[__OGImage initWithCGImage:type:info:alphaInfo:]

// TODO: test failure cases in -[__OGImage initWithData:scale:]

// TODO: test PNG write in -[__OGImage writeToURL:error:]

// TODO: test image destination failure in -[__OGImage writeToURL:error:]

@end
