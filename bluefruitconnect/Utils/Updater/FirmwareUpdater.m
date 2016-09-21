//
//  FirmwareUpdater.m
//  BluefruitUpdater
//
//  Created by Antonio García on 17/04/15.
//  Copyright (C) 2015 Adafruit Industries (www.adafruit.com)
//

#import "FirmwareUpdater.h"
#import "ReleasesParser.h"
#import "DeviceInfoData.h"
#import "LogHelper.h"
#import "DataDownloader.h"

#ifndef COMMANDLINE
    #import "Adafruit_Bluefruit_LE_Connect-Swift.h"
#endif

#pragma mark - FirmwareUpdater
@interface FirmwareUpdater ()
{
    __weak id<CBPeripheralDelegate> previousPeripheralDelegate;
    
    BOOL isManufacturerCharacteristicAvailable;
    BOOL isModelNumberCharacteristicAvailable;
    BOOL isSoftwareRevisionCharacteristicAvailable;
    BOOL isFirmwareRevisionCharacteristicAvailable;
    __weak id<FirmwareUpdaterDelegate> delegate;
    NSDictionary *releases;
    BOOL shouldRecommendBetaReleases;
}

@end

@implementation FirmwareUpdater

static NSString* const kManufacturer = @"Adafruit Industries";

//  Config
static NSString *kReleasesXml = @"updatemanager_releasesxml";

// Constants
static  NSString* const kNordicDeviceFirmwareUpdateService = @"00001530-1212-EFDE-1523-785FEABCD123";
static  NSString* const kDeviceInformationService = @"180A";
static  NSString* const kModelNumberCharacteristic = @"00002A24-0000-1000-8000-00805F9B34FB";
static  NSString* const kManufacturerNameCharacteristic = @"00002A29-0000-1000-8000-00805F9B34FB";
static  NSString* const kSoftwareRevisionCharacteristic = @"00002A28-0000-1000-8000-00805F9B34FB";
static  NSString* const kFirmwareRevisionCharacteristic = @"00002A26-0000-1000-8000-00805F9B34FB";

static CBUUID *disServiceUUID;
static CBUUID *dfuServiceUUID;
static CBUUID *manufacturerCharacteristicUUID;
static CBUUID *modelNumberCharacteristicUUID;
static CBUUID *softwareRevisionCharacteristicUUID;
static CBUUID *firmwareRevisionCharacteristicUUID;

+ (void)initialize {
    disServiceUUID = [CBUUID UUIDWithString:kDeviceInformationService];
    dfuServiceUUID = [CBUUID UUIDWithString:kNordicDeviceFirmwareUpdateService];
    
    manufacturerCharacteristicUUID = [CBUUID UUIDWithString:kManufacturerNameCharacteristic];
    modelNumberCharacteristicUUID = [CBUUID UUIDWithString:kModelNumberCharacteristic];
    softwareRevisionCharacteristicUUID = [CBUUID UUIDWithString:kSoftwareRevisionCharacteristic];
    firmwareRevisionCharacteristicUUID = [CBUUID UUIDWithString:kFirmwareRevisionCharacteristic];
}


+ (NSDictionary *)releasesWithBetaVersions:(BOOL)showBetaVersions
{
    NSDictionary *boardsInfoDictionary = nil;
    
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:kReleasesXml];
    if (data)
    {
        // Parse data
        boardsInfoDictionary = [ReleasesParser parse:data showBetaVersions:showBetaVersions];
    }
    
    return boardsInfoDictionary;
}

+ (void)refreshSoftwareUpdatesDatabaseFromUrl:(NSURL *)dataUrl completionHandler:(void (^)(BOOL))completionHandler
{
    @synchronized(self) {
        // Download data
        [DataDownloader downloadDataFromURL:dataUrl withCompletionHandler:^(NSData *data) {
            // Save to user defaults
            [[NSUserDefaults standardUserDefaults] setObject:data forKey:kReleasesXml];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"didUpdatePreferences" object:nil];
            
            if (completionHandler) {
                completionHandler(data != nil);
            }
        }];
    }
}

#pragma mark  Peripheral Management
- (void)checkUpdatesForPeripheral:(CBPeripheral *)peripheral delegate:(__weak id<FirmwareUpdaterDelegate>)aDelegate shouldDiscoverServices:(BOOL)discoverServices releases:(NSDictionary *)aReleases shouldRecommendBetaReleases: (BOOL)aShouldRecommendBetaReleases
{
    releases = aReleases;
    delegate = aDelegate;
    shouldRecommendBetaReleases = aShouldRecommendBetaReleases;
    previousPeripheralDelegate = peripheral.delegate;
    peripheral.delegate = self;
    
    if (discoverServices) {
        [peripheral discoverServices:nil];
    }
    else {
        // The peripheral is already connected and services discovered, so go to didDiscoverServices
        [self peripheral:peripheral didDiscoverServices:nil];
    }
}


