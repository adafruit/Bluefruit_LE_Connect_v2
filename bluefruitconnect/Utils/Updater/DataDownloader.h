//
//  DataDownloader.h
//  Bluefruit Connect
//
//  Created by Antonio García on 31/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DataDownloader : NSObject

// Download helper
+ (void)downloadDataFromURL:(NSURL *)url withCompletionHandler:(void (^)(NSData *))completionHandler;

@end
