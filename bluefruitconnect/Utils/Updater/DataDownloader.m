//
//  DataDownloader.m
//  Bluefruit Connect
//
//  Created by Antonio García on 31/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

#import "DataDownloader.h"
#import "LogHelper.h"

@implementation DataDownloader

+ (void)downloadDataFromURL:(NSURL *)url withCompletionHandler:(void (^)(NSData *))completionHandler
{
    if ([url.scheme isEqualToString:@"file"])        // Check if url is local and just open the file
    {
        NSData *data = [NSData dataWithContentsOfURL:url];
        completionHandler(data);
    }
    else
    {
        // If the url is not local, download the file
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
        
        NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error != nil) {
                // If any error occurs then just display its description on the console.
                DLog(@"%@", [error description]);
                data = nil;
                
                completionHandler(data);
            }
            else{
                NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
                if (statusCode != 200) {
                    DLog(@"Download file HTTP status code = %ld", (long)statusCode);
                    data = nil;
                }
                
                // Call the completion handler with the returned data on the main thread.
                if (completionHandler) {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        completionHandler(data);
                    }];
                }
            }
        }];
        
        [task resume];
    }
}

@end
