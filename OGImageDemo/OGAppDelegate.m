//
//  OGAppDelegate.m
//  OGImageDemo
//
//  Created by Art Gillespie on 11/26/12.
//  Copyright (c) 2012 Origami Labs, Inc.. All rights reserved.
//

#import "OGAppDelegate.h"
#import "OGViewController.h"
#import "OGImageCache.h"

@implementation OGAppDelegate

- (BOOL)application:(__unused UIApplication *)application didFinishLaunchingWithOptions:(__unused NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.viewController = [[OGViewController alloc] initWithNibName:@"OGViewController" bundle:nil];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self.viewController];
    self.window.rootViewController = navController;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationDidEnterBackground:(__unused UIApplication *)application {
    // purge the disk cache of any image that hasn't been
    // accessed more recently than 2 minutes ago. This is obviously pretty contrived;
    NSDate *before = [NSDate dateWithTimeIntervalSinceNow:-120.];
    [[OGImageCache shared] purgeDiskCacheOfImagesLastAccessedBefore:before];
}

@end
