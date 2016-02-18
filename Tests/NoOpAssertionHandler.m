//
//  NoOpAssertionHandler.m
//  OGImage
//
//  Created by Sixten Otto on 2/20/16.
//  Copyright © 2016 Origami Labs. All rights reserved.
//

#import "NoOpAssertionHandler.h"

@implementation NoOpAssertionHandler

- (void)handleFailureInMethod:(SEL)selector object:(id)object file:(NSString *)fileName lineNumber:(NSInteger)line description:(__unused NSString *)format, ...
{
  NSLog(@"Assertion failure (ignored): %@ for object %@ in %@#%li", NSStringFromSelector(selector), object, fileName, (long)line);
}

- (void)handleFailureInFunction:(NSString *)functionName file:(NSString *)fileName lineNumber:(NSInteger)line description:(__unused NSString *)format, ...
{
  NSLog(@"Assertion failure (ignored): %@ in %@#%li", functionName, fileName, (long)line);
}

@end