- (void)connectToPeripheral:(CBPeripheral *)peripheral {
    
    peripheral.delegate = self;
}

- (void)hasConnectedPeripheralDFUService
{
}

#pragma mark  CBPeripheralDelegate
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {

    // Clear data
    isManufacturerCharacteristicAvailable = true;
    isModelNumberCharacteristicAvailable = true;
    isSoftwareRevisionCharacteristicAvailable = true;
    isFirmwareRevisionCharacteristicAvailable = true;
    
    // Retrieve services
    CBService *dfuService = nil;
    CBService *disService = nil;
    
    for (CBService *service in peripheral.services) {
        //DLog(@"Discovered service %@", service);
        if ([service.UUID isEqual:dfuServiceUUID]) {
            dfuService = service;
        }
        else if ([service.UUID isEqual:disServiceUUID]) {
            disService = service;
        }
    }
    
    // If we have the services that we need, retrieve characteristics
    if (dfuService && disService) {
        _deviceInfoData = [DeviceInfoData new];
        
        /*
         [peripheral discoverCharacteristics:@[manufacturerCharacteristicUUID, modelNumberCharacteristicUUID, softwareRevisionCharacteristicUUID, firmwareRevisionCharacteristicUUID] forService:disService];
         */
        // Note: OSX seems to have problems discovering a specific set of characteristics, so nil is passed to discover all of them
        [peripheral discoverCharacteristics:nil forService:disService];
    }
    else
    {
        peripheral.delegate = previousPeripheralDelegate;
        
        DLog(@"Peripheral has no dfu or dis service available");
        if (/*error && */delegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [delegate onDfuServiceNotFound];
            });
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    // Read the characteristics discovered
    
    if ([service.UUID isEqual:disServiceUUID] || [service.UUID isEqual:dfuServiceUUID]) {
        if (error) {
            DLog("FirmwareUpdater error discovering characteristics: %@", error)
        }
        
        // Check if all characteristics are available
        isModelNumberCharacteristicAvailable = [self service:service containsCharacteristicUUID:modelNumberCharacteristicUUID];
        isSoftwareRevisionCharacteristicAvailable = [self service:service containsCharacteristicUUID:softwareRevisionCharacteristicUUID];
        isManufacturerCharacteristicAvailable = [self service:service containsCharacteristicUUID:manufacturerCharacteristicUUID];
        isFirmwareRevisionCharacteristicAvailable = [self service:service containsCharacteristicUUID:firmwareRevisionCharacteristicUUID];
        
        // Update values
        for (CBCharacteristic *characteristic in service.characteristics) {
            // DLog(@"Discovered characteristic %@", characteristic);
            [peripheral readValueForCharacteristic:characteristic];
        }
    }
}

