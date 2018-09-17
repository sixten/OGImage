//
//  OGTestImageObserver.h
//  OGImage
//
//  Created by Sixten Otto on 2/17/16.
//  Copyright © 2016 Origami Labs. All rights reserved.
//

@import Foundation;

@class OGImage;


typedef void(^OGTestImageObservationBlock)(OGImage *image, NSString *keyPath);


@interface OGTestImageObserver : NSObject

- (instancetype)initWithImage:(OGImage *)image andBlock:(OGTestImageObservationBlock)block;

@end
