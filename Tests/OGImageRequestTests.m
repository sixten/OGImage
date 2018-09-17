//
//  OGImageRequestTests.m
//  OGImage
//
//  Created by Sixten Otto on 7/12/16.
//  Copyright © 2016 Origami Labs. All rights reserved.
//

@import XCTest;
@import OGImage;
#import "__OGImage.h"
#import "OGImageRequest.h"

typedef void (^OG_TaskCompletion)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable);

@interface OGImageRequestTests : XCTestCase
@end

@interface OG_MockSession : NSURLSession

@property (nonatomic, copy) OG_TaskCompletion completion;

@end

@interface OG_MockTask : NSObject

@property (nonatomic, copy) NSURL *url;

@end

@implementation OG_MockSession

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler
{
    OG_MockTask *task = [[OG_MockTask alloc] init];
    task.url = url;
    self.completion = completionHandler;
    return (id)task;
}

@end

@implementation OG_MockTask

- (void)resume {}

@end


@implementation OGImageRequestTests

- (void)testRequestCompletionPassesThroughErrors {
    NSURL *url = [NSURL URLWithString:@"http://example.com/image"];
    OG_MockSession *session = [[OG_MockSession alloc] init];
    
    __block NSError *reportedError = nil;
    OGImageRequest *imageRequest = [[OGImageRequest alloc] initWithURL:url completionBlock:^(__unused __OGImage *image, __unused NSError *error, __unused NSTimeInterval loadTime) {
        XCTAssertNil(image);
        reportedError = error;
    }];
    [imageRequest retrieveImageInSession:session];
    
    NSError *dispatchedError = [NSError errorWithDomain:@"OGBondErrorDomain" code:007 userInfo:nil];
    session.completion(nil, nil, dispatchedError);
    XCTAssertEqual(dispatchedError, reportedError);
}

- (void)testRequestCompletionReturnsErrorForUnsuccessfulRequest {
    NSURL *url = [NSURL URLWithString:@"http://example.com/image"];
    OG_MockSession *session = [[OG_MockSession alloc] init];
    
    __block NSError *reportedError = nil;
    OGImageRequest *imageRequest = [[OGImageRequest alloc] initWithURL:url completionBlock:^(__unused __OGImage *image, __unused NSError *error, __unused NSTimeInterval loadTime) {
        XCTAssertNil(image);
        reportedError = error;
    }];
    [imageRequest retrieveImageInSession:session];
    
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:400 HTTPVersion:nil headerFields:nil];
    session.completion(nil, response, nil);
    
    XCTAssertNotNil(reportedError);
    XCTAssertNotNil(reportedError.userInfo);
    XCTAssertEqualObjects(OGImageLoadingErrorDomain, reportedError.domain);
    XCTAssertEqual(OGImageLoadingHTTPError, reportedError.code);
    XCTAssertEqualObjects(url, reportedError.userInfo[NSURLErrorFailingURLErrorKey]);
    XCTAssertEqualObjects(@400, reportedError.userInfo[OGImageLoadingHTTPStatusErrorKey]);
}

- (void)testRequestCompletionReturnsErrorForInvalidImageData {
    NSData *imageData = [[NSData alloc] initWithBase64EncodedString:@"Tm93IGlzIHRoZSB0aW1lIGZvciBhbGwgZ29vZCBtZW7igKY=" options:0];
    XCTAssertNotNil(imageData);
    
    NSURL *url = [NSURL URLWithString:@"http://example.com/image"];
    OG_MockSession *session = [[OG_MockSession alloc] init];
    
    __block NSError *reportedError = nil;
    OGImageRequest *imageRequest = [[OGImageRequest alloc] initWithURL:url completionBlock:^(__unused __OGImage *image, __unused NSError *error, __unused NSTimeInterval loadTime) {
        XCTAssertNil(image);
        reportedError = error;
    }];
    [imageRequest retrieveImageInSession:session];
    
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:nil headerFields:nil];
    session.completion(imageData, response, nil);
    
    XCTAssertNotNil(reportedError);
    XCTAssertNotNil(reportedError.userInfo);
    XCTAssertEqualObjects(OGImageLoadingErrorDomain, reportedError.domain);
    XCTAssertEqual(OGImageLoadingInvalidImageDataError, reportedError.code);
    XCTAssertEqualObjects(url, reportedError.userInfo[NSURLErrorFailingURLErrorKey]);
}

- (void)testRequestCompletionReturnsImageFromRequestData {
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"Origami" ofType:@"jpg"];
    NSData *imageData = [[NSData alloc] initWithContentsOfFile:path];
    XCTAssertNotNil(imageData);
    
    NSURL *url = [NSURL URLWithString:@"http://example.com/image"];
    OG_MockSession *session = [[OG_MockSession alloc] init];
    
    __block __OGImage *reportedImage = nil;
    OGImageRequest *imageRequest = [[OGImageRequest alloc] initWithURL:url completionBlock:^(__unused __OGImage *image, __unused NSError *error, __unused NSTimeInterval loadTime) {
        XCTAssertNil(error);
        reportedImage = image;
    }];
    [imageRequest retrieveImageInSession:session];
    
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:nil headerFields:nil];
    session.completion(imageData, response, nil);
    
    XCTAssertNotNil(reportedImage);
    XCTAssertEqual(1024.f, reportedImage.size.width);
}

@end