- (BOOL)service:(CBService *)service containsCharacteristicUUID:(CBUUID *)uuid {
    return [service.characteristics indexesOfObjectsPassingTest:^BOOL(CBCharacteristic * _Nonnull characteristic, NSUInteger idx, BOOL * _Nonnull stop) {
        return [characteristic.UUID isEqual:uuid];
    }].count > 0;
    
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    NSData *data = characteristic.value;
    if ([characteristic.UUID isEqual:manufacturerCharacteristicUUID]) {
        _deviceInfoData.manufacturer = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    else if ([characteristic.UUID isEqual:modelNumberCharacteristicUUID]) {
        _deviceInfoData.modelNumber = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    else if ([characteristic.UUID isEqual:softwareRevisionCharacteristicUUID]) {
        _deviceInfoData.softwareRevision = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    else if ([characteristic.UUID isEqual:firmwareRevisionCharacteristicUUID]) {
        _deviceInfoData.firmwareRevision = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    
    //DLog(@"didUpdateValueForCharacteristic %@", characteristic);
    [self onDeviceInfoUpdatedForPeripheral:peripheral];
}

- (void)onDeviceInfoUpdatedForPeripheral:(CBPeripheral *)peripheral
{
    if ((_deviceInfoData.manufacturer || !isManufacturerCharacteristicAvailable) && (_deviceInfoData.modelNumber || !isModelNumberCharacteristicAvailable) && (_deviceInfoData.softwareRevision || !isSoftwareRevisionCharacteristicAvailable) && (_deviceInfoData.firmwareRevision || !isFirmwareRevisionCharacteristicAvailable)) {
        DLog(@"Device Info Data received");
        
        if (delegate == nil) {
            DLog(@"Error: onDeviceInfoUpdatedForPeripheral with no delegate");
        }
        
#ifdef COMMANDLINE
        NSString *versionToIgnore =  [[NSUserDefaults standardUserDefaults] stringForKey:@"UpdateIgnoredVersion"];
#else
        NSString *versionToIgnore =  [Preferences softwareUpdateIgnoredVersion];
#endif
        
        BOOL isFirmwareUpdateAvailable = NO;
        
        NSDictionary *allReleases = releases;
        FirmwareInfo *latestRelease = nil;
        
        if (_deviceInfoData.firmwareRevision != nil) {
            if (![_deviceInfoData hasDefaultBootloaderVersion]) {       // Special check because Nordic dfu library for iOS dont work with the default booloader version
                BOOL isManufacturerCorrect = _deviceInfoData.manufacturer!=nil && [kManufacturer caseInsensitiveCompare:_deviceInfoData.manufacturer] == NSOrderedSame;
                if (isManufacturerCorrect) {
                    if (_deviceInfoData.modelNumber != nil) {
                        BoardInfo *boardInfo = [allReleases objectForKey:_deviceInfoData.modelNumber];
                        if (boardInfo) {
                            NSArray *modelReleases = boardInfo.firmwareReleases;
                            if (modelReleases && modelReleases.count > 0) {
                                // Get the latest release (discard all beta releases)
                                int selectedRelease = 0;
                                do {
                                    latestRelease = [modelReleases objectAtIndex:selectedRelease];
                                    selectedRelease++;
                                } while(latestRelease.isBeta && !shouldRecommendBetaReleases && selectedRelease<modelReleases.count);
                                
                                if (!latestRelease.isBeta || shouldRecommendBetaReleases)
                                {
                                    // Check if the bootloader is compatible with this version
                                    if (_deviceInfoData.bootloaderVersion && [_deviceInfoData.bootloaderVersion compare:latestRelease.minBootloaderVersion options:NSNumericSearch] != NSOrderedAscending) {
                                        // Check if the user chose to ignore this version
                                        if ([latestRelease.version compare:versionToIgnore options:NSNumericSearch] != NSOrderedSame) {
                                            
                                            const BOOL isNewerVersion = _deviceInfoData.softwareRevision!= nil && [latestRelease.version compare:_deviceInfoData.softwareRevision options:NSNumericSearch] == NSOrderedDescending;
                                            const BOOL showUpdateOnlyForNewerVersions = YES;            // only for debug purposes (should be YES for release)
                                            
                                            isFirmwareUpdateAvailable = isNewerVersion || !showUpdateOnlyForNewerVersions;
                                            
#ifdef DEBUG
                                            if (isNewerVersion) {
                                                DLog(@"Updates: New version found. Ask the user to install: %@", latestRelease.version);
                                            }
                                            else {
                                                DLog(@"Updates: Device has already latest version: %@", _deviceInfoData.softwareRevision);
                                                
                                                if (isFirmwareUpdateAvailable) {
                                                    DLog(@"Updates: user asked to show old versions too");
                                                }
                                            }
#endif
                                        }
                                        else {
                                            DLog(@"Updates: User ignored version: %@. Skipping...", versionToIgnore);
                                        }
                                    }
                                    else {
                                        DLog(@"Updates: No non-beta firmware releases found for model: %@", versionToIgnore);
                                        
                                    }
                                }
                                else {
                                    DLog(@"Updates: Bootloader version %@ below minimum needed: %@", _deviceInfoData.bootloaderVersion, latestRelease.minBootloaderVersion);
                                }
                            }
                            else {
                                DLog(@"Updates: No firmware releases found for model: %@", _deviceInfoData.modelNumber);
                            }
                        }
                        else {
                            DLog(@"Updates: No releases found for model:  %@", _deviceInfoData.modelNumber);
                        }
                    }
                    else{
                        DLog(@"Updates: modelNumber not defined");
                    }
                }
                else {
                    DLog(@"Updates: No updates for unknown manufacturer %@", _deviceInfoData.manufacturer);
                }
            }
            else {
                DLog(@"The legacy bootloader on this device is not compatible with this application");
            }
        }
        else {
            DLog(@"Updates: firmwareRevision not defined ");
        }
        
        peripheral.delegate = previousPeripheralDelegate;
        [delegate onFirmwareUpdatesAvailable:isFirmwareUpdateAvailable latestRelease:latestRelease deviceInfoData:_deviceInfoData allReleases:allReleases];
    }
}

@end
