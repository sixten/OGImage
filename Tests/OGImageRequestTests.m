//
//  OGImageRequestTests.m
//  OGImage
//
//  Created by Sixten Otto on 7/12/16.
//  Copyright © 2016 Origami Labs. All rights reserved.
//

@import XCTest;
@import OGImage;
#import "OGImageRequest.h"

@interface OGImageRequestTests : XCTestCase

@end

@implementation OGImageRequestTests

- (void)testRequestReportsIndeterminateProgress {
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"Origami" ofType:@"jpg"];
    NSData *imageData = [[NSData alloc] initWithContentsOfFile:path];
    XCTAssertNotNil(imageData);
    
    NSURL *url = [NSURL URLWithString:@"http://example.com/image"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:nil startImmediately:NO];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    OGImageRequest *imageRequest = [[OGImageRequest alloc] initWithURL:url completionBlock:^(__unused __OGImage *image, __unused NSError *error, __unused NSTimeInterval loadTime) {
        // no-op
    } queue:queue];
    
    // initially indeterminate
    XCTAssertNotNil(imageRequest.progress);
    XCTAssertTrue(imageRequest.progress.isIndeterminate);
    
    // still indeterminate after the response, because unknown content length
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url MIMEType:@"image/jpeg" expectedContentLength:NSURLResponseUnknownLength textEncodingName:nil];
    [imageRequest connection:conn didReceiveResponse:response];
    XCTAssertNotNil(imageRequest.progress);
    XCTAssertTrue(imageRequest.progress.isIndeterminate);
    XCTAssertEqualWithAccuracy(imageRequest.progress.fractionCompleted, 0, 0.001);
    
    // and still indeterminte after receiving some data
    NSRange chunkRange = NSMakeRange(0, (NSUInteger)floor(imageData.length * 0.4));
    NSData *firstChunk = [imageData subdataWithRange:chunkRange];
    [imageRequest connection:conn didReceiveData:firstChunk];
    XCTAssertNotNil(imageRequest.progress);
    XCTAssertTrue(imageRequest.progress.isIndeterminate);
    XCTAssertEqualWithAccuracy(imageRequest.progress.fractionCompleted, 0, 0.001);
}

- (void)testRequestReportsDefiniteProgress {
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"Origami" ofType:@"jpg"];
    NSData *imageData = [[NSData alloc] initWithContentsOfFile:path];
    XCTAssertNotNil(imageData);
    
    NSURL *url = [NSURL URLWithString:@"http://example.com/image"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:nil startImmediately:NO];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    OGImageRequest *imageRequest = [[OGImageRequest alloc] initWithURL:url completionBlock:^(__unused __OGImage *image, __unused NSError *error, __unused NSTimeInterval loadTime) {
        // no-op
    } queue:queue];
    
    // initially indeterminate
    XCTAssertNotNil(imageRequest.progress);
    XCTAssertTrue(imageRequest.progress.isIndeterminate);
    
    // definite after the response, because known content length
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url MIMEType:@"image/jpeg" expectedContentLength:imageData.length textEncodingName:nil];
    [imageRequest connection:conn didReceiveResponse:response];
    XCTAssertNotNil(imageRequest.progress);
    XCTAssertFalse(imageRequest.progress.isIndeterminate);
    XCTAssertEqual(imageRequest.progress.totalUnitCount, imageData.length);
    XCTAssertEqual(imageRequest.progress.completedUnitCount, 0);
    XCTAssertEqualWithAccuracy(imageRequest.progress.fractionCompleted, 0, 0.001);
    
    // updates progress as data comes in
    NSRange chunkRange = NSMakeRange(0, 0);
    for (int step=0; step < 10; ++step) {
        double fraction = (step + 1) / 10.0;
        NSUInteger start = NSMaxRange(chunkRange);
        NSUInteger end = (NSUInteger)floor(imageData.length * fraction);
        chunkRange = NSMakeRange(start, end - start);
        NSData *chunk = [imageData subdataWithRange:chunkRange];
        
        [imageRequest connection:conn didReceiveData:chunk];
        XCTAssertNotNil(imageRequest.progress);
        XCTAssertFalse(imageRequest.progress.isIndeterminate);
        XCTAssertEqual(imageRequest.progress.totalUnitCount, imageData.length);
        XCTAssertEqual(imageRequest.progress.completedUnitCount, end);
        XCTAssertEqualWithAccuracy(imageRequest.progress.fractionCompleted, fraction, 0.05);
    }
}

@end
