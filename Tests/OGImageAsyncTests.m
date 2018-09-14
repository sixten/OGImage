//
//  OGImageAsyncTests.m
//  OGImage
//
//  Created by Sixten Otto on 2/17/16.
//  Copyright © 2016 Origami Labs. All rights reserved.
//

@import XCTest;
@import OGImage;

static NSString * const TEST_IMAGE_URL_STRING = @"https://httpbin.org/image/jpeg";
static NSString * const FAKE_IMAGE_URL_STRING = @"https://httpbin.org/status/404";
static const CGSize TEST_IMAGE_SIZE = {239.f, 178.f};

@interface OGImageAsyncTests : XCTestCase

@end

@implementation OGImageAsyncTests

- (void)test404 {
    OGImage *image = [[OGImage alloc] initWithURL:[NSURL URLWithString:FAKE_IMAGE_URL_STRING]];
    [self keyValueObservingExpectationForObject:image keyPath:@"error" handler:^BOOL(OGImage * _Nonnull img, __unused NSDictionary * _Nonnull change) {
        XCTAssertNil(img.image);
        XCTAssertNotNil(img.progress);
        XCTAssertGreaterThanOrEqual(img.progress.fractionCompleted, 1.0);
        XCTAssertNotNil(img.error);
        XCTAssertEqual(img.error.code, OGImageLoadingHTTPError, @"Expected HTTP error, got %@", image.error);
        XCTAssertEqualObjects(image.error.userInfo[OGImageLoadingHTTPStatusErrorKey], @(404), @"Expected HTTP 404 response, got %@", img.error);
        return YES;
    }];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
}

- (void)testImageOne {
    OGImage *image = [[OGImage alloc] initWithURL:[NSURL URLWithString:TEST_IMAGE_URL_STRING]];
    [self keyValueObservingExpectationForObject:image keyPath:@"image" handler:^BOOL(OGImage * _Nonnull img, __unused NSDictionary * _Nonnull change) {
        XCTAssertNil(img.error);
        XCTAssertNotNil(img.image, @"Got success notification, but no image.");
        XCTAssertNotNil(img.progress);
        XCTAssertGreaterThanOrEqual(img.progress.fractionCompleted, 1.0);
        XCTAssertTrue(CGSizeEqualToSize(TEST_IMAGE_SIZE, img.image.size), @"Expected image of size %@, got %@", NSStringFromCGSize(TEST_IMAGE_SIZE), NSStringFromCGSize(img.image.size));
        return YES;
    }];
  
    [self waitForExpectationsWithTimeout:5. handler:nil];
}

@end
