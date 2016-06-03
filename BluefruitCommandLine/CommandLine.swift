//
//  CommandLine.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 17/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

class CommandLine: NSObject {
    // Config
    private static let appVersion = "0.1"
    
    // Scanning
    var discoveredPeripheralsIdentifiers = [String]()
    private var scanResultsShowIndex = false
    
    // DFU
    private var dfuSemaphore = dispatch_semaphore_create(0)
    private let firmwareUpdater = FirmwareUpdater()
    private let dfuUpdateProcess = DfuUpdateProcess()
    private var dfuPeripheral: CBPeripheral?
    private var hexUrl: NSURL?
    private var iniUrl: NSURL?
    
    // MARK: - Bluetooth Status
    func checkBluetoothErrors() -> String? {
        var errorMessage : String?
        let bleManager = BleManager.sharedInstance
        if let state = bleManager.centralManager?.state {
            switch(state) {
            case .Unsupported:
                errorMessage = "This computer doesn't support Bluetooth Low Energy"
            case .Unauthorized:
                errorMessage = "The application is not authorized to use the Bluetooth Low Energy"
            case .PoweredOff:
                errorMessage = "Bluetooth is currently powered off"
            default:
                errorMessage = nil
            }
        }
        
        return errorMessage
    }
    
    // MARK: - Help
    func showHelp() {
        showVersion()
        
    }
    
    func showVersion() {
        let appInfoString = "Bluefruit v\(CommandLine.appVersion)"
        print(appInfoString)
        
    }
    
    // MARK: - Scan 
    func startScanning() {
        startScanningAndShowIndex(false)
    }
    
    func startScanningAndShowIndex(scanResultsShowIndex: Bool) {
        self.scanResultsShowIndex = scanResultsShowIndex
        
        // Subscribe to Ble Notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didDiscoverPeripheral(_:)), name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        
        BleManager.sharedInstance.startScan()
    }
    
    func stopScanning() {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        
        BleManager.sharedInstance.stopScan()
    }
    
    func didDiscoverPeripheral(notification : NSNotification) {
        
        if let uuid = notification.userInfo?["uuid"] as? String {
            
            if let peripheral = BleManager.sharedInstance.blePeripherals()[uuid] {
                
                if !discoveredPeripheralsIdentifiers.contains(uuid) {
                    discoveredPeripheralsIdentifiers.append(uuid)
                    
                    let name = peripheral.name != nil ? peripheral.name! : "{No Name}"
                    if scanResultsShowIndex {
                        if let index  = discoveredPeripheralsIdentifiers.indexOf(uuid) {
                            print("\(index) -> \(uuid): \(name)")
                        }
                    }
                    else {
                        print("\(uuid): \(name)")
                    }
                }
            }
        }
    }
    
