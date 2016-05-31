//
//  DeviceInfoData.m
//  Bluefruit Connect
//
//  Created by Antonio García on 31/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

#import "DeviceInfoData.h"

@implementation DeviceInfoData

static NSString* const kDefaultBootloaderVersion = @"0.0";

- (NSString *)defaultBootloaderVersion
{
    return kDefaultBootloaderVersion;
}

- (NSString *)bootloaderVersion
{
    NSString *result = kDefaultBootloaderVersion;
    if (_firmwareRevision) {
        NSInteger index = [_firmwareRevision rangeOfString:@", "].location;
        if (index != NSNotFound)
        {
            NSString *bootloaderVersion = [_firmwareRevision substringFromIndex:index+2];
            result = bootloaderVersion;
        }
    }
    return result;
}

- (BOOL)hasDefaultBootloaderVersion
{
    return [[self bootloaderVersion] isEqualToString:kDefaultBootloaderVersion];
}

@end
