//
//  FirmwareUpdater.h
//  BluefruitUpdater
//
//  Created by Antonio García on 17/04/15.
//  Copyright (C) 2015 Adafruit Industries (www.adafruit.com)
//

#import <Foundation/Foundation.h>
@import CoreBluetooth;
#import "ReleasesParser.h"

@class DeviceInfoData;

#pragma mark - FirmwareUpdater
@protocol FirmwareUpdaterDelegate <NSObject>
- (void)onFirmwareUpdatesAvailable:(BOOL)isUpdateAvailable latestRelease:(FirmwareInfo *)latestRelease deviceInfoData:(DeviceInfoData *)deviceInfoData allReleases:(NSDictionary *)allReleases;
- (void)onDfuServiceNotFound;
@end

@interface FirmwareUpdater : NSObject  <CBPeripheralDelegate>

@property DeviceInfoData *deviceInfoData;

// Releases database
+ (void)refreshSoftwareUpdatesDatabaseFromUrl:(NSURL *)url completionHandler:(void (^)(BOOL))completionHandler;
+ (NSDictionary *)releasesWithBetaVersions:(BOOL)showBetaVersions;

// Check updates
- (void)checkUpdatesForPeripheral:(CBPeripheral *)peripheral delegate:(__weak id<FirmwareUpdaterDelegate>) delegate shouldDiscoverServices:(BOOL)discoverServices releases:(NSDictionary *)aReleases shouldRecommendBetaReleases: (BOOL)shouldRecommendBetaReleases;
@end
