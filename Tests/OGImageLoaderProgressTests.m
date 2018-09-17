//
//  OGImageLoaderProgressTests.m
//  OGImage
//
//  Created by Sixten Otto on 7/12/16.
//  Copyright © 2016 Origami Labs. All rights reserved.
//

@import XCTest;
@import OGImage;
#import "OGImageLoader.h"

@interface OGProgressTestLoaderDelegate : NSObject <OGImageLoaderDelegate>

@property (copy, nonatomic) NSURL *url;
@property (strong, nonatomic) NSProgress *progress;
@property (strong, nonatomic) __OGImage *image;
@property (strong, nonatomic) NSError *error;

- (instancetype)initWithURL:(NSURL *)url NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

@interface OGImageLoaderProgressTests : XCTestCase

@end

@implementation OGImageLoaderProgressTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)testLoaderBeginsProgressForFileURLs {
    NSURL *imageURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"Origami" withExtension:@"jpg"];
    XCTAssertNotNil(imageURL, @"Couldn't get URL for test image");
    
    OGProgressTestLoaderDelegate *delegate = [[OGProgressTestLoaderDelegate alloc] initWithURL:imageURL];
    [self keyValueObservingExpectationForObject:delegate keyPath:@"progress" handler:^BOOL(__unused id _Nonnull observedObject, __unused NSDictionary * _Nonnull change) {
        XCTAssertNotNil(delegate.progress);
        XCTAssertTrue(delegate.progress.indeterminate);
        return YES;
    }];
    
    [[OGImageLoader shared] enqueueImageRequest:imageURL delegate:delegate];
    
    [self waitForExpectationsWithTimeout:0.2 handler:nil];
}

- (void)testLoaderBeginsProgressForNetworkRequests {
    NSURL *imageURL = [NSURL URLWithString:@"http://placehold.it/50x50"];
    
    OGProgressTestLoaderDelegate *delegate = [[OGProgressTestLoaderDelegate alloc] initWithURL:imageURL];
    [self keyValueObservingExpectationForObject:delegate keyPath:@"progress" handler:^BOOL(__unused id _Nonnull observedObject, __unused NSDictionary * _Nonnull change) {
        XCTAssertNotNil(delegate.progress);
        return YES;
    }];
    
    [[OGImageLoader shared] enqueueImageRequest:imageURL delegate:delegate];
    
    [self waitForExpectationsWithTimeout:0.2 handler:nil];
}

- (void)testLoaderBeginsProgressForSubsequentRequests {
    NSURL *imageURL = [NSURL URLWithString:@"http://placehold.it/50x50"];
    
    OGProgressTestLoaderDelegate *delegate = [[OGProgressTestLoaderDelegate alloc] initWithURL:imageURL];
    [self keyValueObservingExpectationForObject:delegate keyPath:@"progress" handler:^BOOL(__unused id _Nonnull observedObject, __unused NSDictionary * _Nonnull change) {
        XCTAssertNotNil(delegate.progress);
        return YES;
    }];
    
    // first call to get the URL into the stack; no expectations on this delegate
    OGProgressTestLoaderDelegate *delegate1 = [[OGProgressTestLoaderDelegate alloc] initWithURL:imageURL];
    [[OGImageLoader shared] enqueueImageRequest:imageURL delegate:delegate1];
    
    // second call should re-use the existing request on the stack
    [[OGImageLoader shared] enqueueImageRequest:imageURL delegate:delegate];
    
    [self waitForExpectationsWithTimeout:0.2 handler:nil];
}

@end


@implementation OGProgressTestLoaderDelegate

- (instancetype)initWithURL:(NSURL *)url
{
    NSParameterAssert(url);
    self = [super init];
    if (self) {
        self.url = url;
    }
    return self;
}

- (void)imageLoader:(__unused OGImageLoader*)loader didLoadImage:(__OGImage *)image forURL:(NSURL *)url {
    NSAssert([self.url isEqual:url], @"Got delegate callback for wrong URL");
    self.image = image;
}

- (void)imageLoader:(__unused OGImageLoader*)loader failedForURL:(NSURL *)url error:(NSError *)error {
    NSAssert([self.url isEqual:url], @"Got delegate callback for wrong URL");
    self.error = error;
}

- (void)imageLoader:(__unused OGImageLoader*)loader didBeginLoadingForURL:(NSURL *)url progress:(NSProgress *)progress {
    NSAssert([self.url isEqual:url], @"Got delegate callback for wrong URL");
    self.progress = progress;
}

@end