    // MARK: - DFU
    func dfuPeripheralWithUUIDString(UUIDString: String, hexUrl: NSURL, iniUrl: NSURL?) {
        
        guard let centralManager = BleManager.sharedInstance.centralManager else {
            DLog("centralManager is nil")
            return
        }
        
        if let peripheralUUID = NSUUID(UUIDString: UUIDString) {
            if let peripheral = centralManager.retrievePeripheralsWithIdentifiers([peripheralUUID]).first {
                
                dfuPeripheral = peripheral
                self.hexUrl = hexUrl
                self.iniUrl = iniUrl
                print("Connecting...");
                
                // Connect to peripheral and discover characteristics. This should not be needed but the Dfu library will fail if a previous characteristics discovery has not been done
                
                // Subscribe to Ble Notifications
                NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(dfuDidConnectToPeripheral(_:)), name: BleManager.BleNotifications.DidConnectToPeripheral.rawValue, object: nil)
                
                let blePeripheral = BlePeripheral(peripheral: peripheral, advertisementData: [:], RSSI: 0)
                BleManager.sharedInstance.connect(blePeripheral)
                dispatch_semaphore_wait(dfuSemaphore, DISPATCH_TIME_FOREVER)
            }
        }
        else {
            print("Error. No peripheral found with UUID: \(UUIDString)")
            dfuPeripheral = nil
        }
    }
    
    func dfuDidConnectToPeripheral(notification: NSNotification) {
         NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidConnectToPeripheral.rawValue, object: nil)
        
        guard let dfuPeripheral = dfuPeripheral  else {
            DLog("dfuDidConnectToPeripheral dfuPeripheral is nil")
            dfuFinished()
            return
        }
        
        print("Reading services and characteristics...");        
        self.firmwareUpdater.checkUpdatesForPeripheral(dfuPeripheral, delegate: self, showBetaVersions: true, shouldDiscoverServices: true)
    }

    private func dfuWithCurrentData() {
        
        // Check data
        guard let dfuPeripheral = dfuPeripheral  else {
            DLog("dfuDidConnectToPeripheral dfuPeripheral is nil")
            dfuFinished()
            return
        }
        
        guard let hexUrl = hexUrl else {
            DLog("dfuDidConnectToPeripheral hexPath is nil")
            dfuFinished()
            return
        }
        
        // Setup
        dfuUpdateProcess.delegate = self
        
        
        // Read hex
        guard let hexData = NSData(contentsOfURL: hexUrl) else {
            print("File not found: \(hexUrl)")
            return
        }
        
        // Read ini
        var iniData: NSData? = nil
        if let iniUrl = iniUrl {
            iniData = NSData(contentsOfURL: iniUrl)
            guard iniData != nil else {
                print("File not found: \(iniUrl)")
                return
            }
        }

        // Start dfu
        print("Updating...");
        let isOperationInProgress = dfuUpdateProcess.startDfuOperationBypassingChecksWithPeripheral(dfuPeripheral, hexData: hexData, iniData: iniData)
        if !isOperationInProgress {
            dfuFinished()
        }
        
    }
    
    private func dfuFinished() {
        dispatch_semaphore_signal(dfuSemaphore)
    }

}

// MARK: - DfuUpdateProcessDelegate
extension CommandLine: DfuUpdateProcessDelegate {
    func onUpdateProcessSuccess() {
        BleManager.sharedInstance.restoreCentralManager()        
        
        print("Update completed successfully")
        dfuFinished()
    }
    
    func onUpdateProcessError(errorMessage : String, infoMessage: String?) {
        BleManager.sharedInstance.restoreCentralManager()
        
        print(errorMessage)
        dfuFinished()
        
    }
    
    func onUpdateProgressText(message: String) {
        print("\t"+message)
    }
    
    func onUpdateProgressValue(progress : Double) {
        print(".", terminator: "")
    }
}


// MARK: - FirmwareUpdaterDelegate
extension CommandLine: FirmwareUpdaterDelegate {
    
    func onFirmwareUpdatesAvailable(isUpdateAvailable: Bool, latestRelease: FirmwareInfo!, deviceInfoData: DeviceInfoData!, allReleases: [NSObject : AnyObject]!) {
        
        DLog("onFirmwareUpdatesAvailable: \(isUpdateAvailable)")
        
        print("\tManufacturer: \(deviceInfoData.manufacturer)")
        print("\tModel:        \(deviceInfoData.modelNumber)")
        print("\tSoftware:     \(deviceInfoData.softwareRevision)")
        print("\tFirmware:     \(deviceInfoData.firmwareRevision)")
        print("\tBootlader:    \(deviceInfoData.bootloaderVersion())")
        
        guard deviceInfoData.hasDefaultBootloaderVersion() == false else {
            print("The legacy bootloader on this device is not compatible with this application")
            dfuFinished()
            return
        }
        
        dfuWithCurrentData()
    }
    
    func onDfuServiceNotFound() {
        print("DFU service not found")
             dfuFinished()

    }
    
}

