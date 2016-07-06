//
//  OGImageCacheTests.m
//  OGImage
//
//  Created by Sixten Otto on 7/6/16.
//  Copyright © 2016 Origami Labs. All rights reserved.
//

@import XCTest;
@import OGImage;
#import "__OGImage.h"

@interface OGImageCacheTests : XCTestCase

@end

@implementation OGImageCacheTests

- (NSURL *)temporaryCacheDirectory:(NSUInteger)subdirectories
{
  NSURL *cacheURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
  for (NSUInteger i=0; i<subdirectories; ++i) {
    NSUUID *uuid = [NSUUID UUID];
    cacheURL = [cacheURL URLByAppendingPathComponent:[uuid UUIDString]];
  }
  return cacheURL;
}

- (void)testSharedCacheIsStable {
  id cache1 = [OGImageCache shared];
  XCTAssertNotNil(cache1);
  
  id cache2 = [OGImageCache shared];
  XCTAssertEqual(cache1, cache2);
}

- (void)testCreatesSpecifiedCacheDirectory {
  NSURL *cacheURL = [self temporaryCacheDirectory:2];
  
  BOOL isDirectory;
  BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:[cacheURL path] isDirectory:&isDirectory];
  XCTAssertFalse(exists);
  
  id cache = [[OGImageCache alloc] initWithDirectoryURL:cacheURL];
  XCTAssertNotNil(cache);
  
  exists = [[NSFileManager defaultManager] fileExistsAtPath:[cacheURL path] isDirectory:&isDirectory];
  XCTAssertTrue(exists);
  XCTAssertTrue(isDirectory);
}

- (void)testStoresContentIntoDirectory {
  NSURL *imageURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"Origami" withExtension:@"jpg"];
  __OGImage *image = [[__OGImage alloc] initWithDataAtURL:imageURL];
  NSURL *cacheURL = [self temporaryCacheDirectory:1];
  OGImageCache *cache = [[OGImageCache alloc] initWithDirectoryURL:cacheURL];
  id expectation = [self expectationWithDescription:@"finished fetching"];
  
  [cache setImage:image forKey:@"foo"];
  [cache purgeMemoryCacheForKey:@"foo" andWait:YES];
  sleep(1);
  
  [cache imageForKey:@"foo" block:^(__OGImage *foo){
    XCTAssertNotNil(foo);
    
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:cacheURL includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL];
    XCTAssertEqual(contents.count, 1);
    
    __OGImage *foundImage = [[__OGImage alloc] initWithDataAtURL:[contents firstObject]];
    XCTAssertTrue(CGSizeEqualToSize(image.size, foundImage.size), @"image is not the expected size");
    
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testStoresContentInMemoryOnly {
  NSURL *imageURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"Origami" withExtension:@"jpg"];
  __OGImage *image = [[__OGImage alloc] initWithDataAtURL:imageURL];
  NSURL *cacheURL = [self temporaryCacheDirectory:1];
  OGImageCache *cache = [[OGImageCache alloc] initWithDirectoryURL:cacheURL];
  
  id expectation1 = [self expectationWithDescription:@"first fetch"];
  [cache setMemoryCacheImage:image forKey:@"foo"];
  [cache imageForKey:@"foo" block:^(__OGImage *foo){
    XCTAssertNotNil(foo);
    [expectation1 fulfill];
  }];
  
  id expectation2 = [self expectationWithDescription:@"second fetch"];
  [cache purgeMemoryCacheForKey:@"foo" andWait:YES];
  [cache imageForKey:@"foo" block:^(__OGImage *foo){
    XCTAssertNil(foo);
    [expectation2 fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:0.5 handler:nil];
}

- (void)testPurgingContent {
  NSURL *imageURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"Origami" withExtension:@"jpg"];
  __OGImage *image = [[__OGImage alloc] initWithDataAtURL:imageURL];
  OGImageCache *cache = [[OGImageCache alloc] initWithDirectoryURL:[self temporaryCacheDirectory:1]];
  id expectation = [self expectationWithDescription:@"finished fetching"];

  [cache setImage:image forKey:@"foo"];
  [cache setImage:image forKey:@"bar"];
  [cache setImage:image forKey:@"baz"];
  
  [cache imageForKey:@"foo" block:^(__OGImage *firstFoo){
    XCTAssertNotNil(firstFoo);
    [cache purgeCacheForKey:@"foo" andWait:YES];
    
    [cache imageForKey:@"foo" block:^(__OGImage *secondFoo){
      XCTAssertNil(secondFoo);
      
      [cache imageForKey:@"bar" block:^(__OGImage *firstBar){
        XCTAssertNotNil(firstBar);
        [cache purgeCache:YES];
        
        [cache imageForKey:@"bar" block:^(__OGImage *secondBar){
          XCTAssertNil(secondBar);
          
          [cache imageForKey:@"baz" block:^(__OGImage *baz){
            XCTAssertNil(baz);
            [expectation fulfill];
          }];
        }];
      }];
    }];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testPurgingOldContent {
  NSURL *imageURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"Origami" withExtension:@"jpg"];
  __OGImage *image = [[__OGImage alloc] initWithDataAtURL:imageURL];
  NSURL *cacheURL = [self temporaryCacheDirectory:1];
  OGImageCache *cache = [[OGImageCache alloc] initWithDirectoryURL:cacheURL];

  // starts empty
  NSArray<NSURL *> *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:cacheURL includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL];
  XCTAssertEqual(contents.count, 0);
  
  // store three -> has three
  [cache setImage:image forKey:@"foo"];
  [cache setImage:image forKey:@"bar"];
  [cache setImage:image forKey:@"baz"];
  sleep(1);
  contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:cacheURL includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL];
  XCTAssertEqual(contents.count, 3);
  
  // purge with really old date -> still has three
  [cache purgeDiskCacheOfImagesLastAccessedBefore:[NSDate dateWithTimeIntervalSinceNow:-100.0]];
  sleep(1);
  contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:cacheURL includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL];
  XCTAssertEqual(contents.count, 3);
  
  // purge again with very recent date -> none left
  [cache purgeDiskCacheOfImagesLastAccessedBefore:[NSDate dateWithTimeIntervalSinceNow:-0.5]];
  sleep(1);
  contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:cacheURL includingPropertiesForKeys:@[NSURLContentAccessDateKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL];
  XCTAssertEqual(contents.count, 0);
}

@end
