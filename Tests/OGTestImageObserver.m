//
//  OGTestImageObserver.m
//  OGImage
//
//  Created by Sixten Otto on 2/17/16.
//  Copyright © 2016 Origami Labs. All rights reserved.
//

#import "OGTestImageObserver.h"
#import "OGImage.h"

static NSString *KVOContext = @"OGTestImageObserver observation";

@interface OGTestImageObserver ()

@property (strong, nonatomic) OGImage *image;
@property (copy,   nonatomic) OGTestImageObservationBlock block;

@end

@implementation OGTestImageObserver

- (instancetype)initWithImage:(OGImage *)image andBlock:(OGTestImageObservationBlock)block
{
  self = [super init];
  if( nil != self ) {
    self.image = image;
    self.block = block;
    [image addObserver:self context:&KVOContext];
  }
  return self;
}

- (void)dealloc
{
  [_image removeObserver:self context:&KVOContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if( context == &KVOContext ) {
    if( object == self.image ) {
      self.block(object, keyPath);
    }
  }
  else {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

@end
