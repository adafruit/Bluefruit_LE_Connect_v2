//
//  DeviceInfoData.h
//  Bluefruit Connect
//
//  Created by Antonio García on 31/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DeviceInfoData : NSObject

@property NSString *manufacturer;
@property NSString *modelNumber;
@property NSString *firmwareRevision;
@property NSString *softwareRevision;
- (NSString *)bootloaderVersion;
- (NSString *)defaultBootloaderVersion;
- (BOOL)hasDefaultBootloaderVersion;

@end